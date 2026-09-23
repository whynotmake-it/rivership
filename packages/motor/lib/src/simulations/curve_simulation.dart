import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'package:motor/src/simulations/finite_simulation.dart';

@internal
class CurveSimulation extends Simulation implements FiniteSimulation {
  CurveSimulation({
    required this.duration,
    required this.curve,
    required this.start,
    required this.end,
    required super.tolerance,
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
  double progressAt(double time) {
    final relativeTime = time / duration.toSeconds();
    if (relativeTime > 1) return double.infinity;
    return curve.transform(relativeTime.clamp(0, 1));
  }

  /// The value at [progress] from [progressAt].
  double valueAt(double progress) =>
      progress == double.infinity ? end : start + (end - start) * progress;

  /// Whether [other] follows the same curve over the same duration.
  bool sharesTiming(CurveSimulation other) =>
      identical(curve, other.curve) && duration == other.duration;

  @override
  double dx(double time) {
    // Calculate the approximate derivative using a small delta
    final delta = tolerance.distance;
    final x1 = x(time - delta);
    final x2 = x(time + delta);

    // Return the rate of change (velocity)
    return (x2 - x1) / delta * 2;
  }

  @override
  bool isDone(double time) => time > duration.toSeconds();

  @override
  double get finishSeconds => justAfter(duration.toSeconds());
}

extension on Duration {
  double toSeconds() => inMicroseconds / Duration.microsecondsPerSecond;
}
