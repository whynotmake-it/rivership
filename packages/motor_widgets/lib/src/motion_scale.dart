import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/src/on_end.dart';

/// Animated version of [Transform.scale] that springs to a new [scale]
/// whenever it changes, keeping its velocity when retargeted.
///
/// The Motor version of [AnimatedScale].
class MotionScale extends StatelessWidget {
  /// Creates a [MotionScale].
  const MotionScale({
    required this.scale,
    required this.motion,
    this.child,
    this.alignment = Alignment.center,
    this.filterQuality,
    this.onEnd,
    this.tickerRate,
    this.debugLabel,
    super.key,
  });

  /// The widget below this widget in the tree.
  final Widget? child;

  /// The target scale.
  final double scale;

  /// The motion to animate [scale] with.
  final Motion motion;

  /// The alignment of the origin of the scale, relative to the child's size.
  final Alignment alignment;

  /// The filter quality with which to apply the transform as a bitmap
  /// operation. See [Transform.filterQuality].
  final FilterQuality? filterQuality;

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
    return SingleMotionBuilder(
      value: scale,
      motion: motion,
      onAnimationStatusChanged: onEndListener(onEnd),
      tickerRate: tickerRate,
      debugLabel: debugLabel ?? 'MotionScale',
      builder: (context, scale, child) => Transform.scale(
        scale: scale,
        alignment: alignment,
        filterQuality: filterQuality,
        child: child,
      ),
      child: child,
    );
  }
}
