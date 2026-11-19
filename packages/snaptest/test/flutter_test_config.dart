import 'dart:async';

import 'package:snaptest/snaptest.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  SnaptestWidgetsFlutterBinding.ensureInitialized();
  // Files run concurrently; cleanup here can delete another test's output.
  await loadFonts();

  return testMain();
}
