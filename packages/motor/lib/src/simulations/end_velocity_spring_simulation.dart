import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:meta/meta.dart';

/// A spring simulation that arrives at the target with a specified end
/// velocity.
///
/// This simulation behaves like a regular spring but is designed to reach the
/// target position with a specific velocity rather than settling at zero
/// velocity. This is useful for creating smooth transitions between animations
/// or for creating motion that continues with momentum.
@internal
class EndVelocitySpringSimulation extends Simulation {
  /// Creates an end velocity spring simulation.
  ///
  /// The [spring] parameter defines the spring characteristics.
  /// The [start] parameter is the initial position.
  /// The [end] parameter is the target position.
  /// The [velocity] parameter is the initial velocity.
  /// The [endVelocity] parameter is the desired velocity at the target.
  EndVelocitySpringSimulation(
    this.spring,
    this.start,
    this.end,
    this.velocity,
    this.endVelocity, {
    required super.tolerance,
  }) {
    // Create a regular spring simulation to the target
    _springSimulation = SpringSimulation(
      spring,
      start,
      end,
      velocity,
      tolerance: tolerance,
    );
    
    // Find the time when the spring would naturally reach the target
    _findTargetTime();
  }

  /// The spring description that defines the spring characteristics.
  final SpringDescription spring;

  /// The initial position of the simulation.
  final double start;

  /// The target position of the simulation.
  final double end;

  /// The initial velocity of the simulation.
  final double velocity;

  /// The desired velocity when reaching the target position.
  final double endVelocity;

  late SpringSimulation _springSimulation;
  late double _targetTime;


  void _findTargetTime() {
    // Find when the spring simulation gets close to the target
    _targetTime = 0;
    const timeStep = 0.001;
    const maxTime = 20.0;
    
    while (_targetTime < maxTime) {
      final position = _springSimulation.x(_targetTime);
      if ((position - end).abs() <= tolerance.distance) {
        break;
      }
      _targetTime += timeStep;
    }
    
    // Get the natural velocity at that time (for potential future use)
    // _naturalEndVelocity = _springSimulation.dx(_targetTime);
  }

  @override
  double x(double time) {
    if (time <= _targetTime) {
      return _springSimulation.x(time);
    } else {
      // After target time, move with constant end velocity
      final timeAfterTarget = time - _targetTime;
      return end + endVelocity * timeAfterTarget;
    }
  }

  @override
  double dx(double time) {
    if (time <= _targetTime) {
      // Blend the spring velocity towards the desired end velocity
      final springVelocity = _springSimulation.dx(time);
      final progress = time / _targetTime;
      final blendFactor = math.pow(progress, 2.0).toDouble();
      
      return springVelocity * (1 - blendFactor) + endVelocity * blendFactor;
    } else {
      // After target time, maintain constant end velocity
      return endVelocity;
    }
  }

  @override
  bool isDone(double time) {
    // The simulation is done when we've reached the target and have the
    // correct velocity
    if (time < _targetTime) {
      return false;
    }
    
    final position = x(time);
    final currentVelocity = dx(time);
    
    final positionClose = (position - end).abs() <= tolerance.distance;
    final velocityClose =
        (currentVelocity - endVelocity).abs() <= tolerance.velocity;

    return positionClose && velocityClose;
  }
}
