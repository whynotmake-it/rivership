import 'dart:math' as math;

import 'package:coil_example/src/shell/settings.dart';
import 'package:flutter/widgets.dart';

/// [child] on the screen of a painted [device]: the body with its rim,
/// bezel and side buttons, the screen's rounded corners, and the island or
/// camera hole over the screen.
///
/// [child] sees the device's screen through [MediaQuery]: its size in
/// [orientation], its safe areas as padding, and no keyboard. The frame
/// lays out at the device's real size and scales down to fit, never up.
class PhoneFrame extends StatelessWidget {
  const PhoneFrame({
    required this.device,
    required this.orientation,
    required this.child,
    super.key,
  });

  final CatalogDevice device;
  final Orientation orientation;
  final Widget child;

  /// Room around the body for the buttons that stand out of it.
  static const buttonDepth = 3.0;

  /// The frame's size at scale 1: the screen, the bezel and the buttons.
  static Size sizeOf(CatalogDevice device, Orientation orientation) {
    final screen = device.screenSizeIn(orientation);
    final edge = 2 * (device.bezel + buttonDepth);
    return Size(screen.width + edge, screen.height + edge);
  }

  @override
  Widget build(BuildContext context) {
    final screen = device.screenSizeIn(orientation);
    final safeArea = device.safeAreaIn(orientation);
    final landscape = orientation == Orientation.landscape;
    final media = MediaQuery.of(context).copyWith(
      size: screen,
      padding: safeArea,
      viewPadding: safeArea,
      viewInsets: EdgeInsets.zero,
      displayFeatures: const [],
    );
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: SizedBox.fromSize(
        size: sizeOf(device, orientation),
        child: CustomPaint(
          painter: _BodyPainter(device: device, landscape: landscape),
          foregroundPainter: _CutoutPainter(
            device: device,
            landscape: landscape,
          ),
          child: Padding(
            padding: EdgeInsets.all(device.bezel + buttonDepth),
            child: ClipRSuperellipse(
              borderRadius: BorderRadius.circular(device.screenRadius),
              child: MediaQuery(
                data: media,
                child: SizedBox.fromSize(size: screen, child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints in portrait coordinates: a landscape device is the portrait one
/// turned a quarter counterclockwise, its top to the left.
abstract class _DevicePainter extends CustomPainter {
  const _DevicePainter({required this.device, required this.landscape});

  final CatalogDevice device;
  final bool landscape;

  @override
  void paint(Canvas canvas, Size size) {
    if (!landscape) return paintPortrait(canvas, size);
    canvas
      ..save()
      ..translate(0, size.height)
      ..rotate(-math.pi / 2);
    paintPortrait(canvas, size.flipped);
    canvas.restore();
  }

  void paintPortrait(Canvas canvas, Size size);

  @override
  bool shouldRepaint(_DevicePainter oldDelegate) =>
      device != oldDelegate.device || landscape != oldDelegate.landscape;
}

class _BodyPainter extends _DevicePainter {
  const _BodyPainter({required super.device, required super.landscape});

  static const _frame = Color(0xFF2C2C2F);
  static const _frameLight = Color(0xFF4A4A4F);
  static const _rim = Color(0xFF6B6B70);
  static const _bezel = Color(0xFF060607);

  @override
  void paintPortrait(Canvas canvas, Size size) {
    const depth = PhoneFrame.buttonDepth;
    final body = Rect.fromLTWH(
      depth,
      depth,
      size.width - 2 * depth,
      size.height - 2 * depth,
    );
    final radius = device.screenRadius + device.bezel;

    _buttons(canvas, body);

    // The metal band, lit from above.
    final band = RSuperellipse.fromRectAndRadius(
      body,
      Radius.circular(radius),
    );
    canvas
      ..drawRSuperellipse(
        band,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_frameLight, _frame, _frameLight],
          ).createShader(body),
      )
      ..drawRSuperellipse(
        band.deflate(0.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = _rim,
      );

    // The black glass around the screen.
    final glassInset = math.min(3, device.bezel / 3).toDouble();
    canvas.drawRSuperellipse(
      RSuperellipse.fromRectAndRadius(
        body.deflate(glassInset),
        Radius.circular(radius - glassInset),
      ),
      Paint()..color = _bezel,
    );
  }

  /// The buttons along the body's sides, as fractions of its height (or,
  /// on top of a tablet, its width).
  void _buttons(Canvas canvas, Rect body) {
    final paint = Paint()..color = _frameLight;
    void side(double start, double length, {required bool left}) {
      final top = body.top + body.height * start;
      final rect = Rect.fromLTWH(
        left ? body.left - PhoneFrame.buttonDepth : body.right - 1,
        top,
        PhoneFrame.buttonDepth + 1,
        body.height * length,
      );
      canvas.drawRSuperellipse(
        RSuperellipse.fromRectAndRadius(rect, const Radius.circular(1.5)),
        paint,
      );
    }

    void top(double start, double length) => canvas.drawRSuperellipse(
      RSuperellipse.fromRectAndRadius(
        Rect.fromLTWH(
          body.left + body.width * start,
          body.top - PhoneFrame.buttonDepth,
          body.width * length,
          PhoneFrame.buttonDepth + 1,
        ),
        const Radius.circular(1.5),
      ),
      paint,
    );

    switch (device) {
      case CatalogDevice.iPhone:
        side(0.18, 0.035, left: true); // action
        side(0.26, 0.065, left: true); // volume up
        side(0.345, 0.065, left: true); // volume down
        side(0.27, 0.1, left: false); // side
        side(0.63, 0.07, left: false); // camera control
      case CatalogDevice.pixel:
        side(0.24, 0.07, left: false); // power
        side(0.35, 0.12, left: false); // volume
      case CatalogDevice.iPad:
        top(0.8, 0.07); // top button
        side(0.08, 0.05, left: false); // volume up
        side(0.14, 0.05, left: false); // volume down
    }
  }
}

class _CutoutPainter extends _DevicePainter {
  const _CutoutPainter({required super.device, required super.landscape});

  @override
  void paintPortrait(Canvas canvas, Size size) {
    final inset = device.bezel + PhoneFrame.buttonDepth;
    final centerX = size.width / 2;
    final paint = Paint()..color = const Color(0xFF000000);
    switch (device.cutout) {
      case CatalogCutout.none:
        break;
      case CatalogCutout.island:
        const width = 124.0;
        const height = 36.0;
        canvas
          ..drawRSuperellipse(
            RSuperellipse.fromRectAndRadius(
              Rect.fromLTWH(centerX - width / 2, inset + 11, width, height),
              const Radius.circular(height / 2),
            ),
            paint,
          )
          // The camera behind the glass.
          ..drawCircle(
            Offset(centerX + width / 2 - 20, inset + 11 + height / 2),
            5,
            Paint()..color = const Color(0xFF14142A),
          );
      case CatalogCutout.punchHole:
        final center = Offset(centerX, inset + 24);
        canvas
          ..drawCircle(center, 6.5, paint)
          ..drawCircle(center, 2.5, Paint()..color = const Color(0xFF14142A));
    }
  }
}
