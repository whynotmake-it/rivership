import 'package:fixed_ticker/src/ticker_rate.dart';
import 'package:flutter/widgets.dart';

/// Provides a [TickerRate] to the widget subtree.
///
/// Widgets using `SingleFixedTickerProviderStateMixin` or
/// `FixedTickerProviderStateMixin` automatically pick up the rate from the
/// nearest [TickerRateScope] ancestor (unless they override
/// `tickerRate`).
///
/// ```dart
/// TickerRateScope(
///   rate: TickerRate.fps(30),
///   child: MyAnimatedWidget(),
/// )
/// ```
class TickerRateScope extends InheritedWidget {
  /// Creates a ticker rate scope.
  const TickerRateScope({
    required this.rate,
    required super.child,
    super.key,
  });

  /// The ticker rate for this scope.
  final TickerRate rate;

  /// Returns the [TickerRate] from the nearest [TickerRateScope] ancestor,
  /// or `null` if none exists.
  static TickerRate? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<TickerRateScope>()?.rate;
  }

  /// Returns the [TickerRate] from the nearest [TickerRateScope] ancestor,
  /// or [TickerRate.vsync()] if none exists.
  static TickerRate of(BuildContext context) {
    return maybeOf(context) ?? const TickerRate.vsync();
  }

  @override
  bool updateShouldNotify(TickerRateScope oldWidget) => rate != oldWidget.rate;
}
