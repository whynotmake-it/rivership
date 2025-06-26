import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

const _defaultDurationSeconds = 0.5;

/// A persistent spring animation that is based on response
/// and damping fraction.
///
/// Mostly adapted from
/// [`fluid_animations`](https://pub.dev/packages/fluid_animations).
@immutable
class Spring extends SpringDescription {
  /// Creates a spring with the specified duration and bounce.
  ///
  /// A smooth spring with a response duration and no bounce is created by
  /// default.
  const Spring({
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
  const Spring.withDamping({
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
  /// - [Spring.withDamping]
  double get dampingFraction => 1 - bounce;

  /// An effectively instant spring.
  static const instant = Spring(durationSeconds: 0);

  /// A smooth spring with no bounce.
  ///
  /// This uses the [default values for iOS](https://developer.apple.com/documentation/swiftui/animation/default).
  static const defaultIOS = Spring.withDamping(
    durationSeconds: 0.55,
  );

  /// A spring with a predefined duration and higher amount of bounce.
  static const bouncy = Spring.withDamping(
    dampingFraction: 0.7,
  );

  /// A spring with a predefined response and small amount of bounce
  /// that feels more snappy.
  static const snappy = Spring.withDamping(dampingFraction: 0.85);

  /// A spring animation with a lower response value,
  /// intended for driving interactive animations.
  static const interactive = Spring.withDamping(
    dampingFraction: 0.86,
    durationSeconds: 0.15,
  );

  static const _instantStiffness = 10e15;
  static const _instantDamping = 10e3;

  /// Creates a new [Spring] with the specified properties.
  Spring copyWith({
    double? bounce,
    double? durationSeconds,
  }) =>
      Spring(
        bounce: bounce ?? this.bounce,
        durationSeconds: durationSeconds ?? this.durationSeconds,
      );

  /// Creates a new [Spring] with the specified properties.
  Spring copyWithDamping({
    double? dampingFraction,
    double? durationSeconds,
  }) =>
      Spring.withDamping(
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
      other is Spring &&
      other.durationSeconds == durationSeconds &&
      other.bounce == bounce;

  @override
  int get hashCode => Object.hash(durationSeconds, bounce);
}
