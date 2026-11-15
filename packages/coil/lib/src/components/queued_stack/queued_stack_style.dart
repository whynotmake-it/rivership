import 'package:coil/foundation.dart';
import 'package:flutter/widgets.dart';

/// Overrides for how a `CoilQueuedStack` looks. Unset fields come from
/// [CoilQueuedStackStyle.fallback], derived from the theme's tokens.
class CoilQueuedStackStyle extends CoilComponentStyle<CoilQueuedStackStyle> {
  /// Creates a style.
  const CoilQueuedStackStyle({
    this.cardColor,
    this.textStyle,
    this.countStyle,
    this.iconColor,
    this.radius,
    this.cardMinHeight,
    this.shadowLevel,
    this.gutterWidth,
  });

  /// The defaults from the theme's tokens.
  factory CoilQueuedStackStyle.fallback(
    CoilThemeData theme,
    CoilMetrics metrics,
  ) {
    final c = theme.colors;
    return CoilQueuedStackStyle(
      cardColor: CoilColorMix.oklab(c.accent, c.background, 0.32),
      textStyle: theme.typography.style(
        _subtitle(metrics),
        color: c.mutedForeground,
      ),
      countStyle: theme.typography
          .style(metrics.caption, color: c.mutedForeground)
          .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      iconColor: c.mutedForeground,
      radius: theme.shape.radii(metrics.tier).container,
      cardMinHeight: metrics.controlHeight + 8,
      shadowLevel: 3,
      gutterWidth: metrics.controlHeight + 4,
    );
  }

  /// The subtitle role (DESIGN.md §3.1), which `CoilMetrics` doesn't carry.
  static CoilTypeStep _subtitle(CoilMetrics metrics) =>
      switch ((metrics.tier, metrics.size)) {
        (CoilTier.pointer, CoilSize.regular) => const CoilTypeStep(14, 20),
        (CoilTier.pointer, CoilSize.compact) => const CoilTypeStep(13, 18),
        (CoilTier.touch, CoilSize.regular) => const CoilTypeStep(16, 22),
        (CoilTier.touch, CoilSize.compact) => const CoilTypeStep(15, 20),
      };

  /// A card's fill: `accent` mixed into the background.
  final Color? cardColor;

  /// A card's text.
  final TextStyle? textStyle;

  /// The queued count beside the gutter icon.
  final TextStyle? countStyle;

  /// The gutter icon and the card actions at rest.
  final Color? iconColor;

  /// A card's corner radius.
  final double? radius;

  /// A card's minimum height. Cards grow with the text scale.
  final double? cardMinHeight;

  /// A card's shadow step.
  final int? shadowLevel;

  /// The width of the gutter on each side of the cards. The start gutter
  /// holds the queue icon and count.
  final double? gutterWidth;

  @override
  CoilQueuedStackStyle merge(CoilQueuedStackStyle? other) => other == null
      ? this
      : CoilQueuedStackStyle(
          cardColor: other.cardColor ?? cardColor,
          textStyle: textStyle?.merge(other.textStyle) ?? other.textStyle,
          countStyle: countStyle?.merge(other.countStyle) ?? other.countStyle,
          iconColor: other.iconColor ?? iconColor,
          radius: other.radius ?? radius,
          cardMinHeight: other.cardMinHeight ?? cardMinHeight,
          shadowLevel: other.shadowLevel ?? shadowLevel,
          gutterWidth: other.gutterWidth ?? gutterWidth,
        );

  @override
  List<Object?> get props => [
    cardColor,
    textStyle,
    countStyle,
    iconColor,
    radius,
    cardMinHeight,
    shadowLevel,
    gutterWidth,
  ];
}
