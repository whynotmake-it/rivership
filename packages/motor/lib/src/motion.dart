import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/src/motion_converter.dart';
import 'package:motor/src/simulations/curve_simulation.dart';
import 'package:motor/src/simulations/no_motion_simulation.dart';

export 'motion_curve.dart';

/// {@template Motion}
/// A motion pattern such as spring physics or duration-based curves.
///
/// [Motion] provides a foundation for creating various types of animation
/// behaviors. Concrete implementations of this class define specific motion
/// patterns like spring physics or duration-based curves.
/// {@endtemplate}
@immutable
sealed class MotionBase {
  /// {@macro Motion}
  const MotionBase({
    this.tolerance = Tolerance.defaultTolerance,
  });

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

  /// Returns a motion wrapper that completes in exactly [duration].
  MotionBase scaleTo(Duration duration);

  /// Estimates when [simulation] finishes using exponential search followed by
  /// binary search, avoiding fixed-step scans through the whole timeline.
  ///
  /// This is a building block for motions that need to time-scale or trim
  /// another simulation whose natural duration is unknown. It is not part of
  /// the public API; subclasses may call it from their `createSimulation`
  /// implementations.
  @protected
  double estimateSimulationDuration(
    Simulation simulation, {
    Duration? fallback,
    Duration max = const Duration(seconds: 60),
  }) {
    if (simulation.isDone(0)) return 0;

    final fallbackSeconds = fallback?.toSeconds();
    var lower = 0.0;
    var upper = fallbackSeconds == null || fallbackSeconds <= 0
        ? 1 / 60
        : fallbackSeconds;
    final maxSeconds = max.toSeconds();

    while (upper < maxSeconds && !simulation.isDone(upper)) {
      lower = upper;
      upper *= 2;
    }

    if (!simulation.isDone(upper)) {
      return fallbackSeconds ?? maxSeconds;
    }

    for (var i = 0; i < 24; i++) {
      final mid = (lower + upper) / 2;
      if (simulation.isDone(mid)) {
        upper = mid;
      } else {
        lower = mid;
      }
    }

    return upper;
  }
}

/// {@macro Motion}
///
/// [Motion] describes target-based motion. It always creates a simulation from
/// a start value to an end value.
@immutable
abstract class Motion extends MotionBase {
  /// {@macro Motion}
  const Motion({
    super.tolerance,
  });

  /// {@macro CurvedMotion}
  const factory Motion.curved(Duration duration, [Curve curve]) = CurvedMotion;

  /// Creates a linear motion with a fixed duration.
  const factory Motion.linear(Duration duration) = LinearMotion;

  /// {@macro NoMotion}
  const factory Motion.none([Duration duration]) = NoMotion;

  /// {@macro SpringMotion}
  const factory Motion.customSpring(
    SpringDescription spring, {
    bool snapToEnd,
  }) = SpringMotion;

  /// {@macro CupertinoMotion}
  const factory Motion.cupertino({
    Duration duration,
    double bounce,
    bool snapToEnd,
  }) = CupertinoMotion;

  /// {@macro CupertinoMotion.bouncy}
  const factory Motion.bouncySpring({
    Duration duration,
    double extraBounce,
    bool snapToEnd,
  }) = CupertinoMotion.bouncy;

  /// {@macro CupertinoMotion.snappy}
  const factory Motion.snappySpring({
    Duration duration,
    double extraBounce,
    bool snapToEnd,
  }) = CupertinoMotion.snappy;

  /// {@macro CupertinoMotion.smooth}
  const factory Motion.smoothSpring({
    Duration duration,
    double extraBounce,
    bool snapToEnd,
  }) = CupertinoMotion.smooth;

  /// {@macro CupertinoMotion.interactive}
  const factory Motion.interactiveSpring({
    Duration duration,
    double extraBounce,
    bool snapToEnd,
  }) = CupertinoMotion.interactive;

  /// The characteristic duration of this motion, or `null` if unknown at this
  /// time.
  ///
  /// For fixed-duration motions (curves, linear) this is the exact duration.
  /// For springs it is the spring's characteristic settling time.
  ///
  /// See also:
  /// * [estimateSimulationDuration], as an expensive fallback for when the
  ///   duration is unknown.
  Duration? get duration => null;

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
  Motion scaleTo(Duration duration) {
    return FixedDurationMotion(this, duration: duration);
  }

  @override
  bool operator ==(Object other);

  @override
  int get hashCode;
}

/// A self-directed motion that does not require an end value.
///
/// [FreeMotion] is useful for decay, friction, gravity, and other simulations
/// that evolve from an initial position and velocity.
@immutable
abstract class FreeMotion extends MotionBase {
  /// Creates a free motion.
  const FreeMotion({
    super.tolerance,
  });

  /// {@macro FrictionMotion}
  const factory FreeMotion.friction({
    double drag,
    double constantDeceleration,
  }) = FrictionMotion;

  /// Creates a self-directed simulation.
  Simulation createSimulation({
    double start = 0,
    double velocity = 0,
  });

  /// Returns the value this motion will settle to, or `null` if unknown.
  ///
  /// Override this to provide the resting position for motions where the
  /// terminal value can be computed cheaply (e.g. friction/decay).
  ///
  /// When non-null, downstream consumers can use this to anticipate the
  /// final position without running the full simulation.
  double? finalValue({double start = 0, double velocity = 0}) => null;

  /// Projects where this motion will come to rest for a typed value.
  ///
  /// Normalizes [from] and [velocity] through [converter], computes
  /// [finalValue] for each dimension, and denormalizes the result back to `T`.
  ///
  /// Returns `null` if any dimension's [finalValue] is unknown.
  ///
  /// ```dart
  /// const friction = FrictionMotion();
  /// final resting = friction.project(
  ///   from: currentOffset,
  ///   velocity: flingVelocity,
  ///   converter: MotionConverter.offset,
  /// );
  /// ```
  T? project<T>({
    required T from,
    required T velocity,
    required MotionConverter<T> converter,
  }) {
    final starts = converter.normalize(from);
    final velocities = converter.normalize(velocity);
    final result = <double>[];
    for (var i = 0; i < starts.length; i++) {
      final v = finalValue(start: starts[i], velocity: velocities[i]);
      if (v == null) return null;
      result.add(v);
    }
    return converter.denormalize(result);
  }

  @override
  FreeMotion scaleTo(Duration duration) {
    return FixedDurationFreeMotion(this, duration: duration);
  }
}

/// {@template CurvedMotion}
/// A motion based on a fixed duration and curve.
///
/// [CurvedMotion] implements a motion that follows a specific [Curve] over
/// a fixed [Duration]. This is the most common type of animation in Flutter,
/// similar to what is used with [AnimationController.animateTo].
///
/// This motion always completes in the specified duration and does not need to
/// settle.
/// {@endtemplate}
@immutable
class CurvedMotion extends Motion {
  /// Creates a motion with a fixed duration and curve.
  const CurvedMotion(
    this.duration, [
    this.curve = Curves.linear,
  ]) : super(tolerance: Tolerance.defaultTolerance);

  /// The total duration of the motion.
  @override
  final Duration duration;

  /// The curve that defines the rate of change of the motion over time.
  ///
  /// Defaults to [Curves.linear], which represents a constant rate of change.
  final Curve curve;

  /// Whether this motion needs to settle.
  ///
  /// Always returns false for [CurvedMotion] because it completes in a
  /// fixed duration.
  @override
  bool get needsSettle => false;

  /// Whether this motion will settle without bounds.
  ///
  /// Always returns true for [CurvedMotion] because it always terminates
  /// after the specified duration.
  @override
  bool get unboundedWillSettle => true;

  /// Creates a new [CurvedMotion] with the given parameters.
  CurvedMotion copyWith({
    Duration? duration,
    Curve? curve,
  }) =>
      CurvedMotion(duration ?? this.duration, curve ?? this.curve);

  /// Applies [curve] to the current [duration].
  CurvedMotion withCurve(Curve curve) => copyWith(curve: curve);

  @override
  CurvedMotion scaleTo(Duration duration) => copyWith(duration: duration);

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
    if (other is CurvedMotion) {
      return duration == other.duration && curve == other.curve;
    }
    return false;
  }

  /// Returns a hash code for this object.
  @override
  int get hashCode => Object.hash(duration, curve);

  /// Returns a string representation of this object.
  @override
  String toString() => 'CurvedMotion($duration, curve: $curve)';
}

/// A convenience class for a [CurvedMotion] that uses a linear curve.
class LinearMotion extends CurvedMotion {
  /// Creates a linear motion with a fixed duration.
  const LinearMotion(Duration duration) : super(duration, Curves.linear);

  @override
  LinearMotion scaleTo(Duration duration) => LinearMotion(duration);

  @override
  String toString() => 'LinearMotion($duration)';
}

/// {@template NoMotion}
/// A motion that holds at the current value for [duration] and never reaches
/// its target.
/// {@endtemplate}
class NoMotion extends Motion {
  /// {@macro NoMotion}
  ///
  /// By default, the [duration] is set to zero.
  const NoMotion([this.duration = Duration.zero]);

  /// The duration that this motion holds its value.
  @override
  final Duration duration;

  @override
  NoMotion scaleTo(Duration duration) => NoMotion(duration);

  @override
  String toString() => 'NoMotion($duration)';

  @override
  Simulation createSimulation({
    double start = 0,
    double end = 1,
    double velocity = 0,
  }) {
    return NoMotionSimulation(
      duration: duration,
      value: start,
      tolerance: tolerance,
    );
  }

  @override
  bool get needsSettle => false;

  @override
  bool get unboundedWillSettle => true;
}

/// {@template SpringMotion}
/// A motion based on spring physics.
///
/// [SpringMotion] implements a motion that follows physical spring behavior,
/// using a [SpringDescription] to define its characteristics. This motion
/// is useful for creating natural and responsive animations.
///
/// Spring motions continue until they naturally settle based on physics,
/// rather than completing in a predetermined duration.
/// {@endtemplate}
@immutable
abstract class SpringMotion extends Motion {
  /// {@macro SpringMotion}
  ///
  /// Parameter [description] defines the physical characteristics of the
  /// spring.
  const factory SpringMotion(
    SpringDescription description, {
    bool snapToEnd,
  }) = _DescriptionSpringMotion;

  /// Internal constructor;
  const SpringMotion._({
    this.snapToEnd = true,
  });

  /// The physical description of the spring.
  ///
  /// Contains parameters like mass, stiffness, and damping that define
  /// how the spring behaves.
  SpringDescription get description;

  @override
  Duration get duration => description.duration;

  /// Whether to snap to the end of the spring.
  ///
  /// If true, the spring will snap to the end of the motion when the simulation
  /// is done.
  /// This ensures that the simulation will settle exactly to the target value.
  ///
  /// Defaults to true.
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

  /// Equality operator for [SpringMotion].
  ///
  /// Two [SpringMotion] instances are considered equal if their [description]
  /// descriptions have the same damping, mass, and stiffness values.
  @override
  bool operator ==(Object other) {
    if (other is SpringMotion) {
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

  /// Creates a new [SpringMotion] with the same properties as this one, but
  /// with the specified [description] and [snapToEnd].
  SpringMotion copyWith();
}

class _DescriptionSpringMotion extends SpringMotion {
  /// Creates a new [SpringMotion] with the specified [description].
  const _DescriptionSpringMotion(
    this.description, {
    super.snapToEnd,
  }) : super._();

  @override
  final SpringDescription description;

  @override
  String toString() => 'Spring(description: $description)';

  @override
  SpringMotion copyWith({
    SpringDescription? description,
    bool? snapToEnd,
  }) {
    return _DescriptionSpringMotion(
      description ?? this.description,
      snapToEnd: snapToEnd ?? this.snapToEnd,
    );
  }
}

/// {@template CupertinoMotion}
/// A collection of spring motions that are commonly used in Cupertino apps.
/// {@endtemplate}
class CupertinoMotion extends SpringMotion {
  /// Creates a new [CupertinoMotion] with the specified duration and bounce.
  ///
  /// The duration is the duration of the spring motion, and the bounce is the
  /// amount of bounce in the spring motion.
  ///
  /// By default, this creates a smooth spring with no bounce, matching the
  /// [standard iOS spring motion behavior](https://developer.apple.com/documentation/swiftui/animation/default).
  ///
  /// [snapToEnd] defaults to true.
  const CupertinoMotion({
    this.duration = const Duration(milliseconds: 550),
    this.bounce = 0,
    super.snapToEnd,
  }) : super._();

  /// {@template CupertinoMotion.bouncy}
  /// A spring animation with a predefined duration and higher amount of bounce.
  ///
  /// See also:
  /// * https://developer.apple.com/documentation/swiftui/animation/bouncy
  /// {@endtemplate}
  const CupertinoMotion.bouncy({
    Duration duration = const Duration(milliseconds: 500),
    double extraBounce = 0.0,
    bool snapToEnd = true,
  }) : this(
          duration: duration,
          bounce: 0.3 + extraBounce,
          snapToEnd: snapToEnd,
        );

  /// {@template CupertinoMotion.snappy}
  /// A spring animation with a predefined duration and small amount of bounce
  /// that feels more snappy.
  ///
  /// See also:
  /// * https://developer.apple.com/documentation/swiftui/animation/snappy
  /// {@endtemplate}
  const CupertinoMotion.snappy({
    Duration duration = const Duration(milliseconds: 500),
    double extraBounce = 0.0,
    bool snapToEnd = true,
  }) : this(
          duration: duration,
          bounce: 0.15 + extraBounce,
          snapToEnd: snapToEnd,
        );

  /// {@template CupertinoMotion.smooth}
  /// A smooth spring animation with a predefined duration and no bounce.
  ///
  /// See also:
  /// * https://developer.apple.com/documentation/swiftui/animation/smooth
  /// {@endtemplate}
  const CupertinoMotion.smooth({
    Duration duration = const Duration(milliseconds: 500),
    double extraBounce = 0.0,
    bool snapToEnd = true,
  }) : this(
          duration: duration,
          bounce: extraBounce,
          snapToEnd: snapToEnd,
        );

  /// {@template CupertinoMotion.interactive}
  /// A spring animation with a lower response value,
  /// intended for driving interactive animations.
  ///
  /// See also:
  /// * https://developer.apple.com/documentation/swiftui/animation/interactivespring(response:dampingfraction:blendduration:)
  /// {@endtemplate}
  const CupertinoMotion.interactive({
    Duration duration = const Duration(milliseconds: 150),
    double extraBounce = 0.0,
    bool snapToEnd = true,
  }) : this(
          duration: duration,
          bounce: 0.14 + extraBounce,
          snapToEnd: snapToEnd,
        );

  /// The estimated duration of the spring motion.
  @override
  final Duration duration;

  /// The bounce of the spring motion.
  final double bounce;

  @override
  SpringDescription get description => SpringDescription.withDurationAndBounce(
        duration: duration,
        bounce: bounce,
      );

  /// Creates a new [CupertinoMotion] with the same properties as this one, but
  /// with the specified [bounce] and [duration].
  @override
  CupertinoMotion copyWith({
    Duration? duration,
    double? bounce,
    bool? snapToEnd,
  }) {
    return CupertinoMotion(
      duration: duration ?? description.duration,
      bounce: bounce ?? description.bounce,
      snapToEnd: snapToEnd ?? this.snapToEnd,
    );
  }
}

/// Material Design 3 spring motion tokens for expressive design system.
///
/// This class provides predefined spring motion tokens that follow the
/// Material Design 3 motion guidelines for creating expressive and natural
/// animations. The tokens are organized into two categories:
/// - **Spatial**: For animating position, size, and layout changes
/// - **Effects**: For animating visual properties like opacity and color
///
/// Each category has three speed variants: fast, default, and slow.
///
/// See also:
/// * [Material Design 3 Motion Guidelines](https://m3.material.io/styles/motion/overview/how-it-works#spring-tokens)
/// * [SpringMotion] for the base spring motion implementation
class MaterialSpringMotion extends SpringMotion {
  /// Creates a new [MaterialSpringMotion] with the specified damping and
  /// stiffness.
  const MaterialSpringMotion._({
    required this.damping,
    required this.stiffness,
    super.snapToEnd,
  }) : super._();

  /// Standard spatial motion token - fast variant.
  ///
  /// Used for quick spatial animations like position changes, resizing,
  /// and layout transitions. This is the fastest of the standard spatial
  /// motion tokens.
  ///
  /// **Damping**: 0.9, **Stiffness**: 1400, **Mass**: 1
  const MaterialSpringMotion.standardSpatialFast({
    bool snapToEnd = true,
  }) : this._(
          damping: 0.9,
          stiffness: 1400,
          snapToEnd: snapToEnd,
        );

  /// Standard spatial motion token - default variant.
  ///
  /// The recommended spatial motion for most position changes, resizing,
  /// and layout transitions. Provides a balanced animation speed.
  ///
  /// **Damping**: 0.9, **Stiffness**: 700, **Mass**: 1
  const MaterialSpringMotion.standardSpatialDefault({
    bool snapToEnd = true,
  }) : this._(
          damping: 0.9,
          stiffness: 700,
          snapToEnd: snapToEnd,
        );

  /// Standard spatial motion token - slow variant.
  ///
  /// Used for deliberate spatial animations where a slower, more gentle
  /// motion is desired for position changes, resizing, and layout transitions.
  ///
  /// **Damping**: 0.9, **Stiffness**: 300, **Mass**: 1
  const MaterialSpringMotion.standardSpatialSlow({
    bool snapToEnd = true,
  }) : this._(
          damping: 0.9,
          stiffness: 300,
          snapToEnd: snapToEnd,
        );

  /// Standard effects motion token - fast variant.
  ///
  /// Used for quick visual property animations like opacity, color,
  /// and other non-spatial effects. This is the fastest of the standard
  /// effects motion tokens.
  ///
  /// **Damping**: 1, **Stiffness**: 3800, **Mass**: 1
  const MaterialSpringMotion.standardEffectsFast({
    bool snapToEnd = true,
  }) : this._(
          damping: 1,
          stiffness: 3800,
          snapToEnd: snapToEnd,
        );

  /// Standard effects motion token - default variant.
  ///
  /// The recommended effects motion for most visual property animations
  /// like opacity, color, and other non-spatial effects. Provides a
  /// balanced animation speed.
  ///
  /// **Damping**: 1, **Stiffness**: 1600, **Mass**: 1
  const MaterialSpringMotion.standardEffectsDefault({
    bool snapToEnd = true,
  }) : this._(
          damping: 1,
          stiffness: 1600,
          snapToEnd: snapToEnd,
        );

  /// Standard effects motion token - slow variant.
  ///
  /// Used for deliberate visual property animations where a slower,
  /// more gentle motion is desired for opacity, color, and other
  /// non-spatial effects.
  ///
  /// **Damping**: 1, **Stiffness**: 800, **Mass**: 1
  const MaterialSpringMotion.standardEffectsSlow({
    bool snapToEnd = true,
  }) : this._(
          damping: 1,
          stiffness: 800,
          snapToEnd: snapToEnd,
        );

  /// Expressive spatial motion token - fast variant.
  ///
  /// Used for more dynamic and bouncy spatial animations with increased
  /// expressiveness. Features lower damping for more spring-like behavior
  /// in position changes, resizing, and layout transitions.
  ///
  /// **Damping**: 0.6, **Stiffness**: 800, **Mass**: 1
  const MaterialSpringMotion.expressiveSpatialFast({
    bool snapToEnd = true,
  }) : this._(
          damping: 0.6,
          stiffness: 800,
          snapToEnd: snapToEnd,
        );

  /// Expressive spatial motion token - default variant.
  ///
  /// The recommended expressive spatial motion for creating more dynamic
  /// and bouncy animations with moderate expressiveness. Features lower
  /// damping for spring-like behavior in spatial transitions.
  ///
  /// **Damping**: 0.8, **Stiffness**: 380, **Mass**: 1
  const MaterialSpringMotion.expressiveSpatialDefault({
    bool snapToEnd = true,
  }) : this._(
          damping: 0.8,
          stiffness: 380,
          snapToEnd: snapToEnd,
        );

  /// Expressive spatial motion token - slow variant.
  ///
  /// Used for slower, more deliberate expressive spatial animations
  /// with gentle spring-like behavior. Features lower damping for
  /// increased bounce in position changes and layout transitions.
  ///
  /// **Damping**: 0.8, **Stiffness**: 200, **Mass**: 1
  const MaterialSpringMotion.expressiveSpatialSlow({
    bool snapToEnd = true,
  }) : this._(
          damping: 0.8,
          stiffness: 200,
          snapToEnd: snapToEnd,
        );

  /// Expressive effects motion token - fast variant.
  ///
  /// Used for quick expressive visual property animations. While maintaining
  /// the same spring characteristics as standard effects, this token is part
  /// of the expressive motion system for consistent design language.
  ///
  /// **Damping**: 1, **Stiffness**: 3800, **Mass**: 1
  const MaterialSpringMotion.expressiveEffectsFast({
    bool snapToEnd = true,
  }) : this._(
          damping: 1,
          stiffness: 3800,
          snapToEnd: snapToEnd,
        );

  /// Expressive effects motion token - default variant.
  ///
  /// The recommended expressive effects motion for visual property animations
  /// like opacity and color. Part of the expressive motion system while
  /// maintaining optimal characteristics for non-spatial effects.
  ///
  /// **Damping**: 1, **Stiffness**: 1600, **Mass**: 1
  const MaterialSpringMotion.expressiveEffectsDefault({
    bool snapToEnd = true,
  }) : this._(
          damping: 1,
          stiffness: 1600,
          snapToEnd: snapToEnd,
        );

  /// Expressive effects motion token - slow variant.
  ///
  /// Used for slower, more deliberate expressive visual property animations.
  /// Part of the expressive motion system while maintaining characteristics
  /// optimized for opacity, color, and other non-spatial effects.
  ///
  /// **Damping**: 1, **Stiffness**: 800, **Mass**: 1
  const MaterialSpringMotion.expressiveEffectsSlow({
    bool snapToEnd = true,
  }) : this._(
          damping: 1,
          stiffness: 800,
          snapToEnd: snapToEnd,
        );

  /// The damping factor of the spring motion.
  ///
  /// Works exactly like the [SpringDescription.damping] property.
  final double damping;

  /// The stiffness factor of the spring motion.
  ///
  /// Works exactly like the [SpringDescription.stiffness] property.
  final double stiffness;

  @override
  SpringDescription get description => SpringDescription.withDampingRatio(
        ratio: damping,
        stiffness: stiffness,
        mass: 1,
      );

  @override
  MaterialSpringMotion copyWith({
    double? damping,
    double? stiffness,
    bool? snapToEnd,
  }) {
    return MaterialSpringMotion._(
      damping: damping ?? this.damping,
      stiffness: stiffness ?? this.stiffness,
      snapToEnd: snapToEnd ?? this.snapToEnd,
    );
  }
}

/// A target-based motion that forces [parent] to complete in [duration].
@immutable
class FixedDurationMotion extends Motion {
  /// Creates a fixed-duration wrapper around [parent].
  FixedDurationMotion(
    this.parent, {
    required this.duration,
  }) : super(tolerance: parent.tolerance);

  /// The motion whose shape should be time-scaled.
  final Motion parent;

  /// The duration this motion should take.
  @override
  final Duration duration;

  @override
  bool get needsSettle => false;

  @override
  bool get unboundedWillSettle => true;

  @override
  Simulation createSimulation({
    double start = 0,
    double end = 1,
    double velocity = 0,
  }) {
    final parentSimulation = parent.createSimulation(
      start: start,
      end: end,
      velocity: velocity,
    );
    return _FixedDurationSimulation(
      parent: parentSimulation,
      duration: duration,
      start: start,
      end: end,
      sourceDuration: parent.duration?.toSeconds() ??
          estimateSimulationDuration(parentSimulation, fallback: duration),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is FixedDurationMotion &&
        parent == other.parent &&
        duration == other.duration;
  }

  @override
  int get hashCode => Object.hash(parent, duration);

  @override
  String toString() => 'FixedDurationMotion($parent, duration: $duration)';
}

/// A free motion that forces [parent] to finish in [duration].
@immutable
class FixedDurationFreeMotion extends FreeMotion {
  /// Creates a fixed-duration wrapper around [parent].
  FixedDurationFreeMotion(
    this.parent, {
    required this.duration,
  }) : super(tolerance: parent.tolerance);

  /// The motion whose shape should be time-scaled.
  final FreeMotion parent;

  /// The duration this motion should take.
  final Duration duration;

  @override
  bool get needsSettle => false;

  @override
  bool get unboundedWillSettle => true;

  @override
  Simulation createSimulation({
    double start = 0,
    double velocity = 0,
  }) {
    final simulation = parent.createSimulation(
      start: start,
      velocity: velocity,
    );
    // Free motions have no inherent duration, so always probe the simulation.
    final sourceDuration = estimateSimulationDuration(
      simulation,
      fallback: duration,
    );

    return _FixedDurationSimulation(
      parent: simulation,
      duration: duration,
      start: start,
      end: simulation.x(sourceDuration),
      sourceDuration: sourceDuration,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is FixedDurationFreeMotion &&
        parent == other.parent &&
        duration == other.duration;
  }

  @override
  int get hashCode => Object.hash(parent, duration);

  @override
  double? finalValue({double start = 0, double velocity = 0}) {
    return parent.finalValue(start: start, velocity: velocity);
  }

  @override
  String toString() => 'FixedDurationFreeMotion($parent, duration: $duration)';
}

/// {@template FrictionMotion}
/// A free motion that decelerates due to fluid drag (friction).
///
/// Models a particle slowing down through a medium, like a scroll view
/// coasting to a stop. The [drag] coefficient controls how quickly the motion
/// decelerates — lower values mean faster deceleration.
///
/// An optional [constantDeceleration] can be applied on top of the
/// exponential drag for a more linear slow-down feel.
///
/// Use [finalValue] to compute where the motion will come to rest for a
/// given start position and velocity, without running the full simulation.
/// {@endtemplate}
@immutable
class FrictionMotion extends FreeMotion {
  /// {@macro FrictionMotion}
  ///
  /// [drag] is the fluid drag coefficient (must be > 0). A typical scrolling
  /// drag is around 0.135.
  ///
  /// [constantDeceleration] adds a fixed deceleration on top of the
  /// exponential drag. Defaults to 0.
  const FrictionMotion({
    this.drag = 0.135,
    this.constantDeceleration = 0,
    super.tolerance,
  })  : assert(drag > 0, 'drag must be positive'),
        assert(constantDeceleration >= 0, 'constantDeceleration must be >= 0');

  /// The fluid drag coefficient.
  ///
  /// Must be greater than 0. Lower values mean faster deceleration.
  /// A typical scrolling drag is around 0.135.
  final double drag;

  /// A constant deceleration applied on top of exponential drag.
  ///
  /// Defaults to 0 (pure exponential friction).
  final double constantDeceleration;

  @override
  bool get needsSettle => true;

  @override
  bool get unboundedWillSettle => true;

  @override
  Simulation createSimulation({
    double start = 0,
    double velocity = 0,
  }) {
    return FrictionSimulation(
      drag,
      start,
      velocity,
      tolerance: tolerance,
      constantDeceleration: constantDeceleration,
    );
  }

  @override
  double finalValue({double start = 0, double velocity = 0}) {
    return FrictionSimulation(
      drag,
      start,
      velocity,
      constantDeceleration: constantDeceleration,
    ).finalX;
  }

  @override
  T project<T>({
    required T from,
    required T velocity,
    required MotionConverter<T> converter,
  }) {
    return super.project(from: from, velocity: velocity, converter: converter)!;
  }

  /// Returns a copy with the given fields replaced.
  FrictionMotion copyWith({
    double? drag,
    double? constantDeceleration,
    Tolerance? tolerance,
  }) {
    return FrictionMotion(
      drag: drag ?? this.drag,
      constantDeceleration: constantDeceleration ?? this.constantDeceleration,
      tolerance: tolerance ?? this.tolerance,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is FrictionMotion &&
        drag == other.drag &&
        constantDeceleration == other.constantDeceleration;
  }

  @override
  int get hashCode => Object.hash(drag, constantDeceleration);

  @override
  String toString() => 'FrictionMotion(drag: $drag, '
      'constantDeceleration: $constantDeceleration)';
}

class _FixedDurationSimulation extends Simulation {
  _FixedDurationSimulation({
    required this.parent,
    required this.duration,
    required this.start,
    required this.end,
    required double sourceDuration,
  })  : _durationInSeconds =
            duration.inMicroseconds / Duration.microsecondsPerSecond,
        _sourceDuration = sourceDuration,
        super(tolerance: parent.tolerance);

  final Simulation parent;
  final Duration duration;
  final double start;
  final double end;
  final double _durationInSeconds;
  final double _sourceDuration;

  @override
  double x(double time) {
    if (time <= 0) return start;
    if (_durationInSeconds == 0 || time >= _durationInSeconds) return end;
    return parent.x(_scaleTime(time));
  }

  @override
  double dx(double time) {
    if (time < 0 || _durationInSeconds == 0 || time >= _durationInSeconds) {
      return 0;
    }
    return parent.dx(_scaleTime(time)) * (_sourceDuration / _durationInSeconds);
  }

  @override
  bool isDone(double time) => time >= _durationInSeconds - tolerance.time;

  double _scaleTime(double time) => time / _durationInSeconds * _sourceDuration;
}

/// {@template TrimmedMotion}
/// A motion that uses only a portion of another motion's characteristic curve.
///
/// [TrimmedMotion] allows you to extract a subset of another motion's behavior
/// by extending the simulation range and mapping back to the desired output.
/// This is useful for creating variations of existing motions without defining
/// entirely new physics or curves.
///
/// ## Accuracy by Motion Type
///
/// **Deterministic motions** (like [CurvedMotion]): Trimming produces exact
/// results that precisely match the requested portion of the original curve.
///
/// **Physics-based motions** (like [SpringMotion]): Trimming produces an
/// approximation by extending the simulation range and finishing early.
/// The result approximates the characteristic curve behavior but may not be
/// perfectly accurate to the original motion's physics at every point.
///
/// ## How it works
///
/// 1. Extends the parent simulation over a larger range
/// 2. Maps the "middle portion" back to your desired 0→1 output
/// 3. Finishes early when the trimmed portion is complete
///
/// Example: With `fromStart: 0.2` and `fromEnd: 0.2`, your 0→1 motion will
/// use the middle 60% of the parent motion's characteristic curve.
/// {@endtemplate}
///
/// See also:
/// * [MotionTrimming.trimmed]
/// * [MotionTrimming.sliced]
/// * [MotionTrimming.segment]
@immutable
class TrimmedMotion extends Motion {
  /// {@macro TrimmedMotion}
  ///
  /// Parameters:
  ///   * [parent] - The motion to trim
  ///   * [fromStart] - Amount to trim from the beginning (0.0 = no trim)
  ///   * [fromEnd] - Amount to trim from the end (0.0 = no trim)

  const TrimmedMotion({
    required this.parent,
    required this.fromStart,
    required this.fromEnd,
  })  : assert(fromStart >= 0.0, 'fromStart must be non-negative'),
        assert(fromEnd >= 0.0, 'fromEnd must be non-negative'),
        assert(
          fromStart + fromEnd <= 1.0,
          'fromStart + fromEnd must be less than 1.0, '
          'but received $fromStart + $fromEnd',
        );

  /// The motion to trim.
  final Motion parent;

  /// Amount to trim from the start of the motion curve.
  final double fromStart;

  /// Amount to trim from the end of the motion curve.
  final double fromEnd;

  @override
  Duration? get duration => switch (parent.duration) {
        final d? => Duration(
            microseconds:
                (d.inMicroseconds * (1 - fromStart - fromEnd)).round(),
          ),
        null => null,
      };

  @override
  bool get needsSettle => parent.needsSettle;

  @override
  bool get unboundedWillSettle => parent.unboundedWillSettle;

  @override
  Tolerance get tolerance => parent.tolerance;

  @override
  Simulation createSimulation({
    double start = 0,
    double end = 1,
    double velocity = 0,
  }) {
    final trimmedExtent = 1.0 - fromStart - fromEnd;

    // We simulate the parent over the extended range
    final parentStart = start - trimmedExtent * fromStart;
    final parentEnd = end + trimmedExtent * fromEnd;

    final scaledSim = parent.createSimulation(
      start: parentStart,
      end: parentEnd,
      velocity: velocity,
    );

    return _TrimmedSimulation(
      parent: scaledSim,
      startTrim: fromStart,
      endTrim: fromEnd,
      trimmedExtent: trimmedExtent,
      start: start,
      end: end,
      parentDuration: estimateSimulationDuration(
        scaledSim,
        fallback: const Duration(seconds: 1),
        max: const Duration(seconds: 10),
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    if (other is TrimmedMotion) {
      return parent == other.parent &&
          fromStart == other.fromStart &&
          fromEnd == other.fromEnd;
    }
    return false;
  }

  @override
  int get hashCode => Object.hash(parent, fromStart, fromEnd);

  @override
  String toString() =>
      'TrimmedMotion(parent: $parent, trim: $fromStart-$fromEnd)';
}

class _TrimmedSimulation extends Simulation {
  _TrimmedSimulation({
    required this.parent,
    required this.startTrim,
    required this.endTrim,
    required this.trimmedExtent,
    required this.start,
    required this.end,
    required double parentDuration,
  })  : _duration = parentDuration * trimmedExtent,
        super(tolerance: parent.tolerance);

  final Simulation parent;
  final double startTrim;
  final double endTrim;
  final double trimmedExtent;
  final double start;
  final double end;
  final double _duration;

  @override
  double x(double time) {
    if (time <= 0) return start;
    if (time >= _duration) return end;

    // Map our time to the parent's time range
    final parentDuration = _duration / trimmedExtent;
    final progressStart = startTrim;
    final progressEnd = 1.0 - endTrim;

    // Scale time to fit within trimmed range
    final normalizedTime = time / _duration;
    final parentTime = parentDuration *
        (progressStart + (progressEnd - progressStart) * normalizedTime);

    // Get parent's values to normalize
    final parentStartValue = parent.x(parentDuration * progressStart);
    final parentEndValue = parent.x(parentDuration * progressEnd);
    final parentCurrentValue = parent.x(parentTime);

    // Normalize and map to our range
    if ((parentEndValue - parentStartValue).abs() < 1e-10) {
      return start + (end - start) * normalizedTime;
    }

    final normalizedProgress = (parentCurrentValue - parentStartValue) /
        (parentEndValue - parentStartValue);
    return start + (end - start) * normalizedProgress;
  }

  @override
  double dx(double time) {
    if (time < 0 || time > _duration) return 0;

    // Use numerical differentiation
    const delta = 0.001;
    final x1 = x(time - delta);
    final x2 = x(time + delta);
    return (x2 - x1) / (2 * delta);
  }

  @override
  bool isDone(double time) => time >= _duration - tolerance.time;
}

/// Extension methods for [Motion] to provide convenient trimming functionality.
///
/// **Important**: Trimming behavior varies by motion type:
/// * **Deterministic motions** (like [CurvedMotion]): Trimming is exact and
///   produces precisely the requested portion of the motion curve.
/// * **Physics-based motions** (like [SpringMotion]): Trimming is an
///   approximation that extends the simulation range and maps progress back
///   to the desired output. The result approximates the characteristic curve
///   behavior but may not be perfectly accurate to the original motion's
///   physics at every point.
extension MotionTrimming on Motion {
  /// {@macro TrimmedMotion}
  ///
  /// Parameters:
  ///   * [fromStart] - Amount to trim from the beginning (0.0 = no trim)
  ///   * [fromEnd] - Amount to trim from the end (0.0 = no trim)
  ///
  /// Example:
  /// ```dart
  /// // Exact trimming for curves
  /// final curve = CurvedMotion(Duration(seconds: 1));
  /// final trimmedCurve = curve.trimmed(fromStart: 0.1, fromEnd: 0.1);
  ///
  /// // Approximate trimming for springs
  /// final spring = CupertinoMotion();
  /// final trimmedSpring = spring.trimmed(fromStart: 0.1, fromEnd: 0.1);
  /// ```
  TrimmedMotion trimmed({
    double fromStart = 0.0,
    double fromEnd = 0.0,
  }) {
    return TrimmedMotion(
      parent: this,
      fromStart: fromStart,
      fromEnd: fromEnd,
    );
  }

  /// Creates a [TrimmedMotion] that represents a slice of this motion.
  TrimmedMotion sliced({
    double from = 0.0,
    double to = 1.0,
  }) {
    assert(from >= 0.0 && from <= 1.0, 'from must be between 0 and 1');
    assert(to >= 0.0 && to <= 1.0, 'to must be between 0 and 1');
    assert(from <= to, 'from cannot be greater than to');
    return TrimmedMotion(
      parent: this,
      fromStart: from,
      fromEnd: 1.0 - to,
    );
  }

  /// Creates a [TrimmedMotion] that uses a sub-extent of this motion.
  TrimmedMotion segment({
    required double length,
    double start = 0.0,
  }) {
    assert(start + length <= 1.0, 'start + length cannot be larger than 1');
    return TrimmedMotion(
      parent: this,
      fromStart: start,
      fromEnd: 1.0 - (start + length),
    );
  }
}

extension on Duration {
  double toSeconds() => inMicroseconds / Duration.microsecondsPerSecond;
}
