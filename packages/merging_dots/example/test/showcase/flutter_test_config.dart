import 'dart:async';

import 'package:snaptest/snaptest.dart';

/// Installs the recording binding and real fonts for the showcase.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  SnaptestWidgetsFlutterBinding.ensureInitialized();
  await loadFonts();
  await testMain();
}
