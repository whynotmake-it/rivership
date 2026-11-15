import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:merging_dots/src/model/dot_state.dart';

/// A single freely placed dot.
@immutable
class Dot {
  /// Creates a dot centered on [x] and [y] with [radius], in the units of
  /// the `DotCloud` it belongs to.
  const Dot(this.x, this.y, this.radius);

  /// Reads a dot written by [toJson].
  factory Dot.fromJson(List<Object?> json) => Dot(
    (json[0]! as num).toDouble(),
    (json[1]! as num).toDouble(),
    (json[2]! as num).toDouble(),
  );

  /// The horizontal position of the dot's center.
  final double x;

  /// The vertical position of the dot's center.
  final double y;

  /// The dot's radius.
  final double radius;

  /// The dot's center.
  Offset get center => Offset(x, y);

  /// A copy with the given fields replaced.
  Dot copyWith({double? x, double? y, double? radius}) =>
      Dot(x ?? this.x, y ?? this.y, radius ?? this.radius);

  /// A compact JSON representation: `[x, y, radius]`.
  List<num> toJson() => [_round(x), _round(y), _round(radius)];

  @override
  bool operator ==(Object other) =>
      other is Dot && other.x == x && other.y == y && other.radius == radius;

  @override
  int get hashCode => Object.hash(x, y, radius);

  @override
  String toString() => 'Dot($x, $y, $radius)';
}

/// Freely placed dots inside a design canvas of [size].
///
/// The canvas is scaled to fit the widget that shows it, like an SVG view
/// box, so a cloud designed at 100 x 100 looks the same at any size.
///
/// When a cloud animates to another one, dots are matched by their index:
/// the first dot moves to the first dot, and so on. Extra dots grow from
/// nothing at their position, missing ones shrink away where they are.
///
/// Up to [maxDots] dots are rendered.
@immutable
class DotCloud implements DotState {
  /// Creates a cloud of [dots] on a canvas of [size].
  const DotCloud(this.dots, {this.size = const Size.square(100)});

  /// Reads a cloud written by [toJson].
  factory DotCloud.fromJson(Map<String, Object?> json) {
    final size = json['size']! as List;
    return DotCloud(
      [for (final dot in json['dots']! as List) Dot.fromJson(dot as List)],
      size: Size((size[0] as num).toDouble(), (size[1] as num).toDouble()),
    );
  }

  /// The most dots a cloud can render.
  static const int maxDots = 64;

  /// The dots, in the order they are matched when animating.
  final List<Dot> dots;

  /// The size of the design canvas the dots are placed on.
  final Size size;

  @override
  int get dotCount => dots.length;

  /// A copy with dot [index] replaced by [dot].
  DotCloud withDot(int index, Dot dot) =>
      DotCloud([...dots]..[index] = dot, size: size);

  /// A copy with [dot] added at the end.
  DotCloud withAdded(Dot dot) => DotCloud([...dots, dot], size: size);

  /// A copy without dot [index].
  DotCloud withRemoved(int index) =>
      DotCloud([...dots]..removeAt(index), size: size);

  /// A JSON representation, read by [DotCloud.fromJson].
  Map<String, Object?> toJson() => {
    'size': [_round(size.width), _round(size.height)],
    'dots': [for (final dot in dots) dot.toJson()],
  };

  @override
  void writeChannels(Float32List out) {
    for (var i = 0; i < dots.length; i++) {
      final dot = dots[i];
      final o = i * DotState.stride;
      out[o] = dot.x;
      out[o + 1] = dot.y;
      out[o + 2] = dot.radius;
    }
  }

  @override
  Offset normalizedPosition(int index) {
    final dot = dots[index];
    return Offset(
      size.width == 0 ? 0.5 : dot.x / size.width,
      size.height == 0 ? 0.5 : dot.y / size.height,
    );
  }

  @override
  bool canAnimateTo(DotState other) => other is DotCloud && other.size == size;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DotCloud && other.size == size && listEquals(other.dots, dots);

  @override
  int get hashCode => Object.hash(size, Object.hashAll(dots));

  @override
  String toString() => 'DotCloud(${dots.length} dots, $size)';
}

num _round(double v) {
  final rounded = (v * 100).round() / 100;
  return rounded == rounded.roundToDouble() ? rounded.round() : rounded;
}
