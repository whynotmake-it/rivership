import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'package:motor/src/settling_simulation.dart';

@internal
class NoMotionSimulation extends Simulation with SettlingSimulation {
  NoMotionSimulation({
    required this.duration,
    required this.value,
    required super.tolerance,
  });

  /// How long the value is held, which is also when it has settled.
  final Duration duration;

  @override
  Duration get settlesAt => duration;

  /// The value that is held.
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
