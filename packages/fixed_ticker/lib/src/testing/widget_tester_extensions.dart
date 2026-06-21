import 'package:fixed_ticker/src/fixed_ticker.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Extensions on [WidgetTester] for testing widgets that use [FixedTicker].
extension FixedTickerTesting on WidgetTester {
  /// Like [pumpAndSettle], but also waits for all [FixedTicker] instances to
  /// stop.
  ///
  /// Pumps in [duration] increments until **both**:
  /// - No scheduled frames remain (same as [pumpAndSettle])
  /// - No active [FixedTicker] timers exist
  ///
  /// Throws a [FlutterError] if [timeout] is exceeded (default 10 minutes,
  /// matching [pumpAndSettle]).
  ///
  /// Returns the number of frames pumped.
  Future<int> pumpAndSettleFixedTickers([
    Duration duration = const Duration(milliseconds: 100),
    Duration timeout = const Duration(minutes: 10),
  ]) async {
    var count = 0;
    final endTime = binding.clock.now().add(timeout);
    do {
      if (binding.clock.now().isAfter(endTime)) {
        throw FlutterError('pumpAndSettleFixedTickers timed out');
      }
      await pump(duration);
      count++;
    } while (binding.hasScheduledFrame || FixedTicker.hasActiveTimers);
    return count;
  }
}
