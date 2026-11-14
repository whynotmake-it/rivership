import 'dart:math' as math;
import 'dart:ui';

import 'package:coil/src/foundation/color_mix.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// coil's color tokens.
///
/// [CoilColors.light] and [CoilColors.dark] are the defaults. Change any
/// token with [copyWith].
@immutable
class CoilColors with Diagnosticable {
  /// Creates a color set. Prefer [CoilColors.light] / [CoilColors.dark]
  /// and [copyWith].
  const CoilColors({
    required this.brightness,
    required this.surfaces,
    required this.foreground,
    required this.muted,
    required this.mutedForeground,
    required this.accent,
    required this.selected,
    required this.input,
    required this.destructive,
    required this.destructiveLight,
    required this.info,
    required this.success,
    required this.warning,
    required this.brand,
    required this.overlay,
    required this.hover,
    required this.active,
    required this.tint,
    required this.tintHover,
    required this.red,
    required this.redLabel,
    required this.shadowColor,
    this.borderAlpha = 0.12,
    this.focusRingColor,
  });

  /// The light theme (`light-dark()` first arguments).
  static const light = CoilColors(
    brightness: Brightness.light,
    surfaces: [
      Color(0xFFFAFAFA),
      Color(0xFFFCFCFC),
      Color(0xFFFFFFFF),
      Color(0xFFFFFFFF),
      Color(0xFFFFFFFF),
      Color(0xFFFFFFFF),
      Color(0xFFFFFFFF),
      Color(0xFFFFFFFF),
    ],
    foreground: Color(0xFF171717),
    muted: Color(0xFFF4F4F5),
    mutedForeground: Color(0xFF737373),
    accent: Color(0xFFE5E5E5),
    selected: Color(0xFFD4D4D4),
    input: Color(0xFFE5E5E5),
    destructive: Color(0xFFEF4444),
    destructiveLight: Color(0xFFFEF2F2),
    info: Color(0xFF3B82F6),
    success: Color(0xFF22C55E),
    warning: Color(0xFFF59E0B),
    brand: Color(0xFF6B97FF),
    overlay: Color(0xFF000000),
    hover: Color(0x0A000000), // rgb(0 0 0 / 0.04)
    active: Color(0x12000000), // rgb(0 0 0 / 0.07)
    tint: Color(0x14000000), // rgb(0 0 0 / 0.08)
    tintHover: Color(0x11000000), // rgb(0 0 0 / 0.065)
    red: Color(0xFFFB2C36), // tailwind v4 red-500
    redLabel: Color(0xFFC10007), // tailwind v4 red-700
    shadowColor: Color(0x0F000000), // rgb(0 0 0 / 0.06)
  );

  /// The dark theme (`light-dark()` second arguments).
  static const dark = CoilColors(
    brightness: Brightness.dark,
    surfaces: [
      Color(0xFF171717),
      Color(0xFF1E1E1E),
      Color(0xFF252525),
      Color(0xFF2C2C2C),
      Color(0xFF333333),
      Color(0xFF3A3A3A),
      Color(0xFF414141),
      Color(0xFF484848),
    ],
    foreground: Color(0xFFF5F5F5),
    muted: Color(0xFF1E1E1E),
    mutedForeground: Color(0xFFA3A3A3),
    accent: Color(0xFF525252),
    selected: Color(0xFF525252),
    input: Color(0xFF404040),
    destructive: Color(0xFFFCA5A5),
    destructiveLight: Color(0xFF450A0A),
    info: Color(0xFF93C5FD),
    success: Color(0xFF86EFAC),
    warning: Color(0xFFFCD34D),
    brand: Color(0xFF6B97FF),
    overlay: Color(0xFFFFFFFF),
    hover: Color(0x0FFFFFFF), // rgb(255 255 255 / 0.06)
    active: Color(0x1AFFFFFF), // rgb(255 255 255 / 0.1)
    tint: Color(0x40FFFFFF), // rgb(255 255 255 / 0.25)
    tintHover: Color(0x33FFFFFF), // rgb(255 255 255 / 0.2)
    red: Color(0xFFFB2C36), // tailwind v4 red-500
    redLabel: Color(0xFFFF6467), // tailwind v4 red-400
    shadowColor: Color(0x0F000000),
  );

  /// Whether this is the light or the dark side.
  final Brightness brightness;

  /// The 8-level surface ladder (`--surface-1` .. `--surface-8`).
  final List<Color> surfaces;

  /// `--background`, the page floor (`--surface-1`).
  Color get background => surfaces[0];

  /// `--card` (`--surface-3`).
  Color get card => surfaces[2];

  /// `--foreground`: primary text and the primary button fill.
  final Color foreground;

  /// `--muted`: the quiet fill behind grouped controls.
  final Color muted;

  /// `--muted-foreground`: secondary text, placeholders, idle labels.
  final Color mutedForeground;

  /// `--accent`: a neutral grey (the switch's off track), not the brand
  /// color. See [brand] for that.
  final Color accent;

  /// `--selected`.
  final Color selected;

  /// `--input`.
  final Color input;

  /// `--destructive`.
  final Color destructive;

  /// `--destructive-light`.
  final Color destructiveLight;

  /// `--info`.
  final Color info;

  /// `--success`.
  final Color success;

  /// `--warning`.
  final Color warning;

  /// The one brand color (switch track, focus rings).
  final Color brand;

  /// `--focus-ring`: [focusRingColor] if set, else [brand].
  Color get focusRing => focusRingColor ?? brand;

  /// Overrides the focus ring color (high contrast derives one).
  final Color? focusRingColor;

  /// The [border] opacity over [foreground]: 0.12, 0.4 in high contrast.
  final double borderAlpha;

  /// `--overlay` as an opaque color: black in light, white in dark.
  final Color overlay;

  /// `--hover`: the translucent hover wash.
  final Color hover;

  /// `--active`: the translucent pressed / selected wash.
  final Color active;

  /// `--tint`: the see-through secondary button fill.
  final Color tint;

  /// `--tint-hover`.
  final Color tintHover;

  /// `--border`: `color-mix(in oklab, foreground 12%, transparent)`.
  Color get border => CoilColorMix.withTransparent(foreground, borderAlpha);

  /// The destructive button's red wash base (tailwind red-500).
  final Color red;

  /// The destructive button's label red (red-700 light, red-400 dark).
  final Color redLabel;

  /// `--shadow-color`.
  final Color shadowColor;

  /// Linearly interpolates two color sets, for animated theme changes.
  // A static lerp, like Color.lerp and TextStyle.lerp.
  // ignore: prefer_constructors_over_static_methods
  static CoilColors lerp(CoilColors a, CoilColors b, double t) {
    Color c(Color x, Color y) => Color.lerp(x, y, t)!;
    return CoilColors(
      brightness: t < 0.5 ? a.brightness : b.brightness,
      surfaces: [
        for (var i = 0; i < 8; i++) c(a.surfaces[i], b.surfaces[i]),
      ],
      foreground: c(a.foreground, b.foreground),
      muted: c(a.muted, b.muted),
      mutedForeground: c(a.mutedForeground, b.mutedForeground),
      accent: c(a.accent, b.accent),
      selected: c(a.selected, b.selected),
      input: c(a.input, b.input),
      destructive: c(a.destructive, b.destructive),
      destructiveLight: c(a.destructiveLight, b.destructiveLight),
      info: c(a.info, b.info),
      success: c(a.success, b.success),
      warning: c(a.warning, b.warning),
      brand: c(a.brand, b.brand),
      overlay: c(a.overlay, b.overlay),
      hover: c(a.hover, b.hover),
      active: c(a.active, b.active),
      tint: c(a.tint, b.tint),
      tintHover: c(a.tintHover, b.tintHover),
      red: c(a.red, b.red),
      redLabel: c(a.redLabel, b.redLabel),
      shadowColor: c(a.shadowColor, b.shadowColor),
      borderAlpha: a.borderAlpha + (b.borderAlpha - a.borderAlpha) * t,
      // Stays null when neither side overrides it, so the ring keeps
      // following the brand color.
      focusRingColor: a.focusRingColor == null && b.focusRingColor == null
          ? null
          : c(a.focusRing, b.focusRing),
    );
  }

  /// Returns a copy with the given tokens replaced. Change the brand color
  /// with `copyWith(brand: …)`; focus rings follow it.
  CoilColors copyWith({
    Brightness? brightness,
    List<Color>? surfaces,
    Color? foreground,
    Color? muted,
    Color? mutedForeground,
    Color? accent,
    Color? selected,
    Color? input,
    Color? destructive,
    Color? destructiveLight,
    Color? info,
    Color? success,
    Color? warning,
    Color? brand,
    Color? overlay,
    Color? hover,
    Color? active,
    Color? tint,
    Color? tintHover,
    Color? red,
    Color? redLabel,
    Color? shadowColor,
    double? borderAlpha,
    Color? focusRingColor,
  }) => CoilColors(
    brightness: brightness ?? this.brightness,
    surfaces: surfaces ?? this.surfaces,
    foreground: foreground ?? this.foreground,
    muted: muted ?? this.muted,
    mutedForeground: mutedForeground ?? this.mutedForeground,
    accent: accent ?? this.accent,
    selected: selected ?? this.selected,
    input: input ?? this.input,
    destructive: destructive ?? this.destructive,
    destructiveLight: destructiveLight ?? this.destructiveLight,
    info: info ?? this.info,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    brand: brand ?? this.brand,
    overlay: overlay ?? this.overlay,
    hover: hover ?? this.hover,
    active: active ?? this.active,
    tint: tint ?? this.tint,
    tintHover: tintHover ?? this.tintHover,
    red: red ?? this.red,
    redLabel: redLabel ?? this.redLabel,
    shadowColor: shadowColor ?? this.shadowColor,
    borderAlpha: borderAlpha ?? this.borderAlpha,
    focusRingColor: focusRingColor ?? this.focusRingColor,
  );

  /// The surface at [level] (1–8, clamped): `--surface-N`. Popups sit one
  /// or two levels above what opened them.
  Color surface(int level) => surfaces[level.clamp(1, 8) - 1];

  /// `--shadow-N`, as box shadows. The dark recipe's inset ring and top
  /// highlight can't be box shadows; [insetRing] and [topHighlight] return
  /// them to paint inside the shape (see `CoilSurface`).
  ///
  /// Blur is converted from CSS: a CSS blur of `B` has a Gaussian sigma of
  /// `B / 2`, while a [BoxShadow]'s is `0.57735 × blurRadius + 0.5`.
  List<BoxShadow> shadow(int level) {
    final n = level.clamp(1, 8);
    BoxShadow drop(int i, Color color) => BoxShadow(
      color: color,
      offset: Offset(0, _drop(i)),
      blurRadius: _blurRadius(_drop(i)),
      spreadRadius: -_drop(i) / 2,
    );
    if (brightness == Brightness.light) {
      return [
        BoxShadow(color: shadowColor, spreadRadius: 1),
        for (var i = 1; i < n; i++) drop(i, shadowColor),
      ];
    }
    const dropColor = Color(0x2E000000); // --dm-drop, rgba(0,0,0,0.18)
    return [
      if (n >= 3)
        BoxShadow(
          color: Color.fromRGBO(0, 0, 0, 0.12 + 0.02 * (n - 3)),
          spreadRadius: 1,
        ),
      for (var i = 1; i < n; i++) drop(i, dropColor),
    ];
  }

  /// The [BoxShadow.blurRadius] whose sigma equals that of a CSS blur of
  /// [cssBlur]: `(B / 2 - 0.5) / 0.57735`, never below 0. The 1 px drop
  /// (sigma 0.5) comes out as a hard edge, since a [BoxShadow] with no blur
  /// radius has no sigma.
  static double _blurRadius(double cssBlur) =>
      math.max(0, (cssBlur / 2 - 0.5) / 0.57735);

  /// The inner hairline of `--shadow-N`, as the side of a shape border:
  /// light draws it outside (in [shadow]) and returns [BorderSide.none],
  /// dark draws an inset white ring.
  BorderSide insetRing(int level) {
    if (brightness == Brightness.light) return BorderSide.none;
    final n = level.clamp(1, 8);
    final alpha = n <= 3 ? 0.02 : (n <= 5 ? 0.04 : 0.06);
    return BorderSide(color: Color.fromRGBO(255, 255, 255, alpha));
  }

  /// The dark recipe's `inset 0 1px 0 0` highlight along the top edge, or
  /// null in light mode and on the page (level 1).
  Color? topHighlight(int level) {
    final n = level.clamp(1, 8);
    if (brightness == Brightness.light || n == 1) return null;
    final alpha = n == 2 ? 0.01 : (n <= 4 ? 0.02 : (n <= 6 ? 0.04 : 0.06));
    return Color.fromRGBO(255, 255, 255, alpha);
  }

  static double _drop(int i) =>
      const [1.0, 3.0, 6.0, 12.0, 24.0, 48.0, 96.0][i - 1];

  /// These colors resolved for high contrast
  /// (`MediaQuery.highContrastOf`): borders at foreground 40%, a stronger
  /// off-state track ([accent] pushed toward the foreground), and a focus
  /// ring derived from [brand] with at least 3:1 contrast against the
  /// background.
  CoilColors highContrast() => copyWith(
    accent: CoilColorMix.oklab(accent, foreground, 0.7),
    borderAlpha: 0.4,
    focusRingColor: CoilColorMix.ensureContrast(brand, background, 3),
  );

  @override
  bool operator ==(Object other) =>
      other is CoilColors &&
      other.brightness == brightness &&
      listEquals(other.surfaces, surfaces) &&
      other.foreground == foreground &&
      other.muted == muted &&
      other.mutedForeground == mutedForeground &&
      other.accent == accent &&
      other.selected == selected &&
      other.input == input &&
      other.destructive == destructive &&
      other.destructiveLight == destructiveLight &&
      other.info == info &&
      other.success == success &&
      other.warning == warning &&
      other.brand == brand &&
      other.overlay == overlay &&
      other.hover == hover &&
      other.active == active &&
      other.tint == tint &&
      other.tintHover == tintHover &&
      other.red == red &&
      other.redLabel == redLabel &&
      other.shadowColor == shadowColor &&
      other.borderAlpha == borderAlpha &&
      other.focusRingColor == focusRingColor;

  @override
  int get hashCode => Object.hashAll([
    brightness,
    ...surfaces,
    foreground,
    muted,
    mutedForeground,
    accent,
    selected,
    input,
    destructive,
    destructiveLight,
    info,
    success,
    warning,
    brand,
    overlay,
    hover,
    active,
    tint,
    tintHover,
    red,
    redLabel,
    shadowColor,
  ]);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(EnumProperty('brightness', brightness))
      ..add(ColorProperty('foreground', foreground))
      ..add(ColorProperty('background', background))
      ..add(ColorProperty('brand', brand));
  }
}
