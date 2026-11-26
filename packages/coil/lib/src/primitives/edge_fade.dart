import 'package:coil/src/foundation/theme.dart';
import 'package:coil/src/primitives/eased_gradient.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// Fades the edges of [child], a scrollable, where content is scrolled out
/// of view.
///
/// Each edge fades in as content scrolls away from it, up to [extent] (or
/// [startExtent] and [endExtent] for each end on its own), and the amount
/// springs on the theme's `fade` tokens. It reads only the
/// notifications [child] sends, so it is right on first layout and when
/// the content changes size, and it follows the scroll direction: the right
/// edge in left-to-right, the left in right-to-left, the top of a reversed
/// list. Scrollables nested inside [child] don't drive it.
///
/// Where something opaque floats over an end, such as a composer and the
/// keyboard over a chat's end, or a bar over its start, pass how much it
/// covers as [startCover] or [endCover]: that fade then runs up to the
/// cover's edge instead of the viewport's, and what's under the cover is
/// faded out with it. The scrollable is expected to pad that end by the
/// cover, so its content can scroll clear of it; the fade's strength then
/// counts the content hidden past the cover's edge.
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
    this.startExtent,
    this.endExtent,
    this.startCover = 0,
    this.endCover = 0,
  }) : color = null;

  /// Fades the edges by painting gradients from [color] over [child].
  const CoilScrollEdgeFade.solid({
    required this.child,
    required Color this.color,
    super.key,
    this.axis = Axis.vertical,
    this.extent = 32,
    this.startExtent,
    this.endExtent,
    this.startCover = 0,
    this.endCover = 0,
  });

  /// The scrollable.
  final Widget child;

  /// The scroll axis whose edges fade.
  final Axis axis;

  /// How far each fade reaches, unless [startExtent] or [endExtent] says
  /// otherwise.
  final double extent;

  /// How far the fade where the scroll starts reaches (the top of a
  /// vertical list, the bottom of a reversed one). Defaults to [extent].
  final double? startExtent;

  /// How far the fade where the scroll ends reaches (the bottom of a
  /// vertical list, the top of a reversed one). Defaults to [extent].
  ///
  /// A chat whose composer floats over its end, for one, fades its end
  /// from under the composer to well above it.
  final double? endExtent;

  /// How much of the start something opaque covers, such as a floating
  /// bar: the start fades from the cover's edge, and what's under it is
  /// faded out too. It follows the cover as it moves, with no spring.
  final double startCover;

  /// How much of the end something opaque covers, such as a chat's
  /// composer and the keyboard: the end fades up to the cover's edge, and
  /// what's under it is faded out too. It follows the cover as it moves
  /// (the keyboard sliding in), with no spring.
  final double endCover;

  double get _startExtent => startExtent ?? extent;
  double get _endExtent => endExtent ?? extent;

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
    double hidden(double extent, double length) =>
        extent <= 0 ? 0.0 : (length / extent).clamp(0.0, 1.0);
    final before = hidden(widget._startExtent, metrics.extentBefore);
    final after = hidden(widget._endExtent, metrics.extentAfter);
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
    // The metrics change as it scrolls, and as its extents change, which
    // is reported after the frame. Other scroll notifications can come
    // during layout, when this can't rebuild, and change nothing.
    final child = NotificationListener<ScrollMetricsNotification>(
      onNotification: (n) => _onMetrics(n.metrics, n.depth),
      child: NotificationListener<ScrollUpdateNotification>(
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
            start: before.clamp(0.0, 1.0) * widget._startExtent,
            end: after.clamp(0.0, 1.0) * widget._endExtent,
            startCover: widget.startCover,
            endCover: widget.endCover,
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

/// How far each edge fades, in pixels, how much of each a cover hides,
/// and which way the scroll runs.
@immutable
class _Edges {
  const _Edges({
    required this.start,
    required this.end,
    required this.from,
    required this.to,
    this.startCover = 0,
    this.endCover = 0,
  });

  final double start;
  final double end;
  final double startCover;
  final double endCover;
  final Alignment from;
  final Alignment to;

  double _length(Rect bounds) => from.x == to.x ? bounds.height : bounds.width;

  /// Each end's cover and fade in pixels along [length]: the covers as
  /// they are (up to the whole length), and each fade within half of what
  /// the covers leave, so the two never overlap.
  ({
    ({double cover, double fade}) head,
    ({double cover, double fade}) tail,
  })
  _ends(double length) {
    final headCover = startCover.clamp(0.0, length);
    final tailCover = endCover.clamp(0.0, length - headCover);
    final half = (length - headCover - tailCover) / 2;
    return (
      head: (cover: headCover, fade: start.clamp(0.0, half)),
      tail: (cover: tailCover, fade: end.clamp(0.0, half)),
    );
  }

  /// An opaque mask, transparent under the covers, with eased ends from
  /// each cover's edge.
  Shader mask(Rect bounds) {
    const clear = Color(0x00000000);
    const solid = Color(0xFF000000);
    final length = _length(bounds);
    if (length <= 0 ||
        (start <= 0 && end <= 0 && startCover <= 0 && endCover <= 0)) {
      return const LinearGradient(colors: [solid, solid]).createShader(bounds);
    }
    final (:head, :tail) = _ends(length);
    final (headColors, headStops) = easedRamp(
      from: clear,
      to: solid,
      start: head.cover / length,
      stop: (head.cover + head.fade) / length,
    );
    final (tailColors, tailStops) = easedRamp(
      from: solid,
      to: clear,
      start: 1 - (tail.cover + tail.fade) / length,
      stop: 1 - tail.cover / length,
    );
    return LinearGradient(
      begin: from,
      end: to,
      colors: [clear, ...headColors, ...tailColors, clear],
      stops: [0, ...headStops, ...tailStops, 1],
    ).createShader(bounds);
  }

  @override
  bool operator ==(Object other) =>
      other is _Edges &&
      other.start == start &&
      other.end == end &&
      other.startCover == startCover &&
      other.endCover == endCover &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(start, end, startCover, endCover, from, to);
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
    if (length <= 0) return;
    // The strip from [inset] to [inset] + [along] in from the edge at [at].
    Rect strip(Alignment at, double inset, double along) =>
        switch ((vertical, at.x + at.y > 0)) {
          (true, false) => Rect.fromLTWH(0, inset, size.width, along),
          (true, true) => Rect.fromLTWH(
            0,
            size.height - inset - along,
            size.width,
            along,
          ),
          (false, false) => Rect.fromLTWH(inset, 0, along, size.height),
          (false, true) => Rect.fromLTWH(
            size.width - inset - along,
            0,
            along,
            size.height,
          ),
        };
    final ends = edges._ends(length);
    void edge(({double cover, double fade}) end, Alignment at, Alignment away) {
      if (end.cover > 0) {
        canvas.drawRect(strip(at, 0, end.cover), Paint()..color = color);
      }
      if (end.fade <= 0) return;
      final rect = strip(at, end.cover, end.fade);
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

    edge(ends.head, edges.from, edges.to);
    edge(ends.tail, edges.to, edges.from);
  }

  @override
  bool shouldRepaint(_SolidFadePainter old) =>
      old.edges != edges || old.color != color;
}
