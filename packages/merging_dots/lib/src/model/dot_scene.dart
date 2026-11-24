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

  /// A copy with the given fields replaced.
  SceneLayer copyWith({
    double? opacity,
    double? blend,
    Offset? offset,
    double? squash,
    double? scale,
  }) => SceneLayer(
    opacity: opacity ?? this.opacity,
    blend: blend ?? this.blend,
    offset: offset ?? this.offset,
    squash: squash ?? this.squash,
    scale: scale ?? this.scale,
  );

  /// A JSON representation, read by [SceneLayer.fromJson].
  Map<String, Object?> toJson() => {
    if (opacity != 1) 'opacity': opacity,
    'blend': blend,
    if (offset.dx != 0) 'dx': offset.dx,
    if (offset.dy != 0) 'dy': offset.dy,
    if (squash != 1) 'squash': squash,
    if (scale != 1) 'scale': scale,
  };

  @override
  bool operator ==(Object other) =>
      other is SceneLayer &&
      other.opacity == opacity &&
      other.blend == blend &&
      other.offset == offset &&
      other.squash == squash &&
      other.scale == scale;

  @override
  int get hashCode => Object.hash(opacity, blend, offset, squash, scale);
}

/// A dot of a [DotScene], on one of its layers.
@immutable
class SceneDot {
  /// Creates a dot centered on [x] and [y] with [radius], in canvas units,
  /// on [layer].
  const SceneDot(this.x, this.y, this.radius, {this.layer = 0});

  /// Reads a dot written by [toJson].
  factory SceneDot.fromJson(List<Object?> json) => SceneDot(
    (json[0]! as num).toDouble(),
    (json[1]! as num).toDouble(),
    (json[2]! as num).toDouble(),
    layer: json.length > 3 ? (json[3]! as num).toDouble() : 0,
  );

  /// The horizontal position of the dot's center.
  final double x;

  /// The vertical position of the dot's center.
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

  /// A copy with the given fields replaced.
  SceneDot copyWith({double? x, double? y, double? radius, double? layer}) =>
      SceneDot(
        x ?? this.x,
        y ?? this.y,
        radius ?? this.radius,
        layer: layer ?? this.layer,
      );

  /// A compact JSON representation: `[x, y, radius, layer]`.
  List<num> toJson() => [x, y, radius, if (layer != 0) layer];

  @override
  bool operator ==(Object other) =>
      other is SceneDot &&
      other.x == x &&
      other.y == y &&
      other.radius == radius &&
      other.layer == layer;

  @override
  int get hashCode => Object.hash(x, y, radius, layer);

  @override
  String toString() => 'SceneDot($x, $y, $radius, layer: $layer)';
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
    );
  }

  /// The most layers a scene can have.
  static const int maxLayers = 4;

  /// The most dots a scene renders.
  static const int maxDots = 64;

  /// The channels of a scene entry: six for a layer, of which a dot uses
  /// four.
  static const int stride = 6;

  /// The layers, bottom first.
  final List<SceneLayer> layers;

  /// The dots, in the order they are matched when animating.
  final List<SceneDot> dots;

  /// The size of the design canvas the dots are placed on.
  final Size size;

  /// A copy with the given fields replaced.
  DotScene copyWith({
    List<SceneLayer>? layers,
    List<SceneDot>? dots,
    Size? size,
  }) => DotScene(
    layers: layers ?? this.layers,
    dots: dots ?? this.dots,
    size: size ?? this.size,
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
    }
    for (var i = 0; i < dots.length; i++) {
      final dot = dots[i];
      final o = (layers.length + i) * stride;
      out[o] = dot.x;
      out[o + 1] = dot.y;
      out[o + 2] = dot.radius;
      out[o + 3] = dot.layer;
      out[o + 4] = 0;
      out[o + 5] = 0;
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
          listEquals(other.layers, layers) &&
          listEquals(other.dots, dots);

  @override
  int get hashCode =>
      Object.hash(size, Object.hashAll(layers), Object.hashAll(dots));

  @override
  String toString() =>
      'DotScene(${layers.length} layers, ${dots.length} dots, $size)';
}
