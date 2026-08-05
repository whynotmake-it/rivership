import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:snaptest/src/flutter_sdk_root.dart';
import 'package:snaptest/src/snap.dart';

@internal
const supportedFontExtensions = {'.ttf', '.otf', '.ttc'};

/// Controls how Cupertino system fonts (`CupertinoSystemText` and
/// `CupertinoSystemDisplay`) are loaded for screenshot rendering.
///
/// These font families are used by Flutter's Material iOS typography and
/// Cupertino widgets. Choosing the same font on all platforms ensures
/// golden tests produce identical images everywhere.
///
/// See also:
///
///  * [loadFonts], which accepts a [CupertinoFontConfig].
sealed class CupertinoFontConfig {
  const CupertinoFontConfig();

  /// Loads Apple's SF Pro fonts from `/Library/Fonts` on macOS.
  ///
  /// This provides the most accurate rendering for Cupertino widgets but
  /// only works on macOS with SF Pro installed. Throws a
  /// [StateError] if the fonts are not found or the platform is not macOS.
  ///
  /// Set [fallbackOverride] to silently fall back to a different
  /// font instead of throwing. For example:
  ///
  /// ```dart
  /// await loadFonts(
  ///   cupertinoFonts: CupertinoFontConfig.fromMacOsSystemFonts(
  ///     fallbackOverrideFontFamily: 'Roboto',
  ///   ),
  /// );
  /// ```
  ///
  /// **Note:** Using this option means golden images generated on macOS will
  /// differ from those generated on other platforms. Only use this for
  /// visual debugging screenshots, not for golden tests that run on CI.
  const factory CupertinoFontConfig.fromMacOsSystemFonts({
    String? fallbackOverride,
  }) = _MacOsCupertinoFonts;

  /// Overrides `CupertinoSystemText` and `CupertinoSystemDisplay` with the
  /// given [fontFamily].
  ///
  /// Defaults to `'Roboto'`, which is loaded from the Flutter SDK's bundled
  /// material fonts. For a custom font family, make sure it is already
  /// loaded (e.g. via your `pubspec.yaml` fonts section) before calling
  /// [loadFonts].
  const factory CupertinoFontConfig.override({String fontFamily}) =
      _OverrideCupertinoFonts;
}

class _MacOsCupertinoFonts extends CupertinoFontConfig {
  const _MacOsCupertinoFonts({this.fallbackOverride});

  /// The font family to use as a fallback if SF Pro is not found or we are not
  /// on macOS.
  ///
  /// When `null` (the default), a [StateError] is thrown instead of falling
  /// back. Set this to e.g. `'Roboto'` to silently fall back, but be aware
  /// that golden images will differ between platforms.
  final String? fallbackOverride;
}

class _OverrideCupertinoFonts extends CupertinoFontConfig {
  const _OverrideCupertinoFonts({this.fontFamily = 'Roboto'});

  final String fontFamily;
}

/// Loads fonts and icons required for consistent screenshot rendering.
///
/// This function ensures that all fonts (including system fonts) and icons
/// are properly loaded before taking screenshots. It should be called once
/// before running any tests that use [snap] to ensure consistent text
/// rendering across all screenshots.
///
/// ## Cupertino Fonts
///
/// By default, Cupertino system fonts are overridden with Roboto to ensure
/// consistent rendering across macOS, Linux, and Windows. Pass
/// [cupertinoFonts] to customize this behavior:
///
/// ```dart
/// // Use SF Pro on macOS for visual debugging (not recommended for goldens)
/// await loadFonts(
///   cupertinoFonts: CupertinoFontConfig.fromMacOsSystemFonts(),
/// );
///
/// // Use a custom font (must be declared in pubspec.yaml)
/// await loadFonts(
///   cupertinoFonts: CupertinoFontConfig.override(fontFamily: 'Inter'),
/// );
/// ```
///
/// **Important**: Once fonts are loaded, they cannot be unloaded due to
/// Flutter's limitations. This means that if [loadFonts] is called
/// during one test, all subsequent tests in the same test run will use the
/// loaded fonts, which may cause text to render differently than in a fresh
/// test environment.
///
/// You can work around this limitation by using [Snap.golden], instead of
/// [matchesGoldenFile], which will block out all text independent of the
/// loaded fonts.
///
/// The function is idempotent - calling it multiple times has no additional
/// effect after the first call.
Future<void> loadFonts({
  CupertinoFontConfig cupertinoFonts = const CupertinoFontConfig.override(),
}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await _defaultFontLoading.load(cupertinoFonts);
}

/// Loads fonts from the given [fromPaths] into the Flutter engine under the
/// specified [family].
Future<void> loadFont(String family, List<String> fromPaths) =>
    _defaultBinaryLoader.load(family, fromPaths);

/// Reads font bytes and submits one complete family to Flutter.
///
/// The collaborators are injectable so path selection and registration can be
/// tested without mutating Flutter's process-wide font collection.
@internal
class FontBinaryLoader {
  FontBinaryLoader({
    required this.fileExists,
    required this.readFile,
    required this.readBundle,
    required this.register,
    required this.runAsync,
    void Function(String message)? log,
  }) : log = log ?? debugPrint;

  final bool Function(String path) fileExists;
  final Future<ByteData> Function(String path) readFile;
  final Future<ByteData> Function(String path) readBundle;
  final Future<void> Function(String family, List<ByteData> fonts) register;
  final Future<T?> Function<T>(Future<T> Function() operation) runAsync;
  final void Function(String message) log;

  Future<void> load(String family, List<String> paths) async {
    if (paths.isEmpty) return;

    await runAsync<void>(() async {
      final binaries = <ByteData>[];
      for (final path in paths) {
        try {
          binaries.add(
            await (fileExists(path) ? readFile(path) : readBundle(path)),
          );
        } on Object catch (error) {
          log('Could not load font $path: $error');
        }
      }
      await register(family, binaries);
    });
  }
}

/// One family and the assets from which it should be registered.
@immutable
@internal
class FontRegistration {
  const FontRegistration(this.family, this.assets);

  final String family;
  final List<String> assets;

  @override
  bool operator ==(Object other) =>
      other is FontRegistration &&
      family == other.family &&
      listEquals(assets, other.assets);

  @override
  int get hashCode => Object.hash(family, Object.hashAll(assets));
}

/// A decoded family in Flutter's generated font manifest.
@immutable
@internal
class FontManifestEntry {
  const FontManifestEntry(this.family, this.assets);

  final String family;
  final List<String> assets;
}

/// Material families bundled in a Flutter SDK.
@immutable
@internal
class MaterialFontInventory {
  const MaterialFontInventory({
    required this.roboto,
    required this.robotoCondensed,
    required this.materialIcons,
  });

  final List<String> roboto;
  final List<String> robotoCondensed;
  final List<String> materialIcons;
}

/// Groups supported files by their SDK family naming conventions.
@internal
MaterialFontInventory discoverMaterialFonts(Iterable<String> paths) {
  final roboto = <String>[];
  final condensed = <String>[];
  final icons = <String>[];

  for (final path in paths) {
    if (!_hasSupportedExtension(path)) continue;
    final name = basename(path).toLowerCase();
    if (name.startsWith('roboto-')) {
      roboto.add(path);
    } else if (name.startsWith('robotocondensed-')) {
      condensed.add(path);
    } else if (name.startsWith('materialicons')) {
      icons.add(path);
    }
  }

  return MaterialFontInventory(
    roboto: roboto,
    robotoCondensed: condensed,
    materialIcons: icons,
  );
}

/// Decodes Flutter's generated `FontManifest.json`.
@internal
List<FontManifestEntry> decodeFontManifest(String content) {
  if (content.trim().isEmpty) return const [];

  final decoded = jsonDecode(content);
  if (decoded is! List<Object?>) {
    throw const FormatException('FontManifest.json must contain a list.');
  }

  return [
    for (final item in decoded)
      if (item case {
        'family': final String family,
        'fonts': final List<Object?> fonts,
      })
        FontManifestEntry(family, [
          for (final font in fonts)
            if (font case {'asset': final String asset}) asset,
        ]),
  ];
}

/// Expands package fonts into the names Flutter may use at runtime.
@internal
List<FontRegistration> fontRegistrationsForManifest(
  Iterable<FontManifestEntry> entries,
) {
  final registrations = <FontRegistration>[];
  for (final entry in entries) {
    final packageAsset = entry.assets.where(_isPackageAsset).firstOrNull;
    if (packageAsset == null) {
      registrations.add(FontRegistration(entry.family, entry.assets));
      continue;
    }

    final segments = packageAsset.split('/');
    final package = segments.length > 1 ? segments[1] : null;
    if (package == null || package.isEmpty) {
      registrations.add(FontRegistration(entry.family, entry.assets));
      continue;
    }

    final unqualifiedFamily = entry.family.split('/').last;
    registrations
      ..add(FontRegistration(unqualifiedFamily, entry.assets))
      ..add(
        FontRegistration(
          'packages/$package/$unqualifiedFamily',
          entry.assets,
        ),
      );
  }
  return registrations;
}

/// Returns every manifest asset matching an unqualified family name.
@internal
List<String> fontAssetsForFamily(
  Iterable<FontManifestEntry> entries,
  String family,
) => [
  for (final entry in entries)
    if (entry.family == family || entry.family.endsWith('/$family'))
      ...entry.assets,
];

/// Coordinates SDK, manifest, and Cupertino font registration.
@internal
class FontLoadingOrchestrator {
  FontLoadingOrchestrator({
    required this.sdkRoot,
    required this.isMacOS,
    required this.readManifest,
    required this.listFontFiles,
    required this.loadFamily,
    void Function(String message)? log,
  }) : log = log ?? debugPrint;

  final Directory Function() sdkRoot;
  final bool isMacOS;
  final Future<String?> Function() readManifest;
  final List<String> Function(
    Directory directory, {
    required bool recursive,
  })
  listFontFiles;
  final Future<void> Function(String family, List<String> paths) loadFamily;
  final void Function(String message) log;

  bool _loaded = false;

  Future<void> load([
    CupertinoFontConfig cupertinoFonts = const CupertinoFontConfig.override(),
  ]) async {
    if (_loaded) return;

    final materialDirectory = Directory(
      join(
        sdkRoot().absolute.path,
        'bin',
        'cache',
        'artifacts',
        'material_fonts',
      ),
    );
    final material = discoverMaterialFonts(
      listFontFiles(materialDirectory, recursive: false),
    );
    await _registerMaterialFonts(material);

    final manifest = decodeFontManifest(await readManifest() ?? '');
    for (final registration in fontRegistrationsForManifest(manifest)) {
      await loadFamily(registration.family, registration.assets);
    }

    await _configureCupertino(cupertinoFonts, material, manifest);
    _loaded = true;
  }

  Future<void> _registerMaterialFonts(MaterialFontInventory material) async {
    await loadFamily('Roboto', material.roboto);
    await loadFamily('RobotoCondensed', material.robotoCondensed);
    await loadFamily('MaterialIcons', material.materialIcons);
  }

  Future<void> _configureCupertino(
    CupertinoFontConfig configuration,
    MaterialFontInventory material,
    List<FontManifestEntry> manifest,
  ) async {
    switch (configuration) {
      case _OverrideCupertinoFonts(:final fontFamily):
        await _registerCupertinoOverride(fontFamily, material, manifest);
      case _MacOsCupertinoFonts(:final fallbackOverride):
        final systemFonts = isMacOS ? _findMacOsSystemFonts() : null;
        if (systemFonts != null) {
          await loadFamily('CupertinoSystemText', systemFonts.text);
          await loadFamily('CupertinoSystemDisplay', systemFonts.display);
          return;
        }
        if (fallbackOverride == null) {
          throw StateError(
            'CupertinoFontConfig.fromMacOsSystemFonts() could not find both '
            'SF Pro Text and SF Pro Display in /Library/Fonts. Install them '
            'from https://developer.apple.com/fonts/ or configure a fallback.',
          );
        }
        await _registerCupertinoOverride(
          fallbackOverride,
          material,
          manifest,
        );
    }
  }

  Future<void> _registerCupertinoOverride(
    String family,
    MaterialFontInventory material,
    List<FontManifestEntry> manifest,
  ) async {
    final assets = family == 'Roboto'
        ? material.roboto
        : fontAssetsForFamily(manifest, family);
    if (assets.isEmpty) {
      log(
        'Warning: No font assets found for "$family". '
        'Make sure it is declared in pubspec.yaml.',
      );
      return;
    }
    await loadFamily('CupertinoSystemText', assets);
    await loadFamily('CupertinoSystemDisplay', assets);
  }

  _MacOsSystemFonts? _findMacOsSystemFonts() {
    final candidates = listFontFiles(
      Directory('/Library/Fonts'),
      recursive: true,
    );
    final text = <String>[];
    final display = <String>[];
    for (final path in candidates) {
      if (!_hasSupportedExtension(path)) continue;
      final name = basename(path).toLowerCase();
      if (name.startsWith('sf-pro-text')) {
        text.add(path);
      } else if (name.startsWith('sf-pro-display')) {
        display.add(path);
      }
    }
    if (text.isEmpty || display.isEmpty) return null;
    return _MacOsSystemFonts(text: text, display: display);
  }
}

class _MacOsSystemFonts {
  const _MacOsSystemFonts({required this.text, required this.display});

  final List<String> text;
  final List<String> display;
}

bool _hasSupportedExtension(String path) =>
    supportedFontExtensions.contains(extension(path).toLowerCase());

bool _isPackageAsset(String path) => path.startsWith('packages/');

List<String> _listFiles(Directory directory, {required bool recursive}) =>
    directory
        .listSync(recursive: recursive)
        .whereType<File>()
        .map((file) => file.path)
        .toList();

Future<ByteData> _readFile(String path) async {
  final bytes = await File(path).readAsBytes();
  return bytes.buffer.asByteData(bytes.offsetInBytes, bytes.lengthInBytes);
}

Future<void> _registerFontFamily(
  String family,
  List<ByteData> fonts,
) async {
  final loader = FontLoader(family);
  for (final font in fonts) {
    loader.addFont(Future.value(font));
  }
  await loader.load();
}

final _defaultBinaryLoader = FontBinaryLoader(
  fileExists: (path) => File(path).existsSync(),
  readFile: _readFile,
  readBundle: rootBundle.load,
  register: _registerFontFamily,
  runAsync: maybeRunAsync,
);

final _defaultFontLoading = FontLoadingOrchestrator(
  sdkRoot: flutterSdkRoot,
  isMacOS: Platform.isMacOS,
  readManifest: () => maybeRunAsync(
    () => rootBundle.loadString('FontManifest.json'),
  ),
  listFontFiles: _listFiles,
  loadFamily: loadFont,
);
