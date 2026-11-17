import 'package:coil/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

/// Which glass a [CoilGlassStyle] renders, after Apple's materials.
enum CoilGlassVariant {
  /// Frosted enough for text on any backdrop: buttons, toolbars, menus.
  /// The default.
  regular,

  /// Barely frosted, for glass over media where the content should show
  /// through (a player's controls over video). Needs a dimmed backdrop for
  /// legible text.
  clear,

  /// Regular glass washed with the brand: the one primary floating
  /// action (`CoilButtonVariant.glassProminent`).
  tinted,
}

/// How glass looks, as a coil component style: set it app-wide with
/// `CoilThemeData.withComponentStyle(CoilGlassStyle(...))`, or per layer.
///
/// Every field is nullable; [CoilGlassStyle.fallback] derives the rest from
/// coil's tokens, so a light/dark or brand change flows into the glass.
@immutable
class CoilGlassStyle extends CoilComponentStyle<CoilGlassStyle> {
  /// Creates a glass style.
  const CoilGlassStyle({
    this.variant,
    this.tintAmount,
    this.wash,
    this.refraction,
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
      wash: 0,
      // A narrower bevel that bends no further than its own width: the
      // rim refracts without mirroring (and smearing) the content.
      refraction: 14,
      tint: c.brand,
      shadows: [
        BoxShadow(
          // Soft and close: glass floats just above the content.
          color: dark ? const Color(0x3D000000) : const Color(0x14000000),
          offset: const Offset(0, 2),
          blurRadius: 16,
        ),
      ],
      blend: 12,
      // Reduce Transparency: the floating surface coil already has.
      solidFill: c.surface(3),
      label: c.foreground,
    );
  }

  /// Glass for surfaces that hold rows of text over anything: menus and
  /// popovers. Frost at the top of Apple's slider, plus a wash of coil's
  /// popover surface color, so labels (destructive red included) keep
  /// their contrast over a vivid photo in dark mode too.
  static const dense = CoilGlassStyle(tintAmount: 1, wash: 0.6);

  /// Which material.
  final CoilGlassVariant? variant;

  /// Apple's Liquid Glass slider: 0 is clear, 1 fully tinted (denser,
  /// stronger border, more frost).
  final double? tintAmount;

  /// How much of coil's surface color ([solidFill]) is mixed into the
  /// glass, 0 to 1. Raises legibility at the cost of see-through.
  final double? wash;

  /// The bevel width in logical pixels; the rim bends the backdrop by as
  /// much. 0 turns refraction off.
  final double? refraction;

  /// The color [CoilGlassVariant.tinted] glass is washed with.
  final Color? tint;

  /// Exterior shadows. The renderer cuts them out behind the glass.
  final List<BoxShadow>? shadows;

  /// How close, in logical pixels, grouped shapes come before they melt
  /// into one.
  final double? blend;

  /// The fill when glass is turned off (Reduce Transparency, high
  /// contrast), and the color of the [wash].
  final Color? solidFill;

  /// Text and icons on glass.
  final Color? label;

  /// The layer's optics and lighting for [brightness].
  LiquidGlassSettings settingsFor(Brightness brightness) {
    final base = switch (variant ?? CoilGlassVariant.regular) {
      CoilGlassVariant.clear => LiquidGlassSettings.ios27Clear(
        tintAmount: tintAmount ?? 0,
      ),
      _ => LiquidGlassSettings.ios27Regular(
        brightness: brightness,
        tintAmount: tintAmount ?? 0,
      ),
    };
    final bevel = refraction;
    return bevel == null
        ? base
        : base.copyWith(refractionHeight: bevel, refractionAmount: bevel);
  }

  /// The color of one shape for [brightness].
  LiquidGlassAppearance appearanceFor(Brightness brightness) {
    final amount = wash ?? 0;
    final fill = solidFill;
    return switch (variant ?? CoilGlassVariant.regular) {
      CoilGlassVariant.clear => const LiquidGlassAppearance.ios27Clear(),
      CoilGlassVariant.regular when amount > 0 && fill != null =>
        LiquidGlassAppearance.ios27Regular(
          brightness: brightness,
          tint: fill.withValues(alpha: amount),
        ),
      CoilGlassVariant.regular => LiquidGlassAppearance.ios27Regular(
        brightness: brightness,
      ),
      CoilGlassVariant.tinted => LiquidGlassAppearance.ios27Regular(
        brightness: brightness,
        tint: (tint ?? const Color(0xFF007AFF)).withValues(alpha: 0.85),
      ),
    };
  }

  @override
  CoilGlassStyle merge(CoilGlassStyle? other) => other == null
      ? this
      : CoilGlassStyle(
          variant: other.variant ?? variant,
          tintAmount: other.tintAmount ?? tintAmount,
          wash: other.wash ?? wash,
          refraction: other.refraction ?? refraction,
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
    wash,
    refraction,
    tint,
    shadows,
    blend,
    solidFill,
    label,
  ];
}
