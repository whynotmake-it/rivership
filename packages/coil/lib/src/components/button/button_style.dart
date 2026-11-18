import 'package:coil/foundation.dart';
import 'package:coil/src/components/button/button.dart' show CoilButtonTrack;
import 'package:coil/src/components/button/button_variant.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

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
    this.motions,
    this.plasticity,
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
    final held = WidgetState.selected | WidgetState.pressed;
    final (fill, foreground) = switch (variant) {
      CoilButtonVariant.primary => (
        WidgetStateProperty<Color?>.fromMap({
          held: CoilColorMix.oklab(c.foreground, c.background, 0.8),
          WidgetState.hovered: CoilColorMix.oklab(
            c.foreground,
            c.background,
            0.9,
          ),
          WidgetState.any: c.foreground,
        }),
        WidgetStatePropertyAll<Color?>(c.background),
      ),
      CoilButtonVariant.secondary => (
        WidgetStateProperty<Color?>.fromMap({
          held: c.tint,
          WidgetState.hovered: c.tintHover,
          WidgetState.any: c.tint,
        }),
        WidgetStatePropertyAll<Color?>(c.foreground),
      ),
      CoilButtonVariant.tertiary => (
        WidgetStateProperty<Color?>.fromMap({
          held: c.active,
          WidgetState.hovered: c.hover,
          WidgetState.any: clear,
        }),
        WidgetStatePropertyAll<Color?>(c.foreground),
      ),
      CoilButtonVariant.ghost => (
        WidgetStateProperty<Color?>.fromMap({
          held: c.active,
          WidgetState.hovered: c.hover,
          WidgetState.any: clear,
        }),
        WidgetStateProperty<Color?>.fromMap({
          held | WidgetState.hovered: c.foreground,
          WidgetState.any: c.mutedForeground,
        }),
      ),
      CoilButtonVariant.destructive => (
        WidgetStateProperty<Color?>.fromMap({
          WidgetState.selected: c.red.withValues(alpha: dark ? 0.30 : 0.25),
          WidgetState.pressed: c.red.withValues(alpha: dark ? 0.20 : 0.15),
          WidgetState.hovered: c.red.withValues(alpha: dark ? 0.30 : 0.25),
          WidgetState.any: c.red.withValues(alpha: dark ? 0.20 : 0.15),
        }),
        WidgetStatePropertyAll<Color?>(c.redLabel),
      ),
    };
    return CoilButtonStyle(
      plasticity: theme.plasticity,
      fill: fill,
      foreground: foreground,
      border: variant == CoilButtonVariant.tertiary
          ? c.border
          : const Color(0x00000000),
      radius: theme.shape.radii(metrics.tier).item,
      textStyle: theme.typography.resolve(metrics.tier, metrics.size).body,
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

  /// Springs for the button's animated parts, keyed by [CoilButtonTrack]s:
  /// `{CoilButtonTrack.collapse: const Motion.bouncySpring()}`. A button's
  /// own `motions:` win over these; these win over the motion tokens.
  /// [merge] combines the maps key by key.
  final Map<CoilButtonTrack<Object>, Motion>? motions;

  /// How lit this component is. Defaults to the theme's
  /// `CoilThemeData.plasticity`; set it here to light (or flatten) one
  /// component type or instance.
  final CoilPlasticity? plasticity;

  @override
  CoilButtonStyle merge(CoilButtonStyle? other) => other == null
      ? this
      : CoilButtonStyle(
          plasticity: other.plasticity ?? plasticity,
          fill: CoilComponentStyle.mergeStates(fill, other.fill),
          foreground: CoilComponentStyle.mergeStates(
            foreground,
            other.foreground,
          ),
          border: other.border ?? border,
          radius: other.radius ?? radius,
          textStyle: textStyle?.merge(other.textStyle) ?? other.textStyle,
          iconSize: other.iconSize ?? iconSize,
          minHeight: other.minHeight ?? minHeight,
          motions: other.motions == null
              ? motions
              : {...?motions, ...?other.motions},
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
    motions,
    plasticity,
  ];
}
