import 'dart:ui' as ui;

import 'package:coil/src/foundation/typography.dart';
import 'package:flutter/widgets.dart';

/// The small glyphs coil draws itself (DESIGN.md §11).
enum CoilGlyph {
  /// A tick: checked, copied.
  check,

  /// A dash: indeterminate.
  dash,

  /// An ×: failed.
  cross,

  /// A circled exclamation mark: a field error.
  alert,
}

/// Draws a [CoilGlyph] on the 24-unit grid with a 2-unit round stroke.
///
/// It sizes and colors itself like an `Icon`: from the ambient [IconTheme],
/// scaled with text. [progress] draws the strokes in from 0 (nothing) to 1
/// (complete), for a glyph that animates in.
class CoilDrawnGlyph extends StatelessWidget {
  /// Creates a drawn glyph.
  const CoilDrawnGlyph(this.glyph, {super.key, this.progress = 1, this.color});

  /// Which glyph.
  final CoilGlyph glyph;

  /// How much of the strokes is drawn, 0 to 1.
  final double progress;

  /// The stroke color; the ambient [IconTheme]'s when null.
  final Color? color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size.square(CoilIconSize.of(context)),
      painter: _GlyphPainter(
        glyph,
        progress.clamp(0, 1),
        color ?? IconTheme.of(context).color ?? const Color(0xFF000000),
      ),
    ),
  );
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.glyph, this.progress, this.color);

  final CoilGlyph glyph;
  final double progress;
  final Color color;

  ui.Path _path() => switch (glyph) {
    CoilGlyph.check =>
      ui.Path()
        ..moveTo(6, 12)
        ..lineTo(10, 16)
        ..lineTo(18, 8),
    CoilGlyph.dash =>
      ui.Path()
        ..moveTo(7, 12)
        ..lineTo(17, 12),
    CoilGlyph.cross =>
      ui.Path()
        ..moveTo(7, 7)
        ..lineTo(17, 17)
        ..moveTo(17, 7)
        ..lineTo(7, 17),
    CoilGlyph.alert =>
      ui.Path()
        ..addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 10))
        ..moveTo(12, 8)
        ..lineTo(12, 12)
        ..moveTo(12, 16)
        ..lineTo(12.01, 16),
  };

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    var path = _path();
    if (progress < 1) {
      final drawn = ui.Path();
      for (final metric in path.computeMetrics()) {
        drawn.addPath(metric.extractPath(0, metric.length * progress), .zero);
      }
      path = drawn;
    }
    canvas
      ..save()
      ..scale(size.width / 24)
      ..drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.glyph != glyph || old.progress != progress || old.color != color;
}
