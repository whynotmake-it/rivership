/// @docImport 'package:coil/badge.dart';
library;

import 'package:coil/foundation.dart';
import 'package:coil/src/components/badge/badge.dart' show CoilBadgeTrack;
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// Visual presentation style of a [CoilBadge].
enum CoilBadgeVariant {
  /// The hue blended at 15% into the background, with foreground text.
  solid,

  /// A hairline outline, foreground text, and a colored dot.
  dot,

  /// A dot and a label with no outline and no padding; the label inherits
  /// the surrounding text color.
  ghost,
}

/// Corner radius style of a [CoilBadge].
enum CoilBadgeShape {
  /// Uses the theme's item radius, like a button ([CoilShape.pill] makes
  /// that a pill too).
  item,

  /// Fully rounded: half the badge's height, regardless of the theme's shape.
  pill,
}

/// The hue of a [CoilBadge]: gray, the theme's brand, or one of sixteen
/// fixed hues.
enum CoilBadgeColor {
  /// The neutral default ([CoilColors.accent] fill and muted dot).
  gray(null),

  /// The theme's brand hue.
  ///
  /// A [CoilBadgeVariant.solid] badge is filled with [CoilColors.brandFill]
  /// under [CoilColors.onBrandFill]; [CoilBadgeVariant.dot] and
  /// [CoilBadgeVariant.ghost] show [CoilColors.brand] in the dot.
  brand(null),

  /// Red.
  red(Color(0xFFEF4444)),

  /// Orange.
  orange(Color(0xFFF97316)),

  /// Amber.
  amber(Color(0xFFF59E0B)),

  /// Yellow.
  yellow(Color(0xFFEAB308)),

  /// Lime.
  lime(Color(0xFF84CC16)),

  /// Green.
  green(Color(0xFF22C55E)),

  /// Emerald.
  emerald(Color(0xFF10B981)),

  /// Teal.
  teal(Color(0xFF14B8A6)),

  /// Cyan.
  cyan(Color(0xFF06B6D4)),

  /// Blue.
  blue(Color(0xFF3B82F6)),

  /// Indigo.
  indigo(Color(0xFF6366F1)),

  /// Violet.
  violet(Color(0xFF8B5CF6)),

  /// Purple.
  purple(Color(0xFFA855F7)),

  /// Fuchsia.
  fuchsia(Color(0xFFD946EF)),

  /// Pink.
  pink(Color(0xFFEC4899)),

  /// Rose.
  rose(Color(0xFFF43F5E));

  const CoilBadgeColor(this._hue);

  final Color? _hue;
}

/// Style overrides for a [CoilBadge].
///
/// Unset fields fall back to [CoilBadgeStyle.fallback]. A badge isn't
/// interactive, so its style has no states.
class CoilBadgeStyle extends CoilComponentStyle<CoilBadgeStyle> {
  /// Creates a badge style.
  const CoilBadgeStyle({
    this.fill,
    this.border,
    this.dotColor,
    this.textStyle,
    this.radius,
    this.minHeight,
    this.paddingX,
    this.gap,
    this.dotSize,
    this.motions,
  });

  /// The defaults for [variant] and [color] from [theme]'s tokens.
  ///
  /// A badge never grows a touch bump, so [metrics] only picks the
  /// regular or compact step ([CoilTextTheme.caption] and micro type).
  factory CoilBadgeStyle.fallback(
    CoilThemeData theme,
    CoilMetrics metrics,
    CoilBadgeVariant variant,
    CoilBadgeColor color,
  ) {
    final c = theme.colors;
    final compact = metrics.size == CoilSize.compact;
    final hue = switch (color) {
      CoilBadgeColor.gray => null,
      CoilBadgeColor.brand => c.brand,
      _ => color._hue,
    };
    // A badge never grows a touch bump: its type is the pointer tier's.
    final caption = theme.typography
        .resolve(CoilTier.pointer, metrics.size)
        .caption;
    // The solid brand badge is the brand itself, as a fill that carries
    // text: a 15 % wash would read olive for a yellow brand in dark.
    final brandSolid =
        color == CoilBadgeColor.brand && variant == CoilBadgeVariant.solid;
    return CoilBadgeStyle(
      fill: switch (variant) {
        _ when brandSolid => c.brandFill,
        CoilBadgeVariant.solid =>
          hue == null ? c.accent : Color.lerp(c.background, hue, 0.15),
        _ => const Color(0x00000000),
      },
      border: variant == CoilBadgeVariant.dot ? c.border : null,
      dotColor: hue ?? c.mutedForeground,
      textStyle: variant == CoilBadgeVariant.ghost
          ? caption
          : caption.copyWith(color: brandSolid ? c.onBrandFill : c.foreground),
      radius: theme.shape.radii(CoilTier.pointer).item,
      minHeight: compact ? 20 : 24,
      paddingX: variant == CoilBadgeVariant.ghost ? 0 : (compact ? 8 : 10),
      gap: compact ? 4 : 6,
      dotSize: compact ? 6 : 7,
    );
  }

  /// The fill; transparent for [CoilBadgeVariant.dot] and
  /// [CoilBadgeVariant.ghost].
  final Color? fill;

  /// The 1 px outline; null draws none.
  final Color? border;

  /// The dot color.
  final Color? dotColor;

  /// The label style.
  ///
  /// [CoilBadgeVariant.ghost] leaves its color unset so it inherits.
  final TextStyle? textStyle;

  /// The corner radius of the superellipse for [CoilBadgeShape.item].
  ///
  /// A [CoilBadgeShape.pill] badge is always fully rounded.
  final double? radius;

  /// The minimum height, kept by every variant (ghost included); the
  /// badge grows with the text scale.
  final double? minHeight;

  /// The horizontal padding.
  final double? paddingX;

  /// The gap between the dot and the label.
  final double? gap;

  /// The dot's diameter, before text scaling.
  final double? dotSize;

  /// Springs for the badge's animated parts, keyed by [CoilBadgeTrack] values.
  ///
  /// For example, `{CoilBadgeTrack.size: const Motion.bouncySpring()}`.
  /// [CoilBadge.motions] takes precedence over these, and these take
  /// precedence over the theme motion tokens. [merge] combines the maps key
  /// by key.
  final Map<CoilBadgeTrack<Object>, Motion>? motions;

  @override
  CoilBadgeStyle merge(CoilBadgeStyle? other) => other == null
      ? this
      : CoilBadgeStyle(
          fill: other.fill ?? fill,
          border: other.border ?? border,
          dotColor: other.dotColor ?? dotColor,
          textStyle: textStyle?.merge(other.textStyle) ?? other.textStyle,
          radius: other.radius ?? radius,
          minHeight: other.minHeight ?? minHeight,
          paddingX: other.paddingX ?? paddingX,
          gap: other.gap ?? gap,
          dotSize: other.dotSize ?? dotSize,
          motions: other.motions == null
              ? motions
              : {...?motions, ...?other.motions},
        );

  @override
  List<Object?> get props => [
    fill,
    border,
    dotColor,
    textStyle,
    radius,
    minHeight,
    paddingX,
    gap,
    dotSize,
    motions,
  ];
}
