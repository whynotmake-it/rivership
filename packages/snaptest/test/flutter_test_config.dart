import 'dart:async';

import 'package:snaptest/snaptest.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await cleanSnaps();
  await loadFonts();

  return testMain();
}
