import 'package:fixed_ticker/src/fixed_ticker.dart';
import 'package:fixed_ticker/src/ticker_rate.dart';
import 'package:fixed_ticker/src/ticker_rate_scope.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// A mixin on [State] that creates a single [FixedTicker] with a configurable
/// [tickerRate].
///
/// By default, [tickerRate] reads from the nearest [TickerRateScope] ancestor
/// (if any), falling back to [TickerRate.vsync]. Override it to set a rate
/// regardless of the scope:
///
/// ```dart
/// class _MyState extends State<MyWidget>
///     with SingleFixedTickerProviderStateMixin {
///   @override
///   TickerRate get tickerRate => TickerRate.fps(10);
/// }
/// ```
///
/// When using [TickerRateScope], the rate syncs automatically via
/// [didChangeDependencies]. For state-driven changes, call [updateTickerRate]
/// after [setState]:
///
/// ```dart
/// void _onFpsChanged(int fps) {
///   setState(() => _fps = fps);
///   updateTickerRate();
/// }
/// ```
///
/// Only one [Ticker] may be created via [createTicker]. If you need multiple
/// tickers, use [FixedTickerProviderStateMixin] instead.
mixin SingleFixedTickerProviderStateMixin<T extends StatefulWidget> on State<T>
    implements TickerProvider {
  /// The rate at which the created [FixedTicker] fires.
  ///
  /// By default, reads from the nearest [TickerRateScope] ancestor. If no
  /// scope exists, returns [TickerRate.vsync]. Override to set a rate that
  /// ignores the scope.
  TickerRate get tickerRate =>
      TickerRateScope.maybeOf(context) ?? const TickerRate.vsync();

  FixedTicker? _ticker;
  TickerRate? _lastSyncedRate;

  void _syncTickerRate() {
    final desired = tickerRate;
    if (desired == _lastSyncedRate) return;
    _lastSyncedRate = desired;
    _ticker?.interval = desired.interval;
  }

  @override
  Ticker createTicker(TickerCallback onTick) {
    if (_tickerModeNotifier == null) {
      _updateTickerModeNotifier();
    }
    assert(
      () {
        if (_ticker == null) return true;
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary(
            'SingleFixedTickerProviderStateMixin.createTicker '
            'was called twice.',
          ),
          ErrorDescription(
            'A SingleFixedTickerProviderStateMixin can only be '
            'used as a TickerProvider once.',
          ),
          ErrorDescription(
            'If a State is used for multiple AnimationController '
            'objects, or if it is passed to other objects and '
            'those objects might use it more than one time in '
            'total, then instead of mixing in a '
            'SingleFixedTickerProviderStateMixin, use a regular '
            'FixedTickerProviderStateMixin.',
          ),
        ]);
      }(),
      'createTicker called more than once.',
    );
    _ticker = FixedTicker(
      onTick,
      interval: _lastSyncedRate?.interval,
      debugLabel: kDebugMode ? 'created by ${describeIdentity(this)}' : null,
    );
    _updateTickerModeNotifier();
    return _ticker!;
  }

  /// Applies the current [tickerRate] to the existing ticker.
  ///
  /// Call this after changing the state that drives [tickerRate] via
  /// [setState]. Not needed when the rate comes from a [TickerRateScope] —
  /// that syncs automatically via [didChangeDependencies].
  void updateTickerRate() {
    _syncTickerRate();
  }

  @override
  @mustCallSuper
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTickerRate();
    _updateTickerModeNotifier();
  }

  @override
  @mustCallSuper
  void activate() {
    super.activate();
    _updateTickerModeNotifier();
  }

  @override
  @mustCallSuper
  void dispose() {
    assert(
      () {
        if (_ticker == null || !_ticker!.isActive) return true;
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary('$this was disposed with an active Ticker.'),
          ErrorDescription(
            '$runtimeType created a Ticker via its '
            'SingleFixedTickerProviderStateMixin, but at the '
            'time dispose() was called on the mixin, that '
            'Ticker was still active. The Ticker must be '
            'disposed before calling super.dispose().',
          ),
          ErrorHint(
            'Tickers used by AnimationControllers should be '
            'disposed by calling dispose() on the '
            'AnimationController itself. Otherwise, the '
            'ticker will leak.',
          ),
          _ticker!.describeForError('The offending ticker was'),
        ]);
      }(),
      'Disposed with active ticker.',
    );
    _tickerModeNotifier?.removeListener(_onTickerModeChange);
    _tickerModeNotifier = null;
    super.dispose();
  }

  ValueListenable<bool>? _tickerModeNotifier;

  void _updateTickerModeNotifier() {
    // ignore: deprecated_member_use
    final newNotifier = TickerMode.getNotifier(context);
    if (newNotifier == _tickerModeNotifier) return;
    _tickerModeNotifier?.removeListener(_onTickerModeChange);
    _tickerModeNotifier = newNotifier;
    _tickerModeNotifier!.addListener(_onTickerModeChange);
    _onTickerModeChange();
  }

  void _onTickerModeChange() {
    if (_ticker != null) {
      _ticker!.muted = !_tickerModeNotifier!.value;
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    String? tickerDescription;
    if (_ticker != null) {
      if (_ticker!.isActive && _ticker!.muted) {
        tickerDescription = 'active but muted';
      } else if (_ticker!.isActive) {
        tickerDescription = 'active';
      } else if (_ticker!.muted) {
        tickerDescription = 'inactive, muted';
      } else {
        tickerDescription = 'inactive';
      }
    }
    properties.add(
      DiagnosticsProperty<FixedTicker>(
        'ticker',
        _ticker,
        description: tickerDescription,
        showSeparator: false,
        defaultValue: null,
      ),
    );
  }
}

/// A mixin on [State] that can create multiple [FixedTicker]s with a
/// configurable [tickerRate].
///
/// By default, [tickerRate] reads from the nearest [TickerRateScope] ancestor
/// (if any), falling back to [TickerRate.vsync]. Override it to set a rate
/// regardless of the scope:
///
/// ```dart
/// class _MyState extends State<MyWidget>
///     with FixedTickerProviderStateMixin {
///   @override
///   TickerRate get tickerRate => TickerRate.fps(10);
/// }
/// ```
///
/// When using [TickerRateScope], the rate syncs automatically via
/// [didChangeDependencies]. For state-driven changes, call [updateTickerRate]
/// after [setState]:
///
/// ```dart
/// void _onFpsChanged(int fps) {
///   setState(() => _fps = fps);
///   updateTickerRate();
/// }
/// ```
mixin FixedTickerProviderStateMixin<T extends StatefulWidget> on State<T>
    implements TickerProvider {
  /// The rate at which created [FixedTicker]s fire.
  ///
  /// By default, reads from the nearest [TickerRateScope] ancestor. If no
  /// scope exists, returns [TickerRate.vsync]. Override to set a rate that
  /// ignores the scope.
  TickerRate get tickerRate =>
      TickerRateScope.maybeOf(context) ?? const TickerRate.vsync();

  Set<Ticker>? _tickers;
  TickerRate? _lastSyncedRate;

  void _syncTickerRate() {
    final desired = tickerRate;
    if (desired == _lastSyncedRate) return;
    _lastSyncedRate = desired;
    if (_tickers == null) return;
    for (final ticker in _tickers!) {
      (ticker as _WidgetFixedTicker).interval = desired.interval;
    }
  }

  @override
  @mustCallSuper
  Ticker createTicker(TickerCallback onTick) {
    if (_tickerModeNotifier == null) {
      _updateTickerModeNotifier();
    }
    _tickers ??= <_WidgetFixedTicker>{};
    final result = _WidgetFixedTicker(
      onTick,
      interval: _lastSyncedRate?.interval,
      creator: this,
      debugLabel: kDebugMode ? 'created by ${describeIdentity(this)}' : null,
    );
    _tickers!.add(result);
    return result;
  }

  /// Applies the current [tickerRate] to all existing tickers.
  ///
  /// Call this after changing the state that drives [tickerRate] via
  /// [setState]. Not needed when the rate comes from a [TickerRateScope] —
  /// that syncs automatically via [didChangeDependencies].
  void updateTickerRate() {
    _syncTickerRate();
  }

  void _removeTicker(_WidgetFixedTicker ticker) {
    assert(_tickers != null, 'Tickers set must not be null when removing.');
    assert(
      _tickers!.contains(ticker),
      'Ticker must be in the set when removing.',
    );
    _tickers!.remove(ticker);
  }

  @override
  @mustCallSuper
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTickerRate();
    _updateTickerModeNotifier();
  }

  @override
  @mustCallSuper
  void activate() {
    super.activate();
    _updateTickerModeNotifier();
  }

  @override
  @mustCallSuper
  void dispose() {
    assert(
      () {
        if (_tickers != null) {
          for (final ticker in _tickers!) {
            if (ticker.isActive) {
              throw FlutterError.fromParts(<DiagnosticsNode>[
                ErrorSummary(
                  '$this was disposed with an active Ticker.',
                ),
                ErrorDescription(
                  '$runtimeType created a Ticker via its '
                  'FixedTickerProviderStateMixin, but at the '
                  'time dispose() was called on the mixin, that '
                  'Ticker was still active. All Tickers must be '
                  'disposed before calling super.dispose().',
                ),
                ErrorHint(
                  'Tickers used by AnimationControllers should '
                  'be disposed by calling dispose() on the '
                  'AnimationController itself. Otherwise, the '
                  'ticker will leak.',
                ),
                ticker.describeForError('The offending ticker was'),
              ]);
            }
          }
        }
        return true;
      }(),
      'Disposed with active tickers.',
    );
    _tickerModeNotifier?.removeListener(_onTickerModeChange);
    _tickerModeNotifier = null;
    super.dispose();
  }

  ValueListenable<bool>? _tickerModeNotifier;

  void _updateTickerModeNotifier() {
    // ignore: deprecated_member_use
    final newNotifier = TickerMode.getNotifier(context);
    if (newNotifier == _tickerModeNotifier) return;
    _tickerModeNotifier?.removeListener(_onTickerModeChange);
    _tickerModeNotifier = newNotifier;
    _tickerModeNotifier!.addListener(_onTickerModeChange);
    _onTickerModeChange();
  }

  void _onTickerModeChange() {
    if (_tickers != null) {
      final muted = !_tickerModeNotifier!.value;
      for (final ticker in _tickers!) {
        ticker.muted = muted;
      }
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      DiagnosticsProperty<Set<Ticker>>(
        'tickers',
        _tickers,
        description: _tickers != null
            ? 'tracking ${_tickers!.length} '
                  'ticker${_tickers!.length == 1 ? "" : "s"}'
            : null,
        defaultValue: null,
      ),
    );
  }
}

class _WidgetFixedTicker extends FixedTicker {
  _WidgetFixedTicker(
    super.onTick, {
    required super.interval,
    required FixedTickerProviderStateMixin creator,
    super.debugLabel,
  }) : _creator = creator;

  final FixedTickerProviderStateMixin _creator;

  @override
  void dispose() {
    _creator._removeTicker(this);
    super.dispose();
  }
}
