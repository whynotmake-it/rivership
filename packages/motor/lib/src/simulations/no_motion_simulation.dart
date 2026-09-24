import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'package:motor/src/simulations/finite_simulation.dart';

@internal
class NoMotionSimulation extends Simulation implements FiniteSimulation {
  NoMotionSimulation({
    required this.duration,
    required this.value,
    required super.tolerance,
  });

  /// The duration of the curve.
  final Duration duration;

  /// The start value of the curve.
  final double value;

  @override
  double x(double time) {
    return value;
  }

  @override
  double dx(double time) {
    return 0;
  }

  @override
  bool isDone(double time) => time > duration.toSeconds();

  @override
  double get finishSeconds => justAfter(duration.toSeconds());
}

extension on Duration {
  double toSeconds() => inMicroseconds / Duration.microsecondsPerSecond;
}
