import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Where the targets of a `CoilMotionLayer` are, read at paint time.
abstract interface class CoilLayerGeometry {
  /// The rect of target [index] in the layer's coordinates, or null if no
  /// such target is laid out.
  Rect? rectOf(int index);
}

/// Paints a decoration behind or in front of a `CoilMotionLayer`'s child:
/// a travelling highlight, a selection block, a focus ring.
///
/// Painters notify their listeners when they need a repaint (their Motor
/// controllers ticked); the layer then repaints itself only. Nothing
/// rebuilds and nothing is measured outside paint: target rects come from
/// [CoilLayerGeometry] while painting, after this frame's layout.
abstract class CoilLayerPainter extends ChangeNotifier {
  bool _painting = false;

  /// Paints at [offset] (the layer's origin on [canvas]).
  ///
  /// Starting or redirecting animations here is fine: notifications raised
  /// while painting are swallowed (this frame is being painted already),
  /// and later ticks repaint as usual.
  void paint(Canvas canvas, Offset offset, CoilLayerGeometry geometry);

  /// Runs [paint] with notifications suppressed.
  @nonVirtual
  void paintLayer(Canvas canvas, Offset offset, CoilLayerGeometry geometry) {
    _painting = true;
    try {
      paint(canvas, offset, geometry);
    } finally {
      _painting = false;
    }
  }

  @override
  void notifyListeners() {
    if (_painting) return;
    super.notifyListeners();
  }
}

/// A paint layer for decorations shared by sibling items: a gliding
/// highlight, a tab pill, merged selection blocks, a travelling ring.
///
/// It wraps a group of [CoilMotionTarget]s. While painting it reads each
/// target's rect, then paints [background], the child and [foreground]. A
/// decoration follows a target that resizes or reflows in the same frame,
/// with no measuring pass and no rebuild. Put the layer inside a scroll
/// view's content so it moves with the items.
///
/// Components use `CoilMotionLayer`, which takes immutable layer items;
/// this widget takes the painters it owns.
class CoilPainterLayer extends SingleChildRenderObjectWidget {
  /// Creates a painter layer.
  const CoilPainterLayer({
    required super.child,
    super.key,
    this.background = const [],
    this.foreground = const [],
  });

  /// Painted behind the child.
  final List<CoilLayerPainter> background;

  /// Painted in front of the child.
  final List<CoilLayerPainter> foreground;

  @override
  RenderCoilMotionLayer createRenderObject(BuildContext context) =>
      RenderCoilMotionLayer(
        background: background,
        foreground: foreground,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderCoilMotionLayer renderObject,
  ) {
    renderObject
      ..background = background
      ..foreground = foreground;
  }
}

/// The render object of [CoilPainterLayer].
class RenderCoilMotionLayer extends RenderProxyBox
    implements CoilLayerGeometry {
  /// Creates the render object.
  RenderCoilMotionLayer({
    this._background = const [],
    this._foreground = const [],
  });

  final _targets = <int, RenderBox>{};

  /// Painters behind the child.
  List<CoilLayerPainter> get background => _background;
  List<CoilLayerPainter> _background;
  set background(List<CoilLayerPainter> value) {
    if (listEquals(value, _background)) return;
    _relisten(_background, value);
    _background = value;
    markNeedsPaint();
  }

  /// Painters in front of the child.
  List<CoilLayerPainter> get foreground => _foreground;
  List<CoilLayerPainter> _foreground;
  set foreground(List<CoilLayerPainter> value) {
    if (listEquals(value, _foreground)) return;
    _relisten(_foreground, value);
    _foreground = value;
    markNeedsPaint();
  }

  void _relisten(List<CoilLayerPainter> old, List<CoilLayerPainter> next) {
    if (!attached) return;
    for (final p in old) {
      p.removeListener(markNeedsPaint);
    }
    for (final p in next) {
      p.addListener(markNeedsPaint);
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    for (final p in [..._background, ..._foreground]) {
      p.addListener(markNeedsPaint);
    }
  }

  @override
  void detach() {
    for (final p in [..._background, ..._foreground]) {
      p.removeListener(markNeedsPaint);
    }
    super.detach();
  }

  void _register(int index, RenderBox box) {
    _targets[index] = box;
    markNeedsPaint();
  }

  void _unregister(int index, RenderBox box) {
    if (_targets[index] == box) _targets.remove(index);
    if (attached) markNeedsPaint();
  }

  @override
  Rect? rectOf(int index) {
    final box = _targets[index];
    if (box == null || !box.attached || !box.hasSize || !hasSize) return null;
    return MatrixUtils.transformRect(
      box.getTransformTo(this),
      Offset.zero & box.size,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final p in _background) {
      p.paintLayer(context.canvas, offset, this);
    }
    super.paint(context, offset);
    for (final p in _foreground) {
      p.paintLayer(context.canvas, offset, this);
    }
  }
}

/// Marks [child] as target [index] of the nearest `CoilMotionLayer`.
///
/// The render object registers itself with the layer when attached and
/// asks it to repaint whenever it is laid out, so the layer paints against
/// this frame's geometry.
class CoilMotionTarget extends SingleChildRenderObjectWidget {
  /// Creates a motion target.
  const CoilMotionTarget({required this.index, super.key, super.child});

  /// The target's index in its layer.
  final int index;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderCoilMotionTarget(index);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) =>
      (renderObject as _RenderCoilMotionTarget).index = index;
}

class _RenderCoilMotionTarget extends RenderProxyBox {
  _RenderCoilMotionTarget(this._index);

  RenderCoilMotionLayer? _layer;

  int get index => _index;
  int _index;
  set index(int value) {
    if (value == _index) return;
    _layer?._unregister(_index, this);
    _index = value;
    _layer?._register(_index, this);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    var node = parent;
    while (node != null && node is! RenderCoilMotionLayer) {
      node = node.parent;
    }
    _layer = node as RenderCoilMotionLayer?;
    _layer?._register(_index, this);
  }

  @override
  void detach() {
    _layer?._unregister(_index, this);
    _layer = null;
    super.detach();
  }

  @override
  void performLayout() {
    super.performLayout();
    // Our geometry may have changed: the layer paints against it.
    _layer?.markNeedsPaint();
  }
}
