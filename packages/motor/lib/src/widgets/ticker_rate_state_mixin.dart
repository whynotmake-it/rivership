import 'package:fixed_ticker/fixed_ticker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Lets a widget that creates its own controller tick at a [TickerRate].
///
/// The rate is [widgetTickerRate], or else the nearest [TickerRateScope]. At
/// a fixed rate, tickers are [FixedTicker]s. Otherwise they come from
/// [TickerProviderStateMixin] unchanged, so a widget without a rate behaves
/// exactly as before. Switching between the two calls [resyncTickers], which
/// keeps running animations going.
///
/// Fixed-rate tickers are muted by [TickerMode], but ignore its
/// `forceFrames`.
mixin TickerRateStateMixin<W extends StatefulWidget>
    on State<W>, TickerProviderStateMixin<W> {
  /// The rate set on the widget. Overrides any [TickerRateScope].
  TickerRate? get widgetTickerRate;

  /// Recreates the tickers of this state's controllers with [createTicker].
  void resyncTickers();

  Duration? _interval;
  final _fixedTickers = <_RateTicker>{};
  ValueListenable<bool>? _tickerMode;

  @override
  Ticker createTicker(TickerCallback onTick) {
    final interval = _interval;
    if (interval == null) return super.createTicker(onTick);
    final ticker = _RateTicker(onTick, this, interval)
      ..muted = !_tickerMode!.value;
    _fixedTickers.add(ticker);
    return ticker;
  }

  /// Applies a changed [widgetTickerRate]. Call it from `didUpdateWidget`.
  void updateTickerRate() {
    final rate = widgetTickerRate ?? TickerRateScope.maybeOf(context);
    final interval = rate?.interval;
    if (interval == _interval) return;
    final switchesTicker = (interval == null) != (_interval == null);
    _interval = interval;
    if (switchesTicker) {
      _listenToTickerMode();
      resyncTickers();
    } else {
      for (final ticker in _fixedTickers) {
        ticker.interval = interval;
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    updateTickerRate();
  }

  @override
  void activate() {
    super.activate();
    _listenToTickerMode();
  }

  @override
  void dispose() {
    _tickerMode?.removeListener(_updateMuted);
    _tickerMode = null;
    super.dispose();
  }

  void _listenToTickerMode() {
    // TickerMode.getValuesNotifier is newer than motor's minimum Flutter.
    final notifier = _interval == null
        ? null
        // ignore: deprecated_member_use
        : TickerMode.getNotifier(context);
    if (notifier == _tickerMode) return;
    _tickerMode?.removeListener(_updateMuted);
    _tickerMode = notifier?..addListener(_updateMuted);
    _updateMuted();
  }

  void _updateMuted() {
    final muted = !(_tickerMode?.value ?? true);
    for (final ticker in _fixedTickers) {
      ticker.muted = muted;
    }
  }
}

class _RateTicker extends FixedTicker {
  _RateTicker(super.onTick, TickerRateStateMixin owner, Duration interval)
      : _owner = owner,
        super(
          interval: interval,
          debugLabel:
              kDebugMode ? 'created by ${describeIdentity(owner)}' : null,
        );

  final TickerRateStateMixin _owner;

  @override
  void dispose() {
    _owner._fixedTickers.remove(this);
    super.dispose();
  }
}
