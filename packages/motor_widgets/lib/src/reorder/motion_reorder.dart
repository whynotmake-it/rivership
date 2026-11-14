import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/src/on_end.dart';
import 'package:motor_widgets/src/ticker_rate.dart';

/// Springs its child from where it was painted to where layout now puts it,
/// whenever [flightKey] changes.
///
/// Put one around each item of a list, grid or board, give it the item's
/// identity as its [key] and the item's place (usually its index) as its
/// [flightKey]. When the list reorders, every item whose [flightKey]
/// changed flies from its old spot to its new one. Nothing else starts a
/// flight: scrolling, a sibling resizing or the window resizing move the
/// item with layout, at once.
///
/// ```dart
/// for (final (index, task) in tasks.indexed)
///   MotionReorder(
///     key: ValueKey(task.id),
///     flightKey: index,
///     child: TaskTile(task),
///   ),
/// ```
///
/// ## Keys
///
/// The [key] keeps the item's element, and with it the item's place on
/// screen, when the list reorders. Without one, the elements stay in place,
/// only their contents change, and nothing flies. For `ListView.builder` and
/// `GridView.builder`, also pass a `findChildIndexCallback`, or the list
/// matches items by index and the reordered items appear without flying.
///
/// An item that moves to another parent, such as another column of a board,
/// gets a new element and appears without flying, unless its key is a
/// [GlobalKey]. Set [scope] to the column to make such a move snap even
/// then.
///
/// ## Coordinates
///
/// Flights run in content coordinates: the item's position plus the scroll
/// offset of every enclosing [Scrollable], so they are measured relative to
/// the scrolled content. Scrolling during a flight moves the flight with the
/// content. Without an enclosing scrollable, flights run in global
/// coordinates, or relative to [coordinateSpace].
///
/// While flying, the target can change in two ways:
///
/// * A new [flightKey], such as another reorder or a rollback, redirects
///   the flight toward the new place, keeping its velocity.
/// * A change of layout alone, such as a resize or a sibling growing,
///   moves the whole flight by the same amount, keeping its velocity. The
///   flight never bends toward a layout shift.
///
/// A flight starts exactly where the item was on screen in the last frame,
/// even when an ancestor moved it there without repainting it, as a list
/// does when an item above resizes.
///
/// ## Painting and hit testing
///
/// Only the painting moves. Hit testing and semantics stay at the layout
/// position throughout a flight, so a tap goes to the item that will be
/// there.
///
/// With [repaintBoundary], each frame of a flight only moves a composited
/// layer and repaints nothing.
///
/// ## Reduced motion
///
/// Like the other motor_widgets, this widget has no motion policy of its
/// own. Pass `Motion.instant()` as [motion] for reduced motion, or set
/// [enabled] to false.
class MotionReorder extends StatefulWidget {
  /// Creates a [MotionReorder].
  const MotionReorder({
    required this.flightKey,
    required this.child,
    this.scope,
    this.enabled = true,
    this.coordinateSpace,
    this.repaintBoundary = true,
    this.motion = defaultMotion,
    this.onEnd,
    this.tickerRate,
    this.debugLabel,
    super.key,
  });

  /// The default [motion]: a quick spring with a little bounce.
  static const Motion defaultMotion = CupertinoMotion.snappy(
    duration: Duration(milliseconds: 200),
  );

  /// The item's place, compared with `==`. A change starts a flight from
  /// where the item was painted to its new layout position.
  ///
  /// Usually the item's index.
  final Object flightKey;

  /// A group the item belongs to, compared with `==`, such as the column of
  /// a board. A change makes the item snap to its new place with no flight,
  /// even if [flightKey] changes at the same time.
  final Object? scope;

  /// Whether flights may run. When false, a running flight ends at once and
  /// [flightKey] changes snap.
  ///
  /// Turn it off while another animation owns the item's visual, such as a
  /// `MotionDraggable` landing on it.
  final bool enabled;

  /// A stable ancestor to measure positions in, instead of the screen.
  ///
  /// Use it when something above the item moves it on screen without a
  /// reorder, such as a popup that follows its anchor.
  final GlobalKey? coordinateSpace;

  /// Whether the item is its own repaint boundary.
  ///
  /// When true, a flight moves a composited layer and repaints nothing. When
  /// false, every frame of a flight repaints the nearest repaint boundary
  /// above the item, and a flight starts from where the item was last
  /// painted, which is out of date if an ancestor moved it since without
  /// repainting it.
  final bool repaintBoundary;

  /// The motion of a flight.
  final Motion motion;

  /// {@macro motor_widgets.onEnd}
  final VoidCallback? onEnd;

  /// {@macro motor_widgets.tickerRate}
  final TickerRate? tickerRate;

  /// {@macro motor_widgets.debugLabel}
  final String? debugLabel;

  /// The widget below this widget in the tree.
  final Widget child;

  @override
  State<MotionReorder> createState() => _MotionReorderState();
}

class _MotionReorderState extends State<MotionReorder>
    with FixedTickerProviderStateMixin, WidgetTickerRateMixin {
  @override
  TickerRate? get widgetTickerRate => widget.tickerRate;

  @override
  void didUpdateWidget(MotionReorder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tickerRate != oldWidget.tickerRate) updateTickerRate();
  }

  @override
  Widget build(BuildContext context) {
    final space = widget.coordinateSpace?.currentContext;
    final scrollables = <ScrollableState>[];
    for (
      var scrollable = Scrollable.maybeOf(context);
      scrollable != null;
      scrollable = Scrollable.maybeOf(scrollable.context)
    ) {
      // A scrollable above the coordinate space moves the space and the
      // item together, so its offset isn't part of the item's position.
      if (space != null && !_isAncestor(space, scrollable.context)) break;
      scrollables.add(scrollable);
    }
    return _MotionReorderLayout(
      vsync: this,
      flightKey: widget.flightKey,
      scope: widget.scope,
      enabled: widget.enabled,
      coordinateSpace: widget.coordinateSpace,
      scrollables: scrollables,
      repaintBoundary: widget.repaintBoundary,
      motion: widget.motion,
      onEnd: widget.onEnd,
      debugLabel: widget.debugLabel ?? 'MotionReorder',
      child: widget.child,
    );
  }

  static bool _isAncestor(BuildContext ancestor, BuildContext of) {
    var found = false;
    of.visitAncestorElements((element) {
      found = identical(element, ancestor);
      return !found;
    });
    return found;
  }
}

class _MotionReorderLayout extends SingleChildRenderObjectWidget {
  const _MotionReorderLayout({
    required this.vsync,
    required this.flightKey,
    required this.scope,
    required this.enabled,
    required this.coordinateSpace,
    required this.scrollables,
    required this.repaintBoundary,
    required this.motion,
    required this.onEnd,
    required this.debugLabel,
    super.child,
  });

  final TickerProvider vsync;
  final Object flightKey;
  final Object? scope;
  final bool enabled;
  final GlobalKey? coordinateSpace;
  final List<ScrollableState> scrollables;
  final bool repaintBoundary;
  final Motion motion;
  final VoidCallback? onEnd;
  final String debugLabel;

  @override
  _RenderMotionReorder createRenderObject(BuildContext context) =>
      _RenderMotionReorder(
        vsync: vsync,
        flightKey: flightKey,
        scope: scope,
        enabled: enabled,
        coordinateSpace: coordinateSpace,
        scrollables: scrollables,
        repaintBoundary: repaintBoundary,
        motion: motion,
        onEnd: onEnd,
        debugLabel: debugLabel,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMotionReorder renderObject,
  ) {
    renderObject.update(
      vsync: vsync,
      flightKey: flightKey,
      scope: scope,
      enabled: enabled,
      coordinateSpace: coordinateSpace,
      scrollables: scrollables,
      repaintBoundary: repaintBoundary,
      motion: motion,
      onEnd: onEnd,
      debugLabel: debugLabel,
    );
  }
}

/// The layer of a [_RenderMotionReorder] that is its own repaint boundary.
/// Its transform is the flight's offset.
class _ReorderLayer extends TransformLayer {}

/// Paints its child at an offset that springs from where the child was
/// painted to its layout position, whenever the flight key changes.
///
/// Positions are content coordinates: the global position, or the position
/// in the coordinate space, plus the scroll offsets of the enclosing
/// scrollables. The controller's value is the painted content position, and
/// its target is the layout content position, so the painted offset is the
/// difference.
///
/// A flight is resolved after layout: in [updateCompositedLayer] when this
/// is a repaint boundary, else in [paint]. A flight key change schedules
/// that step; so does every frame of a flight. An item that isn't painted
/// in the frame of a flight key change resolves after that frame instead.
class _RenderMotionReorder extends RenderProxyBox {
  _RenderMotionReorder({
    required TickerProvider vsync,
    required Object flightKey,
    required Object? scope,
    required bool enabled,
    required GlobalKey? coordinateSpace,
    required List<ScrollableState> scrollables,
    required bool repaintBoundary,
    required Motion motion,
    required VoidCallback? onEnd,
    required String debugLabel,
  }) : _vsync = vsync,
       _flightKey = flightKey,
       _scope = scope,
       _enabled = enabled,
       _coordinateSpace = coordinateSpace,
       _scrollables = scrollables,
       _repaintBoundary = repaintBoundary,
       _motion = motion,
       _onEnd = onEnd,
       _debugLabel = debugLabel {
    _trackScrollables();
  }

  TickerProvider _vsync;
  Object _flightKey;
  Object? _scope;
  bool _enabled;
  GlobalKey? _coordinateSpace;
  List<ScrollableState> _scrollables;
  bool _repaintBoundary;
  Motion _motion;
  VoidCallback? _onEnd;
  String _debugLabel;

  MotionController<Offset>? _controller;
  ValueChanged<AnimationStatus>? _onEndListener;

  /// Where a flight from rest starts, read before relayout.
  Offset? _pendingOrigin;

  /// Whether a flight key change redirects the running flight.
  bool _redirect = false;

  /// The layout content position the running flight heads for.
  Offset? _flightTarget;

  /// The painted offset of the last resolve.
  Offset _visual = Offset.zero;

  /// The painted content position of the last resolve, for a flight from
  /// rest when the composited position can't be read.
  Offset? _lastPaintedContent;

  /// Whether a resolve is running, when the controller's listeners must not
  /// schedule another one.
  bool _resolving = false;

  /// Whether a post-frame callback will start a pending flight that no
  /// paint started.
  bool _startScheduled = false;

  bool get _inFlight => _controller?.isAnimating ?? false;

  @override
  bool get isRepaintBoundary => _repaintBoundary;

  void update({
    required TickerProvider vsync,
    required Object flightKey,
    required Object? scope,
    required bool enabled,
    required GlobalKey? coordinateSpace,
    required List<ScrollableState> scrollables,
    required bool repaintBoundary,
    required Motion motion,
    required VoidCallback? onEnd,
    required String debugLabel,
  }) {
    final keyChanged = flightKey != _flightKey;
    final scopeChanged = scope != _scope || coordinateSpace != _coordinateSpace;
    if (!identical(vsync, _vsync)) {
      _vsync = vsync;
      _controller?.resync(vsync);
    }
    _flightKey = flightKey;
    _scope = scope;
    _enabled = enabled;
    _coordinateSpace = coordinateSpace;
    _scrollables = scrollables;
    _trackScrollables();
    if (motion != _motion) {
      _motion = motion;
      _controller?.motion = motion;
    }
    if (onEnd != _onEnd) {
      _onEnd = onEnd;
      _listenForEnd();
    }
    _debugLabel = debugLabel;
    if (repaintBoundary != _repaintBoundary) {
      _repaintBoundary = repaintBoundary;
      markNeedsCompositingBitsUpdate();
      markNeedsPaint();
    }

    if (scopeChanged || !enabled) {
      _abortFlight();
      return;
    }
    if (!keyChanged || !attached || !hasSize) return;
    if (_inFlight) {
      _redirect = true;
      _scheduleStart();
      return;
    }
    _pendingOrigin ??= _originContent();
    if (_pendingOrigin != null) _scheduleStart();
  }

  /// Makes a pending flight start, or redirect, in this frame.
  ///
  /// The paint phase resolves it, so a painted item flies from the frame's
  /// first picture. Flutter skips painting an item that is mounted but off
  /// screen, such as one in a list's cache extent, so a post-frame callback
  /// resolves the flight from this frame's layout if no paint did. Such an
  /// item flies unseen and is at rest by the time it's scrolled in.
  void _scheduleStart() {
    _scheduleResolve();
    if (_startScheduled) return;
    _startScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _startScheduled = false;
      if (!attached || (_pendingOrigin == null && !_redirect)) return;
      _resolve();
    }, debugLabel: 'MotionReorder.start');
  }

  void _trackScrollables() {
    for (final scrollable in _scrollables) {
      _ScrollHistory.of(scrollable.position);
    }
  }

  void _abortFlight() {
    _pendingOrigin = null;
    _redirect = false;
    _flightTarget = null;
    if (!_inFlight && _visual == Offset.zero) return;
    _controller?.stop(canceled: true);
    _scheduleResolve();
  }

  void _scheduleResolve() {
    if (_resolving) return;
    // Falls back to markNeedsPaint while this isn't a repaint boundary.
    markNeedsCompositedLayerUpdate();
  }

  MotionController<Offset> _ensureController() {
    if (_controller case final controller?) return controller;
    final controller = MotionController<Offset>(
      motion: _motion,
      vsync: _vsync,
      converter: MotionConverter.offset,
      initialValue: Offset.zero,
      velocityTracking: const VelocityTracking.off(),
      debugLabel: _debugLabel,
    )..addListener(_scheduleResolve);
    _controller = controller;
    _listenForEnd();
    return controller;
  }

  void _listenForEnd() {
    final controller = _controller;
    if (controller == null) return;
    if (_onEndListener case final listener?) {
      controller.removeStatusListener(listener);
    }
    _onEndListener = onEndListener(_onEnd);
    if (_onEndListener case final listener?) {
      controller.addStatusListener(listener);
    }
  }

  /// The layout position in content coordinates.
  Offset _contentPosition() {
    final space = _spaceRenderObject();
    return localToGlobal(Offset.zero, ancestor: space) +
        _scrollCompensation(composited: false);
  }

  RenderObject? _spaceRenderObject() {
    final space = _coordinateSpace?.currentContext?.findRenderObject();
    return space != null && space.attached ? space : null;
  }

  /// The offset that turns a position into content coordinates: the sum of
  /// the enclosing scrollables' offsets, along their axis directions.
  ///
  /// With [composited], the offsets of the last composited frame.
  Offset _scrollCompensation({required bool composited}) {
    var dx = 0.0;
    var dy = 0.0;
    for (final scrollable in _scrollables) {
      final position = scrollable.position;
      if (!position.hasPixels) continue;
      final pixels = composited
          ? _ScrollHistory.of(position).composited
          : position.pixels;
      switch (position.axisDirection) {
        case AxisDirection.down:
          dy += pixels;
        case AxisDirection.up:
          dy -= pixels;
        case AxisDirection.right:
          dx += pixels;
        case AxisDirection.left:
          dx -= pixels;
      }
    }
    return Offset(dx, dy);
  }

  /// Where the item was painted in the last frame, in content coordinates,
  /// read before relayout.
  Offset? _originContent() {
    if (_compositedGlobal() case final global?) {
      final space = _spaceRenderObject();
      final spaceOrigin = space is RenderBox
          ? space.localToGlobal(Offset.zero)
          : Offset.zero;
      return global - spaceOrigin + _scrollCompensation(composited: true);
    }
    return _lastPaintedContent;
  }

  /// The global position at which this item's layer was last composited, or
  /// null when it has none.
  ///
  /// The layer tree still holds the last frame while widgets rebuild, so
  /// this is where the item was on screen, even if an ancestor moved it
  /// there without repainting it. It walks the layers as [FollowerLayer]
  /// does, without the root layer's device pixel ratio. Ancestor reorder
  /// layers only count with their offset: their flight paints this item but
  /// isn't part of its position.
  Offset? _compositedGlobal() {
    if (!isRepaintBoundary) return null;
    final own = layer;
    if (own is! _ReorderLayer || own.parent == null) return null;
    final chain = <ContainerLayer>[];
    ContainerLayer? current = own;
    while (current != null && current.parent != null) {
      chain.add(current);
      current = current.parent;
    }
    if (current == null || !current.attached) return null;
    final transform = Matrix4.identity();
    for (var i = chain.length - 1; i >= 1; i--) {
      final parent = chain[i];
      if (parent is _ReorderLayer) {
        transform.translateByDouble(parent.offset.dx, parent.offset.dy, 0, 1);
      } else {
        parent.applyTransform(chain[i - 1], transform);
      }
    }
    own.applyTransform(own.firstChild ?? own, transform);
    var global = MatrixUtils.transformPoint(transform, Offset.zero);
    // Ancestors that aren't repaint boundaries paint their flight into the
    // offset of the layers below them.
    for (var node = parent; node != null; node = node.parent) {
      if (node is _RenderMotionReorder && !node.isRepaintBoundary) {
        global -= node._visual;
      }
    }
    return global;
  }

  bool _near(Offset a, Offset b) => (a - b).distanceSquared < 1e-4;

  /// Starts, redirects or moves the flight after layout, and returns the
  /// painted offset.
  Offset _resolve() {
    if (!hasSize) return Offset.zero;
    _resolving = true;
    try {
      final target = _contentPosition();
      final origin = _pendingOrigin;
      final redirect = _redirect;
      _pendingOrigin = null;
      _redirect = false;
      final controller = _controller;
      if (origin != null && _enabled && !_near(origin, target)) {
        _flightTarget = target;
        _ensureController().animateTo(
          target,
          from: origin,
          withVelocity: Offset.zero,
        );
      } else if (controller != null && controller.isAnimating) {
        final previous = _flightTarget ?? target;
        if (!_near(previous, target)) {
          _flightTarget = target;
          if (redirect) {
            controller.animateTo(target);
          } else {
            // Moving both ends of a spring by the same amount keeps its
            // motion exactly, so the flight never bends toward a layout
            // shift.
            controller.animateTo(
              target,
              from: controller.value + (target - previous),
            );
          }
        }
      }
      final flying = _controller?.isAnimating ?? false;
      if (!flying) _flightTarget = null;
      _visual = flying ? _controller!.value - target : Offset.zero;
      _lastPaintedContent = target + _visual;
      return _visual;
    } finally {
      _resolving = false;
    }
  }

  @override
  OffsetLayer updateCompositedLayer({
    required covariant _ReorderLayer? oldLayer,
  }) {
    final layer = oldLayer ?? _ReorderLayer();
    final visual = _resolve();
    layer.transform = Matrix4.translationValues(visual.dx, visual.dy, 0);
    return layer;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    if (isRepaintBoundary) {
      context.paintChild(child, offset);
      return;
    }
    context.paintChild(child, offset + _resolve());
  }

  @override
  void dispose() {
    _controller
      ?..removeListener(_scheduleResolve)
      ..dispose();
    _controller = null;
    super.dispose();
  }
}

/// The pixels of a [ScrollPosition] as of the last composited frame.
///
/// A widget rebuilds after the frame's scroll has already moved, while its
/// layers still show the last frame. Reading where an item was on screen in
/// content coordinates needs the scroll offset of that same frame, which
/// this keeps, one per position.
final class _ScrollHistory {
  _ScrollHistory._(this._position)
    : composited = _position.hasPixels ? _position.pixels : 0 {
    _position.addListener(_changed);
  }

  factory _ScrollHistory.of(ScrollPosition position) =>
      _histories[position] ??= _ScrollHistory._(position);

  static final _histories = Expando<_ScrollHistory>('ScrollHistory');

  final ScrollPosition _position;

  /// The pixels of the last composited frame.
  double composited;

  bool _scheduled = false;

  void _changed() {
    if (_scheduled) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (_position.hasPixels) composited = _position.pixels;
    }, debugLabel: 'MotionReorder.scrollHistory');
  }
}
