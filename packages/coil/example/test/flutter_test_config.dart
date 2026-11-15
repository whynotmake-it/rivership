import 'dart:async';

import 'package:snaptest/snaptest.dart';

/// Loads the real fonts (Inter, Lucide) so layout and overflow checks
/// measure the text the app shows, not Ahem boxes.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await loadFonts();
  await testMain();
}
