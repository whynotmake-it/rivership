import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/src/on_end.dart';

/// Animated version of [Transform.rotate] that springs to new [turns]
/// whenever they change, keeping its velocity when retargeted.
///
/// The Motor version of [AnimatedRotation]. Like it, [turns] are absolute:
/// going from 0.9 to 0.1 turns rotates backwards by 0.8 turns.
class MotionRotation extends StatelessWidget {
  /// Creates a [MotionRotation].
  const MotionRotation({
    required this.turns,
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

  /// The target rotation, in full turns clockwise.
  final double turns;

  /// The motion to animate [turns] with.
  final Motion motion;

  /// The alignment of the origin of the rotation, relative to the child's
  /// size.
  final Alignment alignment;

  /// The filter quality with which to apply the transform as a bitmap
  /// operation. See [Transform.filterQuality].
  final FilterQuality? filterQuality;

  /// {@macro motor_widgets.onEnd}
  final VoidCallback? onEnd;

  /// {@macro motor_widgets.tickerRate}
  final TickerRate? tickerRate;

  /// {@macro motor_widgets.debugLabel}
  final String? debugLabel;

  @override
  Widget build(BuildContext context) {
    return SingleMotionBuilder(
      value: turns,
      motion: motion,
      onAnimationStatusChanged: onEndListener(onEnd),
      tickerRate: tickerRate,
      debugLabel: debugLabel ?? 'MotionRotation',
      builder: (context, turns, child) => Transform.rotate(
        angle: turns * 2 * math.pi,
        alignment: alignment,
        filterQuality: filterQuality,
        child: child,
      ),
      child: child,
    );
  }
}
