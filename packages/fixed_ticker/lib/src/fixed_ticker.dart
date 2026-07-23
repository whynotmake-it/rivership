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
/// multiples naturally meet on the same scheduler boundaries. The scheduler
/// tolerates the bounded microsecond rounding introduced by FPS-derived
/// intervals. Set [shared] to `false` to retain an independent periodic timer.
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

    final compatibleGroups = _groups
        .where((candidate) => candidate.canUse(interval))
        .toList();
    final group = compatibleGroups.firstOrNull;
    final selectedGroup = group ?? (_SharedTickGroup(this, interval)..start());
    _groups.add(selectedGroup);
    selectedGroup.prepareBase(interval);
    for (final compatibleGroup in compatibleGroups.skip(1)) {
      selectedGroup.absorb(compatibleGroup);
    }
    selectedGroup.add(ticker, interval);
    _tickerGroups[ticker] = selectedGroup;
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
  Duration? _pendingBaseInterval;
  final Set<FixedTicker> _joinOnRebase = <FixedTicker>{};
  final Set<FixedTicker> _alignOnRebase = <FixedTicker>{};
  final Set<_SharedTickGroup> _groupsToAbsorbOnRebase = <_SharedTickGroup>{};
  final Map<FixedTicker, Timer> _pendingTimers = <FixedTicker, Timer>{};

  bool canUse(Duration interval) {
    final effectiveBase = _pendingBaseInterval ?? baseInterval;
    return _harmonicMultiple(interval, effectiveBase) != null ||
        _harmonicMultiple(effectiveBase, interval) != null;
  }

  Duration? intervalFor(FixedTicker ticker) {
    return _subscriptions[ticker]?.interval;
  }

  void start() {
    _timer = Timer.periodic(baseInterval, _handleTick);
  }

  void prepareBase(Duration interval) {
    final effectiveBase = _pendingBaseInterval ?? baseInterval;
    if (interval < effectiveBase &&
        _harmonicMultiple(effectiveBase, interval) != null) {
      _pendingBaseInterval = interval;
    }
  }

  void absorb(_SharedTickGroup other) {
    if (identical(this, other)) return;

    prepareBase(other._pendingBaseInterval ?? other.baseInterval);
    if (_pendingBaseInterval != null) {
      _groupsToAbsorbOnRebase.add(other);
      return;
    }
    _absorbNow(other);
  }

  void _absorbNow(_SharedTickGroup other) {
    other._timer?.cancel();
    other._timer = null;
    scheduler.removeGroup(other);

    for (final entry in other._subscriptions.entries) {
      final ticker = entry.key;
      final interval = entry.value.interval;
      prepareBase(interval);
      scheduler._tickerGroups[ticker] = this;
      if (_pendingBaseInterval != null) {
        _subscriptions[ticker] = _SharedTickSubscription(interval, 0, 0);
        _alignOnRebase.add(ticker);
      } else {
        final tickMultiple = _harmonicMultiple(interval, baseInterval)!;
        _subscriptions[ticker] = _SharedTickSubscription(
          interval,
          tickMultiple,
          (_tick ~/ tickMultiple + 1) * tickMultiple,
        );
      }
    }
    other._subscriptions.clear();
    other._joinOnRebase.clear();
    other._alignOnRebase.clear();
    for (final timer in other._pendingTimers.values) {
      timer.cancel();
    }
    other._pendingTimers.clear();
    other._groupsToAbsorbOnRebase.clear();
  }

  void add(FixedTicker ticker, Duration interval) {
    final effectiveBase = _pendingBaseInterval ?? baseInterval;
    final baseMultiple = _harmonicMultiple(effectiveBase, interval);
    if (baseMultiple != null && interval < effectiveBase) {
      prepareBase(interval);
    }

    final pendingBaseInterval = _pendingBaseInterval;
    if (pendingBaseInterval != null) {
      final tickMultiple = _harmonicMultiple(interval, pendingBaseInterval)!;
      _subscriptions[ticker] = _SharedTickSubscription(
        interval,
        tickMultiple,
        0,
      );
      _joinOnRebase.add(ticker);
      _pendingTimers[ticker] = Timer.periodic(interval, (_) {
        if (_joinOnRebase.contains(ticker) &&
            _subscriptions.containsKey(ticker)) {
          ticker._handleSharedTick();
        }
      });
      return;
    }

    final tickMultiple = _harmonicMultiple(interval, baseInterval)!;
    _subscriptions[ticker] = _SharedTickSubscription(
      interval,
      tickMultiple,
      (_tick ~/ tickMultiple + 1) * tickMultiple,
    );
  }

  void remove(FixedTicker ticker) {
    _subscriptions.remove(ticker);
    _joinOnRebase.remove(ticker);
    _alignOnRebase.remove(ticker);
    _pendingTimers.remove(ticker)?.cancel();
    if (_subscriptions.isEmpty) {
      _timer?.cancel();
      _timer = null;
      scheduler.removeGroup(this);
    }
  }

  void _rebase(Duration interval, List<FixedTicker> dueTickers) {
    _timer?.cancel();
    for (final group in _groupsToAbsorbOnRebase.toList()) {
      _absorbNow(group);
    }
    _groupsToAbsorbOnRebase.clear();
    final oldBaseInterval = baseInterval;
    final oldTick = _tick;
    final baseMultiple = _harmonicMultiple(oldBaseInterval, interval)!;
    baseInterval = interval;
    _tick = oldTick * baseMultiple;
    for (final entry in _subscriptions.entries) {
      final ticker = entry.key;
      final subscription = entry.value;
      final tickMultiple = _harmonicMultiple(
        subscription.interval,
        interval,
      )!;
      if (_joinOnRebase.contains(ticker)) {
        dueTickers.add(ticker);
        subscription
          ..tickMultiple = tickMultiple
          ..nextTick = _tick + tickMultiple;
      } else if (_alignOnRebase.contains(ticker)) {
        var nextTick =
            ((_tick + tickMultiple - 1) ~/ tickMultiple) * tickMultiple;
        if (nextTick == _tick) {
          dueTickers.add(ticker);
          nextTick += tickMultiple;
        }
        subscription
          ..tickMultiple = tickMultiple
          ..nextTick = nextTick;
      } else {
        subscription
          ..tickMultiple = tickMultiple
          ..nextTick *= baseMultiple;
      }
    }
    _pendingBaseInterval = null;
    _joinOnRebase.clear();
    _alignOnRebase.clear();
    for (final timer in _pendingTimers.values) {
      timer.cancel();
    }
    _pendingTimers.clear();
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

    final pendingBaseInterval = _pendingBaseInterval;
    if (pendingBaseInterval != null) {
      _rebase(pendingBaseInterval, dueTickers);
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

int? _harmonicMultiple(Duration longer, Duration shorter) {
  final longerMicroseconds = longer.inMicroseconds;
  final shorterMicroseconds = shorter.inMicroseconds;
  if (longerMicroseconds < shorterMicroseconds) return null;

  final multiple =
      (longerMicroseconds + shorterMicroseconds ~/ 2) ~/ shorterMicroseconds;
  final roundingError = (longerMicroseconds - shorterMicroseconds * multiple)
      .abs();
  final maximumRoundingError = (multiple + 1) ~/ 2;
  return roundingError <= maximumRoundingError ? multiple : null;
}
