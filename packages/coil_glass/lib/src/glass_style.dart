import 'package:coil/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

/// Which glass a [CoilGlassStyle] renders, after Apple's materials.
enum CoilGlassVariant {
  /// Frosted enough for text on any backdrop: bars, toolbars, menus,
  /// sheets. The default.
  regular,

  /// Barely frosted, for glass over media where the content should show
  /// through (a player's controls over video). Needs a dimmed backdrop for
  /// legible text.
  clear,

  /// Regular glass washed with the brand color: one primary floating
  /// action per screen, at most.
  tinted,
}

/// How glass looks, as a coil component style: set it app-wide with
/// `CoilThemeData.withComponentStyle(CoilGlassStyle(...))`, or per shape.
///
/// Every field is nullable; [CoilGlassStyle.fallback] derives the rest from
/// coil's tokens, so a light/dark or brand change flows into the glass.
@immutable
class CoilGlassStyle extends CoilComponentStyle<CoilGlassStyle> {
  /// Creates a glass style.
  const CoilGlassStyle({
    this.variant,
    this.tintAmount,
    this.tint,
    this.shadows,
    this.blend,
    this.solidFill,
    this.label,
  });

  /// The defaults from the theme's tokens.
  factory CoilGlassStyle.fallback(CoilThemeData theme) {
    final c = theme.colors;
    final dark = c.brightness == Brightness.dark;
    return CoilGlassStyle(
      variant: CoilGlassVariant.regular,
      // Apple's "Liquid Glass" slider, between Clear (0) and Tinted (1).
      // coil sits at the middle tick: calmer and more legible than iOS's
      // default, still clearly glass.
      tintAmount: 0.5,
      tint: c.brand,
      shadows: [
        BoxShadow(
          // Soft and close: glass floats just above the content, it
          // doesn't hover over it.
          color: dark ? const Color(0x3D000000) : const Color(0x14000000),
          offset: const Offset(0, 2),
          blurRadius: 16,
        ),
      ],
      blend: 16,
      // Reduce Transparency: the floating surface coil already has.
      solidFill: c.surface(3),
      label: c.foreground,
    );
  }

  /// Denser glass for surfaces that hold rows of text over anything:
  /// menus, popovers, sheets. At bar density a menu over a vivid photo
  /// loses the contrast its labels need (destructive red over pink most of
  /// all); Apple's menus are denser than its bars for the same reason.
  /// Give such a surface its own [CoilGlassStyle]d layer:
  /// `CoilGlassLayer(style: CoilGlassStyle.dense, child: menu)`.
  static const dense = CoilGlassStyle(tintAmount: 0.95);

  /// Which material.
  final CoilGlassVariant? variant;

  /// Apple's Liquid Glass slider: 0 is clear, 1 fully tinted (denser wash,
  /// stronger border, more frost).
  final double? tintAmount;

  /// The color [CoilGlassVariant.tinted] glass is washed with.
  final Color? tint;

  /// Exterior shadows. The renderer cuts them out behind the glass.
  final List<BoxShadow>? shadows;

  /// How close, in logical pixels, grouped shapes come before they melt
  /// into one.
  final double? blend;

  /// The fill when glass is turned off (Reduce Transparency, high
  /// contrast).
  final Color? solidFill;

  /// Text and icons on glass.
  final Color? label;

  /// The layer's optics and lighting for [brightness].
  LiquidGlassSettings settingsFor(Brightness brightness) =>
      switch (variant ?? CoilGlassVariant.regular) {
        CoilGlassVariant.clear => LiquidGlassSettings.ios27Clear(
          tintAmount: tintAmount ?? 0,
        ),
        _ => LiquidGlassSettings.ios27Regular(
          brightness: brightness,
          tintAmount: tintAmount ?? 0,
        ),
      };

  /// The color of one shape for [brightness].
  LiquidGlassAppearance appearanceFor(Brightness brightness) =>
      switch (variant ?? CoilGlassVariant.regular) {
        CoilGlassVariant.clear => const LiquidGlassAppearance.ios27Clear(),
        CoilGlassVariant.regular => LiquidGlassAppearance.ios27Regular(
          brightness: brightness,
        ),
        CoilGlassVariant.tinted => LiquidGlassAppearance.ios27Regular(
          brightness: brightness,
          tint: (tint ?? const Color(0xFF007AFF)).withValues(alpha: 0.8),
        ),
      };

  @override
  CoilGlassStyle merge(CoilGlassStyle? other) => other == null
      ? this
      : CoilGlassStyle(
          variant: other.variant ?? variant,
          tintAmount: other.tintAmount ?? tintAmount,
          tint: other.tint ?? tint,
          shadows: other.shadows ?? shadows,
          blend: other.blend ?? blend,
          solidFill: other.solidFill ?? solidFill,
          label: other.label ?? label,
        );

  @override
  List<Object?> get props => [
    variant,
    tintAmount,
    tint,
    shadows,
    blend,
    solidFill,
    label,
  ];
}
