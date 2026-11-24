import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:merging_dots/src/animation/dot_animator.dart';
import 'package:merging_dots/src/model/dot_cloud.dart';
import 'package:merging_dots/src/model/dot_grid.dart';
import 'package:merging_dots/src/model/dot_scene.dart';
import 'package:merging_dots/src/model/dot_state.dart';
import 'package:merging_dots/src/rendering/data_texture.dart';
import 'package:merging_dots/src/rendering/dot_shaders.dart';
import 'package:merging_dots/src/rendering/dot_styles.dart';

const _stride = DotState.stride;

/// The largest value a grid dot can show: its data texture stores
/// `value * 200` in a byte.
const double kMaxGridValue = 255 / 200;

/// Converts a `blend` distance to the smoothing distance of the shaders'
/// exponential union: `1 / (4 * ln 2)`. With it, two touching dots bulge
/// just as far as with a polynomial union of radius `blend`, and dots bridge
/// once their gap is under half of `blend`.
const double _blendToSmoothing = 0.36067376;

/// Shared plumbing of the dot render objects: listens to a [DotAnimator]
/// and repaints, without layout, whenever its values change.
abstract class RenderDots<T extends DotState> extends RenderBox {
  /// Creates a render object that paints the dots of [animator].
  RenderDots({
    required DotAnimator<T> animator,
    required Color color,
    required double devicePixelRatio,
  }) : _animator = animator,
       _color = color,
       _devicePixelRatio = devicePixelRatio;

  DotAnimator<T> _animator;

  /// Where the dots come from.
  DotAnimator<T> get animator => _animator;
  set animator(DotAnimator<T> value) {
    if (identical(value, _animator)) return;
    if (attached) _animator.removeListener(_onAnimatorChanged);
    _animator = value;
    if (attached) _animator.addListener(_onAnimatorChanged);
    _lastLayoutKey = null;
    markNeedsLayout();
  }

  Color _color;

  /// The fill color of the dots.
  Color get color => _color;
  set color(Color value) {
    if (value == _color) return;
    _color = value;
    markNeedsPaint();
  }

  double _devicePixelRatio;

  /// The device pixel ratio, for the width of the anti-aliased edge.
  double get devicePixelRatio => _devicePixelRatio;
  set devicePixelRatio(double value) {
    if (value == _devicePixelRatio) return;
    _devicePixelRatio = value;
    markNeedsPaint();
  }

  ui.FragmentShader? _shader;
  ui.FragmentProgram? _shaderProgram;

  Object? _lastLayoutKey;

  /// What the size depends on, besides constraints. Layout only reruns
  /// when it changes.
  Object layoutKey(T target);

  /// Returns the fragment program, or null while it loads.
  ui.FragmentProgram? get program;

  void _onAnimatorChanged() {
    final key = layoutKey(_animator.target);
    if (key != _lastLayoutKey) {
      _lastLayoutKey = key;
      markNeedsLayout();
    } else {
      markNeedsPaint();
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _animator.addListener(_onAnimatorChanged);
    if (program == null) {
      DotShaders.precache().then((_) {
        if (attached) markNeedsPaint();
      });
    }
  }

  @override
  void detach() {
    _animator.removeListener(_onAnimatorChanged);
    super.detach();
  }

  @override
  void dispose() {
    _shader?.dispose();
    _shader = null;
    super.dispose();
  }

  @override
  bool get isRepaintBoundary => true;

  @override
  bool hitTestSelf(Offset position) => true;

  /// The shader to paint with, or null to draw the fallback.
  ui.FragmentShader? obtainShader() {
    final program = this.program;
    if (program == null) return null;
    if (_shader != null && identical(program, _shaderProgram)) return _shader;
    _shader?.dispose();
    _shaderProgram = program;
    return _shader = program.fragmentShader();
  }

  /// The width of one physical pixel in local coordinates.
  double pixelWidth(Canvas canvas) {
    final transform = canvas.getTransform();
    final scale = math.sqrt(
      transform[0] * transform[0] + transform[1] * transform[1],
    );
    return 1 / (math.max(scale, 1e-6) * _devicePixelRatio);
  }

  /// Sets the color uniform at index 0 to [color], premultiplied.
  void setColor(ui.FragmentShader shader) {
    final a = _color.a;
    shader
      ..setFloat(0, _color.r * a)
      ..setFloat(1, _color.g * a)
      ..setFloat(2, _color.b * a)
      ..setFloat(3, a);
  }

  @override
  void performLayout() {
    _lastLayoutKey = layoutKey(_animator.target);
    size = constraints.constrainSizeAndAttemptToPreserveAspectRatio(
      naturalSize(_animator.target),
    );
  }

  /// The size of the dots when the parent doesn't constrain them.
  Size naturalSize(T target);

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      constraints.constrainSizeAndAttemptToPreserveAspectRatio(
        naturalSize(_animator.target),
      );
}

/// Renders a [DotGrid] from a [DotAnimator] with the grid shader.
///
/// Every frame the dots change, their values are uploaded as a texture with
/// one texel per cell (see [DotDataTexture]). The shader then reads only the
/// 5x5 cells around every pixel.
class RenderDotGrid extends RenderDots<DotGrid> {
  /// Creates a render object for a grid. See `DotGridStyle` for the
  /// meaning of the sizes.
  RenderDotGrid({
    required super.animator,
    required super.color,
    required super.devicePixelRatio,
    required double dotSize,
    required double blend,
    required double offsetRange,
    required double cellSize,
    DotGridShape shape = DotGridShape.goo,
    double cornerRadius = 1,
    double innerRadius = 1,
  }) : _dotSize = dotSize,
       _blend = blend,
       _offsetRange = offsetRange,
       _cellSize = cellSize,
       _shape = shape,
       _cornerRadius = cornerRadius,
       _innerRadius = innerRadius;

  DotGridShape _shape;

  /// How the dots join.
  DotGridShape get shape => _shape;
  set shape(DotGridShape value) {
    if (value == _shape) return;
    _shape = value;
    _bounds = null;
    markNeedsPaint();
  }

  double _cornerRadius;

  /// How round free corners of tiles are, from `0` to `1`.
  double get cornerRadius => _cornerRadius;
  set cornerRadius(double value) {
    if (value == _cornerRadius) return;
    _cornerRadius = value;
    markNeedsPaint();
  }

  double _innerRadius;

  /// How round concave corners of tiles are, from `0` to `1`.
  double get innerRadius => _innerRadius;
  set innerRadius(double value) {
    if (value == _innerRadius) return;
    _innerRadius = value;
    markNeedsPaint();
  }

  double _dotSize;

  /// The diameter of a dot of value 1, as a fraction of the cell size.
  double get dotSize => _dotSize;
  set dotSize(double value) {
    if (value == _dotSize) return;
    _dotSize = value;
    _bounds = null;
    markNeedsPaint();
  }

  double _blend;

  /// How far dots reach out to merge.
  double get blend => _blend;
  set blend(double value) {
    if (value == _blend) return;
    _blend = value;
    _bounds = null;
    markNeedsPaint();
  }

  double _offsetRange;

  /// How far an offset of 1 moves a dot, as a fraction of the cell size.
  double get offsetRange => _offsetRange;
  set offsetRange(double value) {
    if (value == _offsetRange) return;
    _offsetRange = value;
    _bounds = null;
    markNeedsPaint();
  }

  double _cellSize;

  /// The size of a cell when the parent doesn't constrain the grid.
  double get cellSize => _cellSize;
  set cellSize(double value) {
    if (value == _cellSize) return;
    _cellSize = value;
    markNeedsLayout();
  }

  final _data = DotDataTexture();
  int _dataRevision = -1;
  Object? _dataKey;

  /// The cells that hold a visible dot: left, top, right, bottom.
  (int, int, int, int)? _cells;
  Rect? _bounds;

  @override
  ui.FragmentProgram? get program => switch (_shape) {
    DotGridShape.goo => DotShaders.grid,
    DotGridShape.tiles => DotShaders.tiles,
  };

  @override
  Object layoutKey(DotGrid target) => (target.columns, target.rows);

  @override
  Size naturalSize(DotGrid target) =>
      Size(target.columns * _cellSize, target.rows * _cellSize);

  @override
  void dispose() {
    _data.dispose();
    super.dispose();
  }

  /// The distance between two cell centers and the center of the first
  /// cell, for the current size.
  (double, Offset) get _geometry {
    final grid = animator.target;
    final spacing = math.min(
      size.width / grid.columns,
      size.height / grid.rows,
    );
    final origin = Offset(
      (size.width - spacing * grid.columns) / 2 + spacing / 2,
      (size.height - spacing * grid.rows) / 2 + spacing / 2,
    );
    return (spacing, origin);
  }

  /// The cell at [localPosition], or null outside the grid.
  (int, int)? cellAt(Offset localPosition) {
    final grid = animator.target;
    final (spacing, origin) = _geometry;
    final column = ((localPosition.dx - origin.dx) / spacing + 0.5).floor();
    final row = ((localPosition.dy - origin.dy) / spacing + 0.5).floor();
    if (column < 0 || row < 0 || column >= grid.columns || row >= grid.rows) {
      return null;
    }
    return (column, row);
  }

  /// Uploads the animator's values to the data texture.
  void _updateData() {
    final grid = animator.target;
    final key = (grid.columns, grid.rows);
    if (_data.image != null &&
        _dataRevision == animator.revision &&
        _dataKey == key) {
      return;
    }
    _dataRevision = animator.revision;
    _dataKey = key;

    final columns = grid.columns;
    final rows = grid.rows;
    final values = animator.values;
    final count = math.min(animator.dotCount, columns * rows);
    final rgba = Uint8List(columns * rows * 4);

    var left = columns;
    var top = rows;
    var right = -1;
    var bottom = -1;
    for (var i = 0; i < columns * rows; i++) {
      final o = i * _stride;
      final p = i * 4;
      rgba[p + 3] = 255;
      if (i >= count) {
        rgba[p + 1] = 128;
        rgba[p + 2] = 128;
        continue;
      }
      final r = (values[o] * 200).round().clamp(0, 255);
      rgba[p] = r;
      rgba[p + 1] = (values[o + 1] * 127).round().clamp(-127, 127) + 128;
      rgba[p + 2] = (values[o + 2] * 127).round().clamp(-127, 127) + 128;
      if (r > 0) {
        final column = i % columns;
        final row = i ~/ columns;
        left = math.min(left, column);
        right = math.max(right, column);
        top = math.min(top, row);
        bottom = math.max(bottom, row);
      }
    }
    _cells = right < 0 ? null : (left, top, right, bottom);
    _bounds = null;
    _data.upload(rgba, columns, rows);
  }

  Rect? _contentBounds(double spacing, Offset origin) {
    final cells = _cells;
    if (cells == null) return null;
    if (_bounds != null) return _bounds;
    final (left, top, right, bottom) = cells;
    if (_shape == DotGridShape.tiles) {
      // Ink stays inside filled cells and the fillets of their neighbors.
      final reach = spacing * (1 + math.max(0, _dotSize - 1)) + 2;
      return _bounds = Rect.fromLTRB(
        origin.dx + left * spacing - reach,
        origin.dy + top * spacing - reach,
        origin.dx + right * spacing + reach,
        origin.dy + bottom * spacing + reach,
      ).intersect(Offset.zero & size);
    }
    final reach =
        spacing * (_dotSize / 2 * kMaxGridValue + _blend * 1.2 + _offsetRange) +
        2;
    return _bounds = Rect.fromLTRB(
      origin.dx + left * spacing - reach,
      origin.dy + top * spacing - reach,
      origin.dx + right * spacing + reach,
      origin.dy + bottom * spacing + reach,
    ).intersect(Offset.zero & size);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final grid = animator.target;
    final (spacing, origin) = _geometry;
    if (spacing <= 0) return;
    final shader = obtainShader();
    final canvas = context.canvas;

    if (shader == null) {
      _paintFallback(canvas, offset, spacing, origin);
      return;
    }

    _updateData();
    final bounds = _contentBounds(spacing, origin);
    if (bounds == null || bounds.isEmpty) return;

    canvas
      ..save()
      ..translate(offset.dx, offset.dy);
    setColor(shader);
    if (_shape == DotGridShape.tiles) {
      shader
        ..setFloat(4, origin.dx - spacing / 2)
        ..setFloat(5, origin.dy - spacing / 2)
        ..setFloat(6, grid.columns.toDouble())
        ..setFloat(7, grid.rows.toDouble())
        ..setFloat(8, spacing)
        ..setFloat(9, _cornerRadius * 0.5)
        ..setFloat(10, _innerRadius * 0.5)
        ..setFloat(11, (1 - _dotSize) / 2)
        ..setFloat(12, pixelWidth(canvas))
        ..setFloat(13, _data.isRendered ? 1 : 0)
        ..setImageSampler(0, _data.image!);
      canvas
        ..drawRect(bounds, Paint()..shader = shader)
        ..restore();
      return;
    }
    shader
      ..setFloat(4, origin.dx)
      ..setFloat(5, origin.dy)
      ..setFloat(6, grid.columns.toDouble())
      ..setFloat(7, grid.rows.toDouble())
      ..setFloat(8, spacing)
      ..setFloat(9, spacing * _dotSize / 2)
      ..setFloat(10, spacing * _offsetRange)
      ..setFloat(11, spacing * _blend * _blendToSmoothing)
      ..setFloat(12, pixelWidth(canvas))
      ..setFloat(13, _data.isRendered ? 1 : 0)
      ..setImageSampler(0, _data.image!);
    canvas
      ..drawRect(bounds, Paint()..shader = shader)
      ..restore();
  }

  void _paintFallback(
    Canvas canvas,
    Offset offset,
    double spacing,
    Offset origin,
  ) {
    final grid = animator.target;
    final values = animator.values;
    final paint = Paint()..color = color;
    final count = math.min(animator.dotCount, grid.dotCount);
    for (var i = 0; i < count; i++) {
      final o = i * _stride;
      final radius = values[o].clamp(0, kMaxGridValue) * spacing * _dotSize / 2;
      if (radius <= 0) continue;
      final center =
          origin +
          Offset((i % grid.columns) * spacing, (i ~/ grid.columns) * spacing) +
          Offset(values[o + 1], values[o + 2]) * (spacing * _offsetRange);
      canvas.drawCircle(offset + center, radius, paint);
    }
  }
}

/// Renders a [DotCloud] from a [DotAnimator] with the cloud shader.
///
/// The cloud's canvas is scaled to fit and centered, like an SVG view box.
///
/// Every frame the dots change, they are sorted into square tiles at least
/// as large as a dot's reach, and two small textures are uploaded (see
/// [DotDataTexture]): the dots, ordered by tile, and where each tile's dots
/// start. Each pixel then only reads the dots of the 3x3 tiles around it, so
/// a cloud can hold [DotCloud.maxDots] dots. Only the area around the dots
/// is shaded.
class RenderDotCloud extends RenderDots<DotCloud> {
  /// Creates a render object for a cloud, with [blend] in canvas units.
  RenderDotCloud({
    required super.animator,
    required super.color,
    required super.devicePixelRatio,
    required double blend,
  }) : _blend = blend;

  /// The most dots a single tile holds. Matches the shader.
  static const _maxDotsPerTile = 64;

  /// The width of the dot texture, in texels: 128 dots per row.
  static const _dotsWidth = 256;

  /// The most tiles per axis.
  static const _maxTiles = 128;

  double _blend;

  /// How far dots reach out to merge.
  double get blend => _blend;
  set blend(double value) {
    if (value == _blend) return;
    _blend = value;
    markNeedsPaint();
  }

  final _tiles = DotDataTexture();
  final _dots = DotDataTexture();
  int _dataRevision = -1;
  Object? _dataKey;
  _CloudLayout? _layout;

  @override
  ui.FragmentProgram? get program => DotShaders.cloud;

  @override
  Object layoutKey(DotCloud target) => target.size;

  @override
  Size naturalSize(DotCloud target) => target.size;

  @override
  void dispose() {
    _tiles.dispose();
    _dots.dispose();
    super.dispose();
  }

  /// The scale from the cloud's canvas to local coordinates and the local
  /// position of the canvas' origin.
  (double, Offset) get transform {
    final canvasSize = animator.target.size;
    if (canvasSize.isEmpty) return (1, Offset.zero);
    final scale = math.min(
      size.width / canvasSize.width,
      size.height / canvasSize.height,
    );
    return (
      scale,
      Offset(
        (size.width - canvasSize.width * scale) / 2,
        (size.height - canvasSize.height * scale) / 2,
      ),
    );
  }

  /// Converts [localPosition] to the cloud's canvas coordinates.
  Offset toCanvas(Offset localPosition) {
    final (scale, origin) = transform;
    return (localPosition - origin) / scale;
  }

  /// Sorts the dots into tiles and uploads them. Returns null when no dot
  /// is visible.
  _CloudLayout? _updateData(double scale, Offset origin, double smoothing) {
    final key = (scale, origin, smoothing, size);
    if (_dataRevision == animator.revision && _dataKey == key) {
      return _layout;
    }
    _dataRevision = animator.revision;
    _dataKey = key;

    final values = animator.values;
    final count = math.min(animator.dotCount, DotCloud.maxDots);

    // Where the visible dots are, in local pixels.
    final xs = Float64List(count);
    final ys = Float64List(count);
    final rs = Float64List(count);
    var visible = 0;
    var maxRadius = 0.0;
    var left = double.infinity;
    var top = double.infinity;
    var right = double.negativeInfinity;
    var bottom = double.negativeInfinity;
    for (var i = 0; i < count; i++) {
      final o = i * _stride;
      final r = values[o + 2] * scale;
      if (r <= 0) continue;
      final x = origin.dx + values[o] * scale;
      final y = origin.dy + values[o + 1] * scale;
      xs[visible] = x;
      ys[visible] = y;
      rs[visible] = r;
      visible++;
      maxRadius = math.max(maxRadius, r);
      left = math.min(left, x);
      top = math.min(top, y);
      right = math.max(right, x);
      bottom = math.max(bottom, y);
    }
    if (visible == 0) return _layout = null;

    // A tile must be at least a dot's reach, so every dot that touches a
    // pixel is in the pixel's tile or a neighbor.
    final reach = maxRadius + smoothing * 3.5 + 2;
    var tile = math.max<double>(reach, 8);
    final contentLeft = left - reach;
    final contentTop = top - reach;
    final contentWidth = right - left + reach * 2;
    final contentHeight = bottom - top + reach * 2;
    while (contentWidth / tile > _maxTiles ||
        contentHeight / tile > _maxTiles) {
      tile *= 2;
    }
    final columns = math.max(1, (contentWidth / tile).ceil());
    final rows = math.max(1, (contentHeight / tile).ceil());

    // Counting sort by tile.
    final tileOf = Int32List(visible);
    final counts = Int32List(columns * rows);
    for (var i = 0; i < visible; i++) {
      final column = ((xs[i] - contentLeft) / tile).floor().clamp(
        0,
        columns - 1,
      );
      final row = ((ys[i] - contentTop) / tile).floor().clamp(0, rows - 1);
      final t = row * columns + column;
      tileOf[i] = t;
      counts[t]++;
    }
    final starts = Int32List(columns * rows);
    var next = 0;
    for (var t = 0; t < columns * rows; t++) {
      starts[t] = next;
      next += counts[t];
    }
    final order = Int32List(visible);
    final cursor = Int32List.fromList(starts);
    for (var i = 0; i < visible; i++) {
      order[cursor[tileOf[i]]++] = i;
    }

    assert(() {
      final crowded = counts.where((c) => c > _maxDotsPerTile).length;
      if (crowded > 0) {
        debugPrint(
          'merging_dots: $crowded tiles hold more than $_maxDotsPerTile dots. '
          'Dots past that are not drawn. Spread the dots out or make them '
          'smaller.',
        );
      }
      return true;
    }(), 'Only reports crowded tiles.');

    final tileData = Uint8List(columns * rows * 4);
    for (var t = 0; t < columns * rows; t++) {
      final p = t * 4;
      tileData[p] = starts[t] >> 8;
      tileData[p + 1] = starts[t] & 0xFF;
      tileData[p + 2] = math.min(counts[t], _maxDotsPerTile);
      tileData[p + 3] = 255;
    }

    // Positions and radii as 16 bit fractions of the content's span.
    final span = math.max(math.max(contentWidth, contentHeight), maxRadius);
    final dotRows = math.max(1, (visible * 2 / _dotsWidth).ceil());
    final dotData = Uint8List(_dotsWidth * dotRows * 4);
    int quantize(double v) => (v / span * 65535).round().clamp(0, 65535);
    for (var n = 0; n < visible; n++) {
      final i = order[n];
      final x = quantize(xs[i] - contentLeft);
      final y = quantize(ys[i] - contentTop);
      final r = quantize(rs[i]);
      final p = n * 8;
      dotData
        ..[p] = x >> 8
        ..[p + 1] = x & 0xFF
        ..[p + 2] = y >> 8
        ..[p + 3] = 255
        ..[p + 4] = y & 0xFF
        ..[p + 5] = r >> 8
        ..[p + 6] = r & 0xFF
        ..[p + 7] = 255;
    }
    for (var p = visible * 8 + 3; p < dotData.length; p += 4) {
      dotData[p] = 255;
    }

    _tiles.upload(tileData, columns, rows);
    _dots.upload(dotData, _dotsWidth, dotRows);
    return _layout = _CloudLayout(
      origin: Offset(contentLeft, contentTop),
      tile: tile,
      columns: columns,
      rows: rows,
      dotRows: dotRows,
      span: span,
      bounds: Rect.fromLTRB(
        left - reach,
        top - reach,
        right + reach,
        bottom + reach,
      ),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final (scale, origin) = transform;
    final values = animator.values;
    final count = math.min(animator.dotCount, DotCloud.maxDots);
    if (count == 0) return;
    final canvas = context.canvas;
    final shader = obtainShader();

    if (shader == null) {
      final paint = Paint()..color = color;
      for (var i = 0; i < count; i++) {
        final o = i * _stride;
        if (values[o + 2] <= 0) continue;
        canvas.drawCircle(
          offset + origin + Offset(values[o], values[o + 1]) * scale,
          values[o + 2] * scale,
          paint,
        );
      }
      return;
    }

    final smoothing = _blend * scale * _blendToSmoothing;
    final layout = _updateData(scale, origin, smoothing);
    if (layout == null) return;

    canvas
      ..save()
      ..translate(offset.dx, offset.dy);
    setColor(shader);
    shader
      ..setFloat(4, layout.origin.dx)
      ..setFloat(5, layout.origin.dy)
      ..setFloat(6, layout.columns.toDouble())
      ..setFloat(7, layout.rows.toDouble())
      ..setFloat(8, _dotsWidth.toDouble())
      ..setFloat(9, layout.dotRows.toDouble())
      ..setFloat(10, layout.tile)
      ..setFloat(11, layout.span)
      ..setFloat(12, smoothing)
      ..setFloat(13, pixelWidth(canvas))
      ..setFloat(14, _tiles.isRendered ? 1 : 0)
      ..setImageSampler(0, _tiles.image!)
      ..setImageSampler(1, _dots.image!);
    canvas
      ..drawRect(
        layout.bounds.intersect(Offset.zero & size),
        Paint()..shader = shader,
      )
      ..restore();
  }
}

/// Where a cloud's tiles are, for the shader.
class _CloudLayout {
  const _CloudLayout({
    required this.origin,
    required this.tile,
    required this.columns,
    required this.rows,
    required this.dotRows,
    required this.span,
    required this.bounds,
  });

  final Offset origin;
  final double tile;
  final int columns;
  final int rows;
  final int dotRows;
  final double span;
  final Rect bounds;
}

/// Adjusts the layers of a [DotScene] every frame, on top of its
/// animation. A character's idle behaviors, like blinking and looking
/// around, are modifiers.
abstract interface class DotSceneModifier implements Listenable {
  /// Changes the channels of [count] layers in [layers] in place,
  /// [DotScene.stride] values per layer in the order of
  /// [DotScene.writeChannels]: opacity, blend, offset x and y, squash and
  /// scale.
  ///
  /// Called whenever the scene paints. Notify listeners to repaint.
  void modifyLayers(Float32List layers, int count);
}

/// Renders a [DotScene] from a [DotAnimator] with the scene shader.
///
/// The scene's canvas is scaled to fit and centered. Each frame the dots
/// change, they are uploaded as a small texture, and every shaded pixel
/// merges each layer's dots, cuts or inverts and composites the layers.
class RenderDotScene extends RenderDots<DotScene> {
  /// Creates a render object for a scene drawn with [style].
  RenderDotScene({
    required super.animator,
    required super.devicePixelRatio,
    required List<Color> colors,
    required DotSceneStyle style,
    DotSceneModifier? modifier,
  }) : _colors = colors,
       _style = style,
       _modifier = modifier,
       super(color: colors.first);

  static const _sceneStride = DotScene.stride;

  List<Color> _colors;

  /// The color of each layer, resolved from the style.
  List<Color> get colors => _colors;
  set colors(List<Color> value) {
    if (listEquals(value, _colors)) return;
    _colors = value;
    color = value.first;
    markNeedsPaint();
  }

  DotSceneStyle _style;

  /// Whether layers cut and how.
  DotSceneStyle get style => _style;
  set style(DotSceneStyle value) {
    if (value == _style) return;
    _style = value;
    markNeedsPaint();
  }

  DotSceneModifier? _modifier;

  /// Adjusts the layers every frame.
  DotSceneModifier? get modifier => _modifier;
  set modifier(DotSceneModifier? value) {
    if (identical(value, _modifier)) return;
    if (attached) _modifier?.removeListener(markNeedsPaint);
    _modifier = value;
    if (attached) _modifier?.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  final _dots = DotDataTexture();
  final _layers = Float32List(DotScene.maxLayers * _sceneStride);
  int _dataRevision = -1;
  Object? _dataKey;
  (Offset, double, int)? _upload;

  @override
  ui.FragmentProgram? get program => DotShaders.scene;

  @override
  Object layoutKey(DotScene target) => target.size;

  @override
  Size naturalSize(DotScene target) => target.size;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _modifier?.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _modifier?.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void dispose() {
    _dots.dispose();
    super.dispose();
  }

  /// The scale from the scene's canvas to local coordinates and the local
  /// position of the canvas' origin.
  (double, Offset) get transform {
    final canvasSize = animator.target.size;
    if (canvasSize.isEmpty) return (1, Offset.zero);
    final scale = math.min(
      size.width / canvasSize.width,
      size.height / canvasSize.height,
    );
    return (
      scale,
      Offset(
        (size.width - canvasSize.width * scale) / 2,
        (size.height - canvasSize.height * scale) / 2,
      ),
    );
  }

  /// Converts [localPosition] to the scene's canvas coordinates.
  Offset toCanvas(Offset localPosition) {
    final (scale, origin) = transform;
    return (localPosition - origin) / scale;
  }

  int get _layerCount =>
      math.min(animator.target.layers.length, DotScene.maxLayers);

  /// Uploads the dots in local pixels. Returns their top left corner, the
  /// span their values are fractions of, and how many there are.
  (Offset, double, int)? _updateData(double scale, Offset origin) {
    final key = (scale, origin);
    if (_dataRevision == animator.revision && _dataKey == key) return _upload;
    _dataRevision = animator.revision;
    _dataKey = key;

    final values = animator.values;
    final layers = _layerCount;
    final count = math.min(
      animator.dotCount - layers,
      DotScene.maxDots,
    );
    var left = double.infinity;
    var top = double.infinity;
    var right = double.negativeInfinity;
    var bottom = double.negativeInfinity;
    var visible = 0;
    for (var i = 0; i < count; i++) {
      final o = (layers + i) * _sceneStride;
      final r = values[o + 2] * scale;
      if (r <= 0) continue;
      final x = origin.dx + values[o] * scale;
      final y = origin.dy + values[o + 1] * scale;
      left = math.min(left, x - r);
      top = math.min(top, y - r);
      right = math.max(right, x + r);
      bottom = math.max(bottom, y + r);
      visible++;
    }
    if (visible == 0) return _upload = null;

    final span = math.max<double>(math.max(right - left, bottom - top), 1);
    final data = Uint8List(visible * 3 * 4);
    int quantize(double v) => (v * 65535).round().clamp(0, 65535);
    var n = 0;
    for (var i = 0; i < count; i++) {
      final o = (layers + i) * _sceneStride;
      final r = values[o + 2] * scale;
      if (r <= 0) continue;
      final x = quantize((origin.dx + values[o] * scale - left) / span);
      final y = quantize((origin.dy + values[o + 1] * scale - top) / span);
      final radius = quantize(r / span);
      final layer = quantize(
        values[o + 3].clamp(0, layers - 1).toDouble() / 4,
      );
      final p = n * 12;
      data
        ..[p] = x >> 8
        ..[p + 1] = x & 0xFF
        ..[p + 2] = y >> 8
        ..[p + 3] = 255
        ..[p + 4] = y & 0xFF
        ..[p + 5] = radius >> 8
        ..[p + 6] = radius & 0xFF
        ..[p + 7] = 255
        ..[p + 8] = layer >> 8
        ..[p + 9] = layer & 0xFF
        ..[p + 10] = 0
        ..[p + 11] = 255;
      n++;
    }
    _dots.upload(data, visible * 3, 1);
    return _upload = (Offset(left, top), span, visible);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final (scale, origin) = transform;
    final layerCount = _layerCount;
    final values = animator.values;
    if (animator.dotCount <= layerCount) return;

    _layers
      ..fillRange(0, _layers.length, 0)
      ..setRange(0, layerCount * _sceneStride, values);
    _modifier?.modifyLayers(_layers, layerCount);

    final canvas = context.canvas;
    final shader = obtainShader();
    if (shader == null) {
      _paintFallback(canvas, offset, scale, origin);
      return;
    }

    final upload = _updateData(scale, origin);
    if (upload == null) return;
    final (dataOrigin, span, count) = upload;

    // Everything a layer can reach: its offset, scale and blend.
    var reach = 2.0;
    var grow = 1.0;
    for (var l = 0; l < layerCount; l++) {
      final o = l * _sceneStride;
      reach = math.max(
        reach,
        Offset(_layers[o + 2], _layers[o + 3]).distance * scale +
            _layers[o + 1] * scale * _blendToSmoothing * 3.5 +
            2,
      );
      grow = math.max(grow, math.max(_layers[o + 5], 1));
    }
    final bounds = Rect.fromLTWH(
      dataOrigin.dx,
      dataOrigin.dy,
      span,
      span,
    ).inflate(reach + span * (grow - 1)).intersect(Offset.zero & size);
    if (bounds.isEmpty) return;

    shader
      ..setFloat(0, dataOrigin.dx)
      ..setFloat(1, dataOrigin.dy)
      ..setFloat(2, span)
      ..setFloat(3, count.toDouble())
      ..setFloat(4, count * 3.0)
      ..setFloat(5, pixelWidth(canvas))
      ..setFloat(6, _dots.isRendered ? 1 : 0);
    for (var l = 0; l < DotScene.maxLayers; l++) {
      final base = 7 + l * 12;
      final o = l * _sceneStride;
      final present = l < layerCount;
      final layerStyle = _style.layer(l);
      final color = present ? _colors[math.min(l, _colors.length - 1)] : null;
      final a = color?.a ?? 0;
      shader
        ..setFloat(base, (color?.r ?? 0) * a)
        ..setFloat(base + 1, (color?.g ?? 0) * a)
        ..setFloat(base + 2, (color?.b ?? 0) * a)
        ..setFloat(base + 3, a)
        ..setFloat(base + 4, present ? _layers[o] : 0)
        ..setFloat(
          base + 5,
          math.max(0, _layers[o + 1]) * scale * _blendToSmoothing,
        )
        ..setFloat(base + 6, present ? layerStyle.mode.index.toDouble() : 0)
        ..setFloat(base + 7, layerStyle.edgeBlend * scale)
        ..setFloat(base + 8, _layers[o + 2] * scale)
        ..setFloat(base + 9, _layers[o + 3] * scale)
        ..setFloat(base + 10, present ? _layers[o + 4] : 1)
        ..setFloat(base + 11, present ? _layers[o + 5] : 1);
    }
    shader.setImageSampler(0, _dots.image!);

    canvas
      ..save()
      ..translate(offset.dx, offset.dy)
      ..drawRect(bounds, Paint()..shader = shader)
      ..restore();
  }

  void _paintFallback(
    Canvas canvas,
    Offset offset,
    double scale,
    Offset origin,
  ) {
    final values = animator.values;
    final layers = _layerCount;
    final paint = Paint()..color = color;
    for (var i = layers; i < animator.dotCount; i++) {
      final o = i * _sceneStride;
      if (values[o + 2] <= 0 || values[o + 3] >= 0.5) continue;
      canvas.drawCircle(
        offset + origin + Offset(values[o], values[o + 1]) * scale,
        values[o + 2] * scale,
        paint,
      );
    }
  }
}
