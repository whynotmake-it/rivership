import 'dart:math' as math;

import 'package:flutter/animation.dart' show AnimationStatus;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/rendering.dart';
import 'package:meta/meta.dart';
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
///
/// Motor owns the lists on both sides: don't keep or change the list
/// [normalize] returns, or the one [denormalize] receives, after the call.
/// Motor reuses its buffers, so a kept list would change under you. Build a
/// new value from the numbers instead, as motor's own converters do.
///
/// Controllers and builders only swap to a converter that isn't equal to the
/// current one. Motor's converters compare by type, and
/// [MotionConverter.custom] ones by their functions, so pass top-level
/// functions or tear-offs rather than closures created in `build`. A
/// subclass that adds fields should override `==` and `hashCode`.
abstract class MotionConverter<T> {
  /// Creates a motion converter.
  const MotionConverter();

  /// Creates a motion converter with normalize and denormalize functions.
  ///
  /// See [MotionConverter] for more information.
  const factory MotionConverter.custom({
    required Normalize<T> normalize,
    required Denormalize<T> denormalize,
    List<MotionDimension>? dimensions,
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
    List<MotionDimension>? dimensions,
  }) = _CallbackDirectionalMotionConverter<T>;

  /// A motion converter for single values.
  static const single = SingleMotionConverter();

  /// A motion converter for angles in radians, which take the short way round.
  ///
  /// ```dart
  /// MotionController(
  ///   motion: motion,
  ///   vsync: this,
  ///   converter: MotionConverter.angle,
  ///   initialValue: 0,
  /// );
  /// ```
  static const angle = AngleMotionConverter();

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

  /// How each normalized dimension behaves, or null when this converter
  /// doesn't declare them (all linear, count unknown).
  ///
  /// When non-null, its length must match what [normalize] returns; motor
  /// checks `motionPerDimension` against it in debug mode.
  List<MotionDimension>? get dimensions => null;

  /// Converts a value of type [T] to a list of double values.
  ///
  /// Motor may keep the returned list, so don't change it afterwards.
  List<double> normalize(T value);

  /// Converts a list of double values back to a value of type [T].
  ///
  /// [values] is motor's reused buffer and changes after the call, so don't
  /// keep it or change it; read the numbers you need.
  T denormalize(List<double> values);
}

/// How one normalized dimension of a [MotionConverter] behaves.
///
/// Only the presented value is ever clamped; simulation state and velocities
/// are not.
@immutable
final class MotionDimension {
  /// An unbounded dimension, the default: `MotionDimension.linear()`.
  const MotionDimension.linear()
      : period = null,
        min = double.negativeInfinity,
        max = double.infinity;

  /// A dimension that repeats every [period], so targets take the short way
  /// round (350 to 10 degrees moves +20). Values are not wrapped back, so
  /// `value` may leave `[0, period)`: `MotionDimension.periodic(2 * pi)`.
  const MotionDimension.periodic(double this.period)
      : assert(period > 0, 'period must be positive'),
        min = double.negativeInfinity,
        max = double.infinity;

  /// A dimension whose presented value stays within `[min, max]`, while its
  /// overshoot and velocity do not: `MotionDimension.bounded(0, 1)`.
  const MotionDimension.bounded(this.min, this.max)
      : assert(min < max, 'min must be less than max'),
        period = null;

  /// The repeat length of a periodic dimension, otherwise null.
  final double? period;

  /// The lowest presented value, or negative infinity.
  final double min;

  /// The highest presented value, or infinity.
  final double max;

  @override
  bool operator ==(Object other) =>
      other is MotionDimension &&
      other.period == period &&
      other.min == min &&
      other.max == max;

  @override
  int get hashCode => Object.hash(period, min, max);

  @override
  String toString() => period != null
      ? 'periodic($period)'
      : min.isFinite || max.isFinite
          ? 'bounded($min, $max)'
          : 'linear';
}

const _turn = MotionDimension.periodic(2 * math.pi);
const _unit = MotionDimension.bounded(0, 1);
const _linear1 = [MotionDimension.linear()];
const _linear2 = [MotionDimension.linear(), MotionDimension.linear()];
const _linear4 = [
  MotionDimension.linear(),
  MotionDimension.linear(),
  MotionDimension.linear(),
  MotionDimension.linear(),
];

/// Asserts that [count] values or motions match the declared dimensions of
/// [converter]; always returns true.
@internal
bool debugCheckDimensions(MotionConverter<Object?> converter, int count) {
  final expected = converter.dimensions?.length;
  assert(
    expected == null || expected == count,
    '${converter.runtimeType} has $expected dimensions but got $count. '
    'See its documentation for the dimension order.',
  );
  return true;
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
/// ```
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
///
/// Dimensions: value.
class SingleMotionConverter extends MotionConverter<double>
    with ComparableMotionConverter<double>, _EqualByType<double> {
  /// Creates a [SingleMotionConverter].
  const SingleMotionConverter();

  @override
  List<MotionDimension> get dimensions => _linear1;

  @override
  List<double> normalize(double value) => [value];

  @override
  double denormalize(List<double> values) => values[0];
}

/// A [MotionConverter] for angles in radians, animated the short way round.
///
/// Dimensions: value, periodic with a period of 2 pi. The value may leave
/// `[0, 2 pi)`, like an angle that passes a full turn.
///
/// ```dart
/// MotionController(
///   motion: motion,
///   vsync: this,
///   converter: MotionConverter.angle,
///   initialValue: 0,
/// );
/// ```
class AngleMotionConverter extends SingleMotionConverter {
  /// Creates an [AngleMotionConverter].
  const AngleMotionConverter();

  @override
  List<MotionDimension> get dimensions => const [_turn];
}

/// A [MotionConverter] for [Offset] values.
///
/// Dimensions: dx, dy.
class OffsetMotionConverter extends MotionConverter<Offset>
    with _EqualByType<Offset> {
  /// Creates an [OffsetMotionConverter].
  const OffsetMotionConverter();

  @override
  List<MotionDimension> get dimensions => _linear2;

  @override
  List<double> normalize(Offset value) => [value.dx, value.dy];

  @override
  Offset denormalize(List<double> values) => Offset(values[0], values[1]);
}

/// A [MotionConverter] for [Size] values.
///
/// Dimensions: width, height.
class SizeMotionConverter extends MotionConverter<Size>
    with _EqualByType<Size> {
  /// Creates a [SizeMotionConverter].
  const SizeMotionConverter();

  @override
  List<MotionDimension> get dimensions => _linear2;

  @override
  List<double> normalize(Size value) => [value.width, value.height];

  @override
  Size denormalize(List<double> values) => Size(values[0], values[1]);
}

/// A [MotionConverter] for [Rect] values.
///
/// Dimensions: left, top, right, bottom.
class RectMotionConverter extends MotionConverter<Rect>
    with _EqualByType<Rect> {
  /// Creates a [RectMotionConverter].
  const RectMotionConverter();

  @override
  List<MotionDimension> get dimensions => _linear4;

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
///
/// Dimensions: x, y.
class AlignmentMotionConverter extends MotionConverter<Alignment>
    with _EqualByType<Alignment> {
  /// Creates an [AlignmentMotionConverter].
  const AlignmentMotionConverter();

  @override
  List<MotionDimension> get dimensions => _linear2;

  @override
  List<double> normalize(Alignment value) => [value.x, value.y];

  @override
  Alignment denormalize(List<double> values) => Alignment(values[0], values[1]);
}

/// A [MotionConverter] for [Color] values that interpolates in RGB space.
///
/// Dimensions: red, green, blue, alpha, each bounded to 0..1 when presented,
/// so springs may overshoot internally while the shown color stays valid.
/// Velocities read as [Color] keep their sign and may leave 0..1.
class ColorRgbMotionConverter extends MotionConverter<Color>
    with _EqualByType<Color> {
  /// Creates a [ColorRgbMotionConverter].
  const ColorRgbMotionConverter();

  @override
  List<MotionDimension> get dimensions => const [_unit, _unit, _unit, _unit];

  @override
  List<double> normalize(Color value) => [
        value.r,
        value.g,
        value.b,
        value.a,
      ];

  @override
  Color denormalize(List<double> values) => Color.from(
        red: values[0],
        green: values[1],
        blue: values[2],
        alpha: values[3],
      );
}

/// A [MotionConverter] for [EdgeInsets] values.
///
/// Dimensions: left, top, right, bottom.
class EdgeInsetsMotionConverter extends MotionConverter<EdgeInsets>
    with _EqualByType<EdgeInsets> {
  /// Creates a [EdgeInsetsMotionConverter].
  const EdgeInsetsMotionConverter();

  @override
  List<MotionDimension> get dimensions => _linear4;

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
///
/// Dimensions: start, top, end, bottom.
class EdgeInsetsDirectionalMotionConverter
    extends MotionConverter<EdgeInsetsDirectional>
    with _EqualByType<EdgeInsetsDirectional> {
  /// Creates a [EdgeInsetsDirectionalMotionConverter].
  const EdgeInsetsDirectionalMotionConverter();

  @override
  List<MotionDimension> get dimensions => _linear4;

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

/// Equality for converters without fields: equal when of the same type.
mixin _EqualByType<T> on MotionConverter<T> {
  @override
  bool operator ==(Object other) => other.runtimeType == runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}

@immutable
class _CallbackMotionConverter<T> extends MotionConverter<T> {
  const _CallbackMotionConverter({
    required Normalize<T> normalize,
    required Denormalize<T> denormalize,
    this.dimensions,
  })  : _normalize = normalize,
        _denormalize = denormalize;

  @override
  final List<MotionDimension>? dimensions;

  final Normalize<T> _normalize;

  final Denormalize<T> _denormalize;

  @override
  List<double> normalize(T value) => _normalize(value);

  @override
  T denormalize(List<double> values) => _denormalize(values);

  @override
  bool operator ==(Object other) =>
      other is _CallbackMotionConverter<T> &&
      other.runtimeType == runtimeType &&
      _normalize == other._normalize &&
      _denormalize == other._denormalize &&
      listEquals(dimensions, other.dimensions);

  @override
  int get hashCode =>
      Object.hash(_normalize, _denormalize, Object.hashAll(dimensions ?? []));
}

@immutable
class _CallbackDirectionalMotionConverter<T> extends _CallbackMotionConverter<T>
    with DirectionalMotionConverter<T> {
  const _CallbackDirectionalMotionConverter({
    required super.normalize,
    required super.denormalize,
    required int Function(T a, T b) compare,
    super.dimensions,
  }) : _compare = compare;

  final int Function(T a, T b) _compare;

  @override
  int compare(T a, T b) => _compare(a, b);

  @override
  bool operator ==(Object other) =>
      super == other &&
      other is _CallbackDirectionalMotionConverter<T> &&
      _compare == other._compare;

  @override
  int get hashCode => Object.hash(super.hashCode, _compare);
}
