import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/src/motion_size.dart';
import 'package:motor_widgets/src/motion_switcher.dart';

/// A [MotionSwitcher] inside a [MotionSize]: switches its child with a
/// spring transition and springs its size to fit.
///
/// The Motor version of rivership's `AnimatedSizeSwitcher`. If [child] is
/// null, it shrinks to take up as little space as possible.
class MotionSizeSwitcher extends StatelessWidget {
  /// Creates a [MotionSizeSwitcher].
  const MotionSizeSwitcher({
    required this.motion,
    required this.child,
    this.exitMotion,
    this.alignment = Alignment.center,
    this.clipBehavior = Clip.hardEdge,
    this.transitionBuilder = AnimatedSwitcher.defaultTransitionBuilder,
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

  /// The motion the size and an entering child follow.
  final Motion motion;

  /// The spring a leaving child follows. Defaults to [motion].
  final Motion? exitMotion;

  /// How the children are aligned while the size animates.
  final AlignmentGeometry alignment;

  /// How children are clipped while they overflow the animated size.
  final Clip clipBehavior;

  /// Wraps a child in a transition driven by its presence spring. Defaults
  /// to [AnimatedSwitcher.defaultTransitionBuilder].
  ///
  /// See [MotionSwitcher.transitionBuilder]; the animation may overshoot.
  final AnimatedSwitcherTransitionBuilder transitionBuilder;

  /// Whether the size follows the new child at once, ignoring the leaving
  /// children. Defaults to false.
  ///
  /// When false, the leaving children keep their space until they are gone,
  /// so the size only shrinks after they have left. When true, leaving
  /// children are stretched over the new size and may overflow it.
  final bool immediateResize;

  /// {@macro motor_widgets.tickerRate}
  final TickerRate? tickerRate;

  /// {@macro motor_widgets.debugLabel}
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
          transitionBuilder: transitionBuilder,
          tickerRate: tickerRate,
          debugLabel: label,
          // An empty Stack would take the biggest size it is allowed, not
          // the smallest.
          layoutBuilder: (currentChild, previousChildren) =>
              currentChild == null && previousChildren.isEmpty
              ? const SizedBox.shrink()
              : Stack(
                  clipBehavior: clipBehavior,
                  alignment: alignment,
                  children: [
                    ...previousChildren,
                    if (currentChild != null) currentChild,
                  ],
                ),
          child: child,
        ),
      );
    }
    return MotionSwitcher(
      motion: motion,
      exitMotion: exitMotion,
      transitionBuilder: transitionBuilder,
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
