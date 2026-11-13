import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Where the targets of a [CoilMotionLayer] are, read at paint time.
abstract interface class CoilLayerGeometry {
  /// The rect of target [index] in the layer's coordinates, or null if no
  /// such target is laid out.
  Rect? rectOf(int index);
}

/// Paints a decoration behind or in front of a [CoilMotionLayer]'s child:
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

/// Lets a widget that owns a layer ask it where its targets are (for
/// pointer hit tests between frames). Set by the layer's render object.
class CoilMotionLayerHandle implements CoilLayerGeometry {
  RenderFluidMotionLayer? _layer;

  /// The index of every target, in registration order.
  Iterable<int> get indices => _layer?._targets.keys ?? const [];

  @override
  Rect? rectOf(int index) => _layer?.rectOf(index);
}

/// The paint layer for decorations shared by sibling items (research
/// 03-architecture §4.4 B).
///
/// Wraps a group of [CoilMotionTarget]s. At paint it resolves each target's
/// rect from the render tree (after this frame's layout), paints
/// [background] painters, the child, then [foreground] painters. So a
/// highlight follows a row that resizes, reflows or scrolls in the same
/// frame, without measuring passes, post-frame callbacks or rebuilds.
class CoilMotionLayer extends SingleChildRenderObjectWidget {
  /// Creates a motion layer.
  const CoilMotionLayer({
    required super.child,
    super.key,
    this.background = const [],
    this.foreground = const [],
    this.handle,
  });

  /// Painted behind the child.
  final List<CoilLayerPainter> background;

  /// Painted in front of the child.
  final List<CoilLayerPainter> foreground;

  /// Gives the owning widget access to target rects.
  final CoilMotionLayerHandle? handle;

  @override
  RenderFluidMotionLayer createRenderObject(BuildContext context) =>
      RenderFluidMotionLayer(
        background: background,
        foreground: foreground,
        handle: handle,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderFluidMotionLayer renderObject,
  ) {
    renderObject
      ..background = background
      ..foreground = foreground
      ..handle = handle;
  }
}

/// The render object of [CoilMotionLayer].
class RenderFluidMotionLayer extends RenderProxyBox
    implements CoilLayerGeometry {
  /// Creates the render object.
  RenderFluidMotionLayer({
    List<CoilLayerPainter> background = const [],
    List<CoilLayerPainter> foreground = const [],
    CoilMotionLayerHandle? handle,
  }) : _background = background,
       _foreground = foreground,
       _handle = handle {
    _handle?._layer = this;
  }

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

  /// The handle this layer reports to.
  CoilMotionLayerHandle? get handle => _handle;
  CoilMotionLayerHandle? _handle;
  set handle(CoilMotionLayerHandle? value) {
    if (value == _handle) return;
    if (_handle?._layer == this) _handle?._layer = null;
    _handle = value?.._layer = this;
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

/// Marks [child] as target [index] of the nearest [CoilMotionLayer].
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
      _RenderFluidMotionTarget(index);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) =>
      (renderObject as _RenderFluidMotionTarget).index = index;
}

class _RenderFluidMotionTarget extends RenderProxyBox {
  _RenderFluidMotionTarget(this._index);

  RenderFluidMotionLayer? _layer;

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
    while (node != null && node is! RenderFluidMotionLayer) {
      node = node.parent;
    }
    _layer = node as RenderFluidMotionLayer?;
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
