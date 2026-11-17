import 'dart:async';
import 'dart:io';

import 'package:coil/coil.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snaptest/snaptest.dart';

/// Loads real fonts so goldens and text measurements use Allo and Inter
/// instead of Ahem boxes.
///
/// coil bundles no font, so the catalog's fonts are loaded from the example
/// under the family names [CoilTypography.allo] and [CoilTypography.inter]
/// use. The asset manifest doesn't know fonts loaded this way, so the
/// typography's bundled-font check is off.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Inert unless a test records a video with `snap.recordVideo()`.
  SnaptestWidgetsFlutterBinding.ensureInitialized();
  await loadFonts();
  await _load('Allo', 'example/fonts/allo/AlloVariable.ttf');
  await _load('Inter', 'example/fonts/inter/InterVariable.ttf');
  CoilTypography.debugCheckFonts = false;
  // Fresh input-modality tracking (keyboard vs pointer) for every test.
  setUp(CoilInputModality.debugReset);
  await testMain();
}

Future<void> _load(String family, String path) async {
  final bytes = File(path).readAsBytesSync();
  await (FontLoader(
    family,
  )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
}
