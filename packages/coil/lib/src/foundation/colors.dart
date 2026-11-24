import 'dart:math' as math;
import 'dart:ui';

import 'package:coil/src/foundation/color_mix.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// How [CoilColors.fromSeed] turns the brand into [CoilColors.brandFill],
/// the fill of surfaces that carry text on the brand (the brand button, the
/// brand badge).
enum CoilBrandFill {
  /// The brand, deepened or lightened in Oklch (hue and chroma kept) until
  /// its label reaches 4.5 : 1, coil's floor for text, also at the button's
  /// slightly lighter hover and darker pressed tones. A brand that already
  /// passes is kept. The default.
  accessible,

  /// The brand exactly as given, under whichever label (white or
  /// near-black) reads better by APCA. On a mid-tone brand, such as coil's
  /// own blue or an orange, the label falls below 4.5 : 1.
  exact,
}

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
    required this.brandFill,
    required this.onBrandFill,
    required this.brandInk,
    required this.brandWash,
    required this.brandMark,
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
    this.brandFillPolicy = CoilBrandFill.accessible,
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
  /// [brand] is used as given (the default is coil's blue), in light,
  /// dark and high contrast alike: focus rings, selection, the cursor and
  /// the switch follow it (the theme's high contrast darkens only the focus
  /// ring, to 3 : 1). Surfaces that carry text on the brand use
  /// [CoilColors.brandFill] and [CoilColors.onBrandFill], derived from it by
  /// [brandFill] ([CoilBrandFill.accessible] by default). In dark, the
  /// accessible fill of a deep brand, such as navy, is first lifted to
  /// Oklch lightness 0.5 so it stands off the page.
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
    CoilBrandFill brandFill = CoilBrandFill.accessible,
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
    final tones = brandTones(brand ?? base.brand, brightness, brandFill);
    final accents = brandAccents(
      brand ?? base.brand,
      surfaces,
      brightness,
      brandFill,
    );
    final mark = brandMarkFor(
      brand ?? base.brand,
      surfaces,
      brightness,
      brandFill,
    );
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
      brandFill: tones.fill,
      onBrandFill: tones.label,
      brandInk: accents.ink,
      brandWash: accents.wash,
      brandMark: mark,
      brandFillPolicy: brandFill,
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
    brandFill: Color(0xFF4168CB), // brand, deepened to 4.5 : 1
    onBrandFill: Color(0xFFFFFFFF),
    brandInk: Color(0xFF3E65C8), // brand, darkened to 4.5 : 1 on its wash
    brandWash: Color(0x246B97FF), // brand at 14 %
    brandMark: Color(0xFF618DF4), // brand, deepened to 3 : 1
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
    brandFill: Color(0xFF4168CB), // brand, deepened to 4.5 : 1
    onBrandFill: Color(0xFFFFFFFF),
    brandInk: Color(0xFF98B8FF), // brand, lightened to 4.5 : 1 on its wash
    brandWash: Color(0x386B97FF), // brand at 22 %
    brandMark: Color(0xFF6B97FF), // brand
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

  /// The one brand color, exactly as the theme gives it: focus rings, the
  /// on switch, text selection and other marks. Text never sits on it; see
  /// [brandFill] for that.
  final Color brand;

  /// The fill of a surface that carries text on the brand: the brand
  /// button, the brand badge. Under [onBrandFill].
  ///
  /// [CoilColors.fromSeed] derives it from [brand] by a [CoilBrandFill]
  /// policy; the default themes use [CoilBrandFill.accessible], which can
  /// make it a little deeper than [brand]. High contrast always uses the
  /// accessible fill.
  final Color brandFill;

  /// The label and icon color on [brandFill]: white or near-black.
  final Color onBrandFill;

  /// [brand] as text on the page: the label of a selected tab or toggle
  /// segment when `CoilThemeData.brandSelection` is on. Under
  /// [CoilBrandFill.accessible] it's lightened or darkened in Oklch until it
  /// reaches 4.5 : 1 on [brandWash] over every surface a control sits on
  /// (levels 1 to 5) and on each bare surface, and a yellow darkens toward
  /// amber rather than olive; under [CoilBrandFill.exact] it's [brand].
  final Color brandInk;

  /// A translucent brand wash that marks the current item when
  /// `CoilThemeData.brandSelection` is on: the selected tab's pill, the
  /// selected toggle segments. Brand at 14 % in light and 22 % in dark.
  /// Under [CoilBrandFill.accessible] the dark wash lifts a deep brand to
  /// Oklch lightness 0.5 and leans a yellow or lime toward amber, since a
  /// thin brand over a dark page reads as a dark shade of it.
  final Color brandWash;

  /// [brand] as a mark: the focus ring, the on switch's track, the
  /// selected radio's dot and the text cursor. Under
  /// [CoilBrandFill.accessible] it reaches 3 : 1 against the surfaces
  /// controls sit on (levels 1 to 5: the page, cards, popovers, sheets and
  /// dialogs), as WCAG asks of a control's marks: a brand that doesn't is
  /// moved in Oklch lightness, chroma kept, darker in light (coil's blue a
  /// little, a yellow to amber) and lighter in dark (navy, graphite). A
  /// brand that already shows is [brand] itself; so is
  /// [CoilBrandFill.exact].
  final Color brandMark;

  /// How [brandFill], [onBrandFill], [brandInk], [brandWash] and
  /// [brandMark] derive
  /// from [brand]: what [CoilColors.fromSeed] was given, and what [copyWith]
  /// uses when it derives them again for a new brand.
  final CoilBrandFill brandFillPolicy;

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
      brandFill: c(a.brandFill, b.brandFill),
      onBrandFill: c(a.onBrandFill, b.onBrandFill),
      brandInk: c(a.brandInk, b.brandInk),
      brandWash: c(a.brandWash, b.brandWash),
      brandMark: c(a.brandMark, b.brandMark),
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
      brandFillPolicy: t < 0.5 ? a.brandFillPolicy : b.brandFillPolicy,
    );
  }

  /// Returns a copy with the given tokens replaced. Change the brand color
  /// with `copyWith(brand: …)`; focus rings follow it, and [brandFill],
  /// [onBrandFill], [brandInk] and [brandWash] are derived again by
  /// [brandFillPolicy] (the one given here, or this palette's) unless you
  /// pass them too. A new policy alone derives them again as well.
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
    Color? brandFill,
    Color? onBrandFill,
    Color? brandInk,
    Color? brandWash,
    Color? brandMark,
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
    CoilBrandFill? brandFillPolicy,
  }) {
    final newBrightness = brightness ?? this.brightness;
    final newBrand = brand ?? this.brand;
    final newPolicy = brandFillPolicy ?? this.brandFillPolicy;
    // A new brand, side or policy gets its own brand tones unless they're
    // given.
    final changed =
        newBrand != this.brand ||
        newBrightness != this.brightness ||
        newPolicy != this.brandFillPolicy;
    final tones = changed && (brandFill == null || onBrandFill == null)
        ? brandTones(newBrand, newBrightness, newPolicy)
        : null;
    final newSurfaces = surfaces ?? this.surfaces;
    final accents = changed && (brandInk == null || brandWash == null)
        ? brandAccents(newBrand, newSurfaces, newBrightness, newPolicy)
        : null;
    final mark = changed && brandMark == null
        ? brandMarkFor(newBrand, newSurfaces, newBrightness, newPolicy)
        : null;
    return CoilColors(
      brightness: newBrightness,
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
      brand: newBrand,
      brandFill: brandFill ?? tones?.fill ?? this.brandFill,
      onBrandFill: onBrandFill ?? tones?.label ?? this.onBrandFill,
      brandInk: brandInk ?? accents?.ink ?? this.brandInk,
      brandWash: brandWash ?? accents?.wash ?? this.brandWash,
      brandMark: brandMark ?? mark ?? this.brandMark,
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
      brandFillPolicy: newPolicy,
    );
  }

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

  /// How far (Oklch lightness) the brand button moves from [brandFill]:
  /// this much lighter under the pointer and this much darker pressed.
  /// [CoilBrandFill.accessible] checks its label at both tones too, so no
  /// state drops it below 4.5 : 1.
  static const brandStateShift = 0.03;

  /// [brandFill] and its label for [brand] in [brightness] under [policy],
  /// as [CoilColors.fromSeed] derives them.
  ///
  /// The label is white or near-black ([CoilColors.light]'s foreground),
  /// whichever reads better on the brand by APCA: white on a mid blue,
  /// orange, green or purple, dark on a yellow or lime. [CoilBrandFill.exact]
  /// stops there. [CoilBrandFill.accessible] then moves the fill in Oklch,
  /// hue and chroma kept, until the label reaches 4.5 : 1 at the hover and
  /// pressed tones too ([brandStateShift] lighter and darker); in dark it
  /// first lifts a brand darker than Oklch lightness 0.5 to 0.5.
  static ({Color fill, Color label}) brandTones(
    Color brand,
    Brightness brightness,
    CoilBrandFill policy,
  ) => _brandTonesCache[(brand, brightness, policy)] ??= _resolveBrandTones(
    brand,
    brightness,
    policy,
  );

  static final _brandTonesCache =
      <(Color, Brightness, CoilBrandFill), ({Color fill, Color label})>{};

  static ({Color fill, Color label}) _resolveBrandTones(
    Color brand,
    Brightness brightness,
    CoilBrandFill policy,
  ) {
    const white = Color(0xFFFFFFFF);
    final ink = light.foreground;
    Color labelFor(Color fill) =>
        CoilColorMix.apcaContrast(ink, fill).abs() >=
            CoilColorMix.apcaContrast(white, fill).abs()
        ? ink
        : white;
    if (policy == CoilBrandFill.exact) {
      return (fill: brand, label: labelFor(brand));
    }
    var (:l, :c, :h) = CoilColorMix.toOklch(brand);
    final lifted = brightness == Brightness.dark && l < 0.5;
    if (lifted) l = 0.5;
    Color at(double lightness) =>
        CoilColorMix.oklch(lightness, c, h, alpha: brand.a);
    final start = lifted ? at(l) : brand;
    final label = labelFor(start);
    // A hair over 4.5, so the fill still passes once stored in 8 bits.
    bool passes(double lightness) => [
      lightness - brandStateShift,
      lightness + brandStateShift,
    ].every((tone) => CoilColorMix.contrastRatio(label, at(tone)) >= 4.55);
    if (passes(l)) return (fill: start, label: label);
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

  /// [brandInk] and [brandWash] for [brand] over [surfaces] in
  /// [brightness] under [policy], as [CoilColors.fromSeed] derives them.
  ///
  /// [CoilBrandFill.exact] keeps the brand as it is: the ink is [brand] and
  /// the wash is [brand] at 14 % (22 % in dark). [CoilBrandFill.accessible]
  /// lifts a deep brand's dark wash to Oklch lightness 0.5 and leans a
  /// yellow's toward amber, and moves the ink in Oklch lightness until it
  /// reaches 4.5 : 1 on the wash over every surface a control sits on
  /// (levels 1 to 5: a selected tab on the page, a card, a popover, a sheet
  /// or a dialog) and on each bare surface.
  static ({Color ink, Color wash}) brandAccents(
    Color brand,
    List<Color> surfaces,
    Brightness brightness,
    CoilBrandFill policy,
  ) {
    final dark = brightness == Brightness.dark;
    final alpha = dark ? 0.22 : 0.14;
    if (policy == CoilBrandFill.exact) {
      return (ink: brand, wash: brand.withValues(alpha: alpha));
    }
    final (:l, :c, :h) = CoilColorMix.toOklch(brand);
    // Over a dark page a thin brand reads as a dark shade of it: lift a
    // deep one and lean a yellow warm, as a shade would.
    final washBase = dark
        ? CoilColorMix.oklch(
            math.max(l, 0.5),
            c,
            CoilColorMix.warmShadeHue(h, 0.3),
          )
        : brand;
    final wash = washBase.withValues(alpha: alpha);
    final grounds = [
      for (final surface in surfaces.take(_controlLevels)) ...[
        surface,
        Color.alphaBlend(wash, surface),
      ],
    ];
    final ink = _toContrast(
      brand,
      grounds,
      4.5,
      lighter: dark,
      hueAt: (lightness) => CoilColorMix.warmShadeHue(h, l - lightness),
    );
    return (ink: ink, wash: wash);
  }

  /// Below this Oklch chroma a brand reads as grey: graphite (zinc, about
  /// 0.014), stone (0.010) and Tailwind's gray (0.027) are under it; slate
  /// (0.046) and muted navies and teals are over it. See [brandIsChromatic].
  static const brandChromaFloor = 0.03;

  /// Whether [brand] has enough color to mark a selection: its Oklch chroma
  /// is at least [brandChromaFloor]. A grey brand (graphite) can't, so
  /// `CoilThemeData.brandSelection` falls back to the neutral selection for
  /// it; the brand button, the switch and the focus ring still use it.
  bool get brandIsChromatic =>
      CoilColorMix.toOklch(brand).c >= brandChromaFloor;

  /// The surface levels brand ink and marks must show on: the page (1) to
  /// a dialog (5). Levels 6 to 8 are rare stacking (a popover in a dialog),
  /// and holding them would wash the ink out on every page.
  static const _controlLevels = 5;

  /// [brandMark] for [brand] over [surfaces] in [brightness] under
  /// [policy], as [CoilColors.fromSeed] derives it.
  ///
  /// [CoilBrandFill.accessible] moves a brand that doesn't reach 3 : 1
  /// against levels 1 to 5 in Oklch lightness, chroma kept, until it does:
  /// darker in light (a yellow toward amber, not olive), lighter in dark.
  /// A brand that already shows is [brand]; so is [CoilBrandFill.exact].
  static Color brandMarkFor(
    Color brand,
    List<Color> surfaces,
    Brightness brightness,
    CoilBrandFill policy,
  ) {
    if (policy == CoilBrandFill.exact) return brand;
    final (:l, c: _, :h) = CoilColorMix.toOklch(brand);
    return _toContrast(
      brand,
      surfaces.take(_controlLevels).toList(),
      3,
      lighter: brightness == Brightness.dark,
      hueAt: (lightness) => CoilColorMix.warmShadeHue(h, l - lightness),
    );
  }

  /// [color] if it reaches [ratio] against every one of [grounds];
  /// otherwise the color closest to it, at its chroma and [hueAt] its
  /// lightness, made [lighter] (or darker) in Oklch until it does.
  static Color _toContrast(
    Color color,
    List<Color> grounds,
    double ratio, {
    required bool lighter,
    required double Function(double lightness) hueAt,
  }) {
    // A hair over [ratio], so the result still passes in 8 bits.
    bool passes(Color candidate) => grounds.every(
      (ground) => CoilColorMix.contrastRatio(candidate, ground) >= ratio + 0.05,
    );
    if (passes(color)) return color;
    final (:l, :c, h: _) = CoilColorMix.toOklch(color);
    Color at(double lightness) =>
        CoilColorMix.oklch(lightness, c, hueAt(lightness), alpha: color.a);
    var fails = l;
    var ok = lighter ? 1.0 : 0.0;
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

  /// These colors resolved for high contrast
  /// (`MediaQuery.highContrastOf`): borders at foreground 40% and a
  /// stronger off-state track ([accent] pushed toward the foreground). The
  /// theme's high contrast also strengthens the focus ring.
  ///
  /// [brandFill], [onBrandFill], [brandInk], [brandWash] and [brandMark]
  /// take the
  /// [CoilBrandFill.accessible] values, whatever the theme chose, and
  /// [brandFillPolicy] says so; [brand] itself is kept.
  CoilColors highContrast() {
    final tones = brandTones(brand, brightness, CoilBrandFill.accessible);
    final accents = brandAccents(
      brand,
      surfaces,
      brightness,
      CoilBrandFill.accessible,
    );
    return copyWith(
      accent: CoilColorMix.oklab(accent, foreground, 0.7),
      borderAlpha: 0.4,
      brandFill: tones.fill,
      onBrandFill: tones.label,
      brandInk: accents.ink,
      brandWash: accents.wash,
      brandMark: brandMarkFor(
        brand,
        surfaces,
        brightness,
        CoilBrandFill.accessible,
      ),
      brandFillPolicy: CoilBrandFill.accessible,
    );
  }

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
      other.brandFill == brandFill &&
      other.onBrandFill == onBrandFill &&
      other.brandInk == brandInk &&
      other.brandWash == brandWash &&
      other.brandMark == brandMark &&
      other.overlay == overlay &&
      other.hover == hover &&
      other.active == active &&
      other.tint == tint &&
      other.tintHover == tintHover &&
      other.red == red &&
      other.redLabel == redLabel &&
      other.shadowColor == shadowColor &&
      other.scrim == scrim &&
      other.borderAlpha == borderAlpha &&
      other.brandFillPolicy == brandFillPolicy;

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
    brandFill,
    onBrandFill,
    brandInk,
    brandWash,
    brandMark,
    overlay,
    hover,
    active,
    tint,
    tintHover,
    red,
    redLabel,
    shadowColor,
    scrim,
    borderAlpha,
    brandFillPolicy,
  ]);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(EnumProperty('brightness', brightness))
      ..add(ColorProperty('foreground', foreground))
      ..add(ColorProperty('background', background))
      ..add(ColorProperty('brand', brand))
      ..add(ColorProperty('brandFill', brandFill))
      ..add(ColorProperty('onBrandFill', onBrandFill))
      ..add(ColorProperty('brandInk', brandInk))
      ..add(ColorProperty('brandWash', brandWash))
      ..add(ColorProperty('brandMark', brandMark))
      ..add(
        EnumProperty(
          'brandFillPolicy',
          brandFillPolicy,
          defaultValue: CoilBrandFill.accessible,
        ),
      );
  }
}
