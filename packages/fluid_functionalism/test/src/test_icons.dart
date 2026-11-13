import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Stroke glyphs for tests and goldens only. The package bundles no icons:
/// slots take any widget, styled through [IconTheme].
enum TestGlyph { plus, arrowRight, search, x, home, heart, settings }

/// A painted stroke icon that follows the ambient [IconTheme]: `size`,
/// `color`, and `weight` (400 draws a 1.5 stroke on the 24-unit grid; the
/// stroke scales with weight, so a control raising the weight on hover
/// thickens it, like the web's 1.5 → 2 stroke).
class TestIcon extends StatelessWidget {
  const TestIcon(this.glyph, {super.key});

  final TestGlyph glyph;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final size = theme.size ?? 16;
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: _GlyphPainter(
          glyph,
          theme.color ?? const Color(0xFF000000),
          1.5 * (theme.weight ?? 400) / 400,
        ),
      ),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.glyph, this.color, this.stroke);

  final TestGlyph glyph;
  final Color color;
  final double stroke;

  ui.Path _path() {
    final p = ui.Path();
    switch (glyph) {
      case TestGlyph.plus:
        p
          ..moveTo(5, 12)
          ..lineTo(19, 12)
          ..moveTo(12, 5)
          ..lineTo(12, 19);
      case TestGlyph.arrowRight:
        p
          ..moveTo(5, 12)
          ..lineTo(19, 12)
          ..moveTo(12, 5)
          ..lineTo(19, 12)
          ..lineTo(12, 19);
      case TestGlyph.search:
        p
          ..addOval(Rect.fromCircle(center: const Offset(11, 11), radius: 8))
          ..moveTo(21, 21)
          ..lineTo(16.65, 16.65);
      case TestGlyph.x:
        p
          ..moveTo(18, 6)
          ..lineTo(6, 18)
          ..moveTo(6, 6)
          ..lineTo(18, 18);
      case TestGlyph.home:
        p
          ..moveTo(3, 10)
          ..lineTo(12, 3)
          ..lineTo(21, 10)
          ..lineTo(21, 20)
          ..lineTo(15, 20)
          ..lineTo(15, 14)
          ..lineTo(9, 14)
          ..lineTo(9, 20)
          ..lineTo(3, 20)
          ..close();
      case TestGlyph.heart:
        p
          ..moveTo(12, 20)
          ..cubicTo(12, 20, 3, 14.5, 3, 8.5)
          ..cubicTo(3, 5.5, 5.5, 3.5, 8, 3.5)
          ..cubicTo(9.8, 3.5, 11.2, 4.5, 12, 6)
          ..cubicTo(12.8, 4.5, 14.2, 3.5, 16, 3.5)
          ..cubicTo(18.5, 3.5, 21, 5.5, 21, 8.5)
          ..cubicTo(21, 14.5, 12, 20, 12, 20)
          ..close();
      case TestGlyph.settings:
        p.addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 3.5));
        for (final (x1, y1, x2, y2) in const [
          (12.0, 2.0, 12.0, 5.0),
          (12.0, 19.0, 12.0, 22.0),
          (2.0, 12.0, 5.0, 12.0),
          (19.0, 12.0, 22.0, 12.0),
        ]) {
          p
            ..moveTo(x1, y1)
            ..lineTo(x2, y2);
        }
    }
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..scale(size.shortestSide / 24)
      ..drawPath(
        _path(),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.glyph != glyph || old.color != color || old.stroke != stroke;
}
