import 'package:coil/foundation.dart';
import 'package:flutter/widgets.dart';

/// Overrides for how a `CoilChatMessage` looks. Unset fields come from
/// [CoilChatMessageStyle.fallback], derived from the theme's tokens. Set a
/// style app-wide or for a subtree with `CoilThemeData.withComponentStyle`,
/// or per instance with `style:`.
class CoilChatMessageStyle extends CoilComponentStyle<CoilChatMessageStyle> {
  /// Creates a style.
  const CoilChatMessageStyle({
    this.bubble,
    this.textStyle,
    this.metaStyle,
    this.padding,
    this.radius,
    this.maxWidthFactor,
  });

  /// The defaults from the theme's tokens.
  factory CoilChatMessageStyle.fallback(
    CoilThemeData theme,
    CoilMetrics metrics,
  ) {
    final c = theme.colors;
    final compact = metrics.size == CoilSize.compact;
    final touch = metrics.tier == CoilTier.touch;
    return CoilChatMessageStyle(
      bubble: CoilColorMix.oklab(c.accent, c.background, 0.45),
      textStyle: theme.typography.style(
        _subtitle(metrics),
        color: c.foreground,
      ),
      metaStyle: theme.typography
          .style(metrics.caption, color: c.mutedForeground)
          .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6)
          : touch
          ? const EdgeInsets.symmetric(horizontal: 16, vertical: 10)
          : const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      radius: theme.shape.radii(metrics.tier).container,
      maxWidthFactor: 0.8,
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

  /// The user bubble's fill. Assistant messages have no bubble.
  final Color? bubble;

  /// The message text.
  final TextStyle? textStyle;

  /// The time in the meta row.
  final TextStyle? metaStyle;

  /// Space around the text. Assistant messages keep only the vertical part.
  final EdgeInsets? padding;

  /// The user bubble's corner radius.
  final double? radius;

  /// How much of the available width a user message may take, from 0 to 1.
  final double? maxWidthFactor;

  @override
  CoilChatMessageStyle merge(CoilChatMessageStyle? other) => other == null
      ? this
      : CoilChatMessageStyle(
          bubble: other.bubble ?? bubble,
          textStyle: textStyle?.merge(other.textStyle) ?? other.textStyle,
          metaStyle: metaStyle?.merge(other.metaStyle) ?? other.metaStyle,
          padding: other.padding ?? padding,
          radius: other.radius ?? radius,
          maxWidthFactor: other.maxWidthFactor ?? maxWidthFactor,
        );

  @override
  List<Object?> get props => [
    bubble,
    textStyle,
    metaStyle,
    padding,
    radius,
    maxWidthFactor,
  ];
}
