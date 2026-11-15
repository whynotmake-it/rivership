import 'dart:ui';

import 'package:flutter/foundation.dart';

/// How the dots of a `DotGridView` join.
enum DotGridShape {
  /// Round dots that melt into each other like liquid. [DotGridStyle.blend]
  /// sets how gooey.
  goo,

  /// Cells that fuse into rounded letterforms: full cells join their
  /// neighbors with straight edges, free corners are rounded by
  /// [DotGridStyle.cornerRadius], and empty cells wedged between two
  /// filled ones get a concave fillet of [DotGridStyle.innerRadius].
  ///
  /// A cell counts as filled from a value of `0.5`. Below that it shows as
  /// a growing dot; above it, its free corners grow out to their shape.
  tiles,
}

/// How a `DotGridView` draws its dots.
///
/// Sizes are fractions of the distance between two cells, so a style looks
/// the same at any size.
@immutable
class DotGridStyle {
  /// Creates a style of gooey dots, see [DotGridShape.goo].
  const DotGridStyle({
    this.color,
    this.dotSize = 0.8,
    this.blend = 0.6,
    this.offsetRange = 0.5,
    this.cellSize = 10,
  }) : shape = DotGridShape.goo,
       cornerRadius = 1,
       innerRadius = 1,
       assert(dotSize >= 0, 'dotSize must not be negative.'),
       assert(
         blend >= 0 && blend <= 1.4,
         'blend must be between 0 and 1.4: the renderer only looks at the '
         'two nearest cells in every direction.',
       ),
       assert(
         offsetRange >= 0 && offsetRange <= 1,
         'offsetRange must be between 0 and 1.',
       );

  /// Creates a style of fused cells, see [DotGridShape.tiles].
  ///
  /// [dotSize] is the size of a filled cell: at `1` neighbors touch, below
  /// it every shape shrinks by the same amount and above it they fatten.
  const DotGridStyle.tiles({
    this.color,
    this.dotSize = 1,
    this.cornerRadius = 1,
    this.innerRadius = 1,
    this.cellSize = 10,
  }) : shape = DotGridShape.tiles,
       blend = 0,
       offsetRange = 0,
       assert(
         dotSize >= 0.4 && dotSize <= 1.6,
         'dotSize must be between 0.4 and 1.6 for tiles.',
       ),
       assert(
         cornerRadius >= 0 && cornerRadius <= 1,
         'cornerRadius must be between 0 and 1.',
       ),
       assert(
         innerRadius >= 0 && innerRadius <= 1,
         'innerRadius must be between 0 and 1.',
       );

  /// Reads a style written by [toJson].
  factory DotGridStyle.fromJson(Map<String, Object?> json) {
    final color = json['color'] == null ? null : Color(json['color']! as int);
    final cellSize = (json['cellSize'] as num? ?? 10).toDouble();
    if (json['shape'] == DotGridShape.tiles.name) {
      return DotGridStyle.tiles(
        color: color,
        dotSize: (json['dotSize'] as num? ?? 1).toDouble(),
        cornerRadius: (json['cornerRadius'] as num? ?? 1).toDouble(),
        innerRadius: (json['innerRadius'] as num? ?? 1).toDouble(),
        cellSize: cellSize,
      );
    }
    return DotGridStyle(
      color: color,
      dotSize: (json['dotSize'] as num? ?? 0.8).toDouble(),
      blend: (json['blend'] as num? ?? 0.6).toDouble(),
      offsetRange: (json['offsetRange'] as num? ?? 0.5).toDouble(),
      cellSize: cellSize,
    );
  }

  /// How the dots join.
  final DotGridShape shape;

  /// How round free corners of [DotGridShape.tiles] are: `0` is square,
  /// `1` a quarter circle as wide as half a cell.
  final double cornerRadius;

  /// How round the concave corners of [DotGridShape.tiles] are: `0` is
  /// square, `1` a quarter circle, so empty cells show as round holes.
  final double innerRadius;

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
  ///
  /// Fields that don't apply to [shape] are ignored.
  DotGridStyle copyWith({
    Color? color,
    double? dotSize,
    double? blend,
    double? offsetRange,
    double? cellSize,
    double? cornerRadius,
    double? innerRadius,
  }) => switch (shape) {
    DotGridShape.goo => DotGridStyle(
      color: color ?? this.color,
      dotSize: dotSize ?? this.dotSize,
      blend: blend ?? this.blend,
      offsetRange: offsetRange ?? this.offsetRange,
      cellSize: cellSize ?? this.cellSize,
    ),
    DotGridShape.tiles => DotGridStyle.tiles(
      color: color ?? this.color,
      dotSize: dotSize ?? this.dotSize,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      innerRadius: innerRadius ?? this.innerRadius,
      cellSize: cellSize ?? this.cellSize,
    ),
  };

  /// A JSON representation, read by [DotGridStyle.fromJson].
  Map<String, Object?> toJson() => {
    'shape': shape.name,
    if (color case final color?) 'color': color.toARGB32(),
    'dotSize': dotSize,
    'cellSize': cellSize,
    ...switch (shape) {
      DotGridShape.goo => {'blend': blend, 'offsetRange': offsetRange},
      DotGridShape.tiles => {
        'cornerRadius': cornerRadius,
        'innerRadius': innerRadius,
      },
    },
  };

  @override
  bool operator ==(Object other) =>
      other is DotGridStyle &&
      other.shape == shape &&
      other.cornerRadius == cornerRadius &&
      other.innerRadius == innerRadius &&
      other.color == color &&
      other.dotSize == dotSize &&
      other.blend == blend &&
      other.offsetRange == offsetRange &&
      other.cellSize == cellSize;

  @override
  int get hashCode => Object.hash(
    shape,
    color,
    dotSize,
    blend,
    offsetRange,
    cellSize,
    cornerRadius,
    innerRadius,
  );
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
