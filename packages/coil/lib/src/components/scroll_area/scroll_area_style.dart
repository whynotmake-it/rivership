import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
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
    this.touchThickness,
    this.crossAxisMargin,
    this.mainAxisMargin,
    this.fadeExtent,
    this.lineStep,
  });

  /// The defaults from the theme's tokens.
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
      touchThickness: 3,
      crossAxisMargin: 2,
      mainAxisMargin: 4,
      fadeExtent: 32,
      lineStep: 60,
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

  /// The overlay bar's width on the touch tier.
  final double? touchThickness;

  /// The gap between the thumb and the viewport's edge.
  final double? crossAxisMargin;

  /// The gap between the thumb and the viewport's ends.
  final double? mainAxisMargin;

  /// How far the edge fades reach.
  final double? fadeExtent;

  /// How far an arrow key scrolls: about three lines of body text.
  final double? lineStep;

  /// The scrollbar look this style describes. Call it on a resolved style.
  CoilScrollbarLook get scrollbarLook => CoilScrollbarLook(
    color: thumb!,
    hoverColor: thumbHovered!,
    dragColor: thumbDragged!,
    thickness: thickness!,
    hoverThickness: hoverThickness!,
    touchThickness: touchThickness!,
    crossAxisMargin: crossAxisMargin!,
    mainAxisMargin: mainAxisMargin!,
  );

  @override
  CoilScrollAreaStyle merge(CoilScrollAreaStyle? other) => other == null
      ? this
      : CoilScrollAreaStyle(
          thumb: other.thumb ?? thumb,
          thumbHovered: other.thumbHovered ?? thumbHovered,
          thumbDragged: other.thumbDragged ?? thumbDragged,
          thickness: other.thickness ?? thickness,
          hoverThickness: other.hoverThickness ?? hoverThickness,
          touchThickness: other.touchThickness ?? touchThickness,
          crossAxisMargin: other.crossAxisMargin ?? crossAxisMargin,
          mainAxisMargin: other.mainAxisMargin ?? mainAxisMargin,
          fadeExtent: other.fadeExtent ?? fadeExtent,
          lineStep: other.lineStep ?? lineStep,
        );

  @override
  List<Object?> get props => [
    thumb,
    thumbHovered,
    thumbDragged,
    thickness,
    hoverThickness,
    touchThickness,
    crossAxisMargin,
    mainAxisMargin,
    fadeExtent,
    lineStep,
  ];
}
