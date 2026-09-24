/// Tracks how many fixed-rate tickers are currently waiting on a `Timer`,
/// either their own or a shared one.
///
/// Kept in its own library (not exported by `package:fixed_ticker`) so the
/// ticker and the testing utilities can share the count without either one
/// depending on a `@visibleForTesting` member.
abstract final class ActiveTimerRegistry {
  static int _count = 0;

  /// Whether any fixed-rate ticker currently has an active timer.
  static bool get hasActiveTimers => _count > 0;

  /// Records that a fixed-rate ticker started a timer.
  static void increment() => _count++;

  /// Records that a fixed-rate ticker stopped a timer.
  static void decrement() {
    assert(_count > 0, 'decrement called without a matching increment');
    _count--;
  }
}
