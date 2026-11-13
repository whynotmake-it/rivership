import 'package:coil/src/foundation/theme.dart';
import 'package:coil/src/primitives/eased_gradient.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// Fades the edges of [child], a scrollable, where content is scrolled out
/// of view.
///
/// Each edge fades in as content scrolls away from it, up to [extent], and
/// the amount springs on the theme's `fade` tokens. It reads only the
/// notifications [child] sends, so it is right on first layout and when
/// the content changes size, and it follows the scroll direction: the right
/// edge in left-to-right, the left in right-to-left, the top of a reversed
/// list. Scrollables nested inside [child] don't drive it.
///
/// The default constructor masks [child] with a [ShaderMask], which works
/// over any background. Use [CoilScrollEdgeFade.solid] when the background
/// is a known solid color: it paints gradients from that color on top and
/// skips the mask's offscreen layer.
class CoilScrollEdgeFade extends StatefulWidget {
  /// Fades the edges by masking [child].
  const CoilScrollEdgeFade({
    required this.child,
    super.key,
    this.axis = Axis.vertical,
    this.extent = 32,
  }) : color = null;

  /// Fades the edges by painting gradients from [color] over [child].
  const CoilScrollEdgeFade.solid({
    required this.child,
    required Color this.color,
    super.key,
    this.axis = Axis.vertical,
    this.extent = 32,
  });

  /// The scrollable.
  final Widget child;

  /// The scroll axis whose edges fade.
  final Axis axis;

  /// How far each fade reaches.
  final double extent;

  /// The background to fade into, for [CoilScrollEdgeFade.solid].
  final Color? color;

  @override
  State<CoilScrollEdgeFade> createState() => _CoilScrollEdgeFadeState();
}

class _CoilScrollEdgeFadeState extends State<CoilScrollEdgeFade> {
  /// How much content is hidden past each end, 0 to 1 of the extent.
  double _before = 0;
  double _after = 0;
  AxisDirection? _direction;

  bool _onMetrics(ScrollMetrics metrics, int depth) {
    if (depth != 0 || metrics.axis != widget.axis) return false;
    final extent = widget.extent;
    final before = extent <= 0
        ? 0.0
        : (metrics.extentBefore / extent).clamp(0.0, 1.0);
    final after = extent <= 0
        ? 0.0
        : (metrics.extentAfter / extent).clamp(0.0, 1.0);
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
    final motion = CoilTheme.motionOf(context);
    final child = NotificationListener<ScrollMetricsNotification>(
      onNotification: (n) => _onMetrics(n.metrics, n.depth),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) => _onMetrics(n.metrics, n.depth),
        child: widget.child,
      ),
    );
    final direction =
        _direction ??
        (widget.axis == Axis.vertical
            ? AxisDirection.down
            : AxisDirection.right);
    // From where the scroll starts to where it ends, on screen.
    final (from, to) = switch (direction) {
      AxisDirection.down => (Alignment.topCenter, Alignment.bottomCenter),
      AxisDirection.up => (Alignment.bottomCenter, Alignment.topCenter),
      AxisDirection.right => (Alignment.centerLeft, Alignment.centerRight),
      AxisDirection.left => (Alignment.centerRight, Alignment.centerLeft),
    };
    return SingleMotionBuilder(
      value: _before,
      motion: _before > 0 ? motion.fade : motion.fadeExit,
      debugLabel: 'CoilScrollEdgeFade.start',
      child: child,
      builder: (context, before, child) => SingleMotionBuilder(
        value: _after,
        motion: _after > 0 ? motion.fade : motion.fadeExit,
        debugLabel: 'CoilScrollEdgeFade.end',
        child: child,
        builder: (context, after, child) {
          final edges = _Edges(
            start: before.clamp(0.0, 1.0) * widget.extent,
            end: after.clamp(0.0, 1.0) * widget.extent,
            from: from,
            to: to,
          );
          if (widget.color case final color?) {
            return CustomPaint(
              foregroundPainter: _SolidFadePainter(edges, color),
              child: child,
            );
          }
          // Always a ShaderMask, so the tree (and the scroll position)
          // stays the same whether or not an edge is fading.
          return ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: edges.mask,
            child: child,
          );
        },
      ),
    );
  }
}

/// How far each edge fades, in pixels, and which way the scroll runs.
@immutable
class _Edges {
  const _Edges({
    required this.start,
    required this.end,
    required this.from,
    required this.to,
  });

  final double start;
  final double end;
  final Alignment from;
  final Alignment to;

  double _length(Rect bounds) => from.x == to.x ? bounds.height : bounds.width;

  /// An opaque mask with eased transparent ends.
  Shader mask(Rect bounds) {
    const clear = Color(0x00000000);
    const solid = Color(0xFF000000);
    final length = _length(bounds);
    if (length <= 0 || (start <= 0 && end <= 0)) {
      return const LinearGradient(colors: [solid, solid]).createShader(bounds);
    }
    final s = (start / length).clamp(0.0, 0.5);
    final e = (end / length).clamp(0.0, 0.5);
    final (headColors, headStops) = easedRamp(
      from: clear,
      to: solid,
      start: 0,
      stop: s,
    );
    final (tailColors, tailStops) = easedRamp(
      from: solid,
      to: clear,
      start: 1 - e,
      stop: 1,
    );
    return LinearGradient(
      begin: from,
      end: to,
      colors: [...headColors, ...tailColors],
      stops: [...headStops, ...tailStops],
    ).createShader(bounds);
  }

  @override
  bool operator ==(Object other) =>
      other is _Edges &&
      other.start == start &&
      other.end == end &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(start, end, from, to);
}

/// Paints eased gradients from an opaque color at each fading edge.
class _SolidFadePainter extends CustomPainter {
  _SolidFadePainter(this.edges, this.color);

  final _Edges edges;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final vertical = edges.from.x == edges.to.x;
    final length = vertical ? size.height : size.width;
    void edge(double extent, Alignment at, Alignment away) {
      if (extent <= 0 || length <= 0) return;
      // The strip of [extent] next to the edge at [at].
      final along = extent.clamp(0.0, length / 2);
      final rect = switch ((vertical, at.x + at.y > 0)) {
        (true, false) => Rect.fromLTWH(0, 0, size.width, along),
        (true, true) => Rect.fromLTWH(
          0,
          size.height - along,
          size.width,
          along,
        ),
        (false, false) => Rect.fromLTWH(0, 0, along, size.height),
        (false, true) => Rect.fromLTWH(
          size.width - along,
          0,
          along,
          size.height,
        ),
      };
      canvas.drawRect(
        rect,
        Paint()
          ..shader = easedGradient(
            begin: at,
            end: away,
            from: color,
            to: color.withValues(alpha: 0),
          ).createShader(rect),
      );
    }

    edge(edges.start, edges.from, edges.to);
    edge(edges.end, edges.to, edges.from);
  }

  @override
  bool shouldRepaint(_SolidFadePainter old) =>
      old.edges != edges || old.color != color;
}
