import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// The glyph shared by the rivership package logos: a ball with a concentric
/// motion arc below it.
///
/// Use [paint] inside a logo's own painter, or the widget on its own, which
/// fits the glyph into a square of [size].
class LogoGlyph extends StatelessWidget {
  const LogoGlyph({required this.color, this.size = 56, super.key});

  final Color color;
  final double size;

  /// The glyph's height, in ball radii: the ball's top to the arc's bottom.
  static const _height = 1 + 1.5 + 1 / 6 + 1 / 4;

  /// Paints the glyph with a ball of [radius] at [center].
  static void paint(Canvas canvas, Offset center, double radius, Color color) {
    canvas.drawCircle(center, radius, Paint()..color = color);
    final stroke = radius / 2;
    const spread = math.pi * .3;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 1.5 + stroke / 3),
      (math.pi - spread) / 2,
      spread,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _GlyphPainter(color));
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.height / LogoGlyph._height;
    LogoGlyph.paint(canvas, Offset(size.width / 2, radius), radius, color);
  }

  @override
  bool shouldRepaint(_GlyphPainter oldDelegate) => color != oldDelegate.color;
}

/// A package logo as shown in its README: [child] on a slightly tilted,
/// bordered tile, with room around it for the shadow.
class LogoTile extends StatelessWidget {
  const LogoTile({
    required this.color,
    required this.border,
    required this.shadow,
    required this.child,
    this.scale = 4,
    super.key,
  });

  final Color color;
  final Color border;
  final Color shadow;

  /// How much larger than its 56 px in-app size the logo is drawn.
  final double scale;

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Transform.rotate(
      angle: .05,
      child: Container(
        decoration: ShapeDecoration(
          color: color,
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(16 * scale),
            side: BorderSide(color: border),
          ),
          shadows: [
            BoxShadow(
              color: shadow,
              blurRadius: 4 * scale,
              offset: Offset(0, 2 * scale),
            ),
          ],
        ),
        child: child,
      ),
    ),
  );
}
