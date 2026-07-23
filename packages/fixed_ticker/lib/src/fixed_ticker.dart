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
/// Fixed-rate tickers share a phase-aligned scheduler by default. Tickers with
/// equal intervals request frames together, while intervals that are exact
/// multiples naturally meet on the same scheduler boundaries. Set [shared] to
/// `false` to retain an independent periodic timer for a ticker.
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
    bool shared = true,
    super.debugLabel,
  }) : assert(
         interval == null || interval > Duration.zero,
         'interval must be positive when non-null, got $interval.',
       ),
       _interval = interval,
       _shared = shared;

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

  /// Whether fixed-rate ticks use the shared, phase-aligned scheduler.
  ///
  /// This is `true` by default. Set it to `false` when this ticker needs an
  /// independent timer and phase. Changing it while active takes effect
  /// immediately without changing elapsed-time semantics.
  bool get shared => _shared;
  bool _shared;

  set shared(bool value) {
    if (_shared == value) return;
    _stopTimer();
    _shared = value;

    if (!isActive || muted || _interval == null) return;

    _startTimer(_interval!);
    if (shouldScheduleTick) {
      super.scheduleTick();
    }
  }

  Timer? _timer;

  static int _activeCount = 0;
  static final _sharedScheduler = _SharedTickScheduler();

  /// Whether any [FixedTicker] instance currently has an active timer.
  ///
  /// Used by the `pumpAndSettleFixedTickers` test utility to determine when
  /// all fixed-rate animations have completed.
  @visibleForTesting
  static bool get hasActiveTimers =>
      _activeCount > 0 || _sharedScheduler.hasSubscribers;

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
    if (_shared) {
      _sharedScheduler.subscribe(this, interval);
      return;
    }
    if (_timer?.isActive ?? false) return;
    _timer = Timer.periodic(interval, _handleTimerTick);
    _activeCount++;
  }

  void _restartTimer(Duration interval) {
    if (_shared) {
      _sharedScheduler.subscribe(this, interval);
      return;
    }
    if (_timer?.isActive ?? false) {
      _timer!.cancel();
      _timer = Timer.periodic(interval, _handleTimerTick);
    } else {
      _startTimer(interval);
    }
  }

  void _stopTimer() {
    _sharedScheduler.unsubscribe(this);
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

  void _handleSharedTick() {
    if (shouldScheduleTick) {
      super.scheduleTick();
    }
  }
}

class _SharedTickScheduler {
  final Map<FixedTicker, _SharedTickGroup> _tickerGroups =
      <FixedTicker, _SharedTickGroup>{};
  final Set<_SharedTickGroup> _groups = <_SharedTickGroup>{};

  bool get hasSubscribers => _tickerGroups.isNotEmpty;

  void subscribe(FixedTicker ticker, Duration interval) {
    final existingGroup = _tickerGroups[ticker];
    if (existingGroup?.intervalFor(ticker) == interval) return;
    unsubscribe(ticker);

    _SharedTickGroup? group;
    for (final candidate in _groups) {
      if (candidate.canUse(interval)) {
        group = candidate;
        break;
      }
    }
    group ??= _SharedTickGroup(this, interval)..start();
    _groups.add(group);
    group.add(ticker, interval);
    _tickerGroups[ticker] = group;
  }

  void unsubscribe(FixedTicker ticker) {
    final group = _tickerGroups.remove(ticker);
    group?.remove(ticker);
  }

  void removeGroup(_SharedTickGroup group) {
    _groups.remove(group);
  }
}

class _SharedTickGroup {
  _SharedTickGroup(this.scheduler, this.baseInterval);

  final _SharedTickScheduler scheduler;
  Duration baseInterval;
  final Map<FixedTicker, _SharedTickSubscription> _subscriptions =
      <FixedTicker, _SharedTickSubscription>{};

  Timer? _timer;
  int _tick = 0;

  bool canUse(Duration interval) {
    final baseMicroseconds = baseInterval.inMicroseconds;
    final intervalMicroseconds = interval.inMicroseconds;
    return intervalMicroseconds % baseMicroseconds == 0 ||
        baseMicroseconds % intervalMicroseconds == 0;
  }

  Duration? intervalFor(FixedTicker ticker) {
    return _subscriptions[ticker]?.interval;
  }

  void start() {
    _timer = Timer.periodic(baseInterval, _handleTick);
  }

  void add(FixedTicker ticker, Duration interval) {
    if (baseInterval.inMicroseconds % interval.inMicroseconds == 0 &&
        baseInterval != interval) {
      _rebase(interval);
    }

    final tickMultiple = interval.inMicroseconds ~/ baseInterval.inMicroseconds;
    _subscriptions[ticker] = _SharedTickSubscription(
      interval,
      tickMultiple,
      (_tick ~/ tickMultiple + 1) * tickMultiple,
    );
  }

  void remove(FixedTicker ticker) {
    _subscriptions.remove(ticker);
    if (_subscriptions.isEmpty) {
      _timer?.cancel();
      _timer = null;
      scheduler.removeGroup(this);
    }
  }

  void _rebase(Duration interval) {
    _timer?.cancel();
    baseInterval = interval;
    _tick = 0;
    for (final subscription in _subscriptions.values) {
      subscription.tickMultiple =
          subscription.interval.inMicroseconds ~/ interval.inMicroseconds;
      subscription.nextTick = subscription.tickMultiple;
    }
    start();
  }

  void _handleTick(Timer timer) {
    _tick++;
    final dueTickers = <FixedTicker>[];

    for (final MapEntry(key: ticker, value: subscription)
        in _subscriptions.entries) {
      if (subscription.nextTick != _tick) continue;

      dueTickers.add(ticker);
      subscription.nextTick += subscription.tickMultiple;
    }

    for (final ticker in dueTickers) {
      if (_subscriptions.containsKey(ticker)) {
        ticker._handleSharedTick();
      }
    }
  }
}

class _SharedTickSubscription {
  _SharedTickSubscription(this.interval, this.tickMultiple, this.nextTick);

  final Duration interval;
  int tickMultiple;
  int nextTick;
}
