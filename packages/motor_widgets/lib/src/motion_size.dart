import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/src/raw_motion_size.dart';

/// Animated widget that springs its own size toward its child's size
/// whenever the child's size changes.
///
/// The Motor version of [AnimatedSize]. The size is driven by a Motor
/// controller from the render object, so when the child's size changes
/// again mid-flight, the size heads for the new one with the velocity it
/// already has instead of restarting.
///
/// The first layout takes the child's size at once. While the size is
/// smaller than the child, the child is aligned by [alignment] and clipped
/// by [clipBehavior].
///
/// ## Content springs, room snaps
///
/// Unlike [AnimatedSize], this tells *why* the child's size changed. When the
/// child's own content changes (a label gets longer, a message wraps to
/// another line), the size springs to the new one. When a change in the
/// incoming constraints changes the child's size (the window is resized and
/// rewraps or ellipsizes the child), the size snaps to the child's new size
/// at once and drops any spring in flight, so a window being dragged never
/// lags behind the cursor. A change in the constraints that leaves the
/// child's size alone (a sibling taking more room in a [Row]) keeps the
/// spring running.
///
/// A change of the ambient text scale snaps too.
class MotionSize extends StatelessWidget {
  /// Creates a [MotionSize].
  const MotionSize({
    required this.motion,
    this.child,
    this.alignment = Alignment.center,
    this.clipBehavior = Clip.hardEdge,
    this.onEnd,
    this.tickerRate,
    this.debugLabel,
    super.key,
  });

  /// The widget below this widget in the tree.
  final Widget? child;

  /// The alignment of the child within the parent when the parent is not yet
  /// the same size as the child.
  final AlignmentGeometry alignment;

  /// The motion the size follows.
  final Motion motion;

  /// How to clip the child while it is larger than this widget.
  final Clip clipBehavior;

  /// {@macro motor_widgets.onEnd}
  final VoidCallback? onEnd;

  /// {@macro motor_widgets.tickerRate}
  final TickerRate? tickerRate;

  /// {@macro motor_widgets.debugLabel}
  final String? debugLabel;

  @override
  Widget build(BuildContext context) {
    return RawMotionSize(
      motion: motion,
      alignment: alignment,
      clipBehavior: clipBehavior,
      onEnd: onEnd,
      tickerRate: tickerRate,
      debugLabel: debugLabel ?? 'MotionSize',
      child: child,
    );
  }
}
