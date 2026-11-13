import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart' show IconTheme, IconThemeData;

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
/// Apps that swap the font set [fontFamily] (and [fontPackage]). Labels are
/// plain text with even leading: for Inter that centers the cap height in
/// the line box exactly, as CSS `text-box: trim-both cap alphabetic` does.
@immutable
class FluidTypographyThemeData {
  /// Creates typography theme data. Defaults to the bundled Inter.
  const FluidTypographyThemeData({
    this.fontFamily = 'Inter',
    this.fontPackage = 'fluid_functionalism',
  });

  /// The font family.
  final String fontFamily;

  /// The package bundling [fontFamily], or null for an app font.
  final String? fontPackage;

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
  }) => FluidTypographyThemeData(
    fontFamily: fontFamily ?? this.fontFamily,
    fontPackage: fontPackage ?? this.fontPackage,
  );

  @override
  bool operator ==(Object other) =>
      other is FluidTypographyThemeData &&
      other.fontFamily == fontFamily &&
      other.fontPackage == fontPackage;

  @override
  int get hashCode => Object.hash(fontFamily, fontPackage);
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

/// The [IconThemeData.weight]s controls give their icon slots.
///
/// The web draws stroke icons at 1.5 and thickens them to 2 on hover. In
/// Flutter, slot icons are any widget styled by [IconTheme]: variable icon
/// fonts (Material Symbols, ...) read `weight` directly, and stroke icons
/// can scale their stroke with it (`1.5 * weight / 400` reproduces the web).
abstract final class FluidIconWeight {
  /// At rest: a 1.5 stroke.
  static const double rest = 400;

  /// Hovered or active: a 2 stroke (400 × 2 / 1.5).
  static const double emphasis = 1600 / 3;
}
