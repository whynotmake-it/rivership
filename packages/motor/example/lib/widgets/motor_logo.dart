import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';

/// A custom-painted logo for the Motor example app header.
///
/// Draws a stylized waveform representing motion, in a single ink color.
class MotorLogo extends StatelessWidget {
  const MotorLogo({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return CustomPaint(
      size: Size.square(size),
      painter: _MotorLogoPainter(color: t.textPrimary),
    );
  }
}

class _MotorLogoPainter extends CustomPainter {
  _MotorLogoPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.05
      ..color = color.withValues(alpha: .18);

    canvas.drawCircle(Offset(cx, cy), w * 0.44, ringPaint);

    final wavePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.08
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    final startX = w * 0.22;
    final endX = w * 0.78;
    final midY = cy;
    final amp = h * 0.2;

    final path = Path()
      ..moveTo(startX, midY + amp)
      ..cubicTo(
        startX + (endX - startX) * 0.15,
        midY - amp * 1.6,
        cx - (endX - startX) * 0.05,
        midY + amp * 1.2,
        cx,
        midY,
      )
      ..cubicTo(
        cx + (endX - startX) * 0.05,
        midY - amp * 1.2,
        endX - (endX - startX) * 0.15,
        midY + amp * 1.6,
        endX,
        midY - amp,
      );

    canvas.drawPath(path, wavePaint);

    final dotPaint = Paint()..color = color;
    canvas.drawCircle(Offset(endX, midY - amp), w * 0.05, dotPaint);
  }

  @override
  bool shouldRepaint(_MotorLogoPainter oldDelegate) =>
      color != oldDelegate.color;
}
