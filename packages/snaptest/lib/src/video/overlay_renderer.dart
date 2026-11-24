/// Renders a recording's overlay in a widget tree of its own.
///
/// The overlay never joins the app's tree: it has its own [BuildOwner],
/// [PipelineOwner] and root render object, so the app's layout, hit
/// testing, semantics and frames are untouched. Only its animations share
/// the app's clock: tickers in the overlay run on the binding's scheduler,
/// so they advance whenever the test pumps.
library;

import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'package:snaptest/src/video/video_frame.dart';

/// One rendered overlay image and the logical rect it covers.
@internal
class OverlayImage {
  /// Creates an overlay image covering [logicalBounds].
  const OverlayImage(this.image, this.logicalBounds);

  /// The rendered overlay, at the view's device pixel ratio.
  final ui.Image image;

  /// The logical rect in view coordinates that [image] covers.
  final Rect logicalBounds;

  /// Releases the image.
  void dispose() => image.dispose();
}

/// A persistent, isolated widget tree that renders [builder] on demand.
@internal
class OverlayRenderer {
  /// Creates an overlay tree of the given logical [size] and
  /// [devicePixelRatio].
  OverlayRenderer({
    required this.builder,
    required Size size,
    required double devicePixelRatio,
  }) : _devicePixelRatio = devicePixelRatio,
       _frame = ValueNotifier(
         SnapVideoFrame(pointers: const [], elapsed: Duration.zero, size: size),
       ) {
    _root = _OverlayRenderRoot(size);
    _pipelineOwner.rootNode = _root;
    _root
      ..scheduleInitialLayout()
      ..scheduleInitialPaint(OffsetLayer()..attach(_root));
    _element = _OverlayRootElement(_rootWidget(_overlay()))
      ..assignOwner(_buildOwner);
    _buildOwner.buildScope(_element, () => _element.mount(null, null));
  }

  /// Builds the overlay for each frame.
  final SnapVideoOverlayBuilder builder;

  final _focusManager = FocusManager();
  late final _buildOwner = BuildOwner(focusManager: _focusManager);
  final _pipelineOwner = PipelineOwner();
  late final _OverlayRenderRoot _root;
  late final _OverlayRootElement _element;
  final ValueNotifier<SnapVideoFrame> _frame;
  double _devicePixelRatio;
  bool _disposed = false;

  _OverlayRoot _rootWidget(Widget? child) =>
      _OverlayRoot(renderObject: _root, child: child);

  Widget _overlay() => ValueListenableBuilder<SnapVideoFrame>(
    valueListenable: _frame,
    builder: (context, frame, _) => MediaQuery(
      data: MediaQueryData(
        size: frame.size,
        devicePixelRatio: _devicePixelRatio,
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(builder: (context) => builder(context, frame)),
      ),
    ),
  );

  /// Rebuilds the overlay for [frame] and renders it into an image the
  /// caller must dispose.
  ///
  /// Runs synchronously, so it is safe in the test's fake-async zone; the
  /// returned image rasterizes lazily.
  OverlayImage render(SnapVideoFrame frame, double devicePixelRatio) {
    assert(!_disposed, 'The overlay was already disposed.');
    _devicePixelRatio = devicePixelRatio;
    _root.size = frame.size;
    _frame.value = frame;
    _buildOwner
      ..buildScope(_element)
      ..finalizeTree();
    _pipelineOwner
      ..flushLayout()
      ..flushCompositingBits()
      ..flushPaint();
    return OverlayImage(
      _root.toImageSync(devicePixelRatio),
      Offset.zero & frame.size,
    );
  }

  /// Unmounts the overlay tree, disposing its states and stopping their
  /// animations.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _buildOwner.buildScope(_element, () => _element.update(_rootWidget(null)));
    _buildOwner.finalizeTree();
    _pipelineOwner.rootNode = null;
    _root.dispose();
    _pipelineOwner.dispose();
    _frame.dispose();
    _focusManager.dispose();
  }
}

class _OverlayRoot extends RenderObjectWidget {
  const _OverlayRoot({required this.renderObject, this.child});

  final _OverlayRenderRoot renderObject;
  final Widget? child;

  @override
  _OverlayRootElement createElement() => _OverlayRootElement(this);

  @override
  _OverlayRenderRoot createRenderObject(BuildContext context) => renderObject;
}

class _OverlayRootElement extends RenderTreeRootElement with RootElementMixin {
  _OverlayRootElement(_OverlayRoot super.widget);

  Element? _child;

  @override
  _OverlayRenderRoot get renderObject =>
      super.renderObject as _OverlayRenderRoot;

  @override
  void visitChildren(ElementVisitor visitor) {
    if (_child != null) visitor(_child!);
  }

  @override
  void forgetChild(Element child) {
    assert(child == _child, 'Only the single child can be forgotten.');
    _child = null;
    super.forgetChild(child);
  }

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    _child = updateChild(_child, (widget as _OverlayRoot).child, null);
  }

  @override
  void update(_OverlayRoot newWidget) {
    super.update(newWidget);
    _child = updateChild(_child, newWidget.child, null);
  }

  @override
  void insertRenderObjectChild(RenderObject child, Object? slot) {
    renderObject.child = child as RenderBox;
  }

  @override
  void moveRenderObjectChild(
    RenderObject child,
    Object? oldSlot,
    Object? newSlot,
  ) {
    assert(false, 'The overlay root has a single child that never moves.');
  }

  @override
  void removeRenderObjectChild(RenderObject child, Object? slot) {
    renderObject.child = null;
  }
}

/// The root of the overlay's render tree: a fixed-size repaint boundary,
/// like a [RenderView] without a [ui.FlutterView].
class _OverlayRenderRoot extends RenderObject
    with RenderObjectWithChildMixin<RenderBox> {
  _OverlayRenderRoot(this._size);

  Size _size;

  Size get size => _size;

  set size(Size value) {
    if (value == _size) return;
    _size = value;
    markNeedsLayout();
  }

  @override
  bool get isRepaintBoundary => true;

  @override
  bool get sizedByParent => false;

  @override
  void performResize() {
    assert(false, 'The overlay root is never resized by a parent.');
  }

  @override
  void performLayout() {
    child?.layout(BoxConstraints.tight(_size));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) context.paintChild(child!, offset);
  }

  @override
  Rect get paintBounds => Offset.zero & _size;

  @override
  Rect get semanticBounds => Offset.zero & _size;

  @override
  void debugAssertDoesMeetConstraints() {}

  ui.Image toImageSync(double devicePixelRatio) =>
      (layer! as OffsetLayer).toImageSync(
        Offset.zero & _size,
        pixelRatio: devicePixelRatio,
      );
}
