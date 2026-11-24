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
    required this.scrim,
    this.borderAlpha = 0.12,
  });

  /// A full palette from a [brand] color and a neutral tone, for
  /// [brightness].
  ///
  /// The neutral tone tints every grey: surfaces, text, fills and borders
  /// take [neutralHue] (an Oklch hue in degrees: about 60 is warm, 250 is
  /// cool) at [neutralChroma] (Oklch chroma: 0 is pure grey, 0.01 a hint,
  /// 0.03 clearly tinted). Each token keeps the lightness and opacity it has
  /// in [CoilColors.light] or [CoilColors.dark], so the palette keeps its
  /// contrast and surface order. Where a color can't hold the chroma (white,
  /// black, the lightest surfaces), it gets as much as fits.
  ///
  /// Text and status colors keep the contrast they have against the default
  /// background: if the tint lowers it, they get lighter or darker, never a
  /// different hue.
  ///
  /// [brand] is used as given (the default is coil's blue). The focus ring
  /// follows it; [highContrast] darkens it to 3 : 1 against the background.
  ///
  /// With the defaults this is [CoilColors.light] or [CoilColors.dark].
  ///
  /// ```dart
  /// CoilThemeData(
  ///   colors: CoilColors.fromSeed(
  ///     brightness: Brightness.light,
  ///     brand: const Color(0xFF14B8A6),
  ///     neutralHue: 60,
  ///     neutralChroma: 0.01,
  ///   ),
  /// )
  /// ```
  factory CoilColors.fromSeed({
    required Brightness brightness,
    Color? brand,
    double neutralHue = 0,
    double neutralChroma = 0,
  }) {
    // The recipe: every token's lightness and alpha, read from the default
    // palette for this brightness.
    final base = brightness == Brightness.dark ? dark : light;
    Color neutral(Color token) => CoilColorMix.oklch(
      CoilColorMix.toOklch(token).l,
      neutralChroma,
      neutralHue,
      alpha: token.a,
    );
    final surfaces = [for (final surface in base.surfaces) neutral(surface)];
    final background = surfaces[0];
    // Keeps the contrast [token] has against the default background.
    Color legible(Color token, Color generated) =>
        CoilColorMix.ensureContrastByLightness(
          generated,
          background,
          CoilColorMix.contrastRatio(token, base.background),
        );
    Color text(Color token) => legible(token, neutral(token));
    Color status(Color token) => legible(token, token);
    return base.copyWith(
      surfaces: surfaces,
      foreground: text(base.foreground),
      muted: neutral(base.muted),
      mutedForeground: text(base.mutedForeground),
      accent: neutral(base.accent),
      selected: neutral(base.selected),
      input: neutral(base.input),
      destructive: status(base.destructive),
      info: status(base.info),
      success: status(base.success),
      warning: status(base.warning),
      brand: brand,
      overlay: neutral(base.overlay),
      hover: neutral(base.hover),
      active: neutral(base.active),
      tint: neutral(base.tint),
      tintHover: neutral(base.tintHover),
      red: status(base.red),
      redLabel: status(base.redLabel),
      shadowColor: neutral(base.shadowColor),
    );
  }

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
    scrim: Color.from(alpha: 0.2, red: 0, green: 0, blue: 0),
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
    scrim: Color.from(alpha: 0.3, red: 0, green: 0, blue: 0),
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

  /// The accent button's fill: [brand], deepened in Oklch (same hue and
  /// chroma) only as far as its label needs for 4.5 : 1.
  ///
  /// The label ([onBrandFill]) is white or near-black, whichever APCA
  /// says reads better on the brand: white on a mid blue, orange, green or
  /// purple, dark on a yellow or lime, which then keep their color. A brand
  /// that already passes is used as given. In dark, a deep brand
  /// (navy) is first lifted to Oklch lightness 0.5 so it stands off the
  /// page.
  Color get brandFill => _brandTones.fill;

  /// The label and icon color on [brandFill]: white or near-black,
  /// whichever reads with more APCA contrast on [brand].
  Color get onBrandFill => _brandTones.label;

  /// [brand] as text or a thin mark on [background] (a link, a cursor, a
  /// tick): lightened or darkened in Oklch until it reaches 4.5 : 1, hue
  /// and chroma kept.
  ///
  /// A yellow or lime darkened this far would read olive, so it leans warm,
  /// toward amber, as it darkens.
  Color get brandInk {
    final (:l, :c, :h) = CoilColorMix.toOklch(brand);
    Color at(double lightness) =>
        CoilColorMix.oklch(lightness, c, warmShade(h, l - lightness));
    bool passes(Color color) =>
        CoilColorMix.contrastRatio(color, background) >= 4.5;
    if (passes(brand)) return brand;
    final extreme = CoilColorMix.toOklch(background).l > 0.5 ? 0.0 : 1.0;
    var fails = l;
    var ok = extreme;
    for (var i = 0; i < 24; i++) {
      final mid = (fails + ok) / 2;
      if (passes(at(mid))) {
        ok = mid;
      } else {
        fails = mid;
      }
    }
    return at(ok);
  }

  /// [hue] (Oklch degrees) for a shade [darkenedBy] Oklch lightness darker:
  /// yellow-to-lime hues lean toward orange (60), up to 25 degrees, so a
  /// dark yellow reads amber rather than olive. Other hues are kept.
  static double warmShade(double hue, double darkenedBy) {
    if (darkenedBy <= 0 || hue <= 75 || hue >= 150) return hue;
    return hue -
        math.min(25, darkenedBy * 120) * ((150 - hue) / 75).clamp(0, 1);
  }

  ({Color fill, Color label}) get _brandTones =>
      _brandTonesCache[(brand, brightness)] ??= _resolveBrandTones(
        brightness == Brightness.dark ? _lifted(brand) : brand,
      );

  static final _brandTonesCache =
      <(Color, Brightness), ({Color fill, Color label})>{};

  /// A deep brand (navy, a dark green) lifted to Oklch lightness 0.5 so it
  /// still stands off dark surfaces. Lighter brands are kept.
  static Color _lifted(Color brand) {
    final (:l, :c, :h) = CoilColorMix.toOklch(brand);
    return l >= 0.5 ? brand : CoilColorMix.oklch(0.5, c, h, alpha: brand.a);
  }

  static ({Color fill, Color label}) _resolveBrandTones(Color brand) {
    const white = Color(0xFFFFFFFF);
    const ink = Color(0xFF171717);
    // APCA decides which label reads better on the hue (white on a mid
    // blue or orange, dark on yellow); the fill then meets coil's 4.5 : 1
    // text floor, even at the hover tone, which is a little lighter.
    final label =
        CoilColorMix.apcaContrast(ink, brand).abs() >=
            CoilColorMix.apcaContrast(white, brand).abs()
        ? ink
        : white;
    final (:l, :c, :h) = CoilColorMix.toOklch(brand);
    Color at(double lightness) =>
        CoilColorMix.oklch(lightness, c, h, alpha: brand.a);
    bool passes(double lightness) =>
        CoilColorMix.contrastRatio(label, at(lightness + hoverLift)) >= 4.5;
    if (passes(l)) return (fill: brand, label: label);
    // The tone closest to the brand that passes: darker under a white
    // label, lighter under a dark one.
    var fails = l;
    var ok = label == white ? 0.0 : 1.0;
    for (var i = 0; i < 24; i++) {
      final mid = (fails + ok) / 2;
      if (passes(mid)) {
        ok = mid;
      } else {
        fails = mid;
      }
    }
    return (fill: at(ok), label: label);
  }

  /// How much lighter (Oklch) the accent button is under the pointer.
  static const hoverLift = 0.03;

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

  /// The scrim behind coil's modal surfaces: sheets, centered and drawer
  /// dialogs, and a `CoilDrawer` sliding over the page. Black at 20 % in
  /// light and 30 % in dark, where black dims less. Nothing blurs the page
  /// behind it.
  final Color scrim;

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
      scrim: c(a.scrim, b.scrim),
      borderAlpha: a.borderAlpha + (b.borderAlpha - a.borderAlpha) * t,
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
    Color? scrim,
    double? borderAlpha,
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
    scrim: scrim ?? this.scrim,
    borderAlpha: borderAlpha ?? this.borderAlpha,
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
  /// (`MediaQuery.highContrastOf`): borders at foreground 40% and a
  /// stronger off-state track ([accent] pushed toward the foreground). The
  /// theme's high contrast also strengthens the focus ring.
  CoilColors highContrast() => copyWith(
    accent: CoilColorMix.oklab(accent, foreground, 0.7),
    borderAlpha: 0.4,
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
      other.scrim == scrim &&
      other.borderAlpha == borderAlpha;

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
    scrim,
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
