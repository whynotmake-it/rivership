import 'dart:async';
import 'dart:io';

import 'package:coil/coil.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:snaptest/snaptest.dart';

/// Loads coil's catalog fonts (Allo, Inter) from the coil example, like
/// coil's own test config, and the glass shaders when the engine can run
/// them (`flutter test --enable-impeller --enable-flutter-gpu`).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  SnaptestWidgetsFlutterBinding.ensureInitialized();
  await loadFonts();
  await _load('Allo', '../coil/example/fonts/allo/AlloVariable.ttf');
  await _load('Inter', '../coil/example/fonts/inter/InterVariable.ttf');
  CoilTypography.debugCheckFonts = false;
  await LiquidGlass.precache();
  setUp(CoilInputModality.debugReset);
  await testMain();
}

Future<void> _load(String family, String path) async {
  final bytes = File(path).readAsBytesSync();
  await (FontLoader(
    family,
  )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
}
