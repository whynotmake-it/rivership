import 'package:flutter/rendering.dart';

/// A function that converts a value of type [T] to a list of double values.
typedef Normalize<T> = List<double> Function(T value);

/// A function that converts a list of double values back to a value of type [T]
typedef Denormalize<T> = T Function(List<double> values);

/// A converter that handles normalization and denormalization of values
/// for motion controllers.
///
/// This allows for different value types to be animated by converting them
/// to and from lists of doubles that can be used by the animation system.
///
/// See also:
abstract interface class MotionConverter<T> {
  /// Creates a motion converter with normalize and denormalize functions.
  const factory MotionConverter({
    required Normalize<T> normalize,
    required Denormalize<T> denormalize,
  }) = _CallbackMotionConverter<T>;

  /// Converts a value of type [T] to a list of double values.
  List<double> normalize(T value);

  /// Converts a list of double values back to a value of type [T].
  T denormalize(List<double> values);
}

/// A [MotionConverter] for double values.
class SingleMotionConverter implements MotionConverter<double> {
  /// Creates a [SingleMotionConverter].
  const SingleMotionConverter();

  @override
  List<double> normalize(double value) => [value];

  @override
  double denormalize(List<double> values) => values[0];
}

/// A [MotionConverter] for [Offset] values.
class OffsetMotionConverter implements MotionConverter<Offset> {
  /// Creates an [OffsetMotionConverter].
  const OffsetMotionConverter();

  @override
  List<double> normalize(Offset value) => [value.dx, value.dy];

  @override
  Offset denormalize(List<double> values) => Offset(values[0], values[1]);
}

/// A [MotionConverter] for [Size] values.
class SizeMotionConverter implements MotionConverter<Size> {
  /// Creates a [SizeMotionConverter].
  const SizeMotionConverter();

  @override
  List<double> normalize(Size value) => [value.width, value.height];

  @override
  Size denormalize(List<double> values) => Size(values[0], values[1]);
}

/// A [MotionConverter] for [Rect] values.
class RectMotionConverter implements MotionConverter<Rect> {
  /// Creates a [RectMotionConverter].
  const RectMotionConverter();

  @override
  List<double> normalize(Rect value) => [
        value.left,
        value.top,
        value.right,
        value.bottom,
      ];

  @override
  Rect denormalize(List<double> values) => Rect.fromLTRB(
        values[0],
        values[1],
        values[2],
        values[3],
      );
}

/// A [MotionConverter] for [Alignment] values.
class AlignmentMotionConverter implements MotionConverter<Alignment> {
  /// Creates an [AlignmentMotionConverter].
  const AlignmentMotionConverter();

  @override
  List<double> normalize(Alignment value) => [value.x, value.y];

  @override
  Alignment denormalize(List<double> values) => Alignment(values[0], values[1]);
}

class _CallbackMotionConverter<T> implements MotionConverter<T> {
  const _CallbackMotionConverter({
    required Normalize<T> normalize,
    required Denormalize<T> denormalize,
  })  : _normalize = normalize,
        _denormalize = denormalize;

  final Normalize<T> _normalize;

  final Denormalize<T> _denormalize;
  @override
  List<double> normalize(T value) => _normalize(value);

  @override
  T denormalize(List<double> values) => _denormalize(values);
}
