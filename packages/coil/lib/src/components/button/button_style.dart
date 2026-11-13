import 'package:coil/foundation.dart';
import 'package:coil/src/components/button/button_variant.dart';
import 'package:flutter/widgets.dart';

/// Overrides for how a `CoilButton` looks. Every field is optional; unset
/// fields come from [CoilButtonStyle.fallback], derived from the theme's
/// tokens. Set one app-wide or for a subtree with
/// `CoilThemeData.withComponentStyle`, or per button with `style:`.
///
/// Colors are [WidgetStateProperty]s resolved with the button's states:
/// [WidgetState.hovered] (hover-capable pointers only), [WidgetState.pressed],
/// [WidgetState.selected] (held open) and [WidgetState.disabled].
class CoilButtonStyle extends CoilComponentStyle<CoilButtonStyle> {
  /// Creates a button style.
  const CoilButtonStyle({
    this.fill,
    this.foreground,
    this.border,
    this.radius,
    this.textStyle,
    this.iconSize,
    this.minHeight,
  });

  /// The defaults for [variant] from [theme]'s tokens at [metrics].
  factory CoilButtonStyle.fallback(
    CoilThemeData theme,
    CoilMetrics metrics,
    CoilButtonVariant variant,
  ) {
    final c = theme.colors;
    final dark = c.brightness == Brightness.dark;
    final clear = c.hover.withValues(alpha: 0);
    bool held(Set<WidgetState> s) =>
        s.contains(WidgetState.selected) || s.contains(WidgetState.pressed);
    bool hovered(Set<WidgetState> s) => s.contains(WidgetState.hovered);
    final (fill, foreground) = switch (variant) {
      CoilButtonVariant.primary => (
        WidgetStateProperty.resolveWith<Color?>(
          (s) => held(s)
              ? CoilColorMix.oklab(c.foreground, c.background, 0.8)
              : hovered(s)
              ? CoilColorMix.oklab(c.foreground, c.background, 0.9)
              : c.foreground,
        ),
        WidgetStatePropertyAll<Color?>(c.background),
      ),
      CoilButtonVariant.secondary => (
        WidgetStateProperty.resolveWith<Color?>(
          (s) => !held(s) && hovered(s) ? c.tintHover : c.tint,
        ),
        WidgetStatePropertyAll<Color?>(c.foreground),
      ),
      CoilButtonVariant.tertiary => (
        WidgetStateProperty.resolveWith<Color?>(
          (s) => held(s)
              ? c.active
              : hovered(s)
              ? c.hover
              : clear,
        ),
        WidgetStatePropertyAll<Color?>(c.foreground),
      ),
      CoilButtonVariant.ghost => (
        WidgetStateProperty.resolveWith<Color?>(
          (s) => held(s)
              ? c.active
              : hovered(s)
              ? c.hover
              : clear,
        ),
        WidgetStateProperty.resolveWith<Color?>(
          (s) => held(s) || hovered(s) ? c.foreground : c.mutedForeground,
        ),
      ),
      CoilButtonVariant.destructive => (
        WidgetStateProperty.resolveWith<Color?>(
          (s) => c.red.withValues(
            alpha:
                s.contains(WidgetState.selected) ||
                    (!s.contains(WidgetState.pressed) && hovered(s))
                ? (dark ? 0.30 : 0.25)
                : (dark ? 0.20 : 0.15),
          ),
        ),
        WidgetStatePropertyAll<Color?>(c.redLabel),
      ),
    };
    return CoilButtonStyle(
      fill: fill,
      foreground: foreground,
      border: variant == CoilButtonVariant.tertiary
          ? c.border
          : const Color(0x00000000),
      radius: theme.shape.radii(metrics.tier).item,
      textStyle: theme.typography.style(metrics.body),
      iconSize: metrics.iconSize,
      minHeight: metrics.controlHeight,
    );
  }

  /// The surface color.
  final WidgetStateProperty<Color?>? fill;

  /// The label and icon color.
  final WidgetStateProperty<Color?>? foreground;

  /// The 1 px hairline; fully transparent draws none.
  final Color? border;

  /// The corner radius of the superellipse.
  final double? radius;

  /// The label style (its color comes from [foreground]).
  final TextStyle? textStyle;

  /// The icon slot size, before text scaling.
  final double? iconSize;

  /// The minimum height (the button grows with text).
  final double? minHeight;

  @override
  CoilButtonStyle merge(CoilButtonStyle? other) => other == null
      ? this
      : CoilButtonStyle(
          fill: other.fill ?? fill,
          foreground: other.foreground ?? foreground,
          border: other.border ?? border,
          radius: other.radius ?? radius,
          textStyle: textStyle?.merge(other.textStyle) ?? other.textStyle,
          iconSize: other.iconSize ?? iconSize,
          minHeight: other.minHeight ?? minHeight,
        );

  @override
  List<Object?> get props => [
    fill,
    foreground,
    border,
    radius,
    textStyle,
    iconSize,
    minHeight,
  ];
}
