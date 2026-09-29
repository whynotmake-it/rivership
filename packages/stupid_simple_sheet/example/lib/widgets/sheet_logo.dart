import 'dart:ui' as ui;

import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';

/// The Stupid Simple Sheet logo.
///
/// Paints a stylised phone outline with a sheet being dragged upward by a
/// finger touch-point. A motion arc below the touch circle communicates
/// effortless gesture-driven interaction — the "stupid simple" part.
class SheetLogo extends StatelessWidget {
  const SheetLogo({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _SheetLogoPainter(
          deviceColor: t.textTertiary.withValues(alpha: .25),
          sheetColor: t.accentGold,
          gestureColor: t.surface,
        ),
      ),
    );
  }
}

class _SheetLogoPainter extends CustomPainter {
  _SheetLogoPainter({
    required this.deviceColor,
    required this.sheetColor,
    required this.gestureColor,
  });

  final Color deviceColor;
  final Color sheetColor;
  final Color gestureColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final inset = w * 0.12;
    final deviceRect = Rect.fromLTRB(inset, inset, w - inset, h - inset);
    final deviceRadius = w * 0.18;

    // -- Device outline --
    final deviceRRect = RRect.fromRectAndRadius(
      deviceRect,
      Radius.circular(deviceRadius),
    );
    final devicePaint = Paint()
      ..color = deviceColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.045;
    canvas.drawRRect(deviceRRect, devicePaint);

    // -- Sheet body (bottom 2/3 of device rect, rounded top) --
    final sheetTop = deviceRect.top + deviceRect.height * 0.33;
    final sheetRect = Rect.fromLTRB(
      deviceRect.left,
      sheetTop,
      deviceRect.right,
      deviceRect.bottom,
    );
    final sheetTopRadius = w * 0.14;

    canvas.save();
    canvas.clipRRect(deviceRRect);

    final sheetRRect = RRect.fromRectAndCorners(
      sheetRect,
      topLeft: Radius.circular(sheetTopRadius),
      topRight: Radius.circular(sheetTopRadius),
    );

    final sheetPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(sheetRect.center.dx, sheetRect.top),
        Offset(sheetRect.center.dx, sheetRect.bottom),
        [sheetColor, sheetColor.withValues(alpha: .7)],
      );
    canvas.drawRRect(sheetRRect, sheetPaint);

    canvas.restore();

    // -- Touch point with its motion arc, shared with the other logos --
    LogoGlyph.paint(
      canvas,
      Offset(w / 2, sheetTop + sheetTopRadius * 1.4),
      w * 0.09,
      gestureColor.withValues(alpha: .9),
    );
  }

  @override
  bool shouldRepaint(_SheetLogoPainter oldDelegate) =>
      deviceColor != oldDelegate.deviceColor ||
      sheetColor != oldDelegate.sheetColor ||
      gestureColor != oldDelegate.gestureColor;
}
