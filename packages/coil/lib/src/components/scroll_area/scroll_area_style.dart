import 'package:coil/foundation.dart';
import 'package:flutter/widgets.dart';

/// Overrides for how a `CoilScrollArea` looks. Unset fields come from
/// [CoilScrollAreaStyle.fallback], derived from the theme's tokens. Set a
/// style app-wide or for a subtree with
/// `CoilThemeData.withComponentStyle`, or per instance with `style:`.
class CoilScrollAreaStyle extends CoilComponentStyle<CoilScrollAreaStyle> {
  /// Creates a style.
  const CoilScrollAreaStyle({
    this.thumb,
    this.thumbHovered,
    this.thumbDragged,
    this.thickness,
    this.hoverThickness,
    this.fadeExtent,
  });

  /// The defaults from the theme's tokens. [metrics] is unused today; it
  /// keeps every style's fallback the same shape.
  factory CoilScrollAreaStyle.fallback(
    CoilThemeData theme,
    // Same shape as every fallback.
    // ignore: avoid_unused_constructor_parameters
    CoilMetrics metrics,
  ) {
    final fg = theme.colors.foreground;
    return CoilScrollAreaStyle(
      thumb: fg.withValues(alpha: 0.08),
      thumbHovered: fg.withValues(alpha: 0.12),
      thumbDragged: fg.withValues(alpha: 0.16),
      thickness: 4,
      hoverThickness: 6,
      fadeExtent: 32,
    );
  }

  /// The pointer scrollbar's thumb at rest (and the touch overlay bar).
  final Color? thumb;

  /// The thumb while a hovering pointer is over the scrollbar.
  final Color? thumbHovered;

  /// The thumb while it's dragged.
  final Color? thumbDragged;

  /// The pointer thumb's width at rest.
  final double? thickness;

  /// The pointer thumb's width while hovered or dragged.
  final double? hoverThickness;

  /// How far the edge fades reach.
  final double? fadeExtent;

  @override
  CoilScrollAreaStyle merge(CoilScrollAreaStyle? other) => other == null
      ? this
      : CoilScrollAreaStyle(
          thumb: other.thumb ?? thumb,
          thumbHovered: other.thumbHovered ?? thumbHovered,
          thumbDragged: other.thumbDragged ?? thumbDragged,
          thickness: other.thickness ?? thickness,
          hoverThickness: other.hoverThickness ?? hoverThickness,
          fadeExtent: other.fadeExtent ?? fadeExtent,
        );

  @override
  List<Object?> get props => [
    thumb,
    thumbHovered,
    thumbDragged,
    thickness,
    hoverThickness,
    fadeExtent,
  ];
}
