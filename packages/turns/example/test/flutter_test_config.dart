import 'dart:async';
import 'dart:io';

import 'package:coil/coil.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snaptest/snaptest.dart';

/// Configures `snaptest` video/screenshot recording and loads real typography
/// (Allo, Inter, JetBrains Mono, plus Lucide via [loadFonts]) so tests and
/// recordings render crisp text instead of Ahem boxes.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Inert unless a test records a video with `snap.recordVideo()`.
  SnaptestWidgetsFlutterBinding.ensureInitialized();
  await loadFonts();
  await _loadFont('Allo', 'allo/AlloVariable.ttf');
  await _loadFont('Inter', 'inter/InterVariable.ttf');
  await _loadFont('JetBrains Mono', 'jetbrains_mono/JetBrainsMonoVariable.ttf');
  await _loadFont('monospace', 'jetbrains_mono/JetBrainsMonoVariable.ttf');
  CoilTypography.debugCheckFonts = false;
  // Fresh input-modality tracking (keyboard vs pointer) for every test.
  setUp(CoilInputModality.debugReset);
  await testMain();
}

Future<void> _loadFont(String family, String relativePath) async {
  final file = _resolveFontFile(relativePath);
  if (file == null) {
    throw StateError('Could not locate font asset "$relativePath".');
  }
  final bytes = file.readAsBytesSync();
  await (FontLoader(
    family,
  )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
}

File? _resolveFontFile(String relativePath) {
  for (final prefix in const [
    '../../coil/example/lib/fonts/',
    'packages/coil/example/lib/fonts/',
  ]) {
    final file = File('$prefix$relativePath');
    if (file.existsSync()) return file;
  }
  return null;
}
