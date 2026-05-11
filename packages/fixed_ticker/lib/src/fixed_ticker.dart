import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/scheduler.dart';
import 'package:meta/meta.dart';

/// A [Ticker] that fires callbacks at a fixed interval using
/// [Timer.periodic], rather than being driven by the framework's vsync signal.
///
/// ## When to use FixedTicker vs regular Ticker
///
/// Use [FixedTicker] when you want animations to run at a **lower, fixed
/// frame rate** (e.g. 30fps or 10fps) instead of the display's native refresh
/// rate. This is useful for:
/// - Reducing CPU/GPU load for non-critical animations
/// - Achieving a specific visual cadence (e.g. retro-style animation)
/// - Background or secondary animations that don't need 60/120fps
///
/// Use a regular [Ticker] (via `SingleTickerProviderStateMixin`) when you need
/// the smoothest possible animation tied to the display refresh rate.
///
/// ## Drift guarantees
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
/// matches the behavior of the parent [Ticker] class, meaning an animation may
/// complete instantly when unmuted if enough wall-clock time has passed.
///
/// ## Testing
///
/// [FixedTicker] works automatically in both `fakeAsync` and `testWidgets`
/// without any extra setup. `clock.now()` from `package:clock` is
/// automatically faked by both `FakeAsync.run` and the Flutter test binding's
/// internal `FakeAsync`, so elapsed values are deterministic in tests.
///
/// **Important:** The standard `tester.pumpAndSettle()` does **not** detect
/// active [FixedTicker] timers. Use `tester.pumpAndSettleFixedTickers()` from
/// `package:fixed_ticker/testing.dart` instead.
class FixedTicker extends Ticker {
  /// Creates a [FixedTicker] that fires [onTick] every [interval].
  ///
  /// The default [interval] of 33ms corresponds to approximately 30fps.
  FixedTicker(
    TickerCallback onTick, {
    this.interval = const Duration(milliseconds: 33),
    String? debugLabel,
  }) : _onTick = onTick,
       // Pass a no-op to the parent so that when the framework's frame
       // callback fires (_tick), it sets the parent's private _startTime
       // (needed for absorbTicker) without invoking the real animation
       // callback. Our Timer.periodic is the sole source of onTick calls.
       super((_) {}, debugLabel: debugLabel);

  /// The fixed interval between ticks.
  final Duration interval;

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
  bool get scheduled => _timer?.isActive ?? false;

  @override
  bool get isTicking => isActive && !muted;

  @override
  TickerFuture start() {
    _startTime = null;
    _needsParentSync = true;
    return super.start();
  }

  @override
  void scheduleTick({bool rescheduling = false}) {
    assert(!scheduled, 'Cannot schedule a tick while already scheduled.');
    _startTime ??= clock.now();
    if (_needsParentSync) {
      // On the first scheduleTick of each animation cycle, register a frame
      // callback so the parent's _tick fires and sets its private _startTime.
      // This keeps the invariant that
      // (_future == null) == (_startTime == null),
      // which absorbTicker checks. The parent's _tick calls the no-op we
      // passed to super(), so the real animation callback is not invoked.
      // After _tick fires, shouldScheduleTick returns false (because our
      // scheduled override returns true), preventing re-entry.
      //
      // We only do this once per start() cycle — not on mute/unmute — because
      // a frame callback that fires after the animation completes would hit
      // the parent's assert(isTicking).
      _needsParentSync = false;
      super.scheduleTick(rescheduling: rescheduling);
    }
    _timer = Timer.periodic(interval, _handleTimerTick);
    _activeCount++;
  }

  @override
  void unscheduleTick() {
    if (scheduled) {
      _timer!.cancel();
      _timer = null;
      _activeCount--;
    }
    // Cancel any pending frame callback from the parent.
    super.unscheduleTick();
  }

  void _handleTimerTick(Timer timer) {
    _onTick(clock.now().difference(_startTime!));
  }
}
