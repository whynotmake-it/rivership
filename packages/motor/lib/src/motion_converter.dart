import 'dart:ui';

import 'package:flutter/animation.dart' show AnimationStatus;
import 'package:flutter/rendering.dart';
import 'package:motor/src/controllers/motion_controller.dart'
    show MotionController;

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
/// If your values have a defined order (e.g., [double], [int], etc.), consider
/// using [DirectionalMotionConverter] instead to provide directionality
/// information to motion controllers.
abstract class MotionConverter<T> {
  /// Creates a motion converter.
  const MotionConverter();

  /// Creates a motion converter with normalize and denormalize functions.
  ///
  /// See [MotionConverter] for more information.
  const factory MotionConverter.custom({
    required Normalize<T> normalize,
    required Denormalize<T> denormalize,
  }) = _CallbackMotionConverter<T>;

  /// Creates a directional motion converter with normalize, denormalize and
  /// compare functions.
  ///
  /// See [DirectionalMotionConverter] for more information about
  /// directionality.
  const factory MotionConverter.customDirectional({
    required Normalize<T> normalize,
    required Denormalize<T> denormalize,
    required int Function(T a, T b) compare,
  }) = _CallbackDirectionalMotionConverter<T>;

  /// A motion converter for single values.
  static const single = SingleMotionConverter();

  /// A motion converter for offset values.
  static const offset = OffsetMotionConverter();

  /// A motion converter for size values.
  static const size = SizeMotionConverter();

  /// A motion converter for rect values.
  static const rect = RectMotionConverter();

  /// A motion converter for alignment values.
  static const alignment = AlignmentMotionConverter();

  /// A motion converter for color values that interpolates in RGB space.
  static const colorRgb = ColorRgbMotionConverter();

  /// A motion converter for [EdgeInsets] values.
  static const edgeInsets = EdgeInsetsMotionConverter();

  /// A motion converter for [EdgeInsetsDirectional] values.
  static const edgeInsetsDirectional = EdgeInsetsDirectionalMotionConverter();

  /// Converts a value of type [T] to a list of double values.
  List<double> normalize(T value);

  /// Converts a list of double values back to a value of type [T].
  T denormalize(List<double> values);

  /// Linearly interpolates between [a] and [b] using [t] by interpolating each
  /// dimension individually.
  T lerp(T a, T b, double t) {
    final aValues = normalize(a);
    final bValues = normalize(b);
    final resultValues = <double>[];
    for (var i = 0; i < aValues.length; i++) {
      resultValues.add(lerpDouble(aValues[i], bValues[i], t)!);
    }
    return denormalize(resultValues);
  }
}

/// A [MotionConverter] that provides additional information about whether a
/// motion is forward or backwards by exposing a [compare] method.
///
/// Passing a [DirectionalMotionConverter] will lead to the animation status of
/// associated [MotionController]s to correctly report [AnimationStatus.reverse]
/// when animating backwards.
///
/// Most multi-dimensional types where directionality is not well-defined
/// (e.g., [Offset], [Color], etc.) should stick to using a regular
/// [MotionConverter] without directionality.
///
/// However, in certain cases, you might want to define a custom directionality.
/// You could for example implement a custom variant of [SizeMotionConverter]
/// that compares the area (width * height) of two [Size]s to determine which
/// one is "greater".
///
/// ```dart
/// class AreaSizeMotionConverter extends SizeMotionConverter
///     with DirectionalMotionConverter<Size> {
///   @override
///   int compare(Size a, Size b) {
///     final areaA = a.width * a.height;
///     final areaB = b.width * b.height;
///     return areaA.compareTo(areaB);
///   }
/// }
mixin DirectionalMotionConverter<T> on MotionConverter<T> {
  /// Compares two values of type [T] for figuring out directionality.
  ///
  /// Like [Comparable.compare], this should return a negative integer if
  /// [a] is less than [b], zero if they are equal, and a positive integer if
  /// [a] is greater than [b].
  int compare(T a, T b);
}

/// Adds [compare] implementation to a [MotionConverter] for types that
/// implement [Comparable].
mixin ComparableMotionConverter<T extends Comparable<dynamic>>
    on MotionConverter<T> implements DirectionalMotionConverter<T> {
  @override
  int compare(T a, T b) => a.compareTo(b);
}

/// A [MotionConverter] for double values.
class SingleMotionConverter extends MotionConverter<double>
    with ComparableMotionConverter<double> {
  /// Creates a [SingleMotionConverter].
  const SingleMotionConverter();

  @override
  List<double> normalize(double value) => [value];

  @override
  double denormalize(List<double> values) => values[0];
}

/// A [MotionConverter] for [Offset] values.
class OffsetMotionConverter extends MotionConverter<Offset> {
  /// Creates an [OffsetMotionConverter].
  const OffsetMotionConverter();

  @override
  List<double> normalize(Offset value) => [value.dx, value.dy];

  @override
  Offset denormalize(List<double> values) => Offset(values[0], values[1]);
}

/// A [MotionConverter] for [Size] values.
class SizeMotionConverter extends MotionConverter<Size> {
  /// Creates a [SizeMotionConverter].
  const SizeMotionConverter();

  @override
  List<double> normalize(Size value) => [value.width, value.height];

  @override
  Size denormalize(List<double> values) => Size(values[0], values[1]);
}

/// A [MotionConverter] for [Rect] values.
class RectMotionConverter extends MotionConverter<Rect> {
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
class AlignmentMotionConverter extends MotionConverter<Alignment> {
  /// Creates an [AlignmentMotionConverter].
  const AlignmentMotionConverter();

  @override
  List<double> normalize(Alignment value) => [value.x, value.y];

  @override
  Alignment denormalize(List<double> values) => Alignment(values[0], values[1]);
}

/// A [MotionConverter] for [Color] values that interpolates in RGB space.
class ColorRgbMotionConverter extends MotionConverter<Color> {
  /// Creates a [ColorRgbMotionConverter].
  const ColorRgbMotionConverter();

  @override
  List<double> normalize(Color value) => [
        value.r,
        value.g,
        value.b,
        value.a,
      ];

  @override
  Color denormalize(List<double> values) => Color.from(
        red: values[0].clamp(0, 1),
        green: values[1].clamp(0, 1),
        blue: values[2].clamp(0, 1),
        alpha: values[3].clamp(0, 1),
      );
}

/// A [MotionConverter] for [EdgeInsets] values.
class EdgeInsetsMotionConverter extends MotionConverter<EdgeInsets> {
  /// Creates a [EdgeInsetsMotionConverter].
  const EdgeInsetsMotionConverter();

  @override
  List<double> normalize(EdgeInsets value) => [
        value.left,
        value.top,
        value.right,
        value.bottom,
      ];

  @override
  EdgeInsets denormalize(List<double> values) => EdgeInsets.fromLTRB(
        values[0],
        values[1],
        values[2],
        values[3],
      );
}

/// A [MotionConverter] for [EdgeInsetsDirectional] values.
class EdgeInsetsDirectionalMotionConverter
    extends MotionConverter<EdgeInsetsDirectional> {
  /// Creates a [EdgeInsetsDirectionalMotionConverter].
  const EdgeInsetsDirectionalMotionConverter();

  @override
  List<double> normalize(EdgeInsetsDirectional value) => [
        value.start,
        value.top,
        value.end,
        value.bottom,
      ];

  @override
  EdgeInsetsDirectional denormalize(List<double> values) =>
      EdgeInsetsDirectional.fromSTEB(
        values[0],
        values[1],
        values[2],
        values[3],
      );
}

class _CallbackMotionConverter<T> extends MotionConverter<T> {
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

class _CallbackDirectionalMotionConverter<T> extends MotionConverter<T>
    with DirectionalMotionConverter<T> {
  const _CallbackDirectionalMotionConverter({
    required Normalize<T> normalize,
    required Denormalize<T> denormalize,
    required int Function(T a, T b) compare,
  })  : _normalize = normalize,
        _denormalize = denormalize,
        _compare = compare;

  final Normalize<T> _normalize;

  final Denormalize<T> _denormalize;

  final int Function(T a, T b) _compare;

  @override
  List<double> normalize(T value) => _normalize(value);

  @override
  T denormalize(List<double> values) => _denormalize(values);

  @override
  int compare(T a, T b) => _compare(a, b);
}
