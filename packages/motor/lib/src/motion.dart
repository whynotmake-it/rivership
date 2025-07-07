import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/src/simulations/curve_simulation.dart';
import 'package:motor/src/simulations/end_velocity_spring_simulation.dart';

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
/// [CurvedMotion] implements a motion that follows a specific [Curve] over
/// a fixed [Duration]. This is the most common type of animation in Flutter,
/// similar to what is used with [AnimationController.animateTo].
///
/// This motion always completes in the specified duration and does not need to
/// settle.
@immutable
class CurvedMotion extends Motion {
  /// Creates a motion with a fixed duration and curve.
  const CurvedMotion({
    required this.duration,
    this.curve = Curves.linear,
  }) : super(tolerance: const Tolerance(distance: 0, time: 0, velocity: 0));

  /// The total duration of the motion.
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
      CurvedMotion(
        duration: duration ?? this.duration,
        curve: curve ?? this.curve,
      );

  /// Applies [curve] to the current [duration].
  CurvedMotion withCurve(Curve curve) => copyWith(curve: curve);

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
  String toString() => 'CurvedMotion(duration: $duration, curve: $curve)';
}

/// A convenience class for a [CurvedMotion] that uses a linear curve.
class LinearMotion extends CurvedMotion {
  /// Creates a linear motion with a fixed duration.
  ///
  /// The curve is set to [Curves.linear] by default.
  const LinearMotion({required super.duration}) : super(curve: Curves.linear);

  @override
  String toString() => 'LinearMotion(duration: $duration)';
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
abstract class SpringMotion extends Motion {
  /// Creates a motion with spring physics.
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

  /// Whether to snap to the end of the spring.
  ///
  /// If true, the spring will snap to the end of the motion when the simulation
  /// is done.
  /// This ensures that the simulation will settle exactly to the target value.
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

/// A collection of spring motions that are commonly used in Cupertino apps.
class CupertinoMotion extends SpringMotion {
  /// Creates a new [CupertinoMotion] with the specified duration and bounce.
  ///
  /// The duration is the duration of the spring motion, and the bounce is the
  /// amount of bounce in the spring motion.
  ///
  /// By default, this creates a smooth spring with no bounce, matching the
  /// [standard iOS spring motion behavior](https://developer.apple.com/documentation/swiftui/animation/default).
  const CupertinoMotion({
    this.duration = const Duration(milliseconds: 550),
    this.bounce = 0,
    super.snapToEnd,
  }) : super._();

  /// A spring animation with a predefined duration and higher amount of bounce.
  ///
  /// See also:
  /// * https://developer.apple.com/documentation/swiftui/animation/bouncy
  const CupertinoMotion.bouncy({
    Duration duration = const Duration(milliseconds: 500),
    double extraBounce = 0.0,
    bool snapToEnd = true,
  }) : this(
          duration: duration,
          bounce: 0.3 + extraBounce,
          snapToEnd: snapToEnd,
        );

  /// A spring animation with a predefined duration and small amount of bounce
  /// that feels more snappy.
  ///
  /// See also:
  /// * https://developer.apple.com/documentation/swiftui/animation/snappy
  const CupertinoMotion.snappy({
    Duration duration = const Duration(milliseconds: 500),
    double extraBounce = 0.0,
    bool snapToEnd = true,
  }) : this(
          duration: duration,
          bounce: 0.15 + extraBounce,
          snapToEnd: snapToEnd,
        );

  /// A smooth spring animation with a predefined duration and no bounce.
  ///
  /// See also:
  /// * https://developer.apple.com/documentation/swiftui/animation/smooth
  const CupertinoMotion.smooth({
    Duration duration = const Duration(milliseconds: 500),
    double extraBounce = 0.0,
    bool snapToEnd = true,
  }) : this(
          duration: duration,
          bounce: extraBounce,
          snapToEnd: snapToEnd,
        );

  /// A spring animation with a lower response value,
  /// intended for driving interactive animations.
  ///
  /// See also:
  /// * https://developer.apple.com/documentation/swiftui/animation/interactivespring(response:dampingfraction:blendduration:)
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
  const MaterialSpringMotion({
    required this.damping,
    required this.stiffness,
    super.snapToEnd,
  }) : super._();

  /// The damping factor of the spring motion.
  ///
  /// Works exactly like the [SpringDescription.damping] property.
  final double damping;

  /// The stiffness factor of the spring motion.
  ///
  /// Works exactly like the [SpringDescription.stiffness] property.
  final double stiffness;

  @override
  SpringDescription get description => SpringDescription(
        damping: damping,
        stiffness: stiffness,
        mass: 1,
      );

  /// Standard spatial motion token - fast variant.
  ///
  /// Used for quick spatial animations like position changes, resizing,
  /// and layout transitions. This is the fastest of the standard spatial
  /// motion tokens.
  ///
  /// **Damping**: 0.9, **Stiffness**: 1400, **Mass**: 1
  static const standardSpatialFast = MaterialSpringMotion(
    damping: 0.9,
    stiffness: 1400,
  );

  /// Standard spatial motion token - default variant.
  ///
  /// The recommended spatial motion for most position changes, resizing,
  /// and layout transitions. Provides a balanced animation speed.
  ///
  /// **Damping**: 0.9, **Stiffness**: 700, **Mass**: 1
  static const standardSpatialDefault = MaterialSpringMotion(
    damping: 0.9,
    stiffness: 700,
  );

  /// Standard spatial motion token - slow variant.
  ///
  /// Used for deliberate spatial animations where a slower, more gentle
  /// motion is desired for position changes, resizing, and layout transitions.
  ///
  /// **Damping**: 0.9, **Stiffness**: 300, **Mass**: 1
  static const standardSpatialSlow = MaterialSpringMotion(
    damping: 0.9,
    stiffness: 300,
  );

  /// Standard effects motion token - fast variant.
  ///
  /// Used for quick visual property animations like opacity, color,
  /// and other non-spatial effects. This is the fastest of the standard
  /// effects motion tokens.
  ///
  /// **Damping**: 1, **Stiffness**: 3800, **Mass**: 1
  static const standardEffectsFast = MaterialSpringMotion(
    damping: 1,
    stiffness: 3800,
  );

  /// Standard effects motion token - default variant.
  ///
  /// The recommended effects motion for most visual property animations
  /// like opacity, color, and other non-spatial effects. Provides a
  /// balanced animation speed.
  ///
  /// **Damping**: 1, **Stiffness**: 1600, **Mass**: 1
  static const standardEffectsDefault = MaterialSpringMotion(
    damping: 1,
    stiffness: 1600,
  );

  /// Standard effects motion token - slow variant.
  ///
  /// Used for deliberate visual property animations where a slower,
  /// more gentle motion is desired for opacity, color, and other
  /// non-spatial effects.
  ///
  /// **Damping**: 1, **Stiffness**: 800, **Mass**: 1
  static const standardEffectsSlow = MaterialSpringMotion(
    damping: 1,
    stiffness: 800,
  );

  /// Expressive spatial motion token - fast variant.
  ///
  /// Used for more dynamic and bouncy spatial animations with increased
  /// expressiveness. Features lower damping for more spring-like behavior
  /// in position changes, resizing, and layout transitions.
  ///
  /// **Damping**: 0.6, **Stiffness**: 800, **Mass**: 1
  static const expressiveSpatialFast = MaterialSpringMotion(
    damping: 0.6,
    stiffness: 800,
  );

  /// Expressive spatial motion token - default variant.
  ///
  /// The recommended expressive spatial motion for creating more dynamic
  /// and bouncy animations with moderate expressiveness. Features lower
  /// damping for spring-like behavior in spatial transitions.
  ///
  /// **Damping**: 0.8, **Stiffness**: 380, **Mass**: 1
  static const expressiveSpatialDefault = MaterialSpringMotion(
    damping: 0.8,
    stiffness: 380,
  );

  /// Expressive spatial motion token - slow variant.
  ///
  /// Used for slower, more deliberate expressive spatial animations
  /// with gentle spring-like behavior. Features lower damping for
  /// increased bounce in position changes and layout transitions.
  ///
  /// **Damping**: 0.8, **Stiffness**: 200, **Mass**: 1
  static const expressiveSpatialSlow = MaterialSpringMotion(
    damping: 0.8,
    stiffness: 200,
  );

  /// Expressive effects motion token - fast variant.
  ///
  /// Used for quick expressive visual property animations. While maintaining
  /// the same spring characteristics as standard effects, this token is part
  /// of the expressive motion system for consistent design language.
  ///
  /// **Damping**: 1, **Stiffness**: 3800, **Mass**: 1
  static const expressiveEffectsFast = MaterialSpringMotion(
    damping: 1,
    stiffness: 3800,
  );

  /// Expressive effects motion token - default variant.
  ///
  /// The recommended expressive effects motion for visual property animations
  /// like opacity and color. Part of the expressive motion system while
  /// maintaining optimal characteristics for non-spatial effects.
  ///
  /// **Damping**: 1, **Stiffness**: 1600, **Mass**: 1
  static const expressiveEffectsDefault = MaterialSpringMotion(
    damping: 1,
    stiffness: 1600,
  );

  /// Expressive effects motion token - slow variant.
  ///
  /// Used for slower, more deliberate expressive visual property animations.
  /// Part of the expressive motion system while maintaining characteristics
  /// optimized for opacity, color, and other non-spatial effects.
  ///
  /// **Damping**: 1, **Stiffness**: 800, **Mass**: 1
  static const expressiveEffectsSlow = MaterialSpringMotion(
    damping: 1,
    stiffness: 800,
  );

  @override
  MaterialSpringMotion copyWith({
    double? damping,
    double? stiffness,
    bool? snapToEnd,
  }) {
    return MaterialSpringMotion(
      damping: damping ?? this.damping,
      stiffness: stiffness ?? this.stiffness,
      snapToEnd: snapToEnd ?? this.snapToEnd,
    );
  }
}

/// A spring motion that arrives at the target with a specified end velocity.
///
/// [EndVelocitySpringMotion] extends [SpringMotion] to provide spring-based
/// animation that reaches the target position with a specific velocity rather
/// than settling at zero velocity. This is useful for creating smooth
/// transitions between animations or for motion that continues with momentum.
///
/// The motion uses the same spring physics as [SpringMotion] but modifies
/// the simulation to achieve the desired end velocity at the target position.
@immutable
class EndVelocitySpringMotion extends SpringMotion {
  /// Creates a spring motion that arrives at the target with the specified
  /// end velocity.
  ///
  /// Parameters:
  ///   * [description] - The spring characteristics (mass, stiffness, damping)
  ///   * [endVelocity] - The desired velocity when reaching the target position
  ///   * [snapToEnd] - Whether to snap to the end position when done
  const EndVelocitySpringMotion(
    this.description, {
    required this.endVelocity,
    super.snapToEnd,
  }) : super._();

  @override
  final SpringDescription description;

  /// The desired velocity when the motion reaches the target position.
  ///
  /// Unlike regular spring motion which settles to zero velocity, this motion
  /// will arrive at the target with this specific velocity value.
  final double endVelocity;

  @override
  Simulation createSimulation({
    double start = 0,
    double end = 1,
    double velocity = 0,
  }) {
    return EndVelocitySpringSimulation(
      description,
      start,
      end,
      velocity,
      endVelocity,
      tolerance: tolerance,
    );
  }

  @override
  bool operator ==(Object other) {
    if (other is EndVelocitySpringMotion) {
      return description.damping == other.description.damping &&
          description.mass == other.description.mass &&
          description.stiffness == other.description.stiffness &&
          endVelocity == other.endVelocity;
    }
    return false;
  }

  @override
  int get hashCode => Object.hash(
        description.damping,
        description.mass,
        description.stiffness,
        endVelocity,
      );

  @override
  String toString() => 'EndVelocitySpringMotion('
      'description: $description, endVelocity: $endVelocity)';

  @override
  EndVelocitySpringMotion copyWith({
    SpringDescription? description,
    double? endVelocity,
    bool? snapToEnd,
  }) {
    return EndVelocitySpringMotion(
      description ?? this.description,
      endVelocity: endVelocity ?? this.endVelocity,
      snapToEnd: snapToEnd ?? this.snapToEnd,
    );
  }
}
