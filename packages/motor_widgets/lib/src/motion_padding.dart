import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/src/implicit_tracks.dart';
import 'package:motor_widgets/src/layout/padding_extended.dart';

/// Animated version of [Padding] that springs to a new [padding] whenever it
/// changes, keeping its velocity when retargeted.
///
/// The Motor version of [AnimatedPadding]. A spring may overshoot below
/// zero; [PaddingExtended] lays that out instead of asserting.
///
/// The padding is resolved against the ambient [Directionality] first, so
/// any [EdgeInsetsGeometry] works. A change of text direction jumps.
class MotionPadding extends StatelessWidget {
  /// Creates a [MotionPadding].
  const MotionPadding({
    required this.motion,
    required this.padding,
    this.child,
    this.onEnd,
    this.tickerRate,
    this.debugLabel,
    super.key,
  });

  /// The motion to animate [padding] with.
  final Motion motion;

  /// The target padding.
  final EdgeInsetsGeometry padding;

  /// The widget below this widget in the tree.
  final Widget? child;

  /// {@macro motor_widgets.onEnd}
  final VoidCallback? onEnd;

  /// {@macro motor_widgets.tickerRate}
  final TickerRate? tickerRate;

  /// {@macro motor_widgets.debugLabel}
  final String? debugLabel;

  static final _padding = Track<EdgeInsets>(
    MotionConverter.edgeInsets,
    debugLabel: 'MotionPadding.padding',
  );

  @override
  Widget build(BuildContext context) {
    return ImplicitTrackBuilder(
      motion: motion,
      onEnd: onEnd,
      tickerRate: tickerRate,
      debugLabel: debugLabel ?? 'MotionPadding',
      tracks: [
        _padding.implicit(padding.resolve(Directionality.maybeOf(context))),
      ],
      builder: (context, value, child) =>
          PaddingExtended(padding: value(_padding)!, child: child),
      child: child,
    );
  }
}
