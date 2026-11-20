import 'package:coil/src/foundation/theme.dart';
import 'package:coil/src/primitives/surface.dart';
import 'package:flutter/widgets.dart';

/// The raised surface a popover's content sits on: a [CoilSurface] two
/// levels up with the level-3 shadow. Its corners are concentric with the
/// rows inside, and it is as wide as its widest row.
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

  /// The corner radius; when null, concentric with rows at the theme's
  /// item radius `popupInset` in (`CoilRadii.concentric`).
  final double? radius;

  /// The narrowest the surface gets.
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    final metrics = CoilTheme.metricsOf(context);
    final radii = CoilTheme.radiiOf(context);
    final radius = BorderRadius.circular(
      this.radius ??
          radii.concentric(
            radii.item,
            metrics.popupInset,
            innerExtent: metrics.controlHeight,
          ),
    );
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: minWidth),
      child: IntrinsicWidth(
        child: CoilSurface(
          offset: CoilSurface.popoverOffset,
          shadowLevel: 3,
          color: color,
          borderRadius: radius,
          child: ClipRSuperellipse(borderRadius: radius, child: child),
        ),
      ),
    );
  }
}
