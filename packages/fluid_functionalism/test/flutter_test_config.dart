import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:snaptest/snaptest.dart';

/// Loads real fonts so goldens show Inter instead of Ahem boxes.
///
/// When this package is the root package its FontManifest declares the font
/// without a package prefix, but components ask for
/// `packages/fluid_functionalism/Inter`, so that name is loaded explicitly.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await loadFonts();
  final bytes = File('fonts/InterVariable.ttf').readAsBytesSync();
  await (FontLoader(
    'packages/fluid_functionalism/Inter',
  )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  await testMain();
}
