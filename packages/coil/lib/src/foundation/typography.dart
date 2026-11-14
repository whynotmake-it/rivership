import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart'
    show BuildContext, IconTheme, IconThemeData, MediaQuery;

/// The three Inter weights the system uses.
///
/// Each weight is paired with an optical size, so animating between weights
/// keeps text nearly the same width: a heavier `wght` widens it, a higher
/// `opsz` pulls it back.
enum CoilWeight {
  /// Body text: `'wght' 400, 'opsz' 14`.
  normal(400, 14, FontWeight.w400),

  /// Headings and selected items: `'wght' 550, 'opsz' 18`.
  semibold(550, 18, FontWeight.w500),

  /// The display style only: `'wght' 700, 'opsz' 25`.
  bold(700, 25, FontWeight.w700);

  const CoilWeight(this.wght, this.opsz, this.fallbackWeight);

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

  /// The font variations a fraction [t] of the way from [a] to [b], with
  /// `opsz` following `wght` as the weights pair them. For animating a
  /// weight change.
  static List<FontVariation> lerp(CoilWeight a, CoilWeight b, double t) => [
    FontVariation('wght', a.wght + (b.wght - a.wght) * t),
    FontVariation('opsz', a.opsz + (b.opsz - a.opsz) * t),
  ];
}

/// Marks a copyWith argument that wasn't passed.
const Object _keep = Object();

/// One step of the type scale: a font size and a line height in pixels.
@immutable
class CoilTypeStep {
  /// Creates a type step.
  const CoilTypeStep(this.fontSize, this.lineHeight);

  /// Font size in logical pixels.
  final double fontSize;

  /// Line height in logical pixels.
  final double lineHeight;

  @override
  bool operator ==(Object other) =>
      other is CoilTypeStep &&
      other.fontSize == fontSize &&
      other.lineHeight == lineHeight;

  @override
  int get hashCode => Object.hash(fontSize, lineHeight);
}

/// The type family and its metrics, as theme data
/// (`CoilThemeData.typography`). A theme field, so apps can swap the font
/// at runtime.
///
/// Apps that swap the font set [fontFamily] and [fontPackage]:
/// `CoilTypography(fontFamily: 'Brand')` for an app font, or
/// `CoilTypography(fontFamily: null)` for the platform's UI font. Labels are
/// plain text with even leading: for Inter that centers the cap height in
/// the line box exactly, as CSS `text-box: trim-both cap alphabetic` does.
///
/// Weights are `wght` variations ([CoilWeight]), so a font without a `wght`
/// axis draws every weight at its regular weight.
@immutable
class CoilTypography {
  /// Creates typography theme data. Defaults to the bundled Inter; a
  /// different [fontFamily] needs its own [fontPackage] (null for a font
  /// the app bundles or the platform has).
  const CoilTypography({
    this.fontFamily = 'Inter',
    this.fontPackage = 'coil',
  });

  /// The platform's UI font (San Francisco on Apple platforms, Roboto on
  /// Android).
  static const platform = CoilTypography(fontFamily: null, fontPackage: null);

  /// The font family, or null for the platform's UI font.
  final String? fontFamily;

  /// The package bundling [fontFamily], or null for an app or platform font.
  final String? fontPackage;

  /// A text style for [step] at [weight] in [color].
  TextStyle style(
    CoilTypeStep step, {
    CoilWeight weight = CoilWeight.normal,
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

  /// Returns a copy with the given fields replaced. Both are nullable, so
  /// pass `fontPackage: null` when switching to a font outside a package.
  CoilTypography copyWith({
    Object? fontFamily = _keep,
    Object? fontPackage = _keep,
  }) => CoilTypography(
    fontFamily: identical(fontFamily, _keep)
        ? this.fontFamily
        : fontFamily as String?,
    fontPackage: identical(fontPackage, _keep)
        ? this.fontPackage
        : fontPackage as String?,
  );

  @override
  bool operator ==(Object other) =>
      other is CoilTypography &&
      other.fontFamily == fontFamily &&
      other.fontPackage == fontPackage;

  @override
  int get hashCode => Object.hash(fontFamily, fontPackage);
}

/// The [IconThemeData.weight]s controls give their icon slots.
///
/// Controls raise the weight on hover. Variable icon fonts read `weight`
/// directly; a stroke icon can scale its stroke with it (`1.5 * weight /
/// 400` goes from a 1.5 to a 2 stroke).
abstract final class CoilIconWeight {
  /// At rest: a 1.5 stroke.
  static const double rest = 400;

  /// Hovered or active: a 2 stroke (400 × 2 / 1.5).
  static const double emphasis = 1600 / 3;
}

/// The size a painted glyph should draw at, the way Flutter's `Icon` sizes
/// itself: the ambient [IconTheme]'s size, scaled by the ambient
/// `TextScaler` when [IconThemeData.applyTextScaling] is true (coil's
/// icon themes set it, so slot icons and drawn glyphs grow with text).
abstract final class CoilIconSize {
  /// The glyph size at [context]; [fallback] when the theme has none.
  static double of(BuildContext context, {double fallback = 16}) {
    final theme = IconTheme.of(context);
    final size = theme.size ?? fallback;
    return theme.applyTextScaling ?? false
        ? MediaQuery.textScalerOf(context).scale(size)
        : size;
  }
}
