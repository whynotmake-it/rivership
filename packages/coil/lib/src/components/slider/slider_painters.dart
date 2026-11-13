// Internal to CoilSlider; not exported.
// ignore_for_file: public_member_api_docs, use_key_in_widget_constructors

import 'dart:math' as math;

import 'package:coil/src/components/slider/slider.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// The reach of the handle line from the row's ends.
const sliderHandleInset = 5.0;

/// Positions the value bubble centered over the thumb, 8 px above the top.
class SliderBubbleLayout extends SingleChildLayoutDelegate {
  SliderBubbleLayout({required this.fraction, required this.reach});

  /// 0..1 from the leading edge, already mirrored for RTL.
  final double fraction;
  final (double, double) Function(double width) reach;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      const BoxConstraints();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final (start, end) = reach(size.width);
    final x = start + fraction * (end - start);
    return Offset(x - childSize.width / 2, -(8 + childSize.height));
  }

  @override
  bool shouldRelayout(SliderBubbleLayout old) => old.fraction != fraction;
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// The comfortable row's fill, hover preview and handle line.
class SliderFillPainter extends CustomPainter {
  SliderFillPainter({
    required this.controller,
    required this.thumb,
    required this.preview,
    required this.previewOpacity,
    required this.fill,
    required this.previewColor,
    required this.handle,
    required this.emphasis,
    required this.pad,
    required this.rtl,
  }) : super(repaint: controller);

  final TrackController controller;
  final CoilSliderTrack<double> thumb;
  final CoilSliderTrack<double> preview;
  final CoilSliderTrack<double> previewOpacity;
  final Color fill;
  final Color previewColor;
  final Color handle;
  final double emphasis;
  final double pad;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    double mirror(double x) => rtl ? w - x : x;
    double xAt(double f) => pad > 0 ? _lerp(pad, w - pad, f) : _lerp(0, w, f);
    final at = controller.value(thumb).clamp(0.0, 1.0);
    final edge = xAt(at) + (pad > 0 ? 1 : 0);

    Rect span(double a, double b) {
      final l = mirror(a);
      final r = mirror(b);
      return Rect.fromLTRB(math.min(l, r), 0, math.max(l, r), size.height);
    }

    canvas.drawRect(span(0, edge), Paint()..color = fill);

    final shown = controller.value(previewOpacity).clamp(0.0, 1.0);
    if (shown > 0) {
      final p = xAt(controller.value(preview).clamp(0.0, 1.0));
      final a = math.min(edge, p);
      final b = math.max(edge, p);
      canvas.drawRect(
        span(a, b),
        Paint()
          ..color = previewColor.withValues(
            alpha: previewColor.a * shown,
          ),
      );
    }

    final lineX = mirror(
      pad > 0 ? xAt(at) : edge.clamp(sliderHandleInset, w - sliderHandleInset),
    );
    final inset = 8 - emphasis;
    final line = RSuperellipse.fromLTRBR(
      lineX - 1,
      inset,
      lineX + 1,
      size.height - inset,
      const Radius.circular(1),
    );
    canvas.drawRSuperellipse(line, Paint()..color = handle);
  }

  @override
  bool shouldRepaint(SliderFillPainter old) =>
      old.fill != fill ||
      old.previewColor != previewColor ||
      old.handle != handle ||
      old.emphasis != emphasis ||
      old.pad != pad ||
      old.rtl != rtl;
}

/// The dots of the pips variant, the active one in foreground.
class SliderPipsPainter extends CustomPainter {
  SliderPipsPainter({
    required this.controller,
    required this.thumb,
    required this.divisions,
    required this.pad,
    required this.size,
    required this.pip,
    required this.active,
    required this.rtl,
  }) : super(repaint: controller);

  final TrackController controller;
  final CoilSliderTrack<double> thumb;
  final int divisions;
  final double pad;
  final double size;
  final Color pip;
  final Color active;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size box) {
    final at = controller.value(thumb).clamp(0.0, 1.0);
    for (var i = 0; i <= divisions; i++) {
      final f = i / divisions;
      final near = (1 - (at - f).abs() * divisions).clamp(0.0, 1.0);
      var x = _lerp(pad, box.width - pad, f);
      if (rtl) x = box.width - x;
      final d = size * (1 + 0.4 * near);
      canvas.drawRSuperellipse(
        RSuperellipse.fromLTRBR(
          x - d / 2,
          box.height / 2 - d / 2,
          x + d / 2,
          box.height / 2 + d / 2,
          Radius.circular(d / 2),
        ),
        Paint()..color = Color.lerp(pip, active, near)!,
      );
    }
  }

  @override
  bool shouldRepaint(SliderPipsPainter old) =>
      old.pip != pip ||
      old.active != active ||
      old.pad != pad ||
      old.size != size ||
      old.divisions != divisions ||
      old.rtl != rtl;
}

/// The compact pill track: outline, fill up to the knob and the preview.
class SliderCompactPainter extends CustomPainter {
  SliderCompactPainter({
    required this.controller,
    required this.thumb,
    required this.preview,
    required this.previewOpacity,
    required this.fill,
    required this.border,
    required this.previewColor,
    required this.trackHeight,
    required this.box,
    required this.rtl,
  }) : super(repaint: controller);

  final TrackController controller;
  final CoilSliderTrack<double> thumb;
  final CoilSliderTrack<double> preview;
  final CoilSliderTrack<double> previewOpacity;
  final Color fill;
  final Color border;
  final Color previewColor;
  final double trackHeight;
  final double box;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final top = (size.height - trackHeight) / 2;
    final shape = RSuperellipse.fromLTRBR(
      0,
      top,
      w,
      top + trackHeight,
      Radius.circular(trackHeight / 2),
    );
    double mirror(double x) => rtl ? w - x : x;
    double xAt(double f) => _lerp(box / 2, math.max(box / 2, w - box / 2), f);
    Rect span(double a, double b) {
      final l = mirror(a);
      final r = mirror(b);
      return Rect.fromLTRB(
        math.min(l, r),
        top,
        math.max(l, r),
        top + trackHeight,
      );
    }

    final edge = xAt(controller.value(thumb).clamp(0.0, 1.0));
    canvas
      ..save()
      ..clipRSuperellipse(shape)
      ..drawRect(span(0, edge), Paint()..color = fill);
    final shown = controller.value(previewOpacity).clamp(0.0, 1.0);
    if (shown > 0) {
      final p = xAt(controller.value(preview).clamp(0.0, 1.0));
      canvas.drawRect(
        span(math.min(edge, p), math.max(edge, p)),
        Paint()..color = previewColor.withValues(alpha: previewColor.a * shown),
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

  @override
  bool shouldRepaint(SliderCompactPainter old) =>
      old.fill != fill ||
      old.border != border ||
      old.previewColor != previewColor ||
      old.trackHeight != trackHeight ||
      old.box != box ||
      old.rtl != rtl;
}
