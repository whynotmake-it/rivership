import 'package:flutter/scheduler.dart';

/// A [TickerProvider] handing out plain [Ticker]s, used by both sides so
/// neither pays for test-only ticker bookkeeping.
class BenchVsync implements TickerProvider {
  const BenchVsync();

  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}

/// Produces frames by calling the scheduler directly.
///
/// Only [SchedulerBinding.handleBeginFrame] is timed: it runs every ticker
/// callback and the animation listeners they notify, which is the animation
/// engine's per-frame cost. [SchedulerBinding.handleDrawFrame] runs untimed to
/// finish the frame. No widget tree is mounted and `WidgetTester.pump` is not
/// involved, so the numbers are not dominated by test-harness work.
class FrameDriver {
  FrameDriver(this.binding);

  /// 60 Hz.
  static const frameInterval = Duration(microseconds: 16667);

  final SchedulerBinding binding;

  /// Timestamps start far ahead of any real engine frame and only increase.
  Duration _now = const Duration(days: 1000);

  /// Runs one frame, adding the time spent in the ticker phase to [timer].
  void frame([Stopwatch? timer]) {
    _now += frameInterval;
    timer?.start();
    binding.handleBeginFrame(_now);
    timer?.stop();
    binding.handleDrawFrame();
  }
}
