import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:meta/meta.dart';
import 'package:motor/src/simulations/finite_simulation.dart';

/// A spring that moves like Flutter's [SpringSimulation] and settles at a
/// time computed up front, close to when Flutter's `isDone` first holds.
///
/// A spring that oscillates settles once it stays within
/// [Tolerance.distance] of its target; Flutter's `isDone` first holds at a
/// turning point near then. One that does not oscillate also waits for its
/// speed to stay within [Tolerance.velocity], as Flutter's `isDone` does.
///
/// Before that time the value follows the spring exactly. From then on
/// [isDone] is true and, with `snapToEnd`, the value is the target.
@internal
class SettlingSpringSimulation extends Simulation implements FiniteSimulation {
  /// Creates a spring from [start] to [end] with the initial [velocity].
  SettlingSpringSimulation(
    SpringDescription spring,
    double start,
    this.end,
    double velocity, {
    required this.snapToEnd,
    super.tolerance,
  }) : _solution = _Solution(spring, start - end, velocity) {
    final distance = start - end;
    finishSeconds = distance.abs() < tolerance.distance &&
            velocity.abs() < tolerance.velocity
        ? 0
        : _solution.settleSeconds(tolerance);
  }

  /// The target value.
  final double end;

  /// Whether the value is the target once settled.
  final bool snapToEnd;

  final _Solution _solution;

  @override
  late final double? finishSeconds;

  bool _settled(double time) {
    final finish = finishSeconds;
    return finish != null && time >= finish;
  }

  @override
  double x(double time) =>
      snapToEnd && _settled(time) ? end : end + _solution.x(time);

  @override
  double dx(double time) =>
      snapToEnd && _settled(time) ? 0 : _solution.dx(time);

  @override
  bool isDone(double time) => _settled(time);
}

/// The displacement from the target over time. The formulas match Flutter's
/// spring solutions.
sealed class _Solution {
  factory _Solution(
    SpringDescription spring,
    double distance,
    double velocity,
  ) {
    final cmk =
        spring.damping * spring.damping - 4 * spring.mass * spring.stiffness;
    if (cmk > 0) return _Overdamped(spring, cmk, distance, velocity);
    if (cmk < 0) return _Underdamped(spring, distance, velocity);
    return _Critical(spring, distance, velocity);
  }

  double x(double time);
  double dx(double time);

  /// When the spring settles within [tolerance], or null if it never does.
  double? settleSeconds(Tolerance tolerance);
}

class _Critical implements _Solution {
  _Critical(SpringDescription spring, double distance, double velocity)
      : _r = -spring.damping / (2.0 * spring.mass),
        _c1 = distance,
        _c2 = velocity - (-spring.damping / (2.0 * spring.mass) * distance);

  final double _r;
  final double _c1;
  final double _c2;

  @override
  double x(double time) =>
      (_c1 + _c2 * time) * (math.pow(math.e, _r * time) as double);

  @override
  double dx(double time) {
    final power = math.pow(math.e, _r * time) as double;
    return _r * (_c1 + _c2 * time) * power + _c2 * power;
  }

  /// Settles once `(|c1| + |c2| t) e^(r t)`, which bounds the displacement,
  /// and the matching bound on the speed are within tolerance.
  @override
  double? settleSeconds(Tolerance tolerance) {
    if (_r >= 0) return null;
    return math.max(
      _linearTimesDecay(_c1.abs(), _c2.abs(), _r, tolerance.distance),
      _linearTimesDecay(
        (_r * _c1 + _c2).abs(),
        (_r * _c2).abs(),
        _r,
        tolerance.velocity,
      ),
    );
  }
}

class _Overdamped implements _Solution {
  factory _Overdamped(
    SpringDescription spring,
    double cmk,
    double distance,
    double velocity,
  ) {
    final r1 = (-spring.damping - math.sqrt(cmk)) / (2.0 * spring.mass);
    final r2 = (-spring.damping + math.sqrt(cmk)) / (2.0 * spring.mass);
    final c2 = (velocity - r1 * distance) / (r2 - r1);
    final c1 = distance - c2;
    return _Overdamped._(r1, r2, c1, c2);
  }

  _Overdamped._(this._r1, this._r2, this._c1, this._c2);

  final double _r1;
  final double _r2;
  final double _c1;
  final double _c2;

  @override
  double x(double time) =>
      _c1 * math.pow(math.e, _r1 * time) + _c2 * math.pow(math.e, _r2 * time);

  @override
  double dx(double time) =>
      _c1 * _r1 * math.pow(math.e, _r1 * time) +
      _c2 * _r2 * math.pow(math.e, _r2 * time);

  /// Takes the earlier of two bounds on displacement and speed. Summing
  /// both terms is tight when strongly overdamped. Near critical damping the
  /// terms nearly cancel, and rewriting them around `e^(r2 t)` with
  /// `k = |c2 (r2 - r1)|` is tight instead.
  @override
  double? settleSeconds(Tolerance tolerance) {
    if (_r2 >= 0) return null;
    final k = (_c2 * (_r2 - _r1)).abs();
    final distance = (_c1 + _c2).abs();
    final position = math.min(
      _twoDecays(_c1.abs(), _r1, _c2.abs(), _r2, tolerance.distance),
      _linearTimesDecay(distance, k, _r2, tolerance.distance),
    );
    final speed = math.min(
      _twoDecays(
        (_c1 * _r1).abs(),
        _r1,
        (_c2 * _r2).abs(),
        _r2,
        tolerance.velocity,
      ),
      _linearTimesDecay(
        (_r1 * distance).abs() + k,
        (_r2 * k).abs(),
        _r2,
        tolerance.velocity,
      ),
    );
    return math.max(position, speed);
  }
}

class _Underdamped implements _Solution {
  factory _Underdamped(
    SpringDescription spring,
    double distance,
    double velocity,
  ) {
    final w = math.sqrt(
          4.0 * spring.mass * spring.stiffness -
              spring.damping * spring.damping,
        ) /
        (2.0 * spring.mass);
    final r = -(spring.damping / 2.0 / spring.mass);
    return _Underdamped._(w, r, distance, (velocity - r * distance) / w);
  }

  _Underdamped._(this._w, this._r, this._c1, this._c2);

  final double _w;
  final double _r;
  final double _c1;
  final double _c2;

  @override
  double x(double time) =>
      (math.pow(math.e, _r * time) as double) *
      (_c1 * math.cos(_w * time) + _c2 * math.sin(_w * time));

  @override
  double dx(double time) {
    final power = math.pow(math.e, _r * time) as double;
    final cosine = math.cos(_w * time);
    final sine = math.sin(_w * time);
    return power * (_c2 * _w * cosine - _c1 * _w * sine) +
        _r * power * (_c2 * sine + _c1 * cosine);
  }

  /// Bounds the displacement by its envelope `sqrt(c1² + c2²) e^(r t)`.
  @override
  double? settleSeconds(Tolerance tolerance) {
    final amplitude = math.sqrt(_c1 * _c1 + _c2 * _c2);
    if (amplitude <= tolerance.distance) return 0;
    if (_r >= 0) return null;
    return math.log(amplitude / tolerance.distance) / -_r;
  }
}

/// When `(a + b t) e^(r t)` falls to [limit] for good, for `a, b >= 0` and
/// `r < 0`. Newton's method on the logarithm, which is concave, approaches
/// the crossing from above, so the result never falls short of it.
double _linearTimesDecay(double a, double b, double r, double limit) {
  if (b == 0) return a <= limit ? 0 : math.log(a / limit) / -r;
  final peak = math.max(0.0, -1 / r - a / b);
  double g(double t) => math.log(a + b * t) + r * t - math.log(limit);
  if (g(peak) <= 0) return 0;
  var step = -1 / r;
  var t = peak + step;
  while (g(t) > 0) {
    step *= 2;
    t = peak + step;
  }
  for (var i = 0; i < 50; i++) {
    final next = t - g(t) / (b / (a + b * t) + r);
    if ((t - next).abs() < 1e-12) break;
    t = next;
  }
  return t;
}

/// When `p e^(alpha t) + q e^(beta t)` falls to [limit], for `p, q >= 0` and
/// `alpha <= beta < 0`. Newton's method on the logarithm, which is convex,
/// approaches the crossing from below; the last step is rounded up by a
/// nanosecond so the result does not fall short of it.
double _twoDecays(double p, double alpha, double q, double beta, double limit) {
  double h(double t) =>
      math.log(p * math.exp(alpha * t) + q * math.exp(beta * t)) -
      math.log(limit);
  if (h(0) <= 0) return 0;
  var t = q > limit ? math.log(q / limit) / -beta : 0.0;
  for (var i = 0; i < 50; i++) {
    final pa = p * math.exp(alpha * t);
    final qb = q * math.exp(beta * t);
    final next = t - h(t) * (pa + qb) / (pa * alpha + qb * beta);
    if ((next - t).abs() < 1e-12) break;
    t = next;
  }
  return t + 1e-9;
}
