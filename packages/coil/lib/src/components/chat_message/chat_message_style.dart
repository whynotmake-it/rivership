import 'package:coil/foundation.dart';
import 'package:coil/src/components/chat_message/chat_message.dart'
    show CoilChatMessageTrack;
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

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
    this.gap,
    this.metaPaddingX,
    this.metaGap,
    this.actionGap,
    this.menuMinWidth,
    this.motions,
  });

  /// The defaults from the theme's tokens.
  factory CoilChatMessageStyle.fallback(
    CoilThemeData theme,
    CoilMetrics metrics,
  ) {
    final c = theme.colors;
    final compact = metrics.size == CoilSize.compact;
    final touch = metrics.tier == CoilTier.touch;
    final text = theme.typography.resolve(metrics.tier, metrics.size);
    return CoilChatMessageStyle(
      bubble: CoilColorMix.oklab(c.accent, c.background, 0.45),
      textStyle: text.subtitle.copyWith(color: c.foreground),
      metaStyle: text.caption.tabular.copyWith(color: c.mutedForeground),
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6)
          : touch
          ? const EdgeInsets.symmetric(horizontal: 16, vertical: 10)
          : const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      radius: theme.shape.radii(metrics.tier).container,
      maxWidthFactor: 0.8,
      gap: 6,
      metaPaddingX: 4,
      metaGap: 8,
      actionGap: 2,
      menuMinWidth: 220,
    );
  }

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

  /// The space between the attachments, the body and the meta row, and
  /// between attachments.
  final double? gap;

  /// The meta row's horizontal inset.
  final double? metaPaddingX;

  /// The space between the time and the actions.
  final double? metaGap;

  /// The space between action buttons.
  final double? actionGap;

  /// The narrowest the long-press menu gets as a popover.
  final double? menuMinWidth;

  /// Springs for the message's animated parts, keyed by
  /// [CoilChatMessageTrack]s: `{CoilChatMessageTrack.height: const
  /// Motion.bouncySpring()}`. A message's own `motions:` win over these;
  /// these win over the motion tokens. [merge] combines the maps key by key.
  final Map<CoilChatMessageTrack<Object>, Motion>? motions;

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
          gap: other.gap ?? gap,
          metaPaddingX: other.metaPaddingX ?? metaPaddingX,
          metaGap: other.metaGap ?? metaGap,
          actionGap: other.actionGap ?? actionGap,
          menuMinWidth: other.menuMinWidth ?? menuMinWidth,
          motions: other.motions == null
              ? motions
              : {...?motions, ...?other.motions},
        );

  @override
  List<Object?> get props => [
    bubble,
    textStyle,
    metaStyle,
    padding,
    radius,
    maxWidthFactor,
    gap,
    metaPaddingX,
    metaGap,
    actionGap,
    menuMinWidth,
    motions,
  ];
}
