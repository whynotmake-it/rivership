import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart';
import 'package:snaptest/src/flutter_sdk_root.dart';
import 'package:snaptest/src/snap.dart';

@internal
const fontFormats = ['.ttf', '.otf', '.ttc'];

bool _fontsLoaded = false;

/// Loads fonts and icons required for consistent screenshot rendering.
///
/// This function ensures that all fonts (including system fonts) and icons
/// are properly loaded before taking screenshots. It should be called once
/// before running any tests that use [snap] to ensure consistent text
/// rendering across all screenshots.
///
/// **Important**: Once fonts are loaded, they cannot be unloaded due to
/// Flutter's limitations. This means that if [loadFontsAndIcons] is called
/// during one test, all subsequent tests in the same test run will use the
/// loaded fonts, which may cause text to render differently than in a fresh
/// test environment.
///
/// You can work around this limitation by using [snap] with `matchToGolden`
/// set to `true`, instead of [matchesGoldenFile], which will block out all
/// text independent of the loaded fonts.
///
/// ## What it does
///
/// - Loads all application fonts defined in `pubspec.yaml`
/// - If running on macOS, attempts to load SF Pro fonts for accurate Cupertino
///   widget rendering. You can download these fonts from Apple's developer
///   site:
///   https://developer.apple.com/fonts/
/// - If SF Pro fonts are not available, falls back to using Roboto fonts
///   for Cupertino widgets
/// - Ensures icons are properly loaded for rendering
///
/// The function is idempotent - calling it multiple times has no additional
/// effect after the first call.
Future<void> loadFontsAndIcons() async {
  if (_fontsLoaded) return;

  await _loadMaterialFontsFromSdk();
  await _loadFontsFromFontManifest();

  try {
    await _loadMacOSFonts();
  } on MacOsFontLoadException catch (_) {
    await _overrideCupertinoFonts();
  }

  _fontsLoaded = true;
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
      } catch (e, _) {
        debugPrint("Could not load font $path: $e");
      }
    }

    await fontLoader.load();
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

Future<void> _overrideCupertinoFonts() async {
  final root = flutterSdkRoot().absolute.path;

  final materialFontsDir = Directory(
    '$root/bin/cache/artifacts/material_fonts/',
  );

  final existingFonts = materialFontsDir
      .listSync()
      .whereType<File>()
      .where(
        (font) => fontFormats.any((element) => font.path.endsWith(element)),
      )
      .toList();

  final robotoFonts = existingFonts
      .where((font) {
        final name = basename(font.path).toLowerCase();
        return name.startsWith('Roboto-'.toLowerCase());
      })
      .map((file) => file.path)
      .toList();
  if (robotoFonts.isEmpty) {
    debugPrint("Warning: No Roboto font found in SDK");
  }
  await loadFont('CupertinoSystemText', robotoFonts);
  await loadFont('CupertinoSystemDisplay', robotoFonts);
}

Future<void> _loadMacOSFonts() async {
  if (!Platform.isMacOS) {
    throw MacOsFontLoadException(
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

    throw MacOsFontLoadException('SF Pro fonts not found on macOS');
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

@internal
class MacOsFontLoadException implements Exception {
  MacOsFontLoadException(this.message);

  final String message;

  @override
  String toString() => 'CupertinoFontLoadException: $message';
}
