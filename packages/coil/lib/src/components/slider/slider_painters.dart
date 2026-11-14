// Internal to CoilSlider; not exported.
// ignore_for_file: public_member_api_docs

import 'package:coil/primitives.dart';
import 'package:coil/src/components/slider/slider_scale.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// The motion-layer target indices a slider's painters read.
abstract final class SliderTarget {
  /// The label text.
  static const label = 0;

  /// The value text.
  static const value = 1;

  /// The track box (the whole row, or the pill's box).
  static const track = 2;
}

/// What a slider painter needs besides the thumb's position.
@immutable
class SliderPaintState {
  const SliderPaintState({
    required this.reach,
    required this.rtl,
    required this.previewOpacity,
    required this.previewColor,
  });

  final SliderReach reach;
  final bool rtl;
  final double previewOpacity;
  final Color previewColor;

  @override
  bool operator ==(Object other) =>
      other is SliderPaintState &&
      other.reach == reach &&
      other.rtl == rtl &&
      other.previewOpacity == previewOpacity &&
      other.previewColor == previewColor;

  @override
  int get hashCode => Object.hash(reach, rtl, previewOpacity, previewColor);
}

/// How close [at] is to the stop at [index] of [stops]: 1 on it, 0 a full
/// gap to the next stop away.
double sliderNearness(List<double> stops, int index, double at) {
  final f = stops[index];
  final d = at - f;
  if (d == 0) return 1;
  final next = d > 0 ? index + 1 : index - 1;
  final gap = next >= 0 && next < stops.length ? (stops[next] - f).abs() : 1.0;
  return gap == 0 ? 0 : (1 - d.abs() / gap).clamp(0.0, 1.0);
}

/// The x the hover preview runs from: the thumb nearest to [preview].
double _previewFrom(List<double> edges, double preview) => edges.reduce(
  (a, b) => (a - preview).abs() <= (b - preview).abs() ? a : b,
);

/// Paints the regular row's pips, fill, hover preview and handle lines.
///
/// One thumb fills from the start; two fill between them. Pips that would
/// sit under the label or the value are left out, so the text never has
/// dots behind it, on any surface.
class SliderRowPaint extends CoilLayerPaint {
  const SliderRowPaint({
    required Listenable moves,
    required this.fractions,
    required this.preview,
    required this.state,
    required this.fill,
    required this.handles,
    required this.emphasis,
    required this.handleWidth,
    required this.handleInset,
    required this.stops,
    required this.pipSize,
    required this.pipGrowth,
    required this.pip,
    required this.activePip,
  }) : super(repaint: moves);

  /// The thumbs' current fractions, read while painting.
  final ValueGetter<List<double>> fractions;

  /// The hover preview's current fraction, read while painting.
  final ValueGetter<double> preview;
  final SliderPaintState state;
  final Color fill;

  /// One handle line color per thumb.
  final List<Color> handles;
  final double emphasis;
  final double handleWidth;
  final double handleInset;

  /// The fractions to draw pips at, or null for none.
  final List<double>? stops;
  final double pipSize;
  final double pipGrowth;
  final Color pip;
  final Color activePip;

  @override
  bool shouldRepaint(SliderRowPaint oldItem) =>
      oldItem.state != state ||
      oldItem.fill != fill ||
      !listEquals(oldItem.handles, handles) ||
      oldItem.emphasis != emphasis ||
      oldItem.handleWidth != handleWidth ||
      oldItem.handleInset != handleInset ||
      !listEquals(oldItem.stops, stops) ||
      oldItem.pipSize != pipSize ||
      oldItem.pipGrowth != pipGrowth ||
      oldItem.pip != pip ||
      oldItem.activePip != activePip;

  @override
  void paint(Canvas canvas, Offset offset, CoilLayerGeometry geometry) {
    final state = this.state;
    final row = geometry.rectOf(SliderTarget.track);
    if (row == null) return;
    final ats = [for (final f in fractions()) f.clamp(0.0, 1.0)];
    final w = row.width;
    double x(double f) => state.reach.xAt(f, w, rtl: state.rtl);
    Rect span(double a, double b) => Rect.fromLTRB(
      offset.dx + (a < b ? a : b),
      offset.dy,
      offset.dx + (a < b ? b : a),
      offset.dy + row.height,
    );

    final stops = this.stops;
    final half = handleWidth / 2;
    final widest = stops == null ? half : pipSize * (1 + pipGrowth) / 2;
    // The handle lines and the pips are marks at a fraction. The fill runs
    // edge to edge, but a mark at either end stays a little inside the row,
    // so the end pips sit under the handle line at min and max.
    final margin = (half > widest ? half : widest) + 3;
    double mark(double x) => x.clamp(margin, w - margin);

    if (stops != null) {
      final label = geometry.rectOf(SliderTarget.label);
      final value = geometry.rectOf(SliderTarget.value);
      final clear = pipSize * 2;
      for (final (i, f) in stops.indexed) {
        final cx = mark(x(f));
        final cy = row.height / 2;
        bool under(Rect? r) =>
            r != null && r.inflate(clear).contains(Offset(cx, cy));
        if (under(label) || under(value)) continue;
        var near = 0.0;
        for (final at in ats) {
          final n = sliderNearness(stops, i, at);
          if (n > near) near = n;
        }
        final d = pipSize * (1 + pipGrowth * near);
        canvas.drawRSuperellipse(
          RSuperellipse.fromLTRBR(
            offset.dx + cx - d / 2,
            offset.dy + cy - d / 2,
            offset.dx + cx + d / 2,
            offset.dy + cy + d / 2,
            Radius.circular(d / 2),
          ),
          Paint()..color = Color.lerp(pip, activePip, near)!,
        );
      }
    }

    final edges = [for (final at in ats) x(at)];
    canvas.drawRect(
      edges.length == 1
          ? span(state.rtl ? w : 0, edges.first)
          : span(edges.first, edges.last),
      Paint()..color = fill,
    );
    if (state.previewOpacity > 0) {
      final p = x(preview().clamp(0.0, 1.0));
      canvas.drawRect(
        span(_previewFrom(edges, p), p),
        Paint()
          ..color = state.previewColor.withValues(
            alpha: state.previewColor.a * state.previewOpacity,
          ),
      );
    }

    final inset = handleInset - emphasis;
    for (final (i, edge) in edges.indexed) {
      final line = mark(edge);
      canvas.drawRSuperellipse(
        RSuperellipse.fromLTRBR(
          offset.dx + line - half,
          offset.dy + inset,
          offset.dx + line + half,
          offset.dy + row.height - inset,
          Radius.circular(half),
        ),
        Paint()..color = handles[i],
      );
    }
  }
}

/// Paints the pill track's outline, fill and hover preview. One thumb fills
/// from the start; two fill between them.
class SliderPillPaint extends CoilLayerPaint {
  const SliderPillPaint({
    required Listenable moves,
    required this.fractions,
    required this.preview,
    required this.state,
    required this.fill,
    required this.border,
    required this.height,
  }) : super(repaint: moves);

  /// The thumbs' current fractions, read while painting.
  final ValueGetter<List<double>> fractions;

  /// The hover preview's current fraction, read while painting.
  final ValueGetter<double> preview;
  final SliderPaintState state;
  final Color fill;
  final Color border;
  final double height;

  @override
  bool shouldRepaint(SliderPillPaint oldItem) =>
      oldItem.state != state ||
      oldItem.fill != fill ||
      oldItem.border != border ||
      oldItem.height != height;

  @override
  void paint(Canvas canvas, Offset offset, CoilLayerGeometry geometry) {
    final state = this.state;
    final box = geometry.rectOf(SliderTarget.track);
    if (box == null) return;
    final top = offset.dy + (box.height - height) / 2;
    final shape = RSuperellipse.fromLTRBR(
      offset.dx,
      top,
      offset.dx + box.width,
      top + height,
      Radius.circular(height / 2),
    );
    double x(double f) => state.reach.xAt(f, box.width, rtl: state.rtl);
    Rect span(double a, double b) => Rect.fromLTRB(
      offset.dx + (a < b ? a : b),
      top,
      offset.dx + (a < b ? b : a),
      top + height,
    );
    final edges = [for (final f in fractions()) x(f.clamp(0.0, 1.0))];
    canvas
      ..save()
      ..clipRSuperellipse(shape)
      ..drawRect(
        edges.length == 1
            ? span(state.rtl ? box.width : 0, edges.first)
            : span(edges.first, edges.last),
        Paint()..color = fill,
      );
    if (state.previewOpacity > 0) {
      final p = x(preview().clamp(0.0, 1.0));
      canvas.drawRect(
        span(_previewFrom(edges, p), p),
        Paint()
          ..color = state.previewColor.withValues(
            alpha: state.previewColor.a * state.previewOpacity,
          ),
      );
    }
    canvas
      ..restore()
      ..drawRSuperellipse(
        shape.deflate(0.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = border,
      );
  }
}

/// Places a [width]-wide box centered on a thumb, as tall as the track: the
/// thumb's focus and semantics node in a range slider.
class SliderThumbLayout extends SingleChildLayoutDelegate {
  SliderThumbLayout({
    required this.fraction,
    required this.reach,
    required this.rtl,
    required this.width,
  });

  final double fraction;
  final SliderReach reach;
  final bool rtl;
  final double width;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.tightFor(width: width, height: constraints.maxHeight);

  @override
  Offset getPositionForChild(Size size, Size childSize) => Offset(
    reach.xAt(fraction, size.width, rtl: rtl) - childSize.width / 2,
    0,
  );

  @override
  bool shouldRelayout(SliderThumbLayout old) =>
      old.fraction != fraction ||
      old.reach != reach ||
      old.rtl != rtl ||
      old.width != width;
}

/// Positions the value bubble centered over the thumb, [gap] above the top.
class SliderBubbleLayout extends SingleChildLayoutDelegate {
  SliderBubbleLayout({
    required this.fraction,
    required this.reach,
    required this.rtl,
    required this.gap,
  });

  final double fraction;
  final SliderReach reach;
  final bool rtl;
  final double gap;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      const BoxConstraints();

  @override
  Offset getPositionForChild(Size size, Size childSize) => Offset(
    reach.xAt(fraction, size.width, rtl: rtl) - childSize.width / 2,
    -(gap + childSize.height),
  );

  @override
  bool shouldRelayout(SliderBubbleLayout old) =>
      old.fraction != fraction ||
      old.reach != reach ||
      old.rtl != rtl ||
      old.gap != gap;
}
