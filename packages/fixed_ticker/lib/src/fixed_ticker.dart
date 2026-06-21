import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:meta/meta.dart';

/// A [Ticker] that optionally fires callbacks at a fixed interval using
/// [Timer.periodic], rather than being driven by the framework's vsync signal.
///
/// When [interval] is `null`, this behaves exactly like a normal [Ticker] —
/// callbacks fire every frame at the display's refresh rate. When [interval] is
/// set, callbacks fire at that fixed rate instead.
///
/// The [interval] is mutable: changing it at runtime switches between normal
/// and fixed-rate modes (or between different fixed rates) without recreating
/// the ticker or losing animation state.
///
/// ## Elapsed time in fixed-rate mode
///
/// The periodic timer does not compute elapsed time itself. Instead, each
/// timer tick schedules a frame callback through the parent [Ticker]. The
/// parent computes elapsed from Flutter's monotonic frame timestamp, so fixed
/// and normal modes use the same time source across mode switches.
///
/// ## Muting semantics
///
/// When muted (e.g. via `TickerMode`), the periodic timer is cancelled and no
/// callbacks fire. However, elapsed time **includes** the muted period — this
/// matches the behavior of the [Ticker] class, meaning an animation may jump
/// ahead when unmuted if enough frame time has passed.
///
/// ## Testing
///
/// In fixed-rate mode, timer ticks schedule frame callbacks. Widget tests
/// should use `tester.pump()` to advance both timers and frames.
///
/// **Important:** When using a fixed [interval], the standard
/// `tester.pumpAndSettle()` does **not** detect active [FixedTicker] timers.
/// Use `tester.pumpAndSettleFixedTickers()` from
/// `package:fixed_ticker/testing.dart` instead.
class FixedTicker extends Ticker {
  /// Creates a [FixedTicker].
  ///
  /// When [interval] is `null` (the default), this behaves like a normal
  /// [Ticker]. When set to a [Duration], callbacks fire at that fixed rate
  /// using [Timer.periodic].
  FixedTicker(
    super.onTick, {
    Duration? interval,
    super.debugLabel,
  }) : assert(
         interval == null || interval > Duration.zero,
         'interval must be positive when non-null, got $interval.',
       ),
       _interval = interval;

  /// The fixed interval between ticks, or `null` for normal vsync-driven
  /// ticking.
  ///
  /// Changing this while the ticker is active switches modes immediately:
  /// - `null` -> [Duration]: starts a periodic timer, parent frame callbacks
  ///   stop driving the animation.
  /// - [Duration] -> `null`: cancels the timer, parent frame callbacks resume.
  /// - [Duration] -> [Duration]: restarts the timer with the new interval.
  Duration? get interval => _interval;
  Duration? _interval;

  set interval(Duration? value) {
    assert(
      value == null || value > Duration.zero,
      'interval must be positive when non-null, got $value.',
    );
    if (_interval == value) return;
    final wasFixed = _interval != null;
    _interval = value;

    if (!isActive || muted) return;

    if (value != null) {
      _restartTimer(value);
    } else if (wasFixed) {
      _stopTimer();
    }

    if (shouldScheduleTick) {
      super.scheduleTick();
    }
  }

  Timer? _timer;

  static int _activeCount = 0;

  /// Whether any [FixedTicker] instance currently has an active timer.
  ///
  /// Used by the `pumpAndSettleFixedTickers` test utility to determine when
  /// all fixed-rate animations have completed.
  @visibleForTesting
  static bool get hasActiveTimers => _activeCount > 0;

  @override
  void scheduleTick({bool rescheduling = false}) {
    if (_interval != null) {
      if (rescheduling) {
        return;
      }
      _startTimer(_interval!);
      if (shouldScheduleTick) {
        super.scheduleTick(rescheduling: rescheduling);
      }
    } else {
      super.scheduleTick(rescheduling: rescheduling);
    }
  }

  @override
  void unscheduleTick() {
    _stopTimer();
    super.unscheduleTick();
  }

  void _startTimer(Duration interval) {
    if (_timer?.isActive ?? false) return;
    _timer = Timer.periodic(interval, _handleTimerTick);
    _activeCount++;
  }

  void _restartTimer(Duration interval) {
    if (_timer?.isActive ?? false) {
      _timer!.cancel();
      _timer = Timer.periodic(interval, _handleTimerTick);
    } else {
      _startTimer(interval);
    }
  }

  void _stopTimer() {
    if (_timer?.isActive ?? false) {
      _timer!.cancel();
      _activeCount--;
    }
    _timer = null;
  }

  void _handleTimerTick(Timer timer) {
    if (shouldScheduleTick) {
      super.scheduleTick();
    }
  }
}
