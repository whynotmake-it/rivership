import 'dart:ui';

import 'package:flutter/foundation.dart';

/// How a `DotGridView` draws its dots.
///
/// Sizes are fractions of the distance between two cells, so a style looks
/// the same at any size.
@immutable
class DotGridStyle {
  /// Creates a grid style.
  const DotGridStyle({
    this.color,
    this.dotSize = 0.8,
    this.blend = 0.6,
    this.offsetRange = 0.5,
    this.cellSize = 10,
  }) : assert(dotSize >= 0, 'dotSize must not be negative.'),
       assert(
         blend >= 0 && blend <= 1.4,
         'blend must be between 0 and 1.4: the renderer only looks at the '
         'two nearest cells in every direction.',
       ),
       assert(
         offsetRange >= 0 && offsetRange <= 1,
         'offsetRange must be between 0 and 1.',
       );

  /// Reads a style written by [toJson].
  factory DotGridStyle.fromJson(Map<String, Object?> json) => DotGridStyle(
    color: json['color'] == null ? null : Color(json['color']! as int),
    dotSize: (json['dotSize'] as num? ?? 0.8).toDouble(),
    blend: (json['blend'] as num? ?? 0.6).toDouble(),
    offsetRange: (json['offsetRange'] as num? ?? 0.5).toDouble(),
    cellSize: (json['cellSize'] as num? ?? 10).toDouble(),
  );

  /// The color of the dots. Defaults to the ambient `IconTheme` color, so
  /// a dot grid can stand in for an icon.
  final Color? color;

  /// The diameter of a dot with value `1`, as a fraction of the cell size.
  ///
  /// At `1`, full neighbors touch.
  final double dotSize;

  /// How far dots reach out to merge, as a fraction of the cell size.
  ///
  /// `0` draws crisp separate dots. Around `0.5` full neighbors melt into
  /// each other, and the larger it gets, the gooier the dots.
  final double blend;

  /// How far an offset of `1` moves a dot, as a fraction of the cell size.
  final double offsetRange;

  /// The size of a cell when the parent doesn't constrain the grid.
  ///
  /// Under tight or smaller constraints, the grid shrinks to fit and stays
  /// centered.
  final double cellSize;

  /// A copy with the given fields replaced.
  DotGridStyle copyWith({
    Color? color,
    double? dotSize,
    double? blend,
    double? offsetRange,
    double? cellSize,
  }) => DotGridStyle(
    color: color ?? this.color,
    dotSize: dotSize ?? this.dotSize,
    blend: blend ?? this.blend,
    offsetRange: offsetRange ?? this.offsetRange,
    cellSize: cellSize ?? this.cellSize,
  );

  /// A JSON representation, read by [DotGridStyle.fromJson].
  Map<String, Object?> toJson() => {
    if (color case final color?) 'color': color.toARGB32(),
    'dotSize': dotSize,
    'blend': blend,
    'offsetRange': offsetRange,
    'cellSize': cellSize,
  };

  @override
  bool operator ==(Object other) =>
      other is DotGridStyle &&
      other.color == color &&
      other.dotSize == dotSize &&
      other.blend == blend &&
      other.offsetRange == offsetRange &&
      other.cellSize == cellSize;

  @override
  int get hashCode => Object.hash(color, dotSize, blend, offsetRange, cellSize);
}

/// How a `DotCloudView` draws its dots.
@immutable
class DotCloudStyle {
  /// Creates a cloud style.
  const DotCloudStyle({this.color, this.blend = 12})
    : assert(blend >= 0, 'blend must not be negative.');

  /// Reads a style written by [toJson].
  factory DotCloudStyle.fromJson(Map<String, Object?> json) => DotCloudStyle(
    color: json['color'] == null ? null : Color(json['color']! as int),
    blend: (json['blend'] as num? ?? 12).toDouble(),
  );

  /// The color of the dots. Defaults to the ambient `IconTheme` color.
  final Color? color;

  /// How far dots reach out to merge, in the units of the cloud's canvas.
  final double blend;

  /// A copy with the given fields replaced.
  DotCloudStyle copyWith({Color? color, double? blend}) =>
      DotCloudStyle(color: color ?? this.color, blend: blend ?? this.blend);

  /// A JSON representation, read by [DotCloudStyle.fromJson].
  Map<String, Object?> toJson() => {
    if (color case final color?) 'color': color.toARGB32(),
    'blend': blend,
  };

  @override
  bool operator ==(Object other) =>
      other is DotCloudStyle && other.color == color && other.blend == blend;

  @override
  int get hashCode => Object.hash(color, blend);
}
