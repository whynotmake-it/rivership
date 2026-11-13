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

/// Builds Inter text styles for the system.
abstract final class FluidTypography {
  /// The bundled font family.
  static const fontFamily = 'Inter';

  /// The package that bundles [fontFamily].
  static const fontPackage = 'fluid_functionalism';

  /// A text style for [step] at [weight] in [color].
  ///
  /// The line height is distributed evenly above and below, which is the
  /// closest Flutter gets to the web's `text-box: trim-both cap alphabetic`
  /// optical centering.
  static TextStyle style(
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
}
