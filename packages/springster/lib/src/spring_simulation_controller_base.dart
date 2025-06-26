import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';

/// A base class for a controller that manages a spring simulation.
abstract interface class SpringSimulationControllerBase<T extends Object>
    extends Animation<T> {
  @override
  T get value;

  set value(T value);

  /// The lower bound of the animation value.
  ///
  /// {@template springster.spring_simulation.bounds_overshoot_warning}
  /// **Note:** since springs can, and often will, overshoot, [value] is not
  /// guaranteed to be within [lowerBound] and [upperBound]. Make sure to clamp
  /// [value] upon consumption if necessary.
  /// {@endtemplate}
  T get lowerBound;

  /// The upper bound of the animation value.
  ///
  /// {@macro springster.spring_simulation.bounds_overshoot_warning}
  T get upperBound;

  /// Whether the controller is bounded, meaning neither [lowerBound] nor
  /// [upperBound] are infinite.
  bool get isBounded;

  /// The current velocity of the simulation in [T] per second.
  T get velocity;

  /// The current status of this [Animation].
  ///
  /// Spring simulations don't really have a concept of directionality,
  /// especially in higher dimensions.
  /// Thus, this will never return [AnimationStatus.reverse].
  ///
  /// Nonetheless, the naming of [forward] and [reverse] was chosen to maintain
  /// consistency with [AnimationController].
  @override
  AnimationStatus get status;

  /// Whether this animation is currently animating in either the forward or
  /// reverse direction.
  ///
  /// If the animation was stopped (e.g. with [stop] or by setting a new
  /// [value]),
  /// [isAnimating] will return `false` but the [status] will not change,
  /// so the value of [AnimationStatus.isAnimating] might still be `true`.
  @override
  bool get isAnimating;

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

  /// The behavior of the animation.
  ///
  /// Defaults to [AnimationBehavior.normal] for bounded, and
  /// [AnimationBehavior.preserve] for unbounded controllers.
  AnimationBehavior get animationBehavior;

  /// Recreates the [Ticker] with the new [TickerProvider].
  void resync(TickerProvider ticker);

  /// Animates towards [upperBound].
  ///
  /// Only valid if [isBounded] is true, otherwise an [AssertionError] will be
  /// thrown, since unbounded controllers do not have a direction.
  TickerFuture forward({
    T? from,
    T? withVelocity,
  });

  /// Animates towards [lowerBound].
  ///
  /// Only valid if [isBounded] is true, otherwise an [AssertionError] will be
  /// thrown, since unbounded controllers do not have a direction.
  ///
  /// **Note**: [status] will still return [AnimationStatus.forward] when
  /// this is called. See [status] for more information.
  TickerFuture reverse({
    T? from,
    T? withVelocity,
  });

  /// Animates towards [target], while ensuring that any current velocity is
  /// maintained.
  ///
  /// If this controller [isBounded], the [target] will be clamped to be within
  /// [lowerBound] and [upperBound].
  ///
  /// If [from] is provided, the animation will start from there instead of from
  /// the current [value].
  ///
  /// If [withVelocity] is provided, the animation will start with that velocity
  /// instead of [velocity].
  TickerFuture animateTo(
    T target, {
    T? from,
    T? withVelocity,
  });

  /// Stops the current simulation, and depending on the value of [canceled],
  /// either settles the simulation at the current value, or interrupts the
  /// simulation immediately
  ///
  /// Unlike [AnimationController.stop], [canceled] defaults to false.
  /// If you set it to true, the simulation will be stopped immediately.
  /// Otherwise, the simulation will redirect to settle at the current value,
  /// to retain the physical characteristic of the simulation.
  TickerFuture stop({bool canceled = false});

  /// Frees any resources used by this object.
  void dispose();

  /// Asserts that the controller is bounded.
  ///
  /// If the controller is not bounded, it will stop the simulation and return
  /// false.
  @protected
  static bool assertBounded(
    SpringSimulationControllerBase c, {
    required bool forward,
  }) {
    if (!c.isBounded) {
      assert(
        false,
        'Cannot ${forward ? 'forward' : 'reverse'} an unbounded '
        '${objectRuntimeType(c, 'SpringSimulationController')}',
      );

      c.stop(canceled: true);
      return false;
    }

    return true;
  }
}
