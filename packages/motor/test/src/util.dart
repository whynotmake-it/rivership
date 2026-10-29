import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

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

/// When a move settles, read the way playback reads it.
extension MotionSettlingForTests on Motion {
  /// When a move from [start] to [end] with [velocity] settles.
  Duration? settlingDuration({
    double start = 0,
    double end = 1,
    double velocity = 0,
  }) =>
      createSimulation(start: start, end: end, velocity: velocity)
          .estimateSettle();
}

/// When a move settles, read the way playback reads it.
extension FreeMotionSettlingForTests on FreeMotion {
  /// When a move from [start] with [velocity] comes to rest.
  Duration? settlingDuration({double start = 0, double velocity = 0}) =>
      createSimulation(start: start, velocity: velocity).estimateSettle();
}
