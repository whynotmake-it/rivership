import 'package:coil/foundation.dart';
import 'package:flutter/widgets.dart';

/// Overrides for how a `CoilCard` and a `CoilCardGroup` look. Unset fields
/// come from [CoilCardStyle.fallback], derived from the theme's tokens. Set
/// a style app-wide or for a subtree with
/// `CoilThemeData.withComponentStyle`, or per instance with `style:`.
///
/// [overlay] is resolved with [WidgetState.hovered] and
/// [WidgetState.pressed].
class CoilCardStyle extends CoilComponentStyle<CoilCardStyle> {
  /// Creates a style.
  const CoilCardStyle({
    this.surface,
    this.border,
    this.shadows,
    this.radius,
    this.padding,
    this.overlay,
    this.highlight,
    this.divider,
    this.spacing,
    this.gap,
    this.headerGap,
    this.actionSpacing,
    this.mediaExtent,
    this.tile,
    this.tileExtent,
    this.tilePadding,
    this.dismissInset,
    this.titleStyle,
    this.descriptionStyle,
    this.contentStyle,
  });

  /// The defaults from the theme's tokens: surface 3 with its shadow in
  /// light, surface 2 with a hairline in dark.
  factory CoilCardStyle.fallback(CoilThemeData theme, CoilMetrics metrics) {
    final c = theme.colors;
    final light = c.brightness == Brightness.light;
    final typography = theme.typography;
    return CoilCardStyle(
      // TODO(surface-scope): take the elevation from the surface scope.
      surface: c.surface(light ? 3 : 2),
      border: light ? BorderSide.none : BorderSide(color: c.border),
      shadows: light ? c.shadow(3) : const [],
      radius: theme.shape.radii(metrics.tier).container,
      padding: metrics.size == CoilSize.compact ? 12 : 16,
      overlay: WidgetStateProperty.fromMap({
        WidgetState.pressed: c.active,
        WidgetState.hovered: c.hover,
        WidgetState.any: c.hover.withValues(alpha: 0),
      }),
      highlight: c.hover,
      divider: c.border,
      spacing: 8,
      gap: 12,
      headerGap: 4,
      actionSpacing: 4,
      mediaExtent: 160,
      tile: c.active,
      tileExtent: 32,
      tilePadding: 8,
      dismissInset: 8,
      titleStyle: typography.style(
        _title(metrics),
        weight: CoilWeight.semibold,
        color: c.foreground,
      ),
      descriptionStyle: typography.style(
        metrics.caption,
        color: c.mutedForeground,
      ),
      contentStyle: typography.style(metrics.body, color: c.foreground),
    );
  }

  /// The title role (DESIGN.md §3.1) for [metrics].
  static CoilTypeStep _title(CoilMetrics metrics) =>
      switch ((metrics.tier, metrics.size)) {
        (CoilTier.pointer, CoilSize.regular) => const CoilTypeStep(16, 22),
        (CoilTier.pointer, CoilSize.compact) => const CoilTypeStep(14, 20),
        (CoilTier.touch, CoilSize.regular) => const CoilTypeStep(17, 22),
        (CoilTier.touch, CoilSize.compact) => const CoilTypeStep(16, 22),
      };

  /// The card's fill.
  final Color? surface;

  /// The card's outline (a hairline in dark, none in light).
  final BorderSide? border;

  /// The card's shadow.
  final List<BoxShadow>? shadows;

  /// The corner radius of cards, group blocks and the group highlight.
  final double? radius;

  /// The padding around a card's content.
  final double? padding;

  /// The fill over a card with an action: hover (pointer, standalone cards)
  /// and press (touch).
  final WidgetStateProperty<Color?>? overlay;

  /// The highlight that glides between the cards of a group.
  final Color? highlight;

  /// The hairline between the cards of a divided group.
  final Color? divider;

  /// The gap between the cards of a separated group.
  final double? spacing;

  /// The gap between a card's icon, header, content and actions.
  final double? gap;

  /// The gap between the title and the description.
  final double? headerGap;

  /// The gap between a card's action buttons.
  final double? actionSpacing;

  /// The side of an inline card's square media.
  final double? mediaExtent;

  /// The tinted tile behind a card's `icon`.
  final Color? tile;

  /// The smallest side of the icon tile.
  final double? tileExtent;

  /// The padding between the icon tile and its icon.
  final double? tilePadding;

  /// The gap between the dismiss button and the card's top and trailing
  /// edges.
  final double? dismissInset;

  /// The title's text style.
  final TextStyle? titleStyle;

  /// The description's text style.
  final TextStyle? descriptionStyle;

  /// The default text style of the content.
  final TextStyle? contentStyle;

  @override
  CoilCardStyle merge(CoilCardStyle? other) => other == null
      ? this
      : CoilCardStyle(
          surface: other.surface ?? surface,
          border: other.border ?? border,
          shadows: other.shadows ?? shadows,
          radius: other.radius ?? radius,
          padding: other.padding ?? padding,
          overlay: other.overlay ?? overlay,
          highlight: other.highlight ?? highlight,
          divider: other.divider ?? divider,
          spacing: other.spacing ?? spacing,
          gap: other.gap ?? gap,
          headerGap: other.headerGap ?? headerGap,
          actionSpacing: other.actionSpacing ?? actionSpacing,
          mediaExtent: other.mediaExtent ?? mediaExtent,
          tile: other.tile ?? tile,
          tileExtent: other.tileExtent ?? tileExtent,
          tilePadding: other.tilePadding ?? tilePadding,
          dismissInset: other.dismissInset ?? dismissInset,
          titleStyle: titleStyle?.merge(other.titleStyle) ?? other.titleStyle,
          descriptionStyle:
              descriptionStyle?.merge(other.descriptionStyle) ??
              other.descriptionStyle,
          contentStyle:
              contentStyle?.merge(other.contentStyle) ?? other.contentStyle,
        );

  @override
  List<Object?> get props => [
    surface,
    border,
    shadows,
    radius,
    padding,
    overlay,
    highlight,
    divider,
    spacing,
    gap,
    headerGap,
    actionSpacing,
    mediaExtent,
    tile,
    tileExtent,
    tilePadding,
    dismissInset,
    titleStyle,
    descriptionStyle,
    contentStyle,
  ];
}
