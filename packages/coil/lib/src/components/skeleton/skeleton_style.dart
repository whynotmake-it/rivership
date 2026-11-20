import 'package:coil/foundation.dart';
import 'package:coil/src/components/skeleton/skeleton.dart'
    show CoilSkeletonTrack;
import 'package:flutter/painting.dart';
import 'package:motor/motor.dart';

/// Overrides for how a `CoilSkeleton` looks. Unset fields come from
/// [CoilSkeletonStyle.fallback].
class CoilSkeletonStyle extends CoilComponentStyle<CoilSkeletonStyle> {
  /// Creates a skeleton style.
  const CoilSkeletonStyle({
    this.fill,
    this.radius,
    this.textHeightFactor,
    this.motions,
  });

  /// The defaults from [theme]'s tokens at [metrics].
  factory CoilSkeletonStyle.fallback(
    CoilThemeData theme,
    CoilMetrics metrics,
  ) => CoilSkeletonStyle(
    fill: theme.colors.hover,
    radius: theme.shape.radii(metrics.tier).item,
    textHeightFactor: 0.6,
  );

  /// The block color (the `hover` tint).
  final Color? fill;

  /// The corner radius of a block.
  final double? radius;

  /// A text line's height as a fraction of the body line box.
  final double? textHeightFactor;

  /// Springs for the skeleton's animated parts, keyed by
  /// [CoilSkeletonTrack]s: `{CoilSkeletonTrack.swap: const Motion.instant()}`.
  /// A skeleton's own `motions:` win over these; these win over the motion
  /// tokens. [merge] combines the maps key by key.
  final Map<CoilSkeletonTrack<Object>, Motion>? motions;

  @override
  CoilSkeletonStyle merge(CoilSkeletonStyle? other) => other == null
      ? this
      : CoilSkeletonStyle(
          fill: other.fill ?? fill,
          radius: other.radius ?? radius,
          textHeightFactor: other.textHeightFactor ?? textHeightFactor,
          motions: other.motions == null
              ? motions
              : {...?motions, ...?other.motions},
        );

  @override
  List<Object?> get props => [fill, radius, textHeightFactor, motions];
}
