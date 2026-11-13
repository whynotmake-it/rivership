import 'dart:math' as math;

import 'package:coil/src/foundation/theme.dart';
import 'package:flutter/widgets.dart';

/// A raised surface: the fill, shadow and edge of one step on the surface
/// ladder, and the scope that tells its children which step they sit on.
///
/// A surface opened from another one sits above it, so a menu inside a
/// dialog doesn't melt into it. The level is `min(ambient + offset, 8)`,
/// where the ambient level is the nearest [CoilSurface]'s (1, the page,
/// when there is none). Use [popoverOffset] for popovers, menus and sheets
/// and [dialogOffset] for dialogs. The level also reaches routes opened
/// from inside, such as a sheet.
///
/// In dark mode the edge gets a faint inner ring and a lighter top line.
/// They paint over the fill and under [child].
///
/// Pass [shadowLevel] to keep one shadow weight wherever the surface opens
/// while its fill follows the level, and [color] to replace the fill.
///
/// The surface doesn't clip: clip [child] with `ClipRSuperellipse` when it
/// has its own backgrounds.
class CoilSurface extends StatelessWidget {
  /// Creates a surface [offset] steps above the one it sits on.
  const CoilSurface({
    required this.offset,
    required this.child,
    super.key,
    this.borderRadius,
    this.shadowLevel,
    this.color,
  }) : assert(offset >= 0, 'a surface sits at or above its substrate');

  /// The offset of popovers, menus and sheets.
  static const popoverOffset = 2;

  /// The offset of dialogs.
  static const dialogOffset = 4;

  /// How many steps above the ambient surface this one sits.
  final int offset;

  /// The corner radius of the superellipse. Null is the theme's container
  /// radius.
  final BorderRadiusGeometry? borderRadius;

  /// The shadow step. Null follows the surface's own level.
  final int? shadowLevel;

  /// The fill. Null is the color of the surface's level.
  final Color? color;

  /// The content, which sits on this surface's level.
  final Widget child;

  /// The surface level [context] sits on, 1 (the page) to 8.
  static int levelOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SurfaceLevel>()?.level ?? 1;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final level = math.min(levelOf(context) + offset, 8);
    final radius =
        borderRadius ??
        BorderRadius.circular(CoilTheme.radiiOf(context).container);
    final weight = shadowLevel ?? level;
    return _SurfaceLevel(
      level: level,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: color ?? colors.surface(level),
          shadows: colors.shadow(weight),
          shape: RoundedSuperellipseBorder(borderRadius: radius),
        ),
        // Between the fill and the content, as inset shadows are.
        child: CustomPaint(
          painter: _EdgePainter(
            borderRadius: radius,
            ring: colors.insetRing(weight),
            highlight: colors.topHighlight(weight),
            textDirection: Directionality.of(context),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Carries the level. It is an [InheritedTheme] so that routes opened from
/// inside (through [InheritedTheme.capture]) continue the ladder.
class _SurfaceLevel extends InheritedTheme {
  const _SurfaceLevel({required this.level, required super.child});

  final int level;

  @override
  Widget wrap(BuildContext context, Widget child) =>
      _SurfaceLevel(level: level, child: child);

  @override
  bool updateShouldNotify(_SurfaceLevel old) => old.level != level;
}

/// Paints the dark recipe's inset ring and `inset 0 1px 0 0` highlight
/// inside the surface's shape.
class _EdgePainter extends CustomPainter {
  const _EdgePainter({
    required this.borderRadius,
    required this.ring,
    required this.highlight,
    required this.textDirection,
  });

  final BorderRadiusGeometry borderRadius;
  final BorderSide ring;
  final Color? highlight;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final shape = RoundedSuperellipseBorder(
      borderRadius: borderRadius,
      side: ring,
    );
    if (ring.style != BorderStyle.none) {
      shape.paint(canvas, rect, textDirection: textDirection);
    }
    final color = highlight;
    if (color == null) return;
    // The part of the shape that a copy shifted down by 1 px leaves
    // uncovered: a 1 px line along the top that follows the corners.
    final outer = RoundedSuperellipseBorder(
      borderRadius: borderRadius,
    ).getOuterPath(rect, textDirection: textDirection);
    final line = Path.combine(
      PathOperation.difference,
      outer,
      outer.shift(const Offset(0, 1)),
    );
    canvas.drawPath(line, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_EdgePainter old) =>
      old.borderRadius != borderRadius ||
      old.ring != ring ||
      old.highlight != highlight ||
      old.textDirection != textDirection;
}
