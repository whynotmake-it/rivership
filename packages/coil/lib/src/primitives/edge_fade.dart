import 'package:flutter/widgets.dart';

/// Fades out the edges of [child]'s scrollable where more content is
/// hidden. Each fade grows with the distance left to scroll that way, up to
/// [extent].
class CoilEdgeFade extends StatefulWidget {
  /// Creates an edge fade.
  const CoilEdgeFade({
    required this.child,
    super.key,
    this.axis = Axis.vertical,
    this.extent = 32,
    this.enabled = true,
  });

  /// The scrollable.
  final Widget child;

  /// The scroll axis whose edges fade.
  final Axis axis;

  /// How far each fade reaches.
  final double extent;

  /// Whether to fade at all.
  final bool enabled;

  @override
  State<CoilEdgeFade> createState() => _CoilEdgeFadeState();
}

class _CoilEdgeFadeState extends State<CoilEdgeFade> {
  double _before = 0;
  double _after = 0;

  /// Which way the scroll runs: content before the start of a `left` or
  /// `up` axis is on the right or at the bottom.
  AxisDirection? _direction;

  bool _onMetrics(ScrollMetrics metrics, int depth) {
    if (depth != 0 || metrics.axis != widget.axis) return false;
    final before = metrics.extentBefore.clamp(0.0, widget.extent);
    final after = metrics.extentAfter.clamp(0.0, widget.extent);
    final direction = metrics.axisDirection;
    if (before != _before || after != _after || direction != _direction) {
      setState(() {
        _before = before;
        _after = after;
        _direction = direction;
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final Widget child = NotificationListener<ScrollMetricsNotification>(
      onNotification: (n) => _onMetrics(n.metrics, n.depth),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) => _onMetrics(n.metrics, n.depth),
        child: widget.child,
      ),
    );
    // Always a ShaderMask, so the tree (and the scroll position) stays the
    // same whether or not an edge is fading.
    final before = widget.enabled ? _before : 0.0;
    final after = widget.enabled ? _after : 0.0;
    final vertical = widget.axis == Axis.vertical;
    // From where the scroll starts to where it ends, on screen.
    final (from, to) = switch (_direction ??
        (vertical ? AxisDirection.down : AxisDirection.right)) {
      AxisDirection.down => (Alignment.topCenter, Alignment.bottomCenter),
      AxisDirection.up => (Alignment.bottomCenter, Alignment.topCenter),
      AxisDirection.right => (Alignment.centerLeft, Alignment.centerRight),
      AxisDirection.left => (Alignment.centerRight, Alignment.centerLeft),
    };
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) {
        final length = vertical ? bounds.height : bounds.width;
        if (length <= 0 || (before == 0 && after == 0)) {
          return const LinearGradient(
            colors: [Color(0xFF000000), Color(0xFF000000)],
          ).createShader(bounds);
        }
        final start = (before / length).clamp(0.0, 0.5);
        final end = (after / length).clamp(0.0, 0.5);
        return LinearGradient(
          begin: from,
          end: to,
          colors: const [
            Color(0x00000000),
            Color(0xFF000000),
            Color(0xFF000000),
            Color(0x00000000),
          ],
          stops: [0, start, 1 - end, 1],
        ).createShader(bounds);
      },
      child: child,
    );
  }
}
