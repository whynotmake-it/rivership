import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

@internal
class CurveSimulation extends Simulation {
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
  double x(double time) {
    final relativeTime = time / duration.toSeconds();

    if (relativeTime > 1) {
      return end;
    }

    final t = curve.transform(relativeTime.clamp(0, 1));

    return start + (end - start) * t;
  }

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
}

extension on Duration {
  double toSeconds() => inMicroseconds / Duration.microsecondsPerSecond;
}
