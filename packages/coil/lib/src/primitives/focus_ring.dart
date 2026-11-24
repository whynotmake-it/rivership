/// @docImport 'package:coil/src/primitives/interaction.dart';
library;

import 'package:coil/src/foundation/focus_ring_theme.dart'
    show CoilFocusRingTheme;
import 'package:coil/src/foundation/theme.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// The focus ring around [child], as the theme's [CoilFocusRingTheme] draws
/// it: a 1 px line in the brand color by default (2 px in high contrast),
/// [offset] outside it.
///
/// It fades in and out and never changes layout.
///
/// Show it only for keyboard focus, which [CoilInteraction] reports as
/// [WidgetState.focused].
class CoilFocusRing extends StatelessWidget {
  /// Creates a focus ring.
  const CoilFocusRing({
    required this.visible,
    required this.borderRadius,
    required this.child,
    super.key,
    this.offset,
    this.width,
    this.color,
  });

  /// Whether the ring shows.
  final bool visible;

  /// The radius of the [child]'s corners.
  ///
  /// The ring's radius grows by [offset] so it stays concentric.
  /// Directional radii resolve with the ambient [Directionality].
  final BorderRadiusGeometry borderRadius;

  /// Gap between [child] and the ring.
  ///
  /// Defaults to the theme's [CoilFocusRingTheme.offset].
  final double? offset;

  /// Ring thickness.
  ///
  /// Defaults to the theme's [CoilFocusRingTheme.width] (1, or 2 in high
  /// contrast).
  final double? width;

  /// Ring color.
  ///
  /// Defaults to the theme's focus ring color.
  final Color? color;

  /// The decorated widget.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final motion = CoilTheme.motionOf(context);
    final ring = color ?? theme.focusRing.colorOf(theme.colors);
    return SingleMotionBuilder(
      value: visible ? 1 : 0,
      motion: visible ? motion.fade : motion.fadeExit,
      debugLabel: 'CoilFocusRing',
      child: child,
      builder: (context, opacity, child) => CustomPaint(
        foregroundPainter: opacity <= 0
            ? null
            : _RingPainter(
                color: ring.withValues(
                  alpha: ring.a * opacity.clamp(0.0, 1.0),
                ),
                borderRadius: borderRadius.resolve(
                  Directionality.maybeOf(context),
                ),
                offset: offset ?? theme.focusRing.offset,
                width: width ?? theme.focusRing.width,
              ),
        child: child,
      ),
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
