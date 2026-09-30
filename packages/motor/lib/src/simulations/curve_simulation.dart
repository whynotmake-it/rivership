import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'package:motor/src/settling_simulation.dart';

@internal
class CurveSimulation extends Simulation with SettlingSimulation {
  CurveSimulation({
    required this.duration,
    required this.curve,
    required this.start,
    required this.end,
    required super.tolerance,
  }) : _seconds = duration.inMicroseconds / Duration.microsecondsPerSecond;

  /// The duration of the curve, which is also when it has settled.
  final Duration duration;

  @override
  Duration get settlesAt => duration;

  final double _seconds;

  /// The curve to use for the simulation.
  final Curve curve;

  /// The start value of the curve.
  final double start;

  /// The end value of the curve.
  final double end;

  @override
  double x(double time) => valueAt(progressAt(time));

  /// How far along the curve [time] is, or infinity once past the end.
  ///
  /// Simulations that [sharesTiming] can share one progress per time.
  double progressAt(double time) {
    final relativeTime = time / _seconds;
    if (relativeTime > 1) return double.infinity;
    return curve.transform(relativeTime.clamp(0, 1));
  }

  /// The value at [progress] from [progressAt].
  double valueAt(double progress) =>
      progress == double.infinity ? end : start + (end - start) * progress;

  /// Whether [other] follows the same curve over the same duration.
  bool sharesTiming(CurveSimulation other) =>
      identical(curve, other.curve) && duration == other.duration;

  /// Gaps shorter than this (one microsecond) count as no time at all, as
  /// in playback.
  static const _instant = 1e-6;

  @override
  double dx(double time) {
    // A step that starts the moment the curve ends takes over the slope it
    // ended with; once time has passed at rest after that, it is 0.
    if (time - _seconds > _instant) return 0;
    // A central difference over tolerance.time, like Flutter's
    // AnimationController does for its curves, but kept within the curve.
    final at = time.clamp(0.0, _seconds);
    final low = math.max(0.0, at - tolerance.time);
    final high = math.min(_seconds, at + tolerance.time);
    if (high <= low) return 0;
    return (_valueWithin(high) - _valueWithin(low)) / (high - low);
  }

  /// The value at [time] within the curve, including exactly at its end.
  double _valueWithin(double time) =>
      start + (end - start) * curve.transform(time / _seconds);

  @override
  bool isDone(double time) => time > _seconds;
}
