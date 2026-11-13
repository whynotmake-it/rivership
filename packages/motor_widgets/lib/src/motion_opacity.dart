import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/src/converters.dart';
import 'package:motor_widgets/src/on_end.dart';

/// Animated version of [Opacity] that springs to a new [opacity] whenever it
/// changes, keeping its velocity when retargeted.
///
/// The Motor version of [AnimatedOpacity]. The spring may overshoot, but the
/// opacity it shows stays within 0 and 1.
class MotionOpacity extends StatelessWidget {
  /// Creates a [MotionOpacity].
  const MotionOpacity({
    required this.opacity,
    required this.motion,
    this.child,
    this.alwaysIncludeSemantics = false,
    this.onEnd,
    this.tickerRate,
    this.debugLabel,
    super.key,
  });

  /// The widget below this widget in the tree.
  final Widget? child;

  /// The target opacity, between 0 and 1.
  final double opacity;

  /// The motion to animate [opacity] with.
  final Motion motion;

  /// Whether the semantic information of the children is always included.
  ///
  /// See [Opacity.alwaysIncludeSemantics].
  final bool alwaysIncludeSemantics;

  /// Called every time the animation settles.
  final VoidCallback? onEnd;

  /// How often the animation ticks, for example `tickerRate: .fps(30)`.
  ///
  /// Overrides the nearest [TickerRateScope]. Without either, it ticks every
  /// frame.
  final TickerRate? tickerRate;

  /// A name for the controller, shown by inspection tools such as
  /// `motor_devtools`.
  final String? debugLabel;

  @override
  Widget build(BuildContext context) {
    assert(
      opacity >= 0 && opacity <= 1,
      'opacity must be between 0 and 1, was $opacity',
    );
    return MotionBuilder<double>(
      value: opacity,
      motion: motion,
      converter: const UnitIntervalMotionConverter(),
      onAnimationStatusChanged: onEndListener(onEnd),
      tickerRate: tickerRate,
      debugLabel: debugLabel ?? 'MotionOpacity',
      builder: (context, opacity, child) => Opacity(
        opacity: opacity,
        alwaysIncludeSemantics: alwaysIncludeSemantics,
        child: child,
      ),
      child: child,
    );
  }
}
