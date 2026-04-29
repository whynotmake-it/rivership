import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';

/// A custom-painted logo for the Motor example app header.
///
/// Draws a stylized waveform representing motion/animation.
class MotorLogo extends StatelessWidget {
  const MotorLogo({super.key, this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Padding(
      padding: const EdgeInsets.all(10),
      child: CustomPaint(
        size: Size.square(size),
        painter: _MotorLogoPainter(
          ringColor: t.accentGreen,
          waveColor: t.accentBlue,
          dotColor: t.accentPurple,
        ),
      ),
    );
  }
}

class _MotorLogoPainter extends CustomPainter {
  _MotorLogoPainter({
    required this.ringColor,
    required this.waveColor,
    required this.dotColor,
  });

  final Color ringColor;
  final Color waveColor;
  final Color dotColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.06
      ..color = ringColor;

    canvas.drawCircle(Offset(cx, cy), w * 0.42, ringPaint);

    final wavePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.08
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = waveColor;

    final path = Path();
    final startX = w * 0.22;
    final endX = w * 0.78;
    final midY = cy;
    final amp = h * 0.2;

    path.moveTo(startX, midY + amp);
    path.cubicTo(
      startX + (endX - startX) * 0.15,
      midY - amp * 1.6,
      cx - (endX - startX) * 0.05,
      midY + amp * 1.2,
      cx,
      midY,
    );
    path.cubicTo(
      cx + (endX - startX) * 0.05,
      midY - amp * 1.2,
      endX - (endX - startX) * 0.15,
      midY + amp * 1.6,
      endX,
      midY - amp,
    );

    canvas.drawPath(path, wavePaint);

    final dotPaint = Paint()..color = dotColor;
    canvas.drawCircle(Offset(endX, midY - amp), w * 0.045, dotPaint);
  }

  @override
  bool shouldRepaint(_MotorLogoPainter oldDelegate) =>
      ringColor != oldDelegate.ringColor ||
      waveColor != oldDelegate.waveColor ||
      dotColor != oldDelegate.dotColor;
}
