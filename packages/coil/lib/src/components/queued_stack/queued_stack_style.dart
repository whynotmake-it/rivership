import 'package:coil/foundation.dart';
import 'package:coil/src/components/queued_stack/queued_stack.dart'
    show CoilQueuedStackTrack;
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

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
    this.motions,
  });

  /// The defaults from the theme's tokens.
  factory CoilQueuedStackStyle.fallback(
    CoilThemeData theme,
    CoilMetrics metrics,
  ) {
    final c = theme.colors;
    final text = theme.typography.resolve(metrics.tier, metrics.size);
    return CoilQueuedStackStyle(
      cardColor: CoilColorMix.oklab(c.accent, c.background, 0.32),
      textStyle: text.subtitle.copyWith(color: c.mutedForeground),
      countStyle: text.caption.copyWith(color: c.mutedForeground).tabular,
      iconColor: c.mutedForeground,
      radius: theme.shape.radii(metrics.tier).container,
      cardMinHeight: metrics.controlHeight + 8,
      shadowLevel: 3,
      gutterWidth: metrics.controlHeight + 4,
    );
  }

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

  /// Springs for the stack's animated parts, keyed by
  /// [CoilQueuedStackTrack]s: `{CoilQueuedStackTrack.expand: const
  /// Motion.bouncySpring()}`. A stack's own `motions:` win over these; these
  /// win over the motion tokens. [merge] combines the maps key by key.
  final Map<CoilQueuedStackTrack<Object>, Motion>? motions;

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
          motions: other.motions == null
              ? motions
              : {...?motions, ...?other.motions},
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
    motions,
  ];
}
