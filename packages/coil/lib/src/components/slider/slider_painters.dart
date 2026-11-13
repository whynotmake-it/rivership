// Internal to CoilSlider; not exported.
// ignore_for_file: public_member_api_docs

import 'package:coil/primitives.dart';
import 'package:coil/src/components/slider/slider_scale.dart';
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
    required this.previewFraction,
    required this.previewOpacity,
    required this.previewColor,
  });

  final SliderReach reach;
  final bool rtl;
  final double previewFraction;
  final double previewOpacity;
  final Color previewColor;
}

/// Paints the regular row's pips, fill, hover preview and handle line.
///
/// Pips that would sit under the label or the value are left out, so the
/// text never has dots behind it, on any surface.
class SliderRowPainter extends CoilLayerPainter {
  SliderRowPainter({required Listenable thumb, required this.fraction})
    : _thumb = thumb {
    thumb.addListener(notifyListeners);
  }

  final Listenable _thumb;
  final ValueGetter<double> fraction;

  SliderPaintState? _state;
  Color _fill = const Color(0x00000000);
  Color _handle = const Color(0x00000000);
  double _emphasis = 0;
  double _handleWidth = 2;
  double _handleInset = 8;
  int? _divisions;
  double _pipSize = 5;
  double _pipGrowth = 0.4;
  Color _pip = const Color(0x00000000);
  Color _activePip = const Color(0x00000000);

  void update({
    required SliderPaintState state,
    required Color fill,
    required Color handle,
    required double emphasis,
    required double handleWidth,
    required double handleInset,
    required int? pipDivisions,
    required double pipSize,
    required double pipGrowth,
    required Color pip,
    required Color activePip,
  }) {
    _state = state;
    _fill = fill;
    _handle = handle;
    _emphasis = emphasis;
    _handleWidth = handleWidth;
    _handleInset = handleInset;
    _divisions = pipDivisions;
    _pipSize = pipSize;
    _pipGrowth = pipGrowth;
    _pip = pip;
    _activePip = activePip;
    notifyListeners();
  }

  @override
  void dispose() {
    _thumb.removeListener(notifyListeners);
    super.dispose();
  }

  @override
  void paint(Canvas canvas, Offset offset, CoilLayerGeometry geometry) {
    final state = _state;
    final row = geometry.rectOf(SliderTarget.track);
    if (state == null || row == null) return;
    final at = fraction().clamp(0.0, 1.0);
    final w = row.width;
    double x(double f) => state.reach.xAt(f, w, rtl: state.rtl);
    Rect span(double a, double b) => Rect.fromLTRB(
      offset.dx + (a < b ? a : b),
      offset.dy,
      offset.dx + (a < b ? b : a),
      offset.dy + row.height,
    );

    final divisions = _divisions;
    if (divisions != null) {
      final label = geometry.rectOf(SliderTarget.label);
      final value = geometry.rectOf(SliderTarget.value);
      final clear = _pipSize * 2;
      for (var i = 0; i <= divisions; i++) {
        final f = i / divisions;
        final cx = x(f);
        final cy = row.height / 2;
        bool under(Rect? r) =>
            r != null && r.inflate(clear).contains(Offset(cx, cy));
        if (under(label) || under(value)) continue;
        final near = (1 - (at - f).abs() * divisions).clamp(0.0, 1.0);
        final d = _pipSize * (1 + _pipGrowth * near);
        canvas.drawRSuperellipse(
          RSuperellipse.fromLTRBR(
            offset.dx + cx - d / 2,
            offset.dy + cy - d / 2,
            offset.dx + cx + d / 2,
            offset.dy + cy + d / 2,
            Radius.circular(d / 2),
          ),
          Paint()..color = Color.lerp(_pip, _activePip, near)!,
        );
      }
    }

    final edge = x(at);
    canvas.drawRect(span(state.rtl ? w : 0, edge), Paint()..color = _fill);
    if (state.previewOpacity > 0) {
      final p = x(state.previewFraction.clamp(0.0, 1.0));
      canvas.drawRect(
        span(edge, p),
        Paint()
          ..color = state.previewColor.withValues(
            alpha: state.previewColor.a * state.previewOpacity,
          ),
      );
    }

    final inset = _handleInset - _emphasis;
    final half = _handleWidth / 2;
    final line = edge.clamp(half + 3, w - half - 3);
    canvas.drawRSuperellipse(
      RSuperellipse.fromLTRBR(
        offset.dx + line - half,
        offset.dy + inset,
        offset.dx + line + half,
        offset.dy + row.height - inset,
        Radius.circular(half),
      ),
      Paint()..color = _handle,
    );
  }
}

/// Paints the pill track's outline, fill and hover preview.
class SliderPillPainter extends CoilLayerPainter {
  SliderPillPainter({required Listenable thumb, required this.fraction})
    : _thumb = thumb {
    thumb.addListener(notifyListeners);
  }

  final Listenable _thumb;
  final ValueGetter<double> fraction;

  SliderPaintState? _state;
  Color _fill = const Color(0x00000000);
  Color _border = const Color(0x00000000);
  double _height = 18;

  void update({
    required SliderPaintState state,
    required Color fill,
    required Color border,
    required double height,
  }) {
    _state = state;
    _fill = fill;
    _border = border;
    _height = height;
    notifyListeners();
  }

  @override
  void dispose() {
    _thumb.removeListener(notifyListeners);
    super.dispose();
  }

  @override
  void paint(Canvas canvas, Offset offset, CoilLayerGeometry geometry) {
    final state = _state;
    final box = geometry.rectOf(SliderTarget.track);
    if (state == null || box == null) return;
    final top = offset.dy + (box.height - _height) / 2;
    final shape = RSuperellipse.fromLTRBR(
      offset.dx,
      top,
      offset.dx + box.width,
      top + _height,
      Radius.circular(_height / 2),
    );
    double x(double f) => state.reach.xAt(f, box.width, rtl: state.rtl);
    Rect span(double a, double b) => Rect.fromLTRB(
      offset.dx + (a < b ? a : b),
      top,
      offset.dx + (a < b ? b : a),
      top + _height,
    );
    final edge = x(fraction().clamp(0.0, 1.0));
    canvas
      ..save()
      ..clipRSuperellipse(shape)
      ..drawRect(span(state.rtl ? box.width : 0, edge), Paint()..color = _fill);
    if (state.previewOpacity > 0) {
      final p = x(state.previewFraction.clamp(0.0, 1.0));
      canvas.drawRect(
        span(edge, p),
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
          ..color = _border,
      );
  }
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
