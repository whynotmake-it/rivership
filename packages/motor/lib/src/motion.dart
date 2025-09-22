import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/src/extensions/spring_description_extension.dart';
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
abstract class Motion {
  /// {@macro Motion}
  const Motion({
    this.tolerance = Tolerance.defaultTolerance,
  });

  /// {@macro CurvedMotion}
  const factory Motion.curved(Duration duration, [Curve curve]) = CurvedMotion;

  /// Creates a linear motion with a fixed duration.
  const factory Motion.linear(Duration duration) = LinearMotion;

  /// {@macro NoMotion}
  const factory Motion.none([Duration duration]) = NoMotion;

  /// {@macro SpringMotion}
  const factory Motion.customSpring(SpringDescription spring) = SpringMotion;

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
  final Duration duration;

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
    this.snapToEnd = false,
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
    bool snapToEnd = false,
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
    bool snapToEnd = false,
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
    bool snapToEnd = false,
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
    bool snapToEnd = false,
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
  SpringDescription get description =>
      SpringDescriptionExtension.withDurationAndBounce(
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
    bool snapToEnd = false,
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
    bool snapToEnd = false,
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
    bool snapToEnd = false,
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
    bool snapToEnd = false,
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
    bool snapToEnd = false,
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
    bool snapToEnd = false,
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
    bool snapToEnd = false,
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
    bool snapToEnd = false,
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
    bool snapToEnd = false,
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
    bool snapToEnd = false,
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
    bool snapToEnd = false,
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
    bool snapToEnd = false,
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
/// Example: With `startTrim: 0.2` and `endTrim: 0.2`, your 0→1 motion will
/// use the middle 60% of the parent motion's characteristic curve.
/// {@endtemplate}
@immutable
class TrimmedMotion extends Motion {
  /// {@macro TrimmedMotion}
  ///
  /// Parameters:
  ///   * [parent] - The motion to trim
  ///   * [startTrim] - Amount to trim from the beginning (0.0 = no trim)
  ///   * [endTrim] - Amount to trim from the end (0.0 = no trim)

  const TrimmedMotion({
    required this.parent,
    required this.startTrim,
    required this.endTrim,
  })  : assert(startTrim >= 0.0, 'startTrim must be non-negative'),
        assert(endTrim >= 0.0, 'endTrim must be non-negative'),
        assert(
          startTrim + endTrim <= 1.0,
          'startTrim + endTrim must be less than 1.0, '
          'but received $startTrim + $endTrim',
        );

  /// The motion to trim.
  final Motion parent;

  /// Amount to trim from the start of the motion curve.
  final double startTrim;

  /// Amount to trim from the end of the motion curve.
  final double endTrim;

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
    final trimmedExtent = 1.0 - startTrim - endTrim;

    // We simulate the parent over the extended range
    final parentStart = start - trimmedExtent * startTrim;
    final parentEnd = end + trimmedExtent * endTrim;

    final scaledSim = parent.createSimulation(
      start: parentStart,
      end: parentEnd,
      velocity: velocity,
    );

    return _TrimmedSimulation(
      parent: scaledSim,
      startTrim: startTrim,
      endTrim: endTrim,
      trimmedExtent: trimmedExtent,
      start: start,
      end: end,
    );
  }

  @override
  bool operator ==(Object other) {
    if (other is TrimmedMotion) {
      return parent == other.parent &&
          startTrim == other.startTrim &&
          endTrim == other.endTrim;
    }
    return false;
  }

  @override
  int get hashCode => Object.hash(parent, startTrim, endTrim);

  @override
  String toString() =>
      'TrimmedMotion(parent: $parent, trim: $startTrim-$endTrim)';
}

class _TrimmedSimulation extends Simulation {
  _TrimmedSimulation({
    required this.parent,
    required this.startTrim,
    required this.endTrim,
    required this.trimmedExtent,
    required this.start,
    required this.end,
  })  : _duration = _findParentDuration(parent) * trimmedExtent,
        super(tolerance: parent.tolerance);

  final Simulation parent;
  final double startTrim;
  final double endTrim;
  final double trimmedExtent;
  final double start;
  final double end;
  final double _duration;

  static double _findParentDuration(Simulation parent) {
    // For most simulations, check when isDone returns true
    for (var t = 0.01; t <= 10; t += 0.01) {
      if (parent.isDone(t)) {
        return t;
      }
    }
    return 1; // fallback
  }

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
  ///   * [startTrim] - Amount to trim from the beginning (0.0 = no trim)
  ///   * [endTrim] - Amount to trim from the end (0.0 = no trim)

  ///
  /// Example:
  /// ```dart
  /// // Exact trimming for curves
  /// final curve = CurvedMotion(Duration(seconds: 1));
  /// final trimmedCurve = curve.trimmed(startTrim: 0.1, endTrim: 0.1);
  ///
  /// // Approximate trimming for springs
  /// final spring = CupertinoMotion();
  /// final trimmedSpring = spring.trimmed(startTrim: 0.1, endTrim: 0.1);
  /// ```
  TrimmedMotion trimmed({
    double startTrim = 0.0,
    double endTrim = 0.0,
  }) {
    return TrimmedMotion(
      parent: this,
      startTrim: startTrim,
      endTrim: endTrim,
    );
  }

  /// Creates a [TrimmedMotion] that uses a sub-extent of this motion.
  TrimmedMotion subExtent({
    required double extent,
    double start = 0.0,
  }) {
    assert(start + extent <= 1.0, 'start + extent cannot be larger than 1');
    return TrimmedMotion(
      parent: this,
      startTrim: start,
      endTrim: 1.0 - (start + extent),
    );
  }
}
