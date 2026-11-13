import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// The three Inter weights the system uses.
///
/// From `lib/font-weight.ts`: each weight is paired with an optical size so
/// animating between weights keeps the advance width nearly constant (a
/// heavier `wght` widens text, a higher `opsz` pulls it back).
enum FluidWeight {
  /// Body text: `'wght' 400, 'opsz' 14`.
  normal(400, 14, FontWeight.w400),

  /// Headings and selected items: `'wght' 550, 'opsz' 18`.
  semibold(550, 18, FontWeight.w500),

  /// The display style only: `'wght' 700, 'opsz' 25`.
  bold(700, 25, FontWeight.w700);

  const FluidWeight(this.wght, this.opsz, this.fallbackWeight);

  /// The `wght` axis value.
  final double wght;

  /// The `opsz` axis value.
  final double opsz;

  /// The closest static [FontWeight], for fonts without variation axes.
  final FontWeight fallbackWeight;

  /// The font variations for this weight.
  List<FontVariation> get variations => [
    FontVariation('wght', wght),
    FontVariation('opsz', opsz),
  ];
}

/// One step of the type scale: a font size and a line height in pixels.
@immutable
class FluidTypeStep {
  /// Creates a type step.
  const FluidTypeStep(this.fontSize, this.lineHeight);

  /// Font size in logical pixels.
  final double fontSize;

  /// Line height in logical pixels.
  final double lineHeight;

  @override
  bool operator ==(Object other) =>
      other is FluidTypeStep &&
      other.fontSize == fontSize &&
      other.lineHeight == lineHeight;

  @override
  int get hashCode => Object.hash(fontSize, lineHeight);
}

/// The type family and its metrics, as theme data
/// (`FluidThemeData.typography`).
///
/// Apps that swap the font set [fontFamily] (and [fontPackage]) and the
/// font's [capHeight], which `FluidLabel` uses to center labels on their
/// cap height like CSS `text-box: trim-both cap alphabetic`.
@immutable
class FluidTypographyThemeData {
  /// Creates typography theme data. Defaults to the bundled Inter.
  const FluidTypographyThemeData({
    this.fontFamily = 'Inter',
    this.fontPackage = 'fluid_functionalism',
    this.capHeight = interCapHeight,
  });

  /// Inter's cap height as a fraction of the em: OS/2 `sCapHeight` 1490 over
  /// `unitsPerEm` 2048, read from the bundled InterVariable.ttf.
  static const interCapHeight = 1490 / 2048;

  /// The font family.
  final String fontFamily;

  /// The package bundling [fontFamily], or null for an app font.
  final String? fontPackage;

  /// The height of a flat capital (H, E) as a fraction of the font size.
  /// Read it from the font: OS/2 `sCapHeight / unitsPerEm`.
  final double capHeight;

  /// A text style for [step] at [weight] in [color].
  TextStyle style(
    FluidTypeStep step, {
    FluidWeight weight = FluidWeight.normal,
    Color? color,
  }) {
    return TextStyle(
      inherit: false,
      fontFamily: fontFamily,
      package: fontPackage,
      fontSize: step.fontSize,
      height: step.lineHeight / step.fontSize,
      leadingDistribution: TextLeadingDistribution.even,
      // The bundled font is variable: weight comes from `fontVariations`.
      // A non-normal fontWeight here would make the engine synthesize bold
      // on top of the variation.
      fontWeight: FontWeight.w400,
      fontVariations: weight.variations,
      color: color,
      letterSpacing: 0,
      decoration: TextDecoration.none,
      textBaseline: TextBaseline.alphabetic,
    );
  }

  /// Returns a copy with the given fields replaced.
  FluidTypographyThemeData copyWith({
    String? fontFamily,
    String? fontPackage,
    double? capHeight,
  }) => FluidTypographyThemeData(
    fontFamily: fontFamily ?? this.fontFamily,
    fontPackage: fontPackage ?? this.fontPackage,
    capHeight: capHeight ?? this.capHeight,
  );

  @override
  bool operator ==(Object other) =>
      other is FluidTypographyThemeData &&
      other.fontFamily == fontFamily &&
      other.fontPackage == fontPackage &&
      other.capHeight == capHeight;

  @override
  int get hashCode => Object.hash(fontFamily, fontPackage, capHeight);
}

/// Text styles with the default typography (bundled Inter). Components use
/// `FluidTheme.of(context).typography` instead, so apps can swap the font.
abstract final class FluidTypography {
  /// A text style for [step] at [weight] in [color], in Inter.
  static TextStyle style(
    FluidTypeStep step, {
    FluidWeight weight = FluidWeight.normal,
    Color? color,
  }) => const FluidTypographyThemeData().style(
    step,
    weight: weight,
    color: color,
  );
}
