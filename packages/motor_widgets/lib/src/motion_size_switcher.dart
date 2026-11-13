import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/src/motion_size.dart';
import 'package:motor_widgets/src/motion_switcher.dart';
import 'package:motor_widgets/src/motion_transition.dart';

/// A [MotionSwitcher] inside a [MotionSize]: switches its child with a
/// spring transition and springs its size to fit.
///
/// The Motor version of rivership's `AnimatedSizeSwitcher`. If [child] is
/// null, it shrinks to take up as little space as possible.
class MotionSizeSwitcher extends StatelessWidget {
  /// Creates a [MotionSizeSwitcher].
  const MotionSizeSwitcher({
    required this.child,
    this.motion = const CupertinoMotion.smooth(),
    this.exitMotion,
    this.alignment = Alignment.center,
    this.clipBehavior = Clip.hardEdge,
    this.transition = MotionTransition.fade,
    this.immediateResize = false,
    this.tickerRate,
    this.debugLabel,
    super.key,
  });

  /// The child to switch to.
  ///
  /// As in [MotionSwitcher], a child that can't update the previous one (a
  /// different type or key) switches. Null takes up as little space as
  /// possible.
  final Widget? child;

  /// The spring the size and an entering child follow.
  ///
  /// Defaults to [CupertinoMotion.smooth].
  final Motion motion;

  /// The spring a leaving child follows. Defaults to [motion].
  final Motion? exitMotion;

  /// How the children are aligned while the size animates.
  final Alignment alignment;

  /// How children are clipped while they overflow the animated size.
  final Clip clipBehavior;

  /// How a child looks at a presence value. Defaults to
  /// [MotionTransition.fade].
  final MotionTransition transition;

  /// Whether the size follows the new child at once, ignoring the leaving
  /// children. Defaults to false.
  ///
  /// When false, the leaving children keep their space until they are gone,
  /// so the size only shrinks after they have left. When true, leaving
  /// children are stretched over the new size and may overflow it.
  final bool immediateResize;

  /// How often the animations tick, for example `tickerRate: .fps(30)`.
  ///
  /// Overrides the nearest [TickerRateScope]. Without either, they tick every
  /// frame.
  final TickerRate? tickerRate;

  /// A name for the controllers, shown by inspection tools such as
  /// `motor_devtools`.
  final String? debugLabel;

  @override
  Widget build(BuildContext context) {
    final label = debugLabel ?? 'MotionSizeSwitcher';
    if (!immediateResize) {
      return MotionSize(
        motion: motion,
        alignment: alignment,
        clipBehavior: clipBehavior,
        tickerRate: tickerRate,
        debugLabel: '$label size',
        child: MotionSwitcher(
          motion: motion,
          exitMotion: exitMotion,
          transition: transition,
          tickerRate: tickerRate,
          debugLabel: label,
          layoutBuilder: (currentChild, previousChildren) => Stack(
            clipBehavior: clipBehavior,
            alignment: alignment,
            children: [
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          ),
          child: child ?? const _EmptyChild(),
        ),
      );
    }
    return MotionSwitcher(
      motion: motion,
      exitMotion: exitMotion,
      transition: transition,
      tickerRate: tickerRate,
      debugLabel: label,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        clipBehavior: clipBehavior,
        children: [
          for (final child in previousChildren) Positioned.fill(child: child),
          MotionSize(
            motion: motion,
            alignment: alignment,
            clipBehavior: clipBehavior,
            tickerRate: tickerRate,
            debugLabel: '$label size',
            child: currentChild,
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Stands in for a null child, with a type no caller's child has.
class _EmptyChild extends StatelessWidget {
  const _EmptyChild();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
