import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:merging_dots/src/model/dot_state.dart';

/// The animated look of one layer of a [DotScene].
///
/// Everything here animates along with the dots, so a keyframe can, say,
/// fade a layer in, raise its blend and move it at once. What doesn't
/// animate, a layer's color and how it combines, is in `DotSceneStyle`.
@immutable
class SceneLayer {
  /// Creates the look of a layer.
  const SceneLayer({
    this.opacity = 1,
    this.blend = 12,
    this.offset = Offset.zero,
    this.squash = 1,
    this.scale = 1,
    this.turn = Offset.zero,
  });

  /// Reads a layer written by [toJson].
  factory SceneLayer.fromJson(Map<String, Object?> json) {
    double read(String key, double fallback) =>
        (json[key] as num? ?? fallback).toDouble();
    return SceneLayer(
      opacity: read('opacity', 1),
      blend: read('blend', 12),
      offset: Offset(read('dx', 0), read('dy', 0)),
      squash: read('squash', 1),
      scale: read('scale', 1),
      turn: Offset(read('yaw', 0), read('pitch', 0)),
    );
  }

  /// How strongly the layer shows, from `0` to `1`. A cutting or inverting
  /// layer does so this much.
  final double opacity;

  /// How far the layer's dots reach out to merge with each other, in
  /// canvas units.
  final double blend;

  /// Moves every dot of the layer, in canvas units. Eyes look around with
  /// it.
  final Offset offset;

  /// Scales the height of every dot of the layer around its own center.
  /// Eyes blink with it.
  final double squash;

  /// Scales the radius of every dot of the layer. Bodies breathe with it.
  final double scale;

  /// Turns the layer in 3D around the scene's [DotScene.pivot], in radians:
  /// `dx` turns it to the right, `dy` tilts it up.
  ///
  /// Dots with more [SceneDot.depth] move further, so a face whose eyes sit
  /// in front of its body turns with parallax. Turn every layer of a
  /// character the same way to turn its head.
  final Offset turn;

  /// A copy with the given fields replaced.
  SceneLayer copyWith({
    double? opacity,
    double? blend,
    Offset? offset,
    double? squash,
    double? scale,
    Offset? turn,
  }) => SceneLayer(
    opacity: opacity ?? this.opacity,
    blend: blend ?? this.blend,
    offset: offset ?? this.offset,
    squash: squash ?? this.squash,
    scale: scale ?? this.scale,
    turn: turn ?? this.turn,
  );

  /// A JSON representation, read by [SceneLayer.fromJson].
  Map<String, Object?> toJson() => {
    if (opacity != 1) 'opacity': opacity,
    'blend': blend,
    if (offset.dx != 0) 'dx': offset.dx,
    if (offset.dy != 0) 'dy': offset.dy,
    if (squash != 1) 'squash': squash,
    if (scale != 1) 'scale': scale,
    if (turn.dx != 0) 'yaw': turn.dx,
    if (turn.dy != 0) 'pitch': turn.dy,
  };

  @override
  bool operator ==(Object other) =>
      other is SceneLayer &&
      other.opacity == opacity &&
      other.blend == blend &&
      other.offset == offset &&
      other.squash == squash &&
      other.scale == scale &&
      other.turn == turn;

  @override
  int get hashCode => Object.hash(opacity, blend, offset, squash, scale, turn);
}

/// A dot of a [DotScene], on one of its layers: a circle, or a capsule
/// when it is stretched.
@immutable
class SceneDot {
  /// Creates a dot centered on [x] and [y] with [radius], in canvas units,
  /// on [layer].
  ///
  /// A [stretch] other than zero makes it a capsule: a stroke of [radius]
  /// from `(x, y)` to `(x, y) + stretch`. Because circles and capsules are
  /// the same shape, a dot can stretch into a stroke and back while it
  /// animates, like eyes turning into a checkmark.
  const SceneDot(
    this.x,
    this.y,
    this.radius, {
    this.layer = 0,
    this.stretch = Offset.zero,
    this.depth = 0,
  });

  /// A capsule from [start] to [end], [radius] thick on each side.
  SceneDot.capsule(
    Offset start,
    Offset end,
    this.radius, {
    this.layer = 0,
    this.depth = 0,
  }) : x = start.dx,
       y = start.dy,
       stretch = end - start;

  /// Reads a dot written by [toJson].
  factory SceneDot.fromJson(List<Object?> json) {
    double at(int i) => json.length > i ? (json[i]! as num).toDouble() : 0;
    return SceneDot(
      at(0),
      at(1),
      at(2),
      layer: at(3),
      stretch: Offset(at(4), at(5)),
      depth: at(6),
    );
  }

  /// The horizontal position of the dot's center, or of the start of its
  /// capsule.
  final double x;

  /// The vertical position of the dot's center, or of the start of its
  /// capsule.
  final double y;

  /// The dot's radius.
  final double radius;

  /// The index of the layer the dot is on.
  ///
  /// It animates like everything else: halfway between two layers, a dot
  /// is half as large on each of them. That is how a dot turns from body
  /// into an eye. Within a fifth of a layer counts as on it, so a dot
  /// that springs past its new layer doesn't spill into the next one.
  final double layer;

  /// Where the capsule ends, relative to its start. Zero for a circle.
  final Offset stretch;

  /// How far the dot sits in front of the scene's [DotScene.pivot], toward
  /// the viewer, in canvas units. It only matters when its layer turns, see
  /// [SceneLayer.turn]: eyes on the front of a head have depth, and slide
  /// further than the head itself.
  final double depth;

  /// The start of the dot.
  Offset get start => Offset(x, y);

  /// The end of the dot: [start] for a circle.
  Offset get end => start + stretch;

  /// A copy with the given fields replaced.
  SceneDot copyWith({
    double? x,
    double? y,
    double? radius,
    double? layer,
    Offset? stretch,
    double? depth,
  }) => SceneDot(
    x ?? this.x,
    y ?? this.y,
    radius ?? this.radius,
    layer: layer ?? this.layer,
    stretch: stretch ?? this.stretch,
    depth: depth ?? this.depth,
  );

  /// A compact JSON representation: `[x, y, radius, layer, dx, dy,
  /// depth]`, without the trailing values that are zero.
  List<num> toJson() {
    final values = <num>[x, y, radius, layer, stretch.dx, stretch.dy, depth];
    while (values.length > 3 && values.last == 0) {
      values.removeLast();
    }
    return values;
  }

  @override
  bool operator ==(Object other) =>
      other is SceneDot &&
      other.x == x &&
      other.y == y &&
      other.radius == radius &&
      other.layer == layer &&
      other.stretch == stretch &&
      other.depth == depth;

  @override
  int get hashCode => Object.hash(x, y, radius, layer, stretch, depth);

  @override
  String toString() =>
      'SceneDot($x, $y, $radius, layer: $layer, stretch: $stretch, '
      'depth: $depth)';
}

/// Freely placed dots on stacked layers, like the face of a character: a
/// body layer and an eye layer that cuts holes into it, or inverts it.
///
/// Each layer merges its own dots with its own blend, see [SceneLayer]. A
/// dot belongs to one [SceneDot.layer] and can move to another one while
/// animating. How layers are colored and whether they cut the layers below
/// them is up to the `DotSceneStyle` they are shown with.
///
/// Like a `DotCloud`, the canvas of [size] is scaled to fit and dots are
/// matched by index when animating. Scenes animate into each other when
/// they have the same size and number of layers.
@immutable
class DotScene implements DotState {
  /// Creates a scene of [dots] on 1 to [maxLayers] [layers].
  const DotScene({
    required this.layers,
    required this.dots,
    this.size = const Size.square(100),
    this.pivot,
  });

  /// Reads a scene written by [toJson].
  factory DotScene.fromJson(Map<String, Object?> json) {
    final size = json['size']! as List;
    return DotScene(
      layers: [
        for (final layer in json['layers']! as List)
          SceneLayer.fromJson(layer as Map<String, Object?>),
      ],
      dots: [
        for (final dot in json['dots']! as List) SceneDot.fromJson(dot as List),
      ],
      size: Size((size[0] as num).toDouble(), (size[1] as num).toDouble()),
      pivot: switch (json['pivot']) {
        [final num x, final num y] => Offset(x.toDouble(), y.toDouble()),
        _ => null,
      },
    );
  }

  /// The most layers a scene can have.
  static const int maxLayers = 4;

  /// The most dots a scene renders.
  static const int maxDots = 64;

  /// The channels of a scene entry: eight for a layer, and seven of eight
  /// for a dot: position, radius, layer, stretch and depth.
  static const int stride = 8;

  /// The layers, bottom first.
  final List<SceneLayer> layers;

  /// The dots, in the order they are matched when animating.
  final List<SceneDot> dots;

  /// The size of the design canvas the dots are placed on.
  final Size size;

  /// What turning layers turn around, see [SceneLayer.turn]. Defaults to
  /// the middle of the canvas.
  final Offset? pivot;

  /// The point turning layers turn around.
  Offset get turnPivot => pivot ?? size.center(Offset.zero);

  /// A copy with the given fields replaced.
  DotScene copyWith({
    List<SceneLayer>? layers,
    List<SceneDot>? dots,
    Size? size,
    Offset? pivot,
  }) => DotScene(
    layers: layers ?? this.layers,
    dots: dots ?? this.dots,
    size: size ?? this.size,
    pivot: pivot ?? this.pivot,
  );

  /// A copy with layer [index] replaced by [layer].
  DotScene withLayer(int index, SceneLayer layer) =>
      copyWith(layers: [...layers]..[index] = layer);

  /// A copy with dot [index] replaced by [dot].
  DotScene withDot(int index, SceneDot dot) =>
      copyWith(dots: [...dots]..[index] = dot);

  /// A JSON representation, read by [DotScene.fromJson].
  Map<String, Object?> toJson() => {
    'size': [size.width, size.height],
    if (pivot case final pivot?) 'pivot': [pivot.dx, pivot.dy],
    'layers': [for (final layer in layers) layer.toJson()],
    'dots': [for (final dot in dots) dot.toJson()],
  };

  // The layers are animated as the first entries, so their look moves with
  // the same motion as the dots.
  @override
  int get dotCount => layers.length + dots.length;

  @override
  int get channels => stride;

  @override
  int get sizeChannel => 2;

  @override
  void writeChannels(Float32List out) {
    for (var i = 0; i < layers.length; i++) {
      final layer = layers[i];
      final o = i * stride;
      out[o] = layer.opacity;
      out[o + 1] = layer.blend;
      out[o + 2] = layer.offset.dx;
      out[o + 3] = layer.offset.dy;
      out[o + 4] = layer.squash;
      out[o + 5] = layer.scale;
      out[o + 6] = layer.turn.dx;
      out[o + 7] = layer.turn.dy;
    }
    for (var i = 0; i < dots.length; i++) {
      final dot = dots[i];
      final o = (layers.length + i) * stride;
      out[o] = dot.x;
      out[o + 1] = dot.y;
      out[o + 2] = dot.radius;
      out[o + 3] = dot.layer;
      out[o + 4] = dot.stretch.dx;
      out[o + 5] = dot.stretch.dy;
      out[o + 6] = dot.depth;
      out[o + 7] = 0;
    }
  }

  @override
  Offset normalizedPosition(int index) {
    if (index < layers.length) return const Offset(0.5, 0.5);
    final dot = dots[index - layers.length];
    return Offset(
      size.width == 0 ? 0.5 : dot.x / size.width,
      size.height == 0 ? 0.5 : dot.y / size.height,
    );
  }

  @override
  bool canAnimateTo(DotState other) =>
      other is DotScene &&
      other.size == size &&
      other.layers.length == layers.length;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DotScene &&
          other.size == size &&
          other.pivot == pivot &&
          listEquals(other.layers, layers) &&
          listEquals(other.dots, dots);

  @override
  int get hashCode =>
      Object.hash(size, pivot, Object.hashAll(layers), Object.hashAll(dots));

  @override
  String toString() =>
      'DotScene(${layers.length} layers, ${dots.length} dots, $size)';
}
