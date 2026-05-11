import 'package:fixed_ticker/src/fixed_ticker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// A mixin on [State] that creates a single [FixedTicker] at a configurable
/// [tickerInterval].
///
/// This is the fixed-rate equivalent of [SingleTickerProviderStateMixin]. Use
/// it as a drop-in replacement when you want your [AnimationController] to tick
/// at a fixed interval (e.g. 30fps) instead of the display refresh rate.
///
/// Override [tickerInterval] to customize the tick rate:
///
/// ```dart
/// class _MyState extends State<MyWidget>
///     with SingleFixedTickerProviderStateMixin {
///   @override
///   Duration get tickerInterval => const Duration(milliseconds: 100); // 10fps
/// }
/// ```
///
/// Only one [Ticker] may be created via [createTicker]. If you need multiple
/// tickers, use [FixedTickerProviderStateMixin] instead.
mixin SingleFixedTickerProviderStateMixin<T extends StatefulWidget> on State<T>
    implements TickerProvider {
  /// The interval at which the created [FixedTicker] fires.
  ///
  /// Defaults to 33ms (~30fps). Override to change the tick rate.
  Duration get tickerInterval => const Duration(milliseconds: 33);

  FixedTicker? _ticker;

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
      interval: tickerInterval,
      debugLabel: kDebugMode ? 'created by ${describeIdentity(this)}' : null,
    );
    _updateTickerModeNotifier();
    return _ticker!;
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

  ValueListenable<TickerModeData>? _tickerModeNotifier;

  void _updateTickerModeNotifier() {
    final newNotifier = TickerMode.getValuesNotifier(context);
    if (newNotifier == _tickerModeNotifier) return;
    _tickerModeNotifier?.removeListener(_onTickerModeChange);
    _tickerModeNotifier = newNotifier;
    _tickerModeNotifier!.addListener(_onTickerModeChange);
    _onTickerModeChange();
  }

  void _onTickerModeChange() {
    if (_ticker != null) {
      _ticker!.muted = !_tickerModeNotifier!.value.enabled;
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

/// A mixin on [State] that can create multiple [FixedTicker]s at a
/// configurable [tickerInterval].
///
/// This is the fixed-rate equivalent of [TickerProviderStateMixin]. Use it
/// when you need multiple [AnimationController]s on the same [State] and want
/// them all to tick at a fixed interval.
///
/// Override [tickerInterval] to customize the tick rate:
///
/// ```dart
/// class _MyState extends State<MyWidget>
///     with FixedTickerProviderStateMixin {
///   @override
///   Duration get tickerInterval => const Duration(milliseconds: 100); // 10fps
/// }
/// ```
mixin FixedTickerProviderStateMixin<T extends StatefulWidget> on State<T>
    implements TickerProvider {
  /// The interval at which created [FixedTicker]s fire.
  ///
  /// Defaults to 33ms (~30fps). Override to change the tick rate.
  Duration get tickerInterval => const Duration(milliseconds: 33);

  Set<Ticker>? _tickers;

  @override
  Ticker createTicker(TickerCallback onTick) {
    if (_tickerModeNotifier == null) {
      _updateTickerModeNotifier();
    }
    _tickers ??= <_WidgetFixedTicker>{};
    final result = _WidgetFixedTicker(
      onTick,
      interval: tickerInterval,
      creator: this,
      debugLabel: kDebugMode ? 'created by ${describeIdentity(this)}' : null,
    );
    _tickers!.add(result);
    return result;
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

  ValueListenable<TickerModeData>? _tickerModeNotifier;

  void _updateTickerModeNotifier() {
    final newNotifier = TickerMode.getValuesNotifier(context);
    if (newNotifier == _tickerModeNotifier) return;
    _tickerModeNotifier?.removeListener(_onTickerModeChange);
    _tickerModeNotifier = newNotifier;
    _tickerModeNotifier!.addListener(_onTickerModeChange);
    _onTickerModeChange();
  }

  void _onTickerModeChange() {
    if (_tickers != null) {
      final muted = !_tickerModeNotifier!.value.enabled;
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
