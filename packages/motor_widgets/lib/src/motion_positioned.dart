import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/src/converters.dart';
import 'package:motor_widgets/src/implicit_tracks.dart';

final _left = Track<double>(MotionConverter.single, debugLabel: 'left');
final _top = Track<double>(MotionConverter.single, debugLabel: 'top');
final _right = Track<double>(MotionConverter.single, debugLabel: 'right');
final _bottom = Track<double>(MotionConverter.single, debugLabel: 'bottom');
final _width = Track<double>(
  const NonNegativeMotionConverter(),
  debugLabel: 'width',
);
final _height = Track<double>(
  const NonNegativeMotionConverter(),
  debugLabel: 'height',
);

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

  /// The motion to animate with.
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
    return ImplicitTrackBuilder(
      motion: motion,
      onEnd: onEnd,
      tickerRate: tickerRate,
      debugLabel: debugLabel ?? 'MotionPositioned',
      tracks: [
        _left.implicit(left),
        _top.implicit(top),
        _right.implicit(right),
        _bottom.implicit(bottom),
        _width.implicit(width),
        _height.implicit(height),
      ],
      builder: (context, value, child) => Positioned(
        left: value(_left),
        top: value(_top),
        right: value(_right),
        bottom: value(_bottom),
        width: value(_width),
        height: value(_height),
        child: child!,
      ),
      child: child,
    );
  }
}
