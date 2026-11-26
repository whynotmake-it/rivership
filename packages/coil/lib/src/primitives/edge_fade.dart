import 'package:coil/src/foundation/theme.dart';
import 'package:coil/src/primitives/eased_gradient.dart';
import 'package:flutter/foundation.dart' show listEquals;
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
/// Each fade is an eased ramp from hidden at the edge to fully shown at its
/// extent, unless [startStops] or [endStops] shape it: to keep content
/// faintly visible under something translucent near the edge, say.
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
    this.startStops,
    this.endStops,
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
    this.startStops,
    this.endStops,
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

  /// The shape of the fade where the scroll starts, from the edge inward;
  /// null is [CoilFadeStop.ramp]. See [CoilFadeStop].
  final List<CoilFadeStop>? startStops;

  /// The shape of the fade where the scroll ends, from the edge inward;
  /// null is [CoilFadeStop.ramp]. See [CoilFadeStop].
  ///
  /// A chat under a translucent keyboard can keep its content faintly
  /// visible across the keyboard, hide it under the composer, and ramp to
  /// clear above it.
  final List<CoilFadeStop>? endStops;

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
            startStops: widget.startStops ?? CoilFadeStop.ramp,
            endStops: widget.endStops ?? CoilFadeStop.ramp,
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

/// A point in an edge fade: how visible the content is at [position]
/// along the fade, from the edge (0) to the fade's extent (1).
///
/// Between two stops the visibility eases from one to the other; two stops
/// at the same position make a step. Before the first stop and past the
/// last, the first's and the last's visibility hold. A fade's stops are in
/// order of position.
@immutable
class CoilFadeStop {
  /// The content is [opacity] visible at [position].
  const CoilFadeStop(this.position, this.opacity)
    : assert(position >= 0 && position <= 1, 'position is 0 to 1'),
      assert(opacity >= 0 && opacity <= 1, 'opacity is 0 to 1');

  /// Where along the fade: 0 at the edge, 1 at the fade's extent.
  final double position;

  /// How visible the content is there: 0 hidden, 1 untouched.
  final double opacity;

  /// The default: hidden at the edge, easing to fully shown at the extent.
  static const ramp = [CoilFadeStop(0, 0), CoilFadeStop(1, 1)];

  @override
  bool operator ==(Object other) =>
      other is CoilFadeStop &&
      other.position == position &&
      other.opacity == opacity;

  @override
  int get hashCode => Object.hash(position, opacity);
}

/// [stops] as gradient colors and stops along a strip, with [visible] as
/// the color at full visibility (opacity 1) and [hidden] at none: from
/// [edge] (a fraction of the strip, the edge) to [inner] (the extent).
(List<Color>, List<double>) _rampOf(
  List<CoilFadeStop> stops, {
  required double edge,
  required double inner,
  required Color hidden,
  required Color visible,
}) {
  Color at(double opacity) => Color.lerp(hidden, visible, opacity)!;
  double along(double position) => edge + (inner - edge) * position;
  final colors = <Color>[];
  final offsets = <double>[];
  for (var i = 0; i < stops.length; i++) {
    final stop = stops[i];
    if (i == 0) {
      colors.add(at(stop.opacity));
      offsets.add(along(stop.position));
      continue;
    }
    final previous = stops[i - 1];
    final (rampColors, rampStops) = easedRamp(
      from: at(previous.opacity),
      to: at(stop.opacity),
      start: along(previous.position),
      stop: along(stop.position),
    );
    colors.addAll(rampColors);
    offsets.addAll(rampStops);
  }
  return (colors, offsets);
}

/// How far each edge fades, in pixels, its shape, and which way the scroll
/// runs.
@immutable
class _Edges {
  const _Edges({
    required this.start,
    required this.end,
    required this.from,
    required this.to,
    this.startStops = CoilFadeStop.ramp,
    this.endStops = CoilFadeStop.ramp,
  });

  final double start;
  final double end;
  final List<CoilFadeStop> startStops;
  final List<CoilFadeStop> endStops;
  final Alignment from;
  final Alignment to;

  double _length(Rect bounds) => from.x == to.x ? bounds.height : bounds.width;

  /// The fades along [length], each within its half so they never overlap.
  ({double start, double end}) _within(double length) =>
      (start: start.clamp(0.0, length / 2), end: end.clamp(0.0, length / 2));

  /// An opaque mask with eased transparent ends.
  Shader mask(Rect bounds) {
    const clear = Color(0x00000000);
    const solid = Color(0xFF000000);
    final length = _length(bounds);
    if (length <= 0 || (start <= 0 && end <= 0)) {
      return const LinearGradient(colors: [solid, solid]).createShader(bounds);
    }
    final fades = _within(length);
    final (headColors, headStops) = _rampOf(
      startStops,
      edge: 0,
      inner: fades.start / length,
      hidden: clear,
      visible: solid,
    );
    final (tailColors, tailStops) = _rampOf(
      endStops,
      edge: 1,
      inner: 1 - fades.end / length,
      hidden: clear,
      visible: solid,
    );
    return LinearGradient(
      begin: from,
      end: to,
      colors: [...headColors, ...tailColors.reversed],
      stops: [...headStops, ...tailStops.reversed],
    ).createShader(bounds);
  }

  @override
  bool operator ==(Object other) =>
      other is _Edges &&
      other.start == start &&
      other.end == end &&
      listEquals(other.startStops, startStops) &&
      listEquals(other.endStops, endStops) &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(
    start,
    end,
    Object.hashAll(startStops),
    Object.hashAll(endStops),
    from,
    to,
  );
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
    final fades = edges._within(length);
    void edge(
      double extent,
      List<CoilFadeStop> stops,
      Alignment at,
      Alignment away,
    ) {
      if (extent <= 0 || length <= 0) return;
      // The strip of [extent] next to the edge at [at].
      final rect = switch ((vertical, at.x + at.y > 0)) {
        (true, false) => Rect.fromLTWH(0, 0, size.width, extent),
        (true, true) => Rect.fromLTWH(
          0,
          size.height - extent,
          size.width,
          extent,
        ),
        (false, false) => Rect.fromLTWH(0, 0, extent, size.height),
        (false, true) => Rect.fromLTWH(
          size.width - extent,
          0,
          extent,
          size.height,
        ),
      };
      // The color over the content: opaque where it's hidden.
      final (colors, offsets) = _rampOf(
        stops,
        edge: 0,
        inner: 1,
        hidden: color,
        visible: color.withValues(alpha: 0),
      );
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: at,
            end: away,
            colors: colors,
            stops: offsets,
          ).createShader(rect),
      );
    }

    edge(fades.start, edges.startStops, edges.from, edges.to);
    edge(fades.end, edges.endStops, edges.to, edges.from);
  }

  @override
  bool shouldRepaint(_SolidFadePainter old) =>
      old.edges != edges || old.color != color;
}
