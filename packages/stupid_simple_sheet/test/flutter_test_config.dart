import 'dart:async';

import 'package:snaptest/snaptest.dart';

/// Installs the recording-capable test binding before anything else can
/// initialize a binding. The binding is inert when no recording is active,
/// so existing tests are unaffected.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  SnaptestWidgetsFlutterBinding.ensureInitialized();
  await loadFonts();
  await testMain();
}
