import 'dart:math' as math;
import 'dart:ui';

/// Color mixing in Oklab, the way CSS `color-mix(in oklab, ...)` does.
///
/// coil derives state colors by mixing in Oklab (a hovered primary button is
/// 90 % foreground into the background). Mixing in sRGB gives muddier greys.
abstract final class CoilColorMix {
  /// Mixes [a] and [b] in Oklab, taking [amountOfA] (0..1) of [a].
  ///
  /// Equivalent to `color-mix(in oklab, a amountOfA%, b)`. Alpha is mixed
  /// premultiplied, as CSS does.
  static Color oklab(Color a, Color b, double amountOfA) {
    final t = 1 - amountOfA.clamp(0.0, 1.0);
    final alpha = a.a + (b.a - a.a) * t;
    if (alpha == 0) return const Color(0x00000000);
    final la = _toOklab(a);
    final lb = _toOklab(b);
    // Premultiply each component by its alpha, as CSS color-mix does.
    final l = (la[0] * a.a + (lb[0] * b.a - la[0] * a.a) * t) / alpha;
    final m = (la[1] * a.a + (lb[1] * b.a - la[1] * a.a) * t) / alpha;
    final s = (la[2] * a.a + (lb[2] * b.a - la[2] * a.a) * t) / alpha;
    return _fromOklab(l, m, s, alpha);
  }

  /// `color-mix(in oklab, color amount%, transparent)`: the same color at
  /// [amount] alpha.
  static Color withTransparent(Color color, double amount) =>
      color.withValues(alpha: color.a * amount);

  /// The WCAG contrast ratio between [a] and [b] (1..21), ignoring alpha.
  static double contrastRatio(Color a, Color b) {
    double lum(Color c) =>
        0.2126 * _toLinear(c.r) +
        0.7152 * _toLinear(c.g) +
        0.0722 * _toLinear(c.b);
    final la = lum(a);
    final lb = lum(b);
    final hi = la > lb ? la : lb;
    final lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  /// [color], mixed toward black or white (whichever [against] is further
  /// from) in small Oklab steps until it reaches [minRatio] contrast with
  /// [against]. Keeps the hue; returns [color] if it already passes.
  static Color ensureContrast(Color color, Color against, double minRatio) {
    if (contrastRatio(color, against) >= minRatio) return color;
    final towardBlack =
        contrastRatio(const Color(0xFF000000), against) >
        contrastRatio(const Color(0xFFFFFFFF), against);
    final target = towardBlack
        ? const Color(0xFF000000)
        : const Color(0xFFFFFFFF);
    for (var keep = 0.98; keep > 0; keep -= 0.02) {
      final mixed = oklab(color, target, keep);
      if (contrastRatio(mixed, against) >= minRatio) return mixed;
    }
    return target;
  }

  /// Lightens or darkens [color] in Oklch, keeping its hue and chroma,
  /// until it reaches [minRatio] contrast with [against]. Moves away from
  /// [against] (darker on a light background). Returns [color] if it already
  /// passes.
  ///
  /// Unlike [ensureContrast], which mixes toward black or white, this
  /// changes lightness only, so a status color stays as saturated as
  /// before.
  static Color ensureContrastByLightness(
    Color color,
    Color against,
    double minRatio,
  ) {
    bool passes(Color c) => contrastRatio(c, against) >= minRatio;
    if (passes(color)) return color;
    final (:l, :c, :h) = toOklch(color);
    // Away from [against]: darker on a light background.
    final extreme = toOklch(against).l > 0.5 ? 0.0 : 1.0;
    Color at(double lightness) => oklch(lightness, c, h, alpha: color.a);
    if (!passes(at(extreme))) return at(extreme);
    // The smallest lightness change that passes.
    var fails = l;
    var ok = extreme;
    for (var i = 0; i < 32; i++) {
      final mid = (fails + ok) / 2;
      if (passes(at(mid))) {
        ok = mid;
      } else {
        fails = mid;
      }
    }
    return at(ok);
  }

  /// [color] in Oklch: lightness (0..1), chroma (0 for greys, about 0.37 at
  /// most in sRGB) and hue in degrees (0..360). Ignores alpha.
  static ({double l, double c, double h}) toOklch(Color color) {
    final [l, a, b] = _toOklab(color);
    final hue = math.atan2(b, a) * 180 / math.pi;
    return (l: l, c: math.sqrt(a * a + b * b), h: hue < 0 ? hue + 360 : hue);
  }

  /// The sRGB color at Oklch [lightness], [chroma] and [hue] (degrees).
  ///
  /// Colors outside sRGB are mapped into it by lowering the chroma at the
  /// same lightness and hue, as CSS Color 4 gamut mapping does, so a strong
  /// tint on a very light or very dark grey stays the same lightness.
  static Color oklch(
    double lightness,
    double chroma,
    double hue, {
    double alpha = 1,
  }) {
    final l = lightness.clamp(0.0, 1.0);
    final radians = hue * math.pi / 180;
    final cosH = math.cos(radians);
    final sinH = math.sin(radians);
    var c = math.max(0, chroma).toDouble();
    if (!_inGamut(l, c * cosH, c * sinH)) {
      // Binary search for the largest chroma that fits.
      var lo = 0.0;
      var hi = c;
      for (var i = 0; i < 24; i++) {
        final mid = (lo + hi) / 2;
        if (_inGamut(l, mid * cosH, mid * sinH)) {
          lo = mid;
        } else {
          hi = mid;
        }
      }
      c = lo;
    }
    return _fromOklab(l, c * cosH, c * sinH, alpha);
  }

  static bool _inGamut(double lightness, double a, double b) {
    const epsilon = 1e-6;
    final [r, g, bl] = _linearRgb(lightness, a, b);
    return [r, g, bl].every((x) => x >= -epsilon && x <= 1 + epsilon);
  }

  static double _toLinear(double c) =>
      c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

  static double _toGamma(double c) => c <= 0.0031308
      ? 12.92 * c
      : 1.055 * math.pow(c, 1 / 2.4).toDouble() - 0.055;

  static List<double> _toOklab(Color c) {
    final r = _toLinear(c.r);
    final g = _toLinear(c.g);
    final b = _toLinear(c.b);
    final l = _cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
    final m = _cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
    final s = _cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
    return [
      0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
      1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
      0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
    ];
  }

  /// Oklab to linear sRGB, unclamped.
  static List<double> _linearRgb(double lightness, double a, double b) {
    double cube(double x) => x * x * x;
    final l = cube(lightness + 0.3963377774 * a + 0.2158037573 * b);
    final m = cube(lightness - 0.1055613458 * a - 0.0638541728 * b);
    final s = cube(lightness - 0.0894841775 * a - 1.2914855480 * b);
    return [
      4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
      -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
      -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s,
    ];
  }

  static Color _fromOklab(double lightness, double a, double b, double alpha) {
    final [r, g, bl] = _linearRgb(lightness, a, b);
    return Color.from(
      alpha: alpha,
      red: _toGamma(r).clamp(0.0, 1.0),
      green: _toGamma(g).clamp(0.0, 1.0),
      blue: _toGamma(bl).clamp(0.0, 1.0),
    );
  }

  static double _cbrt(double x) =>
      x < 0 ? -math.pow(-x, 1 / 3).toDouble() : math.pow(x, 1 / 3).toDouble();
}
