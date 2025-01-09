import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';

/// A base class for a controller that manages a spring simulation.
abstract interface class SpringSimulationControllerBase<T extends Object>
    extends Animation<T> {
  /// The lower bound of the animation value.
  T get lowerBound;

  /// The upper bound of the animation value.
  T get upperBound;

  /// The current velocity of the simulation in [T] per second.
  T get velocity;

  /// Updates the spring description.
  ///
  /// This will create a new simulation with the current velocity if an
  /// animation is in progress.
  SpringDescription get spring;

  /// Updates the spring description.
  ///
  /// This will create a new simulation with the current velocity if an
  /// animation is in progress.
  set spring(SpringDescription value);

  /// The [Tolerance] for the spring simulation.
  Tolerance get tolerance;

  /// Recreates the [Ticker] with the new [TickerProvider].
  void resync(TickerProvider ticker);

  /// Updates the target value and creates a new simulation with the current
  /// velocity.
  TickerFuture animateTo(
    T target, {
    T? from,
    T? withVelocity,
  });

  /// Stops the current simulation.
  void stop();

  /// Frees any resources used by this object.
  @mustCallSuper
  void dispose();
}
