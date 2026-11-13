import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/src/layout/padding_extended.dart';
import 'package:motor_widgets/src/on_end.dart';

/// A widget similar to [AnimatedPadding], but each side's padding can be
/// simulated independently using [Motion].
///
/// Uses [PaddingExtended] to allow for negative padding values, so a spring
/// that overshoots past zero doesn't clip.
class MotionPadding extends StatelessWidget {
  /// Creates a [MotionPadding] widget.
  const MotionPadding({
    required this.motion,
    required this.padding,
    this.child,
    this.onEnd,
    this.tickerRate,
    this.debugLabel,
    super.key,
  });

  /// The motion that controls the padding animation.
  final Motion motion;

  /// The padding to animate.
  ///
  /// Must be an [EdgeInsets] or an [EdgeInsetsDirectional]. Switching
  /// between the two jumps.
  final EdgeInsetsGeometry padding;

  /// The child widget to apply the padding to.
  final Widget? child;

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
    return MotionBuilder<EdgeInsetsGeometry>(
      value: padding,
      motion: motion,
      converter: switch (padding) {
        EdgeInsets() => const EdgeInsetsMotionConverter(),
        EdgeInsetsDirectional() => const EdgeInsetsDirectionalMotionConverter(),
        _ => throw UnsupportedError(
          'Unsupported EdgeInsetsGeometry type: ${padding.runtimeType}',
        ),
      },
      onAnimationStatusChanged: onEndListener(onEnd),
      tickerRate: tickerRate,
      debugLabel: debugLabel ?? 'MotionPadding',
      builder: (context, value, child) {
        return PaddingExtended(
          padding: value,
          child: child,
        );
      },
      child: child,
    );
  }
}
