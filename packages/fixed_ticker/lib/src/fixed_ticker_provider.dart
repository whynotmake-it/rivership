import 'package:fixed_ticker/src/fixed_ticker.dart';
import 'package:fixed_ticker/src/ticker_rate_scope.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// A mixin on [State] that creates a single [FixedTicker] with a configurable
/// [tickerInterval].
///
/// By default, [tickerInterval] reads from the nearest [TickerRateScope]
/// ancestor (if any), falling back to `null` (normal vsync ticking). Override
/// it to set a fixed rate regardless of the scope:
///
/// ```dart
/// class _MyState extends State<MyWidget>
///     with SingleFixedTickerProviderStateMixin {
///   @override
///   Duration? get tickerInterval =>
///       const Duration(milliseconds: 100); // 10fps
/// }
/// ```
///
/// When using [TickerRateScope], the interval syncs automatically via
/// [didChangeDependencies]. For state-driven changes, call
/// [updateTickerInterval] after [setState]:
///
/// ```dart
/// void _onFpsChanged(int fps) {
///   setState(() => _fps = fps);
///   updateTickerInterval();
/// }
/// ```
///
/// Only one [Ticker] may be created via [createTicker]. If you need multiple
/// tickers, use [FixedTickerProviderStateMixin] instead.
mixin SingleFixedTickerProviderStateMixin<T extends StatefulWidget> on State<T>
    implements TickerProvider {
  /// The interval at which the created [FixedTicker] fires, or `null` for
  /// normal vsync-driven ticking.
  ///
  /// By default, reads from the nearest [TickerRateScope] ancestor. If no
  /// scope exists, returns `null` (vsync). Override to set a fixed rate
  /// that ignores the scope.
  Duration? get tickerInterval =>
      TickerRateScope.maybeOf(context)?.interval;

  FixedTicker? _ticker;
  Duration? _lastSyncedInterval;

  void _syncTickerInterval() {
    final desired = tickerInterval;
    if (desired == _lastSyncedInterval) return;
    _lastSyncedInterval = desired;
    _ticker?.interval = desired;
  }

  @override
  Ticker createTicker(TickerCallback onTick) {
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
      interval: _lastSyncedInterval,
      debugLabel: kDebugMode ? 'created by ${describeIdentity(this)}' : null,
    );
    _updateTickerModeNotifier();
    return _ticker!;
  }

  /// Applies the current [tickerInterval] to the existing ticker.
  ///
  /// Call this after changing the state that drives [tickerInterval]
  /// via [setState]. Not needed when the interval comes from a
  /// [TickerRateScope] — that syncs automatically via
  /// [didChangeDependencies].
  void updateTickerInterval() {
    _syncTickerInterval();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTickerInterval();
    _updateTickerModeNotifier();
  }

  @override
  void activate() {
    super.activate();
    _updateTickerModeNotifier();
  }

  @override
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
/// configurable [tickerInterval].
///
/// By default, [tickerInterval] reads from the nearest [TickerRateScope]
/// ancestor (if any), falling back to `null` (normal vsync ticking). Override
/// it to set a fixed rate regardless of the scope:
///
/// ```dart
/// class _MyState extends State<MyWidget>
///     with FixedTickerProviderStateMixin {
///   @override
///   Duration? get tickerInterval =>
///       const Duration(milliseconds: 100); // 10fps
/// }
/// ```
///
/// When using [TickerRateScope], the interval syncs automatically via
/// [didChangeDependencies]. For state-driven changes, call
/// [updateTickerInterval] after [setState]:
///
/// ```dart
/// void _onFpsChanged(int fps) {
///   setState(() => _fps = fps);
///   updateTickerInterval();
/// }
/// ```
mixin FixedTickerProviderStateMixin<T extends StatefulWidget> on State<T>
    implements TickerProvider {
  /// The interval at which created [FixedTicker]s fire, or `null` for normal
  /// vsync-driven ticking.
  ///
  /// By default, reads from the nearest [TickerRateScope] ancestor. If no
  /// scope exists, returns `null` (vsync). Override to set a fixed rate
  /// that ignores the scope.
  Duration? get tickerInterval =>
      TickerRateScope.maybeOf(context)?.interval;

  Set<Ticker>? _tickers;
  Duration? _lastSyncedInterval;

  void _syncTickerInterval() {
    final desired = tickerInterval;
    if (desired == _lastSyncedInterval) return;
    _lastSyncedInterval = desired;
    if (_tickers == null) return;
    for (final ticker in _tickers!) {
      (ticker as _WidgetFixedTicker).interval = desired;
    }
  }

  @override
  Ticker createTicker(TickerCallback onTick) {
    if (_tickerModeNotifier == null) {
      _updateTickerModeNotifier();
    }
    _tickers ??= <_WidgetFixedTicker>{};
    final result = _WidgetFixedTicker(
      onTick,
      interval: _lastSyncedInterval,
      creator: this,
      debugLabel: kDebugMode ? 'created by ${describeIdentity(this)}' : null,
    );
    _tickers!.add(result);
    return result;
  }

  /// Applies the current [tickerInterval] to all existing tickers.
  ///
  /// Call this after changing the state that drives [tickerInterval]
  /// via [setState]. Not needed when the interval comes from a
  /// [TickerRateScope] — that syncs automatically via
  /// [didChangeDependencies].
  void updateTickerInterval() {
    _syncTickerInterval();
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTickerInterval();
    _updateTickerModeNotifier();
  }

  @override
  void activate() {
    super.activate();
    _updateTickerModeNotifier();
  }

  @override
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
