import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Clips its child using the given [shape].
///
/// Compared to using [ClipPath] directly, this widget optimizes for
/// performance by using more efficient clipping methods when possible.
///
/// If [shape] is null, no clipping is applied.
@internal
class OptimizedClip extends StatelessWidget {
  const OptimizedClip({
    required this.shape,
    required this.child,
    this.clipBehavior = Clip.antiAlias,
    super.key,
  });

  final ShapeBorder? shape;

  final Clip clipBehavior;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final shape = this.shape;
    return switch (shape) {
      null => child,
      RoundedSuperellipseBorder(:final borderRadius) => ClipRSuperellipse(
          borderRadius: borderRadius,
          child: child,
        ),
      RoundedRectangleBorder(:final borderRadius) => ClipRRect(
          borderRadius: borderRadius,
          child: child,
        ),
      OvalBorder() => ClipOval(child: child),
      LinearBorder() => ClipRect(child: child),
      _ => ClipPath(
          clipper: ShapeBorderClipper(
            shape: shape,
          ),
          child: child,
        )
    };
  }
}
