import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
// ignore: implementation_imports
import 'package:motor/src/simulations/simulation_end.dart';

const error = 1e-4;

Matcher equalsSpring(SpringDescription other, {double epsilon = error}) =>
    allOf([
      isA<SpringDescription>(),
      predicate<SpringDescription>(
        (spring) => (spring.mass - other.mass).abs() < epsilon,
        'mass equals ${other.mass}',
      ),
      predicate<SpringDescription>(
        (spring) => (spring.stiffness - other.stiffness).abs() < epsilon,
        'stiffness equals ${other.stiffness}',
      ),
      predicate<SpringDescription>(
        (spring) => (spring.damping - other.damping).abs() < epsilon,
        'damping equals ${other.damping}',
      ),
    ]);

/// Timing read the way playback reads it: from the move's simulation.
extension MotionTimingForTests on Motion {
  /// The step length of a move from 0 to 1 at rest, or null if it has none.
  Duration? get duration => switch (createSimulation()) {
        TimedSimulation(:final duration) => duration,
        _ => null,
      };

  /// When a move from [start] to [end] with [velocity] settles.
  Duration? settlingDuration({
    double start = 0,
    double end = 1,
    double velocity = 0,
  }) =>
      switch (createSimulation(start: start, end: end, velocity: velocity)) {
        TimedSimulation(:final settlesAt) => settlesAt,
        final simulation =>
          settlingDurationOf(searchSettlingSeconds(simulation)),
      };
}

/// Timing read the way playback reads it: from the move's simulation.
extension FreeMotionTimingForTests on FreeMotion {
  /// When a move from [start] with [velocity] comes to rest.
  Duration? settlingDuration({double start = 0, double velocity = 0}) =>
      switch (createSimulation(start: start, velocity: velocity)) {
        TimedSimulation(:final settlesAt) => settlesAt,
        final simulation =>
          settlingDurationOf(searchSettlingSeconds(simulation)),
      };
}
