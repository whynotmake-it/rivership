// Portions of this file were adapted from passsy/spot v0.18.0
// (https://github.com/passsy/spot), Copyright 2022 Pascal Welsch, and were
// modified for Snaptest. Spot is licensed under the Apache License, Version
// 2.0. See LICENSE and NOTICE in the Snaptest package.

/// @docImport 'package:snaptest/src/snap.dart';
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart';
import 'package:snaptest/src/capture.dart';
import 'package:snaptest/src/flutter_sdk_root.dart';

@internal
const fontFormats = ['.ttf', '.otf', '.ttc'];

bool _fontsLoaded = false;
final _fontSources = <String, List<String>>{};
final _fontAliases = <String, String>{};
Future<void>? _pendingFontLoad;

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
/// ## Font aliases
///
/// [fontAliases] maps **alias → source family**, reusing all of the source's
/// font assets (including weight/style variants) under another family name:
///
/// ```dart
/// await loadFonts(fontAliases: {
///   'SanFranciscoPro': 'SF Pro', // SF Pro must be declared in pubspec.yaml.
///   'BrandText': 'Roboto',
///   'AnotherBrandText': 'Roboto',
/// });
/// ```
///
/// Sources can be SDK families or asset families, including
/// `packages/my_package/Family`. This does not discover installed fonts or
/// substitute a fallback: an unknown source or empty alias throws
/// [ArgumentError]. Replacing a loaded family or retargeting an alias throws
/// [StateError], because engine fonts cannot be unloaded.
///
/// Base fonts and [cupertinoFonts] are configured only on the first successful
/// call. Further calls can add aliases, including after test-suite setup has
/// already called [loadFonts]. Repeating the same alias is a no-op. Aliases in
/// one call must refer to already-loaded families, not each other.
Future<void> loadFonts({
  CupertinoFontConfig cupertinoFonts = const CupertinoFontConfig.override(),
  Map<String, String> fontAliases = const {},
}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final aliases = Map.of(fontAliases);
  final error = await maybeRunAsync(() async {
    final previous = _pendingFontLoad;
    final next = () async {
      await previous;
      await _loadFonts(cupertinoFonts, aliases);
    }();
    _pendingFontLoad = next.catchError((Object _) {});
    try {
      await next;
      return null;
    } on Object catch (error, stack) {
      return (error, stack);
    }
  });
  if (error != null) Error.throwWithStackTrace(error.$1, error.$2);
}

Future<void> _loadFonts(
  CupertinoFontConfig cupertinoFonts,
  Map<String, String> fontAliases,
) async {
  if (_fontsLoaded) {
    await _loadFontAliases(fontAliases);
    return;
  }

  await _loadMaterialFontsFromSdk();
  await _loadFontsFromFontManifest();
  await _loadFontAliases(fontAliases);

  switch (cupertinoFonts) {
    case _MacOsCupertinoFonts(
      fallbackOverride: final fallbackOverrideFontFamily,
    ):
      try {
        await _loadMacOSFonts();
      } on _MacOsFontLoadException catch (e) {
        if (fallbackOverrideFontFamily == null) {
          throw StateError(
            'CupertinoFontConfig.fromMacOsSystemFonts() failed: $e\n'
            'SF Pro fonts are only available on macOS with the fonts '
            'installed from https://developer.apple.com/fonts/.\n'
            'To use a fallback font instead, pass '
            'fallbackOverrideFontFamily, or use '
            'CupertinoFontConfig.override() for cross-platform consistency.',
          );
        }
        await _overrideCupertinoFontsWithFamily(fallbackOverrideFontFamily);
      }
    case _OverrideCupertinoFonts(:final fontFamily):
      await _overrideCupertinoFontsWithFamily(fontFamily);
  }

  _fontsLoaded = true;
}

Future<void> _loadFontAliases(Map<String, String> aliases) async {
  for (final MapEntry(key: alias, value: source) in aliases.entries) {
    if (alias.trim().isEmpty || !_fontSources.containsKey(source)) {
      throw ArgumentError.value(
        '$alias → $source',
        'fontAliases',
        'Use a nonempty alias and a loaded source family. '
            'Declare asset fonts in pubspec.yaml.',
      );
    }
    final existing = _fontAliases[alias];
    if ((existing != null && existing != source) ||
        (existing == null &&
            alias != source &&
            _fontSources.containsKey(alias))) {
      throw StateError(
        'Cannot replace loaded font family "$alias" with '
        '"$source": Flutter fonts cannot be unloaded.',
      );
    }
  }
  for (final MapEntry(key: alias, value: source) in aliases.entries) {
    if (alias == source || _fontAliases[alias] == source) continue;
    await loadFont(alias, _fontSources[source]!);
    _fontAliases[alias] = source;
  }
}

/// Loads fonts from the given [fromPaths] into the Flutter engine under the
/// specified [family].
Future<void> loadFont(String family, List<String> fromPaths) async {
  if (fromPaths.isEmpty) {
    return;
  }

  await maybeRunAsync(() async {
    final fontLoader = FontLoader(family);
    for (final path in fromPaths) {
      try {
        final file = File(path);
        if (file.existsSync()) {
          final bytes = file.readAsBytesSync();
          fontLoader.addFont(Future.value(bytes.buffer.asByteData()));
        } else {
          final data = rootBundle.load(path);
          fontLoader.addFont(Future.value(data));
        }
      } catch (e) {
        debugPrint("Could not load font $path: $e");
      }
    }

    await fontLoader.load();
    _fontSources[family] = List.unmodifiable(fromPaths);
  });
}

Future<void> _loadMaterialFontsFromSdk() async {
  final root = flutterSdkRoot().absolute.path;

  final materialFontsDir = Directory(
    '$root/bin/cache/artifacts/material_fonts/',
  );

  final files = materialFontsDir.listSync().whereType<File>().toList();

  final robotoFonts = files
      .where((file) => file.isRobotoFont)
      .map((file) => file.path)
      .toList();

  await loadFont('Roboto', robotoFonts);

  final robotoCondensedFonts = files
      .where((file) => file.isRobotoCondensedFont)
      .map((file) => file.path)
      .toList();
  await loadFont('RobotoCondensed', robotoCondensedFonts);

  final materialIcons = files
      .where((file) => file.isMaterialIconsFont)
      .map((file) => file.path)
      .toList();
  await loadFont('MaterialIcons', materialIcons);
}

Future<void> _loadFontsFromFontManifest() async {
  final fontManifestContent = await maybeRunAsync(
    () => rootBundle.loadString('FontManifest.json'),
  );

  if (fontManifestContent == null || fontManifestContent.isEmpty) {
    return;
  }

  final fontManifestEntries = _parseFontManifest(fontManifestContent);

  for (final (family, assets) in fontManifestEntries) {
    final packageAsset = assets
        .where((it) => it.startsWith('packages/'))
        .firstOrNull;
    final packageName = packageAsset?.split('/')[1];

    if (packageName == null) {
      await loadFont(family, assets);
    } else {
      final fontFamilyName = family.split('/').last;
      // We load it both ways to cover both possibilities.
      await loadFont(fontFamilyName, assets);
      await loadFont('packages/$packageName/$fontFamilyName', assets);
    }
  }
}

List<(String, List<String>)> _parseFontManifest(String content) {
  final fonts = <(String, List<String>)>[];
  final json = jsonDecode(content) as List<dynamic>;
  for (final item in json) {
    if (item is! Map<String, dynamic>) {
      continue;
    }
    final family = item['family'] as String;
    final assets = (item['fonts'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map((font) => font['asset'] as String)
        .toList();
    fonts.add((family, assets));
  }
  return fonts;
}

Future<void> _overrideCupertinoFontsWithFamily(String fontFamily) async {
  final assets = _fontSources[fontFamily];
  if (assets == null || assets.isEmpty) {
    debugPrint(
      'Warning: No font assets found for "$fontFamily". '
      'Make sure it is declared in your pubspec.yaml.',
    );
    return;
  }

  await loadFont('CupertinoSystemText', assets);
  await loadFont('CupertinoSystemDisplay', assets);
}

Future<void> _loadMacOSFonts() async {
  if (!Platform.isMacOS) {
    throw _MacOsFontLoadException(
      '_loadMacOSFonts called on non-macOS platform',
    );
  }

  final base = Directory('/Library/Fonts');

  final sfProTextFonts = base
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.isSFProTextFont)
      .map((file) => file.path)
      .toList();

  final sfProDisplayFonts = base
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.isSFProDisplayFont)
      .map((file) => file.path)
      .toList();

  if (sfProTextFonts.isEmpty || sfProDisplayFonts.isEmpty) {
    debugPrint(
      "You are on macOS but no SF Pro fonts were found in "
      "/Library/Fonts. Please install them from Apple's developer site: https://developer.apple.com/fonts/",
    );

    throw _MacOsFontLoadException('SF Pro fonts not found on macOS');
  }

  await loadFont('CupertinoSystemText', sfProTextFonts);
  await loadFont('CupertinoSystemDisplay', sfProDisplayFonts);
}

extension on File {
  bool get isFont {
    final lower = path.toLowerCase();
    return fontFormats.any(lower.endsWith);
  }

  bool get isRobotoFont {
    if (!isFont) {
      return false;
    }
    final name = basename(path).toLowerCase();
    return name.startsWith('roboto-');
  }

  bool get isRobotoCondensedFont {
    if (!isFont) {
      return false;
    }
    final name = basename(path).toLowerCase();
    return name.startsWith('robotocondensed-');
  }

  bool get isMaterialIconsFont {
    if (!isFont) {
      return false;
    }
    final name = basename(path).toLowerCase();
    return name.startsWith('materialicons-');
  }

  bool get isSFProTextFont {
    if (!isFont) {
      return false;
    }
    final name = basename(path).toLowerCase();
    return name.startsWith('sf-pro-text');
  }

  bool get isSFProDisplayFont {
    if (!isFont) {
      return false;
    }
    final name = basename(path).toLowerCase();
    return name.startsWith('sf-pro-display');
  }
}

class _MacOsFontLoadException implements Exception {
  _MacOsFontLoadException(this.message);

  final String message;

  @override
  String toString() => 'MacOsFontLoadException: $message';
}
