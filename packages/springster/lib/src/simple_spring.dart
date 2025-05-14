import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

const _defaultDurationSeconds = 0.5;

const _deprecationMessage =
    'Use `Spring` and `CupertinoMotion` instead. See class '
    'documentation for migration guide regarding negative bounce values.';

/// A persistent spring animation that is based on a duration in seconds
/// and a bounce, or damping fraction.
///
/// Mostly adapted from
/// [`fluid_animations`](https://pub.dev/packages/fluid_animations).
///
/// ## Migration to Flutter SDK's SpringDescription.withDurationAndBounce
///
/// This class is deprecated in favor of Flutter SDK's built-in
/// `SpringDescription.withDurationAndBounce()`. However, there are important
/// behavioral differences for negative bounce values (overdamped springs):
///
/// ### For non-negative bounce values (0 ≤ bounce ≤ 1):
/// Both implementations produce identical results and can be migrated directly:
/// ```dart
/// // Old
/// SimpleSpring(bounce: 0.5, durationSeconds: 1.0)
///
/// // New
/// SpringDescription.withDurationAndBounce(
///   bounce: 0.5,
///   duration: Duration(seconds: 1)
/// )
/// ```
///
/// ### For negative bounce values (overdamped springs):
/// The implementations use different mathematical formulas and produce
/// different spring behaviors:
///
/// **SimpleSpring formula:**
/// ```
/// damping = 4π(1 - bounce) / duration
/// ```
///
/// **Flutter SDK formula:**
/// ```
/// dampingRatio = 1 / (bounce + 1)  // for negative bounce
/// damping = dampingRatio * 2 * sqrt(mass * stiffness)
/// ```
///
/// **Example with bounce = -0.5, duration = 1s:**
/// - SimpleSpring: `damping ≈ 18.85`
/// - Flutter SDK: `damping ≈ 25.1`
///
/// This results in different settling behaviors for overdamped springs.
/// If you rely on specific overdamped spring behavior, you may need to
/// adjust your bounce values when migrating, or continue using this class
/// until you can test and adjust the visual behavior.
///
/// ### Migration strategy:
/// 1. For bounce ≥ 0: Direct migration with identical behavior
/// 2. For bounce < 0: Test visual behavior and potentially adjust bounce values
/// 3. Consider using `SpringDescription` with explicit mass/stiffness/damping
///    if you need exact control over spring physics
@Deprecated(_deprecationMessage)
@immutable
class SimpleSpring extends SpringDescription {
  /// Creates a spring with the specified duration and bounce.
  ///
  /// A smooth spring with a response duration and no bounce is created by
  /// default.
  @Deprecated(_deprecationMessage)
  const SimpleSpring({
    this.durationSeconds = _defaultDurationSeconds,
    this.bounce = 0,
  })  : assert(
          -1 <= bounce && bounce <= 1,
          'The bounce value needs to be in a range of -1 to 1.',
        ),
        super(
          mass: 1,
          stiffness: durationSeconds > 0
              ? (2 * pi / durationSeconds) * (2 * pi / durationSeconds)
              : _instantStiffness,
          damping: durationSeconds > 0
              ? 4 * pi * (1 - bounce) / durationSeconds
              : _instantDamping,
        );

  /// Creates a persistent spring that is based on duration
  /// and damping fraction.
  ///
  /// [dampingFraction] is the amount of drag applied to the value being
  /// animated, as a fraction of an estimate of amount needed to produce
  /// critical damping.
  /// It is effectively the inverse of the bounce amount.
  ///
  ///
  /// A smooth spring with a response duration and no bounce is created by
  /// default.
  @Deprecated(_deprecationMessage)
  const SimpleSpring.withDamping({
    double dampingFraction = 1.0,
    this.durationSeconds = _defaultDurationSeconds,
  })  : bounce = 1 - dampingFraction,
        super(
          mass: 1,
          stiffness: durationSeconds > 0
              ? (2 * pi / durationSeconds) * (2 * pi / durationSeconds)
              : _instantStiffness,
          damping: durationSeconds > 0
              ? 4 * pi * dampingFraction / durationSeconds
              : _instantDamping,
        );

  /// Defines the pace of the spring.
  ///
  /// This is approximately equal to the settling duration,
  /// but for springs with very large bounce values, will be the duration of
  /// the period of oscillation for the spring.
  final double durationSeconds;

  /// How bouncy the spring should be.
  ///
  /// A value of 0 indicates no bounces (a critically damped spring),
  /// positive values indicate increasing amounts of bounciness up to a maximum
  /// of 1.0 (corresponding to undamped oscillation), and negative values
  /// indicate overdamped springs with a minimum value of -1.0.
  @override
  final double bounce;

  /// The amount of drag applied to the value being
  /// animated, as a fraction of an estimate of amount needed to produce
  /// critical damping.
  ///
  /// It is effectively the inverse of the bounce amount.
  ///
  /// See also:
  /// - [SimpleSpring.withDamping]
  double get dampingFraction => 1 - bounce;

  static const _instantStiffness = 10e15;
  static const _instantDamping = 10e3;

  /// Creates a new [SimpleSpring] with the specified properties.
  SimpleSpring copyWith({
    double? bounce,
    double? durationSeconds,
  }) =>
      SimpleSpring(
        bounce: bounce ?? this.bounce,
        durationSeconds: durationSeconds ?? this.durationSeconds,
      );

  /// Creates a new [SimpleSpring] with the specified properties.
  SimpleSpring copyWithDamping({
    double? dampingFraction,
    double? durationSeconds,
  }) =>
      SimpleSpring.withDamping(
        dampingFraction: dampingFraction ?? this.dampingFraction,
        durationSeconds: durationSeconds ?? this.durationSeconds,
      );

  @override
  String toString() {
    // ignore: lines_longer_than_80_chars
    return '${objectRuntimeType(this, 'Spring')}(bounce: $bounce, duration: $durationSeconds)';
  }

  @override
  bool operator ==(Object other) =>
      other is SimpleSpring &&
      other.durationSeconds == durationSeconds &&
      other.bounce == bounce;

  @override
  int get hashCode => Object.hash(durationSeconds, bounce);
}
