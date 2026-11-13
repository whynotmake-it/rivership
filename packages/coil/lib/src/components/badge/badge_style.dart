import 'package:coil/foundation.dart';
import 'package:flutter/widgets.dart';

/// How a `CoilBadge` is drawn.
enum CoilBadgeVariant {
  /// The hue at 15 % into the background, foreground text.
  solid,

  /// A hairline outline, foreground text and a colored dot.
  dot,

  /// No outline and no padding; inherits the surrounding text color.
  ghost,
}

/// The hue of a `CoilBadge`: gray, the theme's brand, or a Tailwind-500 hue.
enum CoilBadgeColor {
  /// The neutral default (`accent` fill, muted dot).
  gray(null),

  /// The theme's `brand` color.
  brand(null),

  /// Tailwind red-500.
  red(Color(0xFFEF4444)),

  /// Tailwind orange-500.
  orange(Color(0xFFF97316)),

  /// Tailwind amber-500.
  amber(Color(0xFFF59E0B)),

  /// Tailwind yellow-500.
  yellow(Color(0xFFEAB308)),

  /// Tailwind lime-500.
  lime(Color(0xFF84CC16)),

  /// Tailwind green-500.
  green(Color(0xFF22C55E)),

  /// Tailwind emerald-500.
  emerald(Color(0xFF10B981)),

  /// Tailwind teal-500.
  teal(Color(0xFF14B8A6)),

  /// Tailwind cyan-500.
  cyan(Color(0xFF06B6D4)),

  /// Tailwind blue-500.
  blue(Color(0xFF3B82F6)),

  /// Tailwind indigo-500.
  indigo(Color(0xFF6366F1)),

  /// Tailwind violet-500.
  violet(Color(0xFF8B5CF6)),

  /// Tailwind purple-500.
  purple(Color(0xFFA855F7)),

  /// Tailwind fuchsia-500.
  fuchsia(Color(0xFFD946EF)),

  /// Tailwind pink-500.
  pink(Color(0xFFEC4899)),

  /// Tailwind rose-500.
  rose(Color(0xFFF43F5E));

  const CoilBadgeColor(this._hue);

  final Color? _hue;
}

/// Overrides for how a `CoilBadge` looks. Unset fields come from
/// [CoilBadgeStyle.fallback].
///
/// A badge isn't interactive, so its style has no states.
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
  });

  /// The defaults for [variant] and [color] from [theme]'s tokens.
  ///
  /// A badge never grows a touch bump, so [metrics] only picks the
  /// regular or compact step (`caption` and `micro` type).
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
    final step = compact
        ? const CoilTypeStep(11, 14)
        : const CoilTypeStep(12, 16);
    return CoilBadgeStyle(
      fill: switch (variant) {
        CoilBadgeVariant.solid =>
          hue == null ? c.accent : Color.lerp(c.background, hue, 0.15),
        _ => const Color(0x00000000),
      },
      border: variant == CoilBadgeVariant.dot ? c.border : null,
      dotColor: hue ?? c.mutedForeground,
      textStyle: theme.typography.style(
        step,
        color: variant == CoilBadgeVariant.ghost ? null : c.foreground,
      ),
      radius: theme.shape.radii(CoilTier.pointer).item,
      minHeight: compact ? 20 : 24,
      paddingX: variant == CoilBadgeVariant.ghost ? 0 : (compact ? 8 : 10),
      gap: compact ? 4 : 6,
      dotSize: compact ? 6 : 7,
    );
  }

  /// The fill; transparent for `dot` and `ghost`.
  final Color? fill;

  /// The 1 px outline; null draws none.
  final Color? border;

  /// The dot color.
  final Color? dotColor;

  /// The label style. Ghost leaves its color unset so it inherits.
  final TextStyle? textStyle;

  /// The corner radius of the superellipse.
  final double? radius;

  /// The minimum height; the badge grows with the text scale.
  final double? minHeight;

  /// The horizontal padding.
  final double? paddingX;

  /// The gap between the dot and the label.
  final double? gap;

  /// The dot's diameter, before text scaling.
  final double? dotSize;

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
  ];
}
