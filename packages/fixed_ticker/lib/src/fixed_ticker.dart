import 'dart:async';

import 'package:clock/clock.dart';
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
/// ## Drift guarantees (fixed-rate mode)
///
/// Elapsed time is computed as `clock.now().difference(_startTime)` on every
/// tick, so there is **zero drift accumulation** regardless of timer jitter.
/// Each callback always receives the true wall-clock elapsed time since the
/// animation started.
///
/// ## Muting semantics
///
/// When muted (e.g. via `TickerMode`), the periodic timer is cancelled and no
/// callbacks fire. However, elapsed time **includes** the muted period — this
/// matches the behavior of the [Ticker] class, meaning an animation may
/// complete instantly when unmuted if enough wall-clock time has passed.
///
/// ## Testing
///
/// [FixedTicker] works automatically in both `fakeAsync` and `testWidgets`
/// without any extra setup. Elapsed values are deterministic in tests.
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
  })  : assert(
         interval == null || interval > Duration.zero,
         'interval must be positive when non-null, got $interval.',
       ),
       _onTick = onTick,
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

    if (_startTime != null) {
      debugPrint(
        '[FixedTicker] interval setter: switching to $value, '
        'elapsed=${clock.now().difference(_startTime!)}',
      );
    }

    if (!isActive || muted) return;

    if (value != null) {
      if (_timer != null && _timer!.isActive) {
        _timer!.cancel();
        _timer = Timer.periodic(value, _handleTimerTick);
      } else {
        _startTime ??= clock.now();
        if (!super.scheduled) {
          super.scheduleTick();
        }
        _timer = Timer.periodic(value, _handleTimerTick);
        _activeCount++;
      }
    } else if (wasFixed) {
      _timer!.cancel();
      _timer = null;
      _activeCount--;
      if (!super.scheduled) {
        super.scheduleTick();
      }
    }
  }

  final TickerCallback _onTick;
  Timer? _timer;
  DateTime? _startTime;
  bool _needsParentSync = false;

  static int _activeCount = 0;

  /// Whether any [FixedTicker] instance currently has an active timer.
  ///
  /// Used by the `pumpAndSettleFixedTickers` test utility to determine when
  /// all fixed-rate animations have completed.
  @visibleForTesting
  static bool get hasActiveTimers => _activeCount > 0;

  @override
  bool get scheduled => _interval != null
      ? ((_timer?.isActive ?? false) || super.scheduled)
      : super.scheduled;

  @override
  bool get isTicking =>
      _interval != null ? (isActive && !muted) : super.isTicking;

  @override
  TickerFuture start() {
    _startTime = null;
    _needsParentSync = true;
    return super.start();
  }

  @override
  void scheduleTick({bool rescheduling = false}) {
    if (_startTime == null) {
      _startTime = clock.now();
      debugPrint('[FixedTicker] scheduleTick: _startTime set to $_startTime');
    }
    if (_interval != null) {
      assert(!scheduled, 'Cannot schedule a tick while already scheduled.');
      if (_needsParentSync) {
        // Register a frame callback so the parent's _tick fires and sets its
        // private _startTime (needed for absorbTicker). The parent's _tick
        // calls the real callback with elapsed ≈ 0, then checks
        // shouldScheduleTick — which returns false because our scheduled
        // override reports the timer as active — preventing re-entry.
        _needsParentSync = false;
        super.scheduleTick(rescheduling: rescheduling);
      }
      _timer = Timer.periodic(_interval!, _handleTimerTick);
      _activeCount++;
    } else {
      super.scheduleTick(rescheduling: rescheduling);
    }
  }

  @override
  void unscheduleTick() {
    if (_timer != null && _timer!.isActive) {
      _timer!.cancel();
      _timer = null;
      _activeCount--;
    }
    if (super.scheduled) {
      _needsParentSync = true;
    }
    super.unscheduleTick();
  }

  @override
  void absorbTicker(Ticker originalTicker) {
    if (originalTicker is FixedTicker) {
      _startTime = originalTicker._startTime;
    }
    _needsParentSync = false;
    super.absorbTicker(originalTicker);
  }

  void _handleTimerTick(Timer timer) {
    final elapsed = clock.now().difference(_startTime!);
    debugPrint('[FixedTicker] _handleTimerTick: elapsed=$elapsed');
    _onTick(elapsed);
  }
}
