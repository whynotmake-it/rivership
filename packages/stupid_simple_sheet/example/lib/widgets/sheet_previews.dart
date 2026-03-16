import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:stupid_simple_sheet_example/widgets/example_theme.dart';

// ---------------------------------------------------------------------------
// Shared mini-sheet preview primitives
// ---------------------------------------------------------------------------

/// A tiny rounded-top sheet anchored to the bottom of its parent [Stack].
class MiniSheet extends StatelessWidget {
  const MiniSheet({
    super.key,
    this.width = 120,
    this.height = 80,
    this.child,
  });

  final double width;
  final double height;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Positioned(
      bottom: 0,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: t.previewMiniSurface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(ExampleTheme.miniSheetRadius),
          ),
          border: Border.all(color: t.previewMiniBorder),
          boxShadow: [
            BoxShadow(
              color: t.previewMiniShadow,
              blurRadius: 24,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

/// A tiny drag handle bar drawn at the top of a mini sheet.
class MiniHandle extends StatelessWidget {
  const MiniHandle({super.key});

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 6),
        width: 24,
        height: 3,
        decoration: BoxDecoration(
          color: t.previewHandle,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// A small horizontal line used to suggest list items inside a mini sheet.
class MiniListLine extends StatelessWidget {
  const MiniListLine({super.key, this.widthFraction = 0.6});

  final double widthFraction;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return FractionallySizedBox(
      widthFactor: widthFraction,
      child: Container(
        height: 3,
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: t.previewLine,
          borderRadius: BorderRadius.circular(1.5),
        ),
      ),
    );
  }
}

/// A colored rounded rectangle used as an accent element inside previews.
class MiniAccent extends StatelessWidget {
  const MiniAccent({
    super.key,
    this.widthFraction = 0.6,
    this.heightFraction = 0.4,
    this.color,
  });

  final double widthFraction;
  final double heightFraction;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return FractionallySizedBox(
      widthFactor: widthFraction,
      heightFactor: heightFraction,
      child: Container(
        decoration: BoxDecoration(
          color: color ?? t.accent,
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }
}

/// A centered mini "modal" box (not anchored to the bottom).
class MiniModal extends StatelessWidget {
  const MiniModal({
    super.key,
    this.width = 100,
    this.height = 60,
    this.child,
  });

  final double width;
  final double height;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: t.previewMiniSurface,
        borderRadius: BorderRadius.circular(ExampleTheme.miniModalRadius),
        border: Border.all(color: t.previewMiniBorder),
        boxShadow: [
          BoxShadow(
            color: t.previewMiniShadow,
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: t.cardHighlight,
            blurRadius: 0,
            spreadRadius: 1,
          ),
        ],
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// Background pattern painters for preview areas
// ---------------------------------------------------------------------------

/// Paints a dot grid background, matching the "mockup-grid" pattern.
class DotGridPainter extends CustomPainter {
  const DotGridPainter({
    this.dotColor = const Color(0xFFC7C7CC),
    this.dotRadius = 0.5,
    this.spacing = 16,
  });

  final Color dotColor;
  final double dotRadius;
  final double spacing;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = dotColor;
    for (var x = 0.0; x < size.width; x += spacing) {
      for (var y = 0.0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(DotGridPainter oldDelegate) =>
      dotColor != oldDelegate.dotColor ||
      dotRadius != oldDelegate.dotRadius ||
      spacing != oldDelegate.spacing;
}

/// Paints horizontal ruled lines, matching the "mockup-lines" pattern.
class LineGridPainter extends CustomPainter {
  const LineGridPainter({
    this.lineColor = const Color(0xFFE5E5EA),
    this.lineWidth = 0.5,
    this.spacing = 20,
  });

  final Color lineColor;
  final double lineWidth;
  final double spacing;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = lineWidth;
    for (var y = spacing; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(LineGridPainter oldDelegate) =>
      lineColor != oldDelegate.lineColor ||
      lineWidth != oldDelegate.lineWidth ||
      spacing != oldDelegate.spacing;
}

/// Paints horizontal dashed lines at specific fractional positions.
class DashedLinePainter extends CustomPainter {
  const DashedLinePainter({
    required this.fractions,
    this.lineColor = const Color(0xFFC7C7CC),
    this.dashWidth = 4,
    this.gapWidth = 3,
  });

  final List<double> fractions;
  final Color lineColor;
  final double dashWidth;
  final double gapWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 0.5;

    for (final frac in fractions) {
      final y = size.height * (1 - frac);
      var x = 0.0;
      while (x < size.width) {
        canvas.drawLine(
          Offset(x, y),
          Offset(math.min(x + dashWidth, size.width), y),
          paint,
        );
        x += dashWidth + gapWidth;
      }
    }
  }

  @override
  bool shouldRepaint(DashedLinePainter oldDelegate) =>
      fractions != oldDelegate.fractions || lineColor != oldDelegate.lineColor;
}
