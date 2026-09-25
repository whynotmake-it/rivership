import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:meta/meta.dart';

/// When a [SpringSimulation] from [start] to [end] with [velocity] is done
/// for good, in seconds, or null if that can't be computed.
///
/// "Done" is [SpringSimulation.isDone]: position and velocity within
/// [tolerance]. An underdamped spring can report done near a peak and then
/// not done again; this returns the time from which it stays done. It
/// returns 0 when the spring is done at the start.
///
/// The spring's position and velocity have closed forms. For an underdamped
/// spring their peaks shrink geometrically, so the last peak above the
/// tolerance follows directly, and a safeguarded Newton step finds where the
/// value falls below it before the next zero. A critically damped or
/// overdamped spring has at most one extremum, after which one root is
/// enough.
@internal
double? springSettleSeconds(
  SpringDescription spring, {
  required double start,
  required double end,
  required double velocity,
  required Tolerance tolerance,
}) {
  final m = spring.mass;
  final k = spring.stiffness;
  final c = spring.damping;
  if (!(m > 0 && k > 0 && c > 0)) return null;
  final distance = start - end;

  final _Form x;
  final _Form v;
  final discriminant = c * c - 4 * m * k;
  // Near critical damping the overdamped form cancels badly.
  if (discriminant.abs() <= 1e-9 * c * c) {
    final r = -c / (2 * m);
    final c1 = distance;
    final c2 = velocity - r * distance;
    x = _Critical(c1, c2, r);
    v = _Critical(r * c1 + c2, r * c2, r);
  } else if (discriminant > 0) {
    final root = math.sqrt(discriminant);
    final r1 = (-c - root) / (2 * m);
    final r2 = (-c + root) / (2 * m);
    final c2 = (velocity - r1 * distance) / (r2 - r1);
    final c1 = distance - c2;
    x = _Overdamped(c1, c2, r1, r2);
    v = _Overdamped(c1 * r1, c2 * r2, r1, r2);
  } else {
    final w = math.sqrt(-discriminant) / (2 * m);
    final r = -c / (2 * m);
    final c1 = distance;
    final c2 = (velocity - r * distance) / w;
    x = _Underdamped(c1, c2, r, w);
    v = _Underdamped(c2 * w + r * c1, r * c2 - c1 * w, r, w);
  }

  // SpringSimulation.isDone, on the same closed forms.
  bool isDone(double t) =>
      x.f(t).abs() < tolerance.distance && v.f(t).abs() < tolerance.velocity;
  if (isDone(0)) return 0;

  final double seconds0;
  if (x is _Underdamped && v is _Underdamped) {
    // |f| stays under its envelope, so the form whose envelope reaches the
    // tolerance later usually decides, and the other needn't be solved.
    final xEnvelope = x.envelopeSeconds(tolerance.distance);
    final vEnvelope = v.envelopeSeconds(tolerance.velocity);
    final (first, firstTol, other, otherTol, otherEnvelope) =
        xEnvelope >= vEnvelope
            ? (x, tolerance.distance, v, tolerance.velocity, vEnvelope)
            : (v, tolerance.velocity, x, tolerance.distance, xEnvelope);
    final decided = first.lastAtLeast(firstTol);
    seconds0 = otherEnvelope <= decided
        ? decided
        : math.max(decided, other.lastAtLeast(otherTol));
  } else {
    seconds0 = math.max(
      x.lastAtLeast(tolerance.distance),
      v.lastAtLeast(tolerance.velocity),
    );
  }
  var seconds = seconds0;
  if (!seconds.isFinite) return null;
  // The root is where the value equals the tolerance, which isDone
  // excludes: step to the first time it reports done.
  for (var i = 0; i < 12 && !isDone(seconds); i++) {
    seconds += 1e-9 * (1 << i) * math.max(1, seconds);
  }
  return isDone(seconds) ? seconds : null;
}

/// One of a spring's closed-form solutions, for position or velocity.
abstract class _Form {
  double f(double t);

  double df(double t);

  /// f(t) and f'(t) together, sharing their exponential.
  (double, double) fdf(double t);

  /// The last time |f| >= [tol], or 0 if never.
  double lastAtLeast(double tol);

  /// Where |f| falls to [tol] in (lo, hi), where |f| is decreasing.
  /// A safeguarded Newton step: it keeps a bracket and bisects when a step
  /// would leave it.
  double root(double lo, double hi, double tol, [double? guess]) {
    var a = lo;
    var b = hi;
    var t = guess != null && guess > lo && guess < hi ? guess : hi;
    for (var i = 0; i < 60; i++) {
      final (ft, dft) = fdf(t);
      final g = ft.abs() - tol;
      // Close enough: the caller steps onto the first time it's done.
      if (g.abs() <= tol * 1e-6) return t;
      if (g >= 0) {
        a = t;
      } else {
        b = t;
      }
      final dg = ft >= 0 ? dft : -dft;
      var next = dg == 0 ? (a + b) / 2 : t - g / dg;
      if (!(next > a && next < b)) next = (a + b) / 2;
      if ((next - t).abs() <= 1e-10) return next;
      if (b - a <= 1e-10) return b;
      t = next;
    }
    return b;
  }

  /// For forms with at most one extremum at [peak], after which |f|
  /// decays with rate [r], and a zero at [zero] before it (or none).
  double monotoneTail(double? peak, double? zero, double r, double tol) {
    final s = peak == null || peak < 0 ? 0.0 : peak;
    final fs = f(s).abs();
    if (fs >= tol) {
      final guess = s + math.log(fs / tol) / -r;
      var hi = guess + 1 / -r;
      while (f(hi).abs() >= tol) {
        hi = s + (hi - s) * 2;
      }
      return root(s, hi, tol, guess);
    }
    if (s > 0 && f(0).abs() >= tol && zero != null && zero > 0 && zero < s) {
      return root(0, zero, tol);
    }
    return 0;
  }
}

/// `e^(rt) * (p cos wt + q sin wt)`.
class _Underdamped extends _Form {
  _Underdamped(this.p, this.q, this.r, this.w);

  final double p;
  final double q;
  final double r;
  final double w;

  @override
  double f(double t) =>
      math.exp(r * t) * (p * math.cos(w * t) + q * math.sin(w * t));

  @override
  double df(double t) => fdf(t).$2;

  @override
  (double, double) fdf(double t) {
    final e = math.exp(r * t);
    final cos = math.cos(w * t);
    final sin = math.sin(w * t);
    return (
      e * (p * cos + q * sin),
      e * ((q * w + r * p) * cos + (r * q - p * w) * sin),
    );
  }

  /// When the envelope of |f| falls to [tol]; |f| stays under it from then
  /// on.
  double envelopeSeconds(double tol) {
    final magnitude = math.sqrt(p * p + q * q);
    if (magnitude <= tol) return 0;
    return math.log(magnitude / tol) / -r;
  }

  @override
  double lastAtLeast(double tol) {
    final magnitude = math.sqrt(p * p + q * q);
    if (magnitude == 0) return 0;
    final a = -r;
    final theta = math.atan2(q, p);
    final psi = math.atan2(w, a);
    final base = theta + psi + math.pi / 2;
    final firstPeak = (-base / math.pi).ceil();
    final halfSwing = (math.pi - psi) / w;
    // The peaks of |f| are at (base + k pi) / w, with magnitudes
    // magnitude * sin(psi) * e^(-a t): find the last one still >= tol.
    final peakMagnitude = magnitude * math.sin(psi);
    if (peakMagnitude >= tol) {
      final latest = math.log(peakMagnitude / tol) / a;
      final last = ((latest * w - base) / math.pi).floor();
      if (last >= firstPeak) {
        final peak = (base + last * math.pi) / w;
        final envelope = math.log(magnitude / tol) / a;
        if (f(peak).abs() >= tol) {
          return root(peak, peak + halfSwing, tol, envelope);
        }
        // Rounding at the boundary peak: use the one before.
        if (last - 1 >= firstPeak) {
          final previous = (base + (last - 1) * math.pi) / w;
          return root(previous, previous + halfSwing, tol);
        }
      }
    }
    if (f(0).abs() >= tol) {
      final before = (base + (firstPeak - 1) * math.pi) / w;
      return root(0, before + halfSwing, tol);
    }
    return 0;
  }
}

/// `(p + q t) e^(rt)`.
class _Critical extends _Form {
  _Critical(this.p, this.q, this.r);

  final double p;
  final double q;
  final double r;

  @override
  double f(double t) => (p + q * t) * math.exp(r * t);

  @override
  double df(double t) => (q + r * p + r * q * t) * math.exp(r * t);

  @override
  (double, double) fdf(double t) {
    final e = math.exp(r * t);
    return ((p + q * t) * e, (q + r * p + r * q * t) * e);
  }

  @override
  double lastAtLeast(double tol) => monotoneTail(
        q == 0 ? null : -(q + r * p) / (r * q),
        q == 0 ? null : -p / q,
        r,
        tol,
      );
}

/// `a e^(r1 t) + b e^(r2 t)`, with r1 < r2 < 0.
class _Overdamped extends _Form {
  _Overdamped(this.a, this.b, this.r1, this.r2);

  final double a;
  final double b;
  final double r1;
  final double r2;

  @override
  double f(double t) => a * math.exp(r1 * t) + b * math.exp(r2 * t);

  @override
  double df(double t) => a * r1 * math.exp(r1 * t) + b * r2 * math.exp(r2 * t);

  @override
  (double, double) fdf(double t) {
    final e1 = math.exp(r1 * t);
    final e2 = math.exp(r2 * t);
    return (a * e1 + b * e2, a * r1 * e1 + b * r2 * e2);
  }

  @override
  double lastAtLeast(double tol) {
    double? at(double ratio) => ratio > 0 ? math.log(ratio) / (r1 - r2) : null;
    return monotoneTail(
      a == 0 ? null : at(-b * r2 / (a * r1)),
      a == 0 ? null : at(-b / a),
      r2,
      tol,
    );
  }
}
