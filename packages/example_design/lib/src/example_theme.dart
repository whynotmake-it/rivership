import 'package:flutter/cupertino.dart';

/// Resolved design tokens for the example apps, adapting to light and dark.
///
/// Inspired by the Dia design language: a near-monochrome system on a soft
/// canvas, frosted surfaces with a single gentle shadow, generous radii, and
/// featherweight type.
///
/// Obtain via [ExampleTheme.of], which resolves the palette against the
/// current platform brightness.
@immutable
class ExampleTheme {
  const ExampleTheme._({
    required this.canvas,
    required this.surface,
    required this.surfaceSolid,
    required this.fog,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.border,
    required this.borderStrong,
    required this.shadowColor,
  });

  /// The page background — the lightest, calmest layer.
  final Color canvas;

  /// Translucent frosted surface fill (pair with a backdrop blur).
  final Color surface;

  /// Opaque surface fill for places where translucency reads poorly.
  final Color surfaceSolid;

  /// Subtle inset / soft-fill background (insets, previews, soft buttons).
  final Color fog;

  /// Primary text and iconography.
  final Color textPrimary;

  /// Secondary body copy.
  final Color textSecondary;

  /// Tertiary text, metadata, captions.
  final Color textTertiary;

  /// Hairline borders and dividers.
  final Color border;

  /// A slightly stronger border for emphasis.
  final Color borderStrong;

  /// The color of the single soft shadow.
  final Color shadowColor;

  /// The single, soft shadow used across the system.
  List<BoxShadow> get softShadow => [
        BoxShadow(
          color: shadowColor,
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ];

  /// A lighter ambient shadow for resting chips and pills.
  List<BoxShadow> get hairlineShadow => [
        BoxShadow(
          color: shadowColor,
          blurRadius: 8,
        ),
      ];

  // Shared radii.
  static const cardRadius = 28.0;
  static const previewRadius = 18.0;
  static const miniSheetRadius = 16.0;
  static const miniModalRadius = 12.0;

  // ---------------------------------------------------------------------------
  // Backwards-compatible aliases.
  //
  // The legacy palette exposed six accent colors and a handful of mini-surface
  // tokens. The Dia system is monochrome, so these now resolve onto the neutral
  // palette — keeping older example apps (e.g. stupid_simple_sheet) compiling
  // while inheriting the new, quiet look automatically.
  // ---------------------------------------------------------------------------
  Color get accent => textPrimary;
  Color get accentGreen => textPrimary;
  Color get accentGold => textPrimary;
  Color get accentBlue => textPrimary;
  Color get accentPurple => textPrimary;
  Color get accentOrange => textPrimary;
  Color get accentIndigo => textPrimary;

  Color get borderSubtle => border;
  Color get previewMiniSurface => surfaceSolid;
  Color get previewMiniBorder => border;
  Color get previewMiniShadow => shadowColor;
  Color get previewLine => border;
  Color get previewHandle => borderStrong;
  Color get cardHighlight => surface;
  Color get pillShadow => shadowColor;
  Color get pillBorder => border;

  /// Resolves the palette for the current platform brightness.
  static ExampleTheme of(BuildContext context) {
    final brightness = MediaQuery.platformBrightnessOf(context);
    return brightness == Brightness.dark ? dark : light;
  }

  /// The primary Dia look: a warm-white canvas with frosted surfaces.
  static final light = ExampleTheme._(
    canvas: const Color(0xFFF8F8F8),
    surface: const Color(0xFFFFFFFF).withValues(alpha: .9),
    surfaceSolid: const Color(0xFFFFFFFF),
    fog: const Color(0xFFEFEFEF),
    textPrimary: const Color(0xFF111113),
    textSecondary: const Color(0xFF636363),
    textTertiary: const Color(0xFF9A9A9C),
    border: const Color(0xFF000000).withValues(alpha: .08),
    borderStrong: const Color(0xFF000000).withValues(alpha: .16),
    shadowColor: const Color(0xFF000000).withValues(alpha: .08),
  );

  /// A near-monochrome dark adaptation keeping the same quiet philosophy.
  static final dark = ExampleTheme._(
    canvas: const Color(0xFF0E0E10),
    surface: const Color(0xFFFFFFFF).withValues(alpha: .055),
    surfaceSolid: const Color(0xFF1C1C1F),
    fog: const Color(0xFF161618),
    textPrimary: const Color(0xFFF5F5F6),
    textSecondary: const Color(0xFFA8A8AD),
    textTertiary: const Color(0xFF6E6E73),
    border: const Color(0xFFFFFFFF).withValues(alpha: .08),
    borderStrong: const Color(0xFFFFFFFF).withValues(alpha: .18),
    shadowColor: const Color(0xFF000000).withValues(alpha: .5),
  );
}
