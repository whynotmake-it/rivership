import 'package:coil/src/foundation/material.dart';
import 'package:coil/src/foundation/theme.dart';
import 'package:coil/src/primitives/surface.dart';
import 'package:flutter/widgets.dart';

/// The raised surface a popover's content sits on: a [CoilSurface] two
/// levels up with the level-3 shadow. Its corners are concentric with the
/// rows inside, and it is as wide as its widest row.
///
/// Under a [CoilMaterialScope] the material builds the surface instead
/// (role [CoilSurfaceRole.popover]); [color] then doesn't apply.
class CoilPopoverSurface extends StatelessWidget {
  /// Creates a popover surface.
  const CoilPopoverSurface({
    required this.child,
    super.key,
    this.color,
    this.radius,
    this.minWidth = 0,
  });

  /// The content.
  final Widget child;

  /// The fill; the surface level's color when null.
  final Color? color;

  /// The corner radius; the theme's item radius plus the popup inset when
  /// null, so it stays concentric with the rows.
  final double? radius;

  /// The narrowest the surface gets.
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    final metrics = CoilTheme.metricsOf(context);
    final radius = BorderRadius.circular(
      this.radius ?? CoilTheme.radiiOf(context).item + metrics.popupInset,
    );
    final clipped = ClipRSuperellipse(borderRadius: radius, child: child);
    final material = CoilMaterialScope.maybeOf(context)?.surface(
      context,
      CoilSurfaceSpec(role: CoilSurfaceRole.popover, borderRadius: radius),
      clipped,
    );
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: minWidth),
      child: IntrinsicWidth(
        child: material != null
            ? CoilSurface.scope(
                offset: CoilSurface.popoverOffset,
                child: material,
              )
            : CoilSurface(
                offset: CoilSurface.popoverOffset,
                shadowLevel: 3,
                color: color,
                borderRadius: radius,
                child: clipped,
              ),
      ),
    );
  }
}
