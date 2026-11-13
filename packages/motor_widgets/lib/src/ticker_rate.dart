import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// A [FixedTickerProviderStateMixin] whose rate is the widget's own
/// [widgetTickerRate], or else the nearest [TickerRateScope].
mixin WidgetTickerRateMixin<W extends StatefulWidget>
    on State<W>, FixedTickerProviderStateMixin<W> {
  /// The rate set on the widget. Overrides any [TickerRateScope].
  TickerRate? get widgetTickerRate;

  @override
  TickerRate get tickerRate =>
      widgetTickerRate ??
      TickerRateScope.maybeOf(context) ??
      const TickerRate.vsync();
}
