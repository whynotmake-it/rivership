import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/src/converters.dart';
import 'package:motor_widgets/src/implicit_tracks.dart';

/// The tracks of a [MotionPositioned], one per animated property.
///
/// Use them as keys of [MotionPositioned.motions] to give a property its own
/// motion:
///
/// ```dart
/// MotionPositioned(
///   motion: const .smoothSpring(),
///   motions: {.left: const .snappySpring()},
///   …
/// )
/// ```
final class MotionPositionedTrack<T extends Object> extends Track<T> {
  MotionPositionedTrack._(super.converter, {required String super.debugLabel});

  /// [MotionPositioned.left].
  static final left = MotionPositionedTrack<double>._(
    MotionConverter.single,
    debugLabel: 'MotionPositioned.left',
  );

  /// [MotionPositioned.top].
  static final top = MotionPositionedTrack<double>._(
    MotionConverter.single,
    debugLabel: 'MotionPositioned.top',
  );

  /// [MotionPositioned.right].
  static final right = MotionPositionedTrack<double>._(
    MotionConverter.single,
    debugLabel: 'MotionPositioned.right',
  );

  /// [MotionPositioned.bottom].
  static final bottom = MotionPositionedTrack<double>._(
    MotionConverter.single,
    debugLabel: 'MotionPositioned.bottom',
  );

  /// [MotionPositioned.width].
  static final width = MotionPositionedTrack<double>._(
    const NonNegativeMotionConverter(),
    debugLabel: 'MotionPositioned.width',
  );

  /// [MotionPositioned.height].
  static final height = MotionPositionedTrack<double>._(
    const NonNegativeMotionConverter(),
    debugLabel: 'MotionPositioned.height',
  );
}

/// Animated version of [Positioned] that springs to a new position whenever
/// it changes. Only works as a child of a [Stack].
///
/// The Motor version of [AnimatedPositioned]. Each edge and dimension has its
/// own track, so changing one keeps the others' motion. As in
/// [AnimatedPositioned], an edge or dimension that goes from null to a value
/// starts there instead of animating.
class MotionPositioned extends StatelessWidget {
  /// Creates a [MotionPositioned].
  ///
  /// Only two out of the three horizontal values ([left], [right], [width]),
  /// and only two out of the three vertical values ([top], [bottom],
  /// [height]), can be set.
  const MotionPositioned({
    required this.child,
    required this.motion,
    this.motions,
    this.left,
    this.top,
    this.right,
    this.bottom,
    this.width,
    this.height,
    this.onEnd,
    this.tickerRate,
    this.debugLabel,
    super.key,
  }) : assert(
         left == null || right == null || width == null,
         'Only two of left, right and width can be set',
       ),
       assert(
         top == null || bottom == null || height == null,
         'Only two of top, bottom and height can be set',
       );

  /// Creates a [MotionPositioned] from a [Rect].
  MotionPositioned.fromRect({
    required this.child,
    required this.motion,
    required Rect rect,
    this.motions,
    this.onEnd,
    this.tickerRate,
    this.debugLabel,
    super.key,
  }) : left = rect.left,
       top = rect.top,
       width = rect.width,
       height = rect.height,
       right = null,
       bottom = null;

  /// The widget below this widget in the tree.
  final Widget child;

  /// The offset of the child's left edge from the left of the stack.
  final double? left;

  /// The offset of the child's top edge from the top of the stack.
  final double? top;

  /// The offset of the child's right edge from the right of the stack.
  final double? right;

  /// The offset of the child's bottom edge from the bottom of the stack.
  final double? bottom;

  /// The child's width.
  final double? width;

  /// The child's height.
  final double? height;

  /// The motion every property follows, unless [motions] has its own.
  final Motion motion;

  /// {@macro motor_widgets.motions}
  ///
  /// For example `motions: {.left: const .snappySpring()}`.
  final Map<MotionPositionedTrack<Object>, Motion>? motions;

  /// {@macro motor_widgets.onEnd}
  final VoidCallback? onEnd;

  /// {@macro motor_widgets.tickerRate}
  final TickerRate? tickerRate;

  /// {@macro motor_widgets.debugLabel}
  final String? debugLabel;

  @override
  Widget build(BuildContext context) {
    return ImplicitTrackBuilder(
      motion: motion,
      motions: motions,
      onEnd: onEnd,
      tickerRate: tickerRate,
      debugLabel: debugLabel ?? 'MotionPositioned',
      tracks: [
        MotionPositionedTrack.left.implicit(left),
        MotionPositionedTrack.top.implicit(top),
        MotionPositionedTrack.right.implicit(right),
        MotionPositionedTrack.bottom.implicit(bottom),
        MotionPositionedTrack.width.implicit(width),
        MotionPositionedTrack.height.implicit(height),
      ],
      builder: (context, value, child) => Positioned(
        left: value(MotionPositionedTrack.left),
        top: value(MotionPositionedTrack.top),
        right: value(MotionPositionedTrack.right),
        bottom: value(MotionPositionedTrack.bottom),
        width: value(MotionPositionedTrack.width),
        height: value(MotionPositionedTrack.height),
        child: child!,
      ),
      child: child,
    );
  }
}
