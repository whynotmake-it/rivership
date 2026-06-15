import 'dart:ui';

import 'package:example_design/src/example_theme.dart';
import 'package:flutter/cupertino.dart';

/// A frosted, single-shadow surface — the primary content container.
///
/// Uses a translucent fill plus a backdrop blur so content layered beneath
/// (like an [AmbientGlow]) reads as soft, refracted light rather than a hard
/// panel.
class FrostedCard extends StatelessWidget {
  const FrostedCard({
    required this.child,
    this.padding = EdgeInsets.zero,
    this.radius = ExampleTheme.surfaceRadius,
    this.clip = true,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    final borderRadius = BorderRadius.circular(radius);

    final content = DecoratedBox(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: borderRadius,
        border: Border.all(color: t.border),
        boxShadow: t.softShadow,
      ),
      child: Padding(padding: padding, child: child),
    );

    if (!clip) return content;

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: content,
      ),
    );
  }
}

/// A neutral, quiet filled button. Never chromatic.
class NeutralButton extends StatefulWidget {
  const NeutralButton({
    required this.onPressed,
    required this.child,
    this.filled = true,
    super.key,
  });

  /// The action. When null, the button reads as disabled.
  final VoidCallback? onPressed;

  /// When false, renders as a transparent ghost button.
  final bool filled;

  final Widget child;

  @override
  State<NeutralButton> createState() => _NeutralButtonState();
}

class _NeutralButtonState extends State<NeutralButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    final enabled = widget.onPressed != null;
    final bg = widget.filled
        ? (_pressed ? t.textPrimary : t.pebble)
        : (_pressed ? t.fog : const Color(0x00000000));
    final fg = widget.filled && _pressed
        ? t.surfaceSolid
        : enabled
        ? t.textPrimary
        : t.textTertiary;

    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(
            color: fg,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.1,
          ),
          child: IconTheme.merge(
            data: IconThemeData(color: fg, size: 18),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// A small, quiet pill / chip label.
class GhostPill extends StatelessWidget {
  const GhostPill(this.text, {this.icon, super.key});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.fog,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(icon != null ? 10 : 14, 7, 14, 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: t.textSecondary),
              const SizedBox(width: 6),
            ],
            Text(
              text,
              style: TextStyle(
                color: t.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A soft, blurred wash of the [ExampleTheme.spectrum] gradient — the system's
/// only chromatic moment. Place it behind frosted surfaces for refracted light.
class AmbientGlow extends StatelessWidget {
  const AmbientGlow({
    this.opacity = 0.35,
    this.blur = 60,
    this.alignment = Alignment.topCenter,
    super.key,
  });

  final double opacity;
  final double blur;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Align(
            alignment: alignment,
            child: FractionallySizedBox(
              widthFactor: 0.9,
              heightFactor: 0.55,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: ExampleTheme.spectrum,
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints a poly-line through normalized points (0..1 in both axes).
///
/// The most recent samples are at the right edge; older samples fade out to
/// the left, giving a sense of motion history.
class TrajectoryLine extends StatelessWidget {
  const TrajectoryLine({
    required this.points,
    this.color,
    this.gradient,
    this.thickness = 3,
    this.fade = true,
    super.key,
  });

  /// Normalized points where x and y are both in `0..1`.
  final List<Offset> points;
  final Color? color;
  final Gradient? gradient;
  final double thickness;
  final bool fade;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _LinePainter(
        points: points,
        color: color ?? const Color(0xFF000000),
        gradient: gradient,
        thickness: thickness,
        fade: fade,
      ),
      size: Size.infinite,
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.points,
    required this.color,
    required this.gradient,
    required this.thickness,
    required this.fade,
  });

  final List<Offset> points;
  final Color color;
  final Gradient? gradient;
  final double thickness;
  final bool fade;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final scaled = [
      for (final p in points) Offset(p.dx * size.width, p.dy * size.height),
    ];

    final shader = gradient?.createShader(
      Rect.fromLTWH(0, 0, size.width, size.height),
    );

    for (var i = 0; i < scaled.length - 1; i++) {
      final progress = i / (scaled.length - 1);
      final opacity = fade ? Curves.easeIn.transform(progress) : 1.0;
      final paint = Paint()
        ..strokeWidth = thickness
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      if (shader != null) {
        paint
          ..shader = shader
          ..color = const Color(0xFFFFFFFF).withValues(alpha: opacity);
      } else {
        paint.color = color.withValues(alpha: opacity);
      }
      canvas.drawLine(scaled[i], scaled[i + 1], paint);
    }
  }

  @override
  bool shouldRepaint(_LinePainter oldDelegate) =>
      points != oldDelegate.points ||
      color != oldDelegate.color ||
      gradient != oldDelegate.gradient ||
      thickness != oldDelegate.thickness ||
      fade != oldDelegate.fade;
}
