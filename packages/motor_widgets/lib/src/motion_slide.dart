import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/src/on_end.dart';

/// Animated version of [FractionalTranslation] that springs to a new
/// [offset] whenever it changes, keeping its velocity when retargeted.
///
/// The Motor version of [AnimatedSlide]. [offset] is relative to the child's
/// size: `Offset(0, 1)` moves it down by its own height.
class MotionSlide extends StatelessWidget {
  /// Creates a [MotionSlide].
  const MotionSlide({
    required this.offset,
    required this.motion,
    this.child,
    this.onEnd,
    this.tickerRate,
    this.debugLabel,
    super.key,
  });

  /// The widget below this widget in the tree.
  final Widget? child;

  /// The target offset, as a fraction of the child's size.
  final Offset offset;

  /// The motion to animate [offset] with.
  final Motion motion;

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
    return MotionBuilder<Offset>(
      value: offset,
      motion: motion,
      converter: MotionConverter.offset,
      onAnimationStatusChanged: onEndListener(onEnd),
      tickerRate: tickerRate,
      debugLabel: debugLabel ?? 'MotionSlide',
      builder: (context, offset, child) => FractionalTranslation(
        translation: offset,
        child: child,
      ),
      child: child,
    );
  }
}
