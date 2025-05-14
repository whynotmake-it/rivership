import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';
import 'package:springster/src/duration_spring.dart';
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
  ///   * [Spring]
  const factory Motion.spring(SpringDescription spring) = Spring;

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
/// [Spring] implements a motion that follows physical spring behavior,
/// using a [SpringDescription] to define its characteristics. This motion
/// is useful for creating natural and responsive animations.
///
/// Spring motions continue until they naturally settle based on physics,
/// rather than completing in a predetermined duration.
@immutable
class Spring extends Motion {
  /// Creates a motion with spring physics.
  ///
  /// Parameter [description] defines the physical characteristics of the
  /// spring.
  const Spring(this.description, {this.snapToEnd = true});

  /// The physical description of the spring.
  ///
  /// Contains parameters like mass, stiffness, and damping that define
  /// how the spring behaves.
  final SpringDescription description;

  /// Whether to snap to the end of the spring.
  ///
  /// If true, the spring will snap to the end of the motion when the simulation
  /// is done.
  /// This ensures that the simulation will settle exactly to the target value.
  final bool snapToEnd;

  /// Whether this motion needs to settle.
  ///
  /// Always returns true for [Spring] because spring physics requires
  /// the animation to continue until the spring naturally settles.
  @override
  bool get needsSettle => true;

  /// Whether this motion will settle without bounds.
  ///
  /// Returns false for [Spring] because spring physics may not
  /// necessarily terminate without bounds in all configurations.
  @override
  bool get unboundedWillSettle => false;

  /// Creates a simulation for this motion.
  ///
  /// Returns a [SpringSimulation] that follows the physical behavior
  /// defined by the [description] description.
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
        description,
        start,
        end,
        velocity,
        tolerance: tolerance,
        snapToEnd: snapToEnd,
      );

  /// Equality operator for [Spring].
  ///
  /// Two [Spring] instances are considered equal if their [description]
  /// descriptions have the same damping, mass, and stiffness values.
  @override
  bool operator ==(Object other) {
    if (other is Spring) {
      return description.damping == other.description.damping &&
          description.mass == other.description.mass &&
          description.stiffness == other.description.stiffness;
    }
    return false;
  }

  /// Returns a hash code for this object.
  @override
  int get hashCode =>
      Object.hash(description.damping, description.mass, description.stiffness);

  /// Returns a string representation of this object.
  @override
  String toString() => 'Spring(spring: $description)';

  /// Creates a new [Spring] with the same properties as this one, but with
  /// the specified [description] and [snapToEnd].
  Spring copyWith({
    SpringDescription? description,
    bool? snapToEnd,
  }) =>
      Spring(
        description ?? this.description,
        snapToEnd: snapToEnd ?? this.snapToEnd,
      );
}

/// A collection of spring motions that are commonly used in Cupertino apps.
///
/// These motions are based on the [DurationSpring] class and are designed to
/// match the behavior of the springs used in Cupertino apps.
class CupertinoMotion extends Spring {
  /// Creates a new [CupertinoMotion] with the specified duration and bounce.
  ///
  /// The duration is the duration of the spring motion, and the bounce is the
  /// amount of bounce in the spring motion.
  ///
  /// The default duration is 500 milliseconds, and the default bounce is 0.
  CupertinoMotion({
    Duration duration = const Duration(milliseconds: 500),
    double bounce = 0,
    bool snapToEnd = true,
  }) : this._(
          DurationSpring(
            durationSeconds: duration.toFractionalSeconds(),
            bounce: bounce,
          ),
          snapToEnd: snapToEnd,
        );

  const CupertinoMotion._(
    DurationSpring super.description, {
    super.snapToEnd,
  }) : super();

  @override
  DurationSpring get description => super.description as DurationSpring;

  /// A smooth spring with no bounce.
  ///
  /// This uses the [default values for iOS](https://developer.apple.com/documentation/swiftui/animation/default).
  static const standard =
      CupertinoMotion._(DurationSpring.withDamping(durationSeconds: 0.55));

  /// A spring with a predefined duration and higher amount of bounce.
  static const bouncy = CupertinoMotion._(DurationSpring(bounce: 0.3));

  /// A snappy spring with a damping fraction of 0.85.
  static const snappy =
      CupertinoMotion._(DurationSpring.withDamping(dampingFraction: 0.85));

  /// A smooth spring with a predefined duration and no bounce.
  static const smooth = CupertinoMotion._(DurationSpring());

  /// A spring animation with a lower response value,
  /// intended for driving interactive animations.
  static const interactive = CupertinoMotion._(
    DurationSpring.withDamping(
      dampingFraction: 0.86,
      durationSeconds: 0.15,
    ),
  );

  /// Creates a new [CupertinoMotion] with the same properties as this one,
  /// but with a different damping fraction, and optionally a different
  /// duration.
  CupertinoMotion withDamping({
    double? dampingFraction,
    Duration? duration,
    bool? snapToEnd,
  }) =>
      CupertinoMotion._(
        description.copyWithDamping(
          dampingFraction: dampingFraction,
          durationSeconds: duration?.toFractionalSeconds(),
        ),
        snapToEnd: snapToEnd ?? this.snapToEnd,
      );

  /// Creates a new [CupertinoMotion] with the same properties as this one,
  /// but with a different bounce, and optionally a different duration.
  CupertinoMotion withBounce({
    double? bounce,
    Duration? duration,
    bool? snapToEnd,
  }) =>
      CupertinoMotion._(
        description.copyWith(
          bounce: bounce,
          durationSeconds: duration?.toFractionalSeconds(),
        ),
        snapToEnd: snapToEnd ?? this.snapToEnd,
      );
}

extension on Duration {
  double toFractionalSeconds() =>
      inMicroseconds / Duration.microsecondsPerSecond;
}
