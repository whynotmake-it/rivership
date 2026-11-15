import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:merging_dots/src/animation/dot_animator.dart';
import 'package:merging_dots/src/model/dot_cloud.dart';
import 'package:merging_dots/src/model/dot_grid.dart';
import 'package:merging_dots/src/model/dot_state.dart';
import 'package:merging_dots/src/rendering/dot_shaders.dart';

const _stride = DotState.stride;

/// The largest value a grid dot can show: its data texture stores
/// `value * 200` in a byte.
const double kMaxGridValue = 255 / 200;

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
    if (_shader != null) return _shader;
    final program = this.program;
    if (program == null) return null;
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
/// one texel per cell, rendered on the GPU from a single draw of vertices.
/// The shader then reads only the 5x5 cells around every pixel.
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
  }) : _dotSize = dotSize,
       _blend = blend,
       _offsetRange = offsetRange,
       _cellSize = cellSize;

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

  ui.Image? _data;
  int _dataRevision = -1;
  Object? _dataKey;

  // Geometry of the data texture, cached per grid size.
  int _meshColumns = 0;
  int _meshRows = 0;
  Float32List _positions = Float32List(0);
  Uint16List _indices = Uint16List(0);
  Int32List _colors = Int32List(0);

  /// The cells that hold a visible dot: left, top, right, bottom.
  (int, int, int, int)? _cells;
  Rect? _bounds;

  @override
  ui.FragmentProgram? get program => DotShaders.grid;

  @override
  Object layoutKey(DotGrid target) => (target.columns, target.rows);

  @override
  Size naturalSize(DotGrid target) =>
      Size(target.columns * _cellSize, target.rows * _cellSize);

  @override
  void dispose() {
    _data?.dispose();
    _data = null;
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

  void _ensureMesh(int columns, int rows) {
    if (columns == _meshColumns && rows == _meshRows) return;
    assert(
      columns * rows * 4 <= 65536,
      'A dot grid can have at most 16384 cells.',
    );
    _meshColumns = columns;
    _meshRows = rows;
    final cells = columns * rows;
    _positions = Float32List(cells * 8);
    _indices = Uint16List(cells * 6);
    _colors = Int32List(cells * 4);
    for (var i = 0; i < cells; i++) {
      final x = (i % columns).toDouble();
      final y = (i ~/ columns).toDouble();
      _positions.setAll(i * 8, [x, y, x + 1, y, x + 1, y + 1, x, y + 1]);
      final v = i * 4;
      _indices.setAll(i * 6, [v, v + 1, v + 2, v, v + 2, v + 3]);
    }
  }

  /// Uploads the animator's values to the data texture.
  void _updateData() {
    final grid = animator.target;
    final key = (grid.columns, grid.rows);
    if (_data != null &&
        _dataRevision == animator.revision &&
        _dataKey == key) {
      return;
    }
    _dataRevision = animator.revision;
    _dataKey = key;

    final columns = grid.columns;
    final rows = grid.rows;
    _ensureMesh(columns, rows);
    final values = animator.values;
    final colors = _colors;
    final count = math.min(animator.dotCount, columns * rows);

    var left = columns;
    var top = rows;
    var right = -1;
    var bottom = -1;
    for (var i = 0; i < count; i++) {
      final o = i * _stride;
      final r = (values[o] * 200).round().clamp(0, 255);
      final g = (values[o + 1] * 127).round().clamp(-127, 127) + 128;
      final b = (values[o + 2] * 127).round().clamp(-127, 127) + 128;
      final argb = 0xFF000000 | (r << 16) | (g << 8) | b;
      final c = i * 4;
      colors[c] = argb;
      colors[c + 1] = argb;
      colors[c + 2] = argb;
      colors[c + 3] = argb;
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

    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawVertices(
      ui.Vertices.raw(
        VertexMode.triangles,
        _positions,
        colors: colors,
        indices: _indices,
      ),
      BlendMode.dst,
      Paint(),
    );
    final picture = recorder.endRecording();
    _data?.dispose();
    _data = picture.toImageSync(columns, rows);
    picture.dispose();
  }

  Rect? _contentBounds(double spacing, Offset origin) {
    final cells = _cells;
    if (cells == null) return null;
    if (_bounds != null) return _bounds;
    final (left, top, right, bottom) = cells;
    final reach =
        spacing * (_dotSize / 2 * kMaxGridValue + _blend / 4 + _offsetRange) +
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
    shader
      ..setFloat(4, origin.dx)
      ..setFloat(5, origin.dy)
      ..setFloat(6, grid.columns.toDouble())
      ..setFloat(7, grid.rows.toDouble())
      ..setFloat(8, spacing)
      ..setFloat(9, spacing * _dotSize / 2)
      ..setFloat(10, spacing * _offsetRange)
      ..setFloat(11, spacing * _blend)
      ..setFloat(12, pixelWidth(canvas))
      ..setImageSampler(0, _data!);
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
/// Only the area around the dots is shaded.
class RenderDotCloud extends RenderDots<DotCloud> {
  /// Creates a render object for a cloud, with [blend] in canvas units.
  RenderDotCloud({
    required super.animator,
    required super.color,
    required super.devicePixelRatio,
    required double blend,
  }) : _blend = blend;

  double _blend;

  /// How far dots reach out to merge.
  double get blend => _blend;
  set blend(double value) {
    if (value == _blend) return;
    _blend = value;
    markNeedsPaint();
  }

  @override
  ui.FragmentProgram? get program => DotShaders.cloud;

  @override
  Object layoutKey(DotCloud target) => target.size;

  @override
  Size naturalSize(DotCloud target) => target.size;

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

    final blend = _blend * scale;
    var left = double.infinity;
    var top = double.infinity;
    var right = double.negativeInfinity;
    var bottom = double.negativeInfinity;
    setColor(shader);
    for (var i = 0; i < count; i++) {
      final o = i * _stride;
      final x = origin.dx + values[o] * scale;
      final y = origin.dy + values[o + 1] * scale;
      final r = values[o + 2] * scale;
      final u = 4 + i * 4;
      shader
        ..setFloat(u, x)
        ..setFloat(u + 1, y)
        ..setFloat(u + 2, r);
      if (r <= 0) continue;
      final reach = r + blend / 4 + 2;
      left = math.min(left, x - reach);
      top = math.min(top, y - reach);
      right = math.max(right, x + reach);
      bottom = math.max(bottom, y + reach);
    }
    if (right < left) return;

    canvas
      ..save()
      ..translate(offset.dx, offset.dy);
    shader
      ..setFloat(260, count.toDouble())
      ..setFloat(261, blend)
      ..setFloat(262, pixelWidth(canvas));
    canvas
      ..drawRect(
        Rect.fromLTRB(left, top, right, bottom),
        Paint()..shader = shader,
      )
      ..restore();
  }
}
