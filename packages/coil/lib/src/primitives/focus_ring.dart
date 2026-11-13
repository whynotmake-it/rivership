import 'package:coil/src/foundation/colors.dart' show CoilColors;
import 'package:coil/src/foundation/theme.dart';
import 'package:flutter/widgets.dart';

/// Paints the system's focus indicator around [child] without affecting
/// layout: a 1 px ring in [CoilColors.focusRing].
///
/// Matches Tailwind's `focus-visible:ring-1` (a ring hugging the border box)
/// and, with [offset], `ring-offset-*` (a gap between control and ring).
/// Show it only for keyboard focus (`CoilInteraction` reports it as
/// [WidgetState.focused]).
class CoilFocusRing extends StatelessWidget {
  /// Creates a focus ring.
  const CoilFocusRing({
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
              color: color ?? CoilTheme.of(context).colors.focusRing,
              borderRadius: borderRadius,
              offset: offset,
              width: width ?? CoilTheme.of(context).focusRingWidth,
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
    final outline = borderRadius
        .resolve(TextDirection.ltr)
        .toRSuperellipse(Offset.zero & size)
        .inflate(grow);
    // The ring follows the control's superellipse at its offset.
    canvas.drawRSuperellipse(
      outline,
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
