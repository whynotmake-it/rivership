import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// A two-dimensional spring simulation.
///
/// Simulates the motion of two connected springs operating independently
/// in the X and Y dimensions.
class SpringSimulation2D extends Simulation {
  /// Creates a simulation from the provided spring description, start
  /// distances, end distances, and initial velocities.
  ///
  /// This simulates two springs with the same [SpringDescription] but under
  /// different conditions. This can be used to simulate two-dimensional
  /// movement.
  ///
  /// The simulation outputs two different values [x] and [y] which each
  /// correspond to their own spring simulation.
  ///
  /// When running [SpringSimulation2D] with [AnimationController] the
  /// controller only takes the value for [x] into account. To retrieve
  /// the [y] value, use `simulation.y(simulation.deltaTime)`.
  SpringSimulation2D({
    required (double x, double y) start,
    required (double x, double y) end,
    required Offset velocity,
    required SpringDescription spring,
    super.tolerance,
  })  : _endPosition = end,
        _simulationX = SpringSimulation(
          spring,
          start.$1,
          end.$1,
          velocity.dx,
          tolerance: tolerance,
        ),
        _simulationY = SpringSimulation(
          spring,
          start.$2,
          end.$2,
          velocity.dy,
          tolerance: tolerance,
        );

  final SpringSimulation _simulationX;
  final SpringSimulation _simulationY;

  final (double, double) _endPosition;

  double _deltaTime = 0;

  /// The current time of this simulation.
  double get deltaTime => _deltaTime;

  /// Returns the position of the spring simulation in the X dimension
  /// at the given [time].
  ///
  /// Also updates the [deltaTime].
  @override
  double x(double time) {
    _deltaTime = time;
    return _simulationX.x(time);
  }

  /// Returns the velocity of the spring simulation in the X dimension
  /// at the given [time].
  @override
  double dx(double time) {
    return _simulationX.dx(time);
  }

  /// Returns the position of the spring simulation in the Y dimension
  /// at the given [time].
  double y(double time) {
    return _simulationY.x(time);
  }

  /// Returns the velocity of the spring simulation in the Y dimension
  /// at the given [time].
  double dy(double time) {
    return _simulationY.dx(time);
  }

  @override
  bool isDone(double time) {
    return nearZero(
          _simulationX.x(time) - _endPosition.$1,
          tolerance.distance,
        ) &&
        nearZero(_simulationX.dx(time), tolerance.velocity) &&
        nearZero(
          _simulationY.x(time) - _endPosition.$2,
          tolerance.distance,
        ) &&
        nearZero(_simulationY.dx(time), tolerance.velocity);
  }
}
