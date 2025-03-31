import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';
import 'package:springster/src/simulations/curve_simulation.dart';

/// {@template Motion}
/// A motion pattern such as spring physics or duration-based curves.
///
/// [Motion] provides a foundation for creating various types of animation
/// behaviors. Concrete implementations of this class define specific motion
/// patterns like spring physics or duration-based curves.
/// {@endtemplate}
@immutable
abstract class Motion {
  /// {@macro Motion}
  const Motion({
    this.tolerance = Tolerance.defaultTolerance,
  });

  /// Creates a motion with a fixed duration that uses moves linearly.
  ///
  /// See also:
  ///   * [DurationAndCurve]
  const factory Motion.duration(Duration duration) = DurationAndCurve._;

  /// Creates a motion with a fixed duration that uses a [Curve].
  ///
  /// See also:
  ///   * [DurationAndCurve]
  const factory Motion.durationAndCurve({
    required Duration duration,
    Curve curve,
  }) = DurationAndCurve;

  /// Creates a motion with spring physics.
  ///
  /// See also:
  ///   * [SpringMotion]
  const factory Motion.spring(SpringDescription spring) = SpringMotion;

  /// The tolerance for this motion.
  ///
  /// Default is [Tolerance.defaultTolerance].
  final Tolerance tolerance;

  /// Whether this motion needs to settle.
  ///
  /// If this is true, the motion will continue to animate until the velocity
  /// is less than the [tolerance], whenever it is supposed to be stopped.
  bool get needsSettle;

  /// Whether this motion will settle without bounds.
  ///
  /// If this is false, this motion will never terminate without bounds.
  bool get unboundedWillSettle;

  /// Creates a simulation for this motion.
  ///
  /// This method creates a [Simulation] object that defines how the animation
  /// will progress over time based on the motion's characteristics.
  ///
  /// Parameters:
  ///   * [start] - The starting value for the simulation, defaults to 0.
  ///   * [end] - The ending value for the simulation, defaults to 1.
  ///   * [velocity] - The initial velocity for the simulation, defaults to 0.
  ///
  /// Returns a [Simulation] that can be used by an [AnimationController].
  Simulation createSimulation({
    double start = 0,
    double end = 1,
    double velocity = 0,
  });

  @override
  bool operator ==(Object other);

  @override
  int get hashCode;
}

/// A motion based on a fixed duration and curve.
///
/// [DurationAndCurve] implements a motion that follows a specific [Curve] over
/// a fixed [Duration]. This is the most common type of animation in Flutter,
/// similar to what is used with [AnimationController.animateTo].
///
/// This motion always completes in the specified duration and does not need to
/// settle.
@immutable
class DurationAndCurve extends Motion {
  /// Creates a motion with a fixed duration and curve.
  const DurationAndCurve({
    required this.duration,
    this.curve = Curves.linear,
  }) : super(tolerance: const Tolerance(distance: 0, time: 0, velocity: 0));

  const DurationAndCurve._(Duration duration)
      : this(duration: duration, curve: Curves.linear);

  /// The total duration of the motion.
  final Duration duration;

  /// The curve that defines the rate of change of the motion over time.
  ///
  /// Defaults to [Curves.linear], which represents a constant rate of change.
  final Curve curve;

  /// Whether this motion needs to settle.
  ///
  /// Always returns false for [DurationAndCurve] because it completes in a
  /// fixed duration.
  @override
  bool get needsSettle => false;

  /// Whether this motion will settle without bounds.
  ///
  /// Always returns true for [DurationAndCurve] because it always terminates
  /// after the specified duration.
  @override
  bool get unboundedWillSettle => true;

  /// Creates a new [DurationAndCurve] with the given parameters.
  DurationAndCurve copyWith({
    Duration? duration,
    Curve? curve,
  }) =>
      DurationAndCurve(
        duration: duration ?? this.duration,
        curve: curve ?? this.curve,
      );

  /// Applies [curve] to the current [duration].
  DurationAndCurve withCurve(Curve curve) => copyWith(curve: curve);

  @override
  Simulation createSimulation({
    double start = 0,
    double end = 1,
    double velocity = 0,
  }) {
    return CurveSimulation(
      duration: duration,
      curve: curve,
      start: start,
      end: end,
      tolerance: tolerance,
    );
  }

  @override
  bool operator ==(Object other) {
    if (other is DurationAndCurve) {
      return duration == other.duration && curve == other.curve;
    }
    return false;
  }

  /// Returns a hash code for this object.
  @override
  int get hashCode => Object.hash(duration, curve);

  /// Returns a string representation of this object.
  @override
  String toString() => 'DurationAndCurve(duration: $duration, curve: $curve)';
}

/// A motion based on spring physics.
///
/// [SpringMotion] implements a motion that follows physical spring behavior,
/// using a [SpringDescription] to define its characteristics. This motion
/// is useful for creating natural and responsive animations.
///
/// Spring motions continue until they naturally settle based on physics,
/// rather than completing in a predetermined duration.
@immutable
class SpringMotion extends Motion {
  /// Creates a motion with spring physics.
  ///
  /// Parameter [spring] defines the physical characteristics of the spring.
  const SpringMotion(this.spring, {this.snapToEnd = true});

  /// The physical description of the spring.
  ///
  /// Contains parameters like mass, stiffness, and damping that define
  /// how the spring behaves.
  final SpringDescription spring;

  /// Whether to snap to the end of the spring.
  ///
  /// If true, the spring will snap to the end of the motion when the simulation
  /// is done.
  final bool snapToEnd;

  /// Whether this motion needs to settle.
  ///
  /// Always returns true for [SpringMotion] because spring physics requires
  /// the animation to continue until the spring naturally settles.
  @override
  bool get needsSettle => true;

  /// Whether this motion will settle without bounds.
  ///
  /// Returns false for [SpringMotion] because spring physics may not
  /// necessarily terminate without bounds in all configurations.
  @override
  bool get unboundedWillSettle => false;

  /// Creates a simulation for this motion.
  ///
  /// Returns a [SpringSimulation] that follows the physical behavior
  /// defined by the [spring] description.
  ///
  /// Parameters:
  ///   * [start] - The starting value for the simulation, defaults to 0.
  ///   * [end] - The ending value (target position) for the simulation,
  ///     defaults to 1.
  ///   * [velocity] - The initial velocity of the spring, defaults to 0.
  @override
  Simulation createSimulation({
    double start = 0,
    double end = 1,
    double velocity = 0,
  }) =>
      SpringSimulation(
        spring,
        start,
        end,
        velocity,
        tolerance: tolerance,
        snapToEnd: snapToEnd,
      );

  /// Equality operator for [SpringMotion].
  ///
  /// Two [SpringMotion] instances are considered equal if their [spring]
  /// descriptions have the same damping, mass, and stiffness values.
  @override
  bool operator ==(Object other) {
    if (other is SpringMotion) {
      return spring.damping == other.spring.damping &&
          spring.mass == other.spring.mass &&
          spring.stiffness == other.spring.stiffness;
    }
    return false;
  }

  /// Returns a hash code for this object.
  @override
  int get hashCode =>
      Object.hash(spring.damping, spring.mass, spring.stiffness);

  /// Returns a string representation of this object.
  @override
  String toString() => 'Spring(spring: $spring)';
}
