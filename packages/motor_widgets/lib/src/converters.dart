import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:vector_math/vector_math_64.dart' show Quaternion, Vector3;

const _nonNegative = MotionDimension.bounded(0, double.infinity);

/// Equality for converters without fields: equal when of the same type.
mixin _EqualByType<T> on MotionConverter<T> {
  @override
  bool operator ==(Object other) => other.runtimeType == runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// A [double] that is shown within `[0, 1]`, such as an opacity.
///
/// The spring may overshoot; only the value handed to the builder is
/// clamped, so the overshoot's velocity is kept.
class UnitIntervalMotionConverter extends MotionConverter<double>
    with _EqualByType<double>, DirectionalMotionConverter<double> {
  /// Creates a [UnitIntervalMotionConverter].
  const UnitIntervalMotionConverter();

  @override
  List<MotionDimension> get dimensions => const [MotionDimension.bounded(0, 1)];

  @override
  List<double> normalize(double value) => [value];

  @override
  double denormalize(List<double> values) => values[0];

  @override
  int compare(double a, double b) => a.compareTo(b);
}

/// A [double] that is never shown below zero, such as a width.
class NonNegativeMotionConverter extends MotionConverter<double>
    with _EqualByType<double>, DirectionalMotionConverter<double> {
  /// Creates a [NonNegativeMotionConverter].
  const NonNegativeMotionConverter();

  @override
  List<MotionDimension> get dimensions => const [
    MotionDimension.bounded(0, double.infinity),
  ];

  @override
  List<double> normalize(double value) => [value];

  @override
  double denormalize(List<double> values) => values[0];

  @override
  int compare(double a, double b) => a.compareTo(b);
}

/// A [Size] that is never shown below zero in either dimension.
class NonNegativeSizeMotionConverter extends MotionConverter<Size>
    with _EqualByType<Size> {
  /// Creates a [NonNegativeSizeMotionConverter].
  const NonNegativeSizeMotionConverter();

  @override
  List<MotionDimension> get dimensions => const [
    MotionDimension.bounded(0, double.infinity),
    MotionDimension.bounded(0, double.infinity),
  ];

  @override
  List<double> normalize(Size value) => [value.width, value.height];

  @override
  Size denormalize(List<double> values) => Size(values[0], values[1]);
}

/// A [BorderRadius]: the x and y radius of each corner.
///
/// Radii are never shown below zero.
class BorderRadiusMotionConverter extends MotionConverter<BorderRadius>
    with _EqualByType<BorderRadius> {
  /// Creates a [BorderRadiusMotionConverter].
  const BorderRadiusMotionConverter();

  @override
  List<MotionDimension> get dimensions =>
      const [_nonNegative, _nonNegative, _nonNegative, _nonNegative] +
      const [_nonNegative, _nonNegative, _nonNegative, _nonNegative];

  @override
  List<double> normalize(BorderRadius value) => [
    value.topLeft.x,
    value.topLeft.y,
    value.topRight.x,
    value.topRight.y,
    value.bottomLeft.x,
    value.bottomLeft.y,
    value.bottomRight.x,
    value.bottomRight.y,
  ];

  @override
  BorderRadius denormalize(List<double> values) => BorderRadius.only(
    topLeft: Radius.elliptical(values[0], values[1]),
    topRight: Radius.elliptical(values[2], values[3]),
    bottomLeft: Radius.elliptical(values[4], values[5]),
    bottomRight: Radius.elliptical(values[6], values[7]),
  );
}

/// A [Matrix4], animated the way `Matrix4Tween` interpolates one: decomposed
/// into translation, rotation (as a quaternion) and scale.
///
/// The rotation is renormalized when the value is read, so a spring that
/// overshoots still yields a pure rotation. Like `Matrix4Tween`, perspective
/// and skew are not preserved.
class Matrix4MotionConverter extends MotionConverter<Matrix4>
    with _EqualByType<Matrix4> {
  /// Creates a [Matrix4MotionConverter].
  const Matrix4MotionConverter();

  @override
  List<double> normalize(Matrix4 value) {
    final translation = Vector3.zero();
    final rotation = Quaternion.identity();
    final scale = Vector3.zero();
    value.decompose(translation, rotation, scale);
    return [
      translation.x,
      translation.y,
      translation.z,
      rotation.x,
      rotation.y,
      rotation.z,
      rotation.w,
      scale.x,
      scale.y,
      scale.z,
    ];
  }

  @override
  Matrix4 denormalize(List<double> values) {
    final rotation = Quaternion(values[3], values[4], values[5], values[6]);
    if (rotation.length == 0) {
      rotation.setValues(0, 0, 0, 1);
    } else {
      rotation.normalize();
    }
    return Matrix4.compose(
      Vector3(values[0], values[1], values[2]),
      rotation,
      Vector3(values[7], values[8], values[9]),
    );
  }
}
