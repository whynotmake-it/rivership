import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

@internal
class NoMotionSimulation extends Simulation {
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
}

extension on Duration {
  double toSeconds() => inMicroseconds / Duration.microsecondsPerSecond;
}
