import 'package:fluid_functionalism/fluid_functionalism.dart'
    show FluidColors, FluidPressable;
import 'package:fluid_functionalism/src/foundation/fluid_theme.dart';
import 'package:flutter/widgets.dart';

/// Paints the system's focus indicator around [child] without affecting
/// layout: a 1 px ring in [FluidColors.focusRing].
///
/// Matches Tailwind's `focus-visible:ring-1` (a ring hugging the border box)
/// and, with [offset], `ring-offset-*` (a gap between control and ring).
/// Show it only for keyboard focus; see [FluidPressable].
class FluidFocusRing extends StatelessWidget {
  /// Creates a focus ring.
  const FluidFocusRing({
    required this.visible,
    required this.borderRadius,
    required this.child,
    super.key,
    this.offset = 0,
    this.width,
    this.color,
  });

  /// Whether the ring shows.
  final bool visible;

  /// The radius of the [child]'s corners. The ring's radius grows by
  /// [offset] so it stays concentric.
  final BorderRadius borderRadius;

  /// Gap between [child] and the ring.
  final double offset;

  /// Ring thickness. Defaults to the theme's `focusRingWidth` (1, or 2 in
  /// high contrast).
  final double? width;

  /// Ring color. Defaults to the theme's focus ring color.
  final Color? color;

  /// The decorated widget.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: visible
          ? _RingPainter(
              color: color ?? FluidTheme.of(context).colors.focusRing,
              borderRadius: borderRadius,
              offset: offset,
              width: width ?? FluidTheme.of(context).focusRingWidth,
            )
          : null,
      child: child,
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.color,
    required this.borderRadius,
    required this.offset,
    required this.width,
  });

  final Color color;
  final BorderRadius borderRadius;
  final double offset;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final grow = offset + width / 2;
    final rrect = borderRadius
        .resolve(TextDirection.ltr)
        .toRRect(Offset.zero & size)
        .inflate(grow);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.color != color ||
      old.borderRadius != borderRadius ||
      old.offset != offset ||
      old.width != width;
}
