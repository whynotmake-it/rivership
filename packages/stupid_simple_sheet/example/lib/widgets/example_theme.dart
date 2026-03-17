import 'package:flutter/cupertino.dart';

/// Resolved color tokens for the example app, adapting to light and dark mode.
///
/// Obtain via [ExampleTheme.of] which resolves all dynamic colors against the
/// current [BuildContext].
class ExampleTheme {
  const ExampleTheme._({
    required this.canvas,
    required this.surface,
    required this.previewBg,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.borderSubtle,
    required this.borderGlow,
    required this.accent,
    required this.accentGreen,
    required this.accentGold,
    required this.accentBlue,
    required this.accentPurple,
    required this.accentOrange,
    required this.accentIndigo,
    required this.previewMiniSurface,
    required this.previewMiniBorder,
    required this.previewMiniShadow,
    required this.previewLine,
    required this.previewHandle,
    required this.innerShadowColor,
    required this.innerBorderColor,
    required this.cardShadow,
    required this.cardHighlight,
    required this.pillShadow,
    required this.pillBorder,
  });

  // Backgrounds
  final Color canvas;
  final Color surface;
  final Color previewBg;

  // Text
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  // Borders
  final Color borderSubtle;
  final Color borderGlow;

  // Accents
  final Color accent;
  final Color accentGreen;
  final Color accentGold;
  final Color accentBlue;
  final Color accentPurple;
  final Color accentOrange;
  final Color accentIndigo;

  // Preview mini-widget tokens
  final Color previewMiniSurface;
  final Color previewMiniBorder;
  final Color previewMiniShadow;
  final Color previewLine;
  final Color previewHandle;

  // Card inner shadow / border
  final Color innerShadowColor;
  final Color innerBorderColor;
  final Color cardShadow;
  final Color cardHighlight;

  // Pill badge tokens
  final Color pillShadow;
  final Color pillBorder;

  /// Resolve all tokens for the current brightness.
  static ExampleTheme of(BuildContext context) {
    final brightness = MediaQuery.platformBrightnessOf(context);
    return brightness == Brightness.dark ? dark : light;
  }

  // Radii (shared, not brightness-dependent)
  static const cardRadius = 24.0;
  static const previewRadius = 14.0;
  static const miniSheetRadius = 16.0;
  static const miniModalRadius = 12.0;

  // ---------------------------------------------------------------------------
  // Dark palette
  // ---------------------------------------------------------------------------
  static final dark = ExampleTheme._(
    canvas: const Color(0xFF1A1A1D),
    surface: const Color(0xFF2B2B30),
    previewBg: const Color(0xFF1A1A1D),
    textPrimary: const Color(0xFFFFFFFF),
    textSecondary: const Color(0xFF8E8E93),
    textTertiary: const Color(0xFF636366),
    borderSubtle: const Color(0xFFFFFFFF).withValues(alpha: .06),
    borderGlow: const Color(0xFFFFFFFF).withValues(alpha: .12),
    accent: const Color(0xFF34C759),
    accentGreen: const Color(0xFF34C759),
    accentGold: const Color(0xFFE4B363),
    accentBlue: const Color(0xFF0A84FF),
    accentPurple: const Color(0xFFBF5AF2),
    accentOrange: const Color(0xFFFF9F0A),
    accentIndigo: const Color(0xFF5E5CE6),
    previewMiniSurface: const Color(0xFF2B2B30),
    previewMiniBorder: const Color(0xFFFFFFFF).withValues(alpha: .08),
    previewMiniShadow: const Color(0xFF000000).withValues(alpha: .4),
    previewLine: const Color(0xFFFFFFFF).withValues(alpha: .08),
    previewHandle: const Color(0xFFFFFFFF).withValues(alpha: .2),
    innerShadowColor: const Color(0xFF000000).withValues(alpha: .35),
    innerBorderColor: const Color(0xFF000000).withValues(alpha: .3),
    cardShadow: const Color(0xFF000000).withValues(alpha: .2),
    cardHighlight: const Color(0xFFFFFFFF).withValues(alpha: .05),
    pillShadow: const Color(0xFF000000).withValues(alpha: .12),
    pillBorder: const Color(0xFFFFFFFF).withValues(alpha: .1),
  );

  // ---------------------------------------------------------------------------
  // Light palette
  // ---------------------------------------------------------------------------
  static final light = ExampleTheme._(
    canvas: const Color(0xFFFAFAFC),
    surface: const Color(0xFFFFFFFF),
    previewBg: const Color(0xFFF2F2F7),
    textPrimary: const Color(0xFF151618),
    textSecondary: const Color(0xFF8E8E93),
    textTertiary: const Color(0xFFC7C7CC),
    borderSubtle: const Color(0xFF000000).withValues(alpha: .08),
    borderGlow: const Color(0xFF000000).withValues(alpha: .08),
    accent: const Color(0xFF34C759),
    accentGreen: const Color(0xFF34C759),
    accentGold: const Color(0xFFE4B363),
    accentBlue: const Color(0xFF007AFF),
    accentPurple: const Color(0xFFAF52DE),
    accentOrange: const Color(0xFFFF9500),
    accentIndigo: const Color(0xFF5856D6),
    previewMiniSurface: const Color(0xFFFFFFFF),
    previewMiniBorder: const Color(0xFF000000).withValues(alpha: .08),
    previewMiniShadow: const Color(0xFF000000).withValues(alpha: .08),
    previewLine: const Color(0xFFF2F2F7),
    previewHandle: const Color(0xFFE5E5EA),
    innerShadowColor: const Color(0xFF000000).withValues(alpha: .04),
    innerBorderColor: const Color(0xFF000000).withValues(alpha: .04),
    cardShadow: const Color(0xFF000000).withValues(alpha: .04),
    cardHighlight: const Color(0xFFFFFFFF).withValues(alpha: .8),
    pillShadow: const Color(0xFF000000).withValues(alpha: .04),
    pillBorder: const Color(0xFFE5E5EA),
  );
}
