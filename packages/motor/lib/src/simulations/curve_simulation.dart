import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'package:motor/src/motion.dart';
import 'package:motor/src/simulations/finite_simulation.dart';

/// A simulation that follows [curve] from [start] to [end] over [duration],
/// as [CurvedMotion] does.
///
/// Return it from a custom [Motion] whose movement is a curve, and it plays
/// as fast as [CurvedMotion]: motor evaluates the curve once per frame for
/// all dimensions of a value that share the same [curve] instance and
/// [duration], and knows when it ends without searching. For a custom
/// [Curve] alone, `Motion.curved` is enough.
///
/// ```dart
/// class ByDistanceMotion extends Motion {
///   const ByDistanceMotion();
///
///   @override
///   bool get needsSettle => false;
///
///   @override
///   Simulation createSimulation({
///     double start = 0,
///     double end = 1,
///     double velocity = 0,
///   }) =>
///       CurveSimulation(
///         duration: Duration(milliseconds: 200 + (end - start).abs().round()),
///         curve: Curves.easeOut,
///         start: start,
///         end: end,
///         tolerance: tolerance,
///       );
///
///   @override
///   bool operator ==(Object other) => other is ByDistanceMotion;
///
///   @override
///   int get hashCode => (ByDistanceMotion).hashCode;
/// }
///
/// final position = Track<double>(.single, motion: const ByDistanceMotion());
/// ```
///
/// It is `final` because motor reads it through its curve rather than [x],
/// so an override of [x] would be ignored.
final class CurveSimulation extends Simulation implements FiniteSimulation {
  /// Creates a simulation that follows [curve] from [start] to [end] over
  /// [duration].
  CurveSimulation({
    required this.duration,
    required this.curve,
    required this.start,
    required this.end,
    super.tolerance,
  });

  /// The duration of the curve.
  final Duration duration;

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
  @internal
  double progressAt(double time) {
    final relativeTime = time / duration.toSeconds();
    if (relativeTime > 1) return double.infinity;
    return curve.transform(relativeTime.clamp(0, 1));
  }

  /// The value at [progress] from [progressAt].
  @internal
  double valueAt(double progress) =>
      progress == double.infinity ? end : start + (end - start) * progress;

  /// Whether [other] follows the same curve over the same duration.
  @internal
  bool sharesTiming(CurveSimulation other) =>
      identical(curve, other.curve) && duration == other.duration;

  @override
  double dx(double time) {
    // A central difference over tolerance.time, like Flutter's
    // AnimationController does for its curves, but kept within the curve:
    // at and after its end this is the slope it ended with, which is what a
    // following step inherits.
    final seconds = duration.toSeconds();
    final at = time.clamp(0.0, seconds);
    final low = math.max(0.0, at - tolerance.time);
    final high = math.min(seconds, at + tolerance.time);
    if (high <= low) return 0;
    return (_valueWithin(high) - _valueWithin(low)) / (high - low);
  }

  /// The value at [time] within the curve, including exactly at its end.
  double _valueWithin(double time) =>
      start + (end - start) * curve.transform(time / duration.toSeconds());

  @override
  bool isDone(double time) => time > duration.toSeconds();

  @override
  @internal
  double get finishSeconds => justAfter(duration.toSeconds());
}

extension on Duration {
  double toSeconds() => inMicroseconds / Duration.microsecondsPerSecond;
}
