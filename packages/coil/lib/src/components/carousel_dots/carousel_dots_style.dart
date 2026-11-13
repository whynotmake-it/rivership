import 'package:coil/foundation.dart';
import 'package:flutter/widgets.dart';

/// Overrides for how a `CoilCarouselDots` looks. Unset fields come from
/// [CoilCarouselDotsStyle.fallback], derived from the theme's tokens. Set a
/// style app-wide or for a subtree with `CoilThemeData.withComponentStyle`,
/// or per instance with `style:`.
class CoilCarouselDotsStyle extends CoilComponentStyle<CoilCarouselDotsStyle> {
  /// Creates a style.
  const CoilCarouselDotsStyle({
    this.track,
    this.fill,
    this.highlight,
    this.dotSize,
    this.pillWidth,
    this.targetSize,
    this.radius,
  });

  /// The defaults from the theme's tokens.
  factory CoilCarouselDotsStyle.fallback(
    CoilThemeData theme,
    CoilMetrics metrics,
  ) {
    final c = theme.colors;
    const target = 18.0;
    return CoilCarouselDotsStyle(
      track: CoilColorMix.withTransparent(c.foreground, 0.15),
      fill: CoilColorMix.withTransparent(c.foreground, 0.4),
      highlight: c.hover,
      dotSize: 6,
      pillWidth: 24,
      targetSize: target,
      // Round, except in the sharp shape family.
      radius: theme.shape == CoilShape.sharp
          ? theme.shape.radii(metrics.tier).item
          : target / 2,
    );
  }

  /// Every dot's color, and the current pill's track behind its fill.
  final Color? track;

  /// The current pill's fill: solid, or growing with `progress`.
  final Color? fill;

  /// The hover highlight that glides between dots.
  final Color? highlight;

  /// The diameter of a resting dot, and the height of the pill.
  final double? dotSize;

  /// The width of the current dot's pill.
  final double? pillWidth;

  /// The height of each dot's round click target. The dot sits centered in
  /// it, so dots are `targetSize - dotSize` apart.
  final double? targetSize;

  /// The corner radius of the targets and the highlight. Dots and the pill
  /// are fully rounded unless this is smaller than half their height.
  final double? radius;

  @override
  CoilCarouselDotsStyle merge(CoilCarouselDotsStyle? other) => other == null
      ? this
      : CoilCarouselDotsStyle(
          track: other.track ?? track,
          fill: other.fill ?? fill,
          highlight: other.highlight ?? highlight,
          dotSize: other.dotSize ?? dotSize,
          pillWidth: other.pillWidth ?? pillWidth,
          targetSize: other.targetSize ?? targetSize,
          radius: other.radius ?? radius,
        );

  @override
  List<Object?> get props => [
    track,
    fill,
    highlight,
    dotSize,
    pillWidth,
    targetSize,
    radius,
  ];
}
