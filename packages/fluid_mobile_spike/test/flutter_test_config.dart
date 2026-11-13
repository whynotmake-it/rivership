import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:snaptest/snaptest.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await loadFonts();
  // The goldens render real Inter. Register it under both names a style can
  // resolve to: the package-qualified family the library asks for, and the
  // bare family the package's own font manifest declares.
  final bytes = File('fonts/InterVariable.ttf').readAsBytesSync();
  for (final family in ['packages/fluid_mobile_spike/Inter', 'Inter']) {
    await (FontLoader(
      family,
    )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  }
  await testMain();
}
