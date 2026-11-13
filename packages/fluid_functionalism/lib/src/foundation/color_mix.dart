import 'dart:math' as math;
import 'dart:ui';

/// Color mixing that matches CSS `color-mix(in oklab, ...)`.
///
/// The web source mixes most of its state colors in Oklab (for example the
/// primary button's hover fill is `color-mix(in oklab, foreground 90%,
/// background)`). Mixing in sRGB gives visibly different greys, so the port
/// mixes in Oklab too.
abstract final class FluidColorMix {
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

  static Color _fromOklab(double lightness, double a, double b, double alpha) {
    final l = math.pow(lightness + 0.3963377774 * a + 0.2158037573 * b, 3);
    final m = math.pow(lightness - 0.1055613458 * a - 0.0638541728 * b, 3);
    final s = math.pow(lightness - 0.0894841775 * a - 1.2914855480 * b, 3);
    final r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s;
    final g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s;
    final bl = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s;
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
