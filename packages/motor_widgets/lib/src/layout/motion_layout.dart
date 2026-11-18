import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/src/drag/flight.dart';
import 'package:motor_widgets/src/drag/motion_draggable.dart';
import 'package:motor_widgets/src/painted_position.dart';
import 'package:motor_widgets/src/ticker_rate.dart';

/// Animates its [MotionLayoutItem]s when their order changes.
///
/// Each item has an [MotionLayoutItem.id]. When the widgets around an item
/// are rebuilt and the item ends up in another place, it flies from where
/// it was painted to its new place on a spring:
///
/// ```dart
/// MotionLayoutGroup(
///   child: Column(
///     children: [
///       for (final todo in todos)
///         MotionLayoutItem(id: todo.id, child: TodoTile(todo)),
///     ],
///   ),
/// )
/// ```
///
/// Reorders, inserts and removals around an item, and moves to another
/// container of the same group, all fly. An item is found by its id, not by
/// its widget, so it flies even when it is built anew, such as by a lazy
/// list or in another column.
///
/// ## What flies
///
/// An item checks whether it moved when it is rebuilt or built anew,
/// comparing where it was painted in the last frame with where it is laid
/// out now. Nothing is checked in frames without a rebuild, so:
///
/// * Scrolling never moves an item, and neither do animations elsewhere,
///   such as a sticky header.
/// * A neighbor that grows on its own, such as with a `MotionSize`, moves
///   an item without a rebuild, so the item follows it frame by frame
///   instead of flying.
/// * An item that wasn't on screen in the last frame appears in place.
///
/// A [MotionDraggable] lands on the item with its id, and hands the rest of
/// its landing to the item's spring.
class MotionLayoutGroup extends StatefulWidget {
  /// Animates the [MotionLayoutItem]s below [child].
  const MotionLayoutGroup({
    required this.child,
    this.motion = defaultMotion,
    this.enabled = true,
    this.debugLabel,
    this.tickerRate,
    super.key,
  });

  /// The default [motion]: a quick spring with a little bounce.
  static const Motion defaultMotion = CupertinoMotion.snappy(
    duration: Duration(milliseconds: 200),
  );

  /// The motion of every item that has none of its own.
  final Motion motion;

  /// Whether items fly. While false, they jump to their new places.
  final bool enabled;

  /// {@macro motor_widgets.debugLabel}
  final String? debugLabel;

  /// {@macro motor_widgets.tickerRate}
  final TickerRate? tickerRate;

  /// The widget below this widget in the tree.
  final Widget child;

  /// Whether [context] is below a [MotionLayoutGroup].
  static bool isIn(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_GroupScope>() != null;

  @override
  State<MotionLayoutGroup> createState() => _MotionLayoutGroupState();
}

/// One item of a [MotionLayoutGroup], which flies when its layout moves it.
///
/// See [MotionLayoutGroup] for what counts as a move.
///
/// While a [MotionDraggable] with the same id lands on it, the item keeps
/// its place but hides its child, and the landing hands off to the item's
/// spring once the item can be seen.
class MotionLayoutItem extends StatefulWidget {
  /// Animates [child] when its layout moves it.
  const MotionLayoutItem({
    required this.id,
    required this.child,
    this.motion,
    this.enabled = true,
    super.key,
  });

  /// The item's identity, compared with `==`. Unique within the group, which
  /// is also where a [MotionDraggable] with the same id lands.
  final Object id;

  /// The item's motion. Defaults to the group's.
  final Motion? motion;

  /// Whether the item flies. While false, it jumps to its new place.
  final bool enabled;

  /// The widget below this widget in the tree.
  final Widget child;

  @override
  State<MotionLayoutItem> createState() => MotionLayoutItemState();
}

class _MotionLayoutGroupState extends State<MotionLayoutGroup>
    with FixedTickerProviderStateMixin, WidgetTickerRateMixin {
  final _records = <Object, _Record>{};

  /// The landing sites of the group's items: ids are unique within it.
  final _landings = LandingRegistry();

  /// The scrollables around the group, which move it with its items.
  List<ScrollableState> _outside = const [];

  @override
  TickerRate? get widgetTickerRate => widget.tickerRate;

  @override
  void didUpdateWidget(MotionLayoutGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tickerRate != oldWidget.tickerRate) updateTickerRate();
  }

  @override
  void dispose() {
    for (final record in _records.values) {
      record.dispose();
    }
    _records.clear();
    super.dispose();
  }

  _Record _recordFor(Object id) => _records[id] ??= _Record();

  /// Reports two items with [id] once this frame is done. While a lazy list
  /// rebuilds, an item's new widget is built before its old one goes away.
  void _checkDuplicates(Object id, _RenderItem item) {
    assert(() {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !item.attached) return;
        final record = _records[id];
        final other = record?.owner;
        if (other == null || identical(other, item) || !other.attached) {
          return;
        }
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: FlutterError(
              'Two MotionLayoutItems in one MotionLayoutGroup have the id '
              '$id.',
            ),
            library: 'motor_widgets',
          ),
        );
      }, debugLabel: 'MotionLayoutGroup.duplicates');
      return true;
    }(), 'never fails: it only reports duplicate ids');
  }

  /// Forgets [id] once no item has it any more, after this frame.
  void _release(Object id, _RenderItem owner) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      final record = _records[id];
      if (record == null || !identical(record.owner, owner)) return;
      if (owner.attached) return;
      _records.remove(id);
      record.dispose();
    }, debugLabel: 'MotionLayoutGroup.release');
  }

  MotionController<Offset> _controllerFor(_Record record, Motion motion) {
    final controller = record.controller ??= MotionController<Offset>(
      motion: motion,
      vsync: this,
      converter: MotionConverter.offset,
      initialValue: Offset.zero,
      velocityTracking: const VelocityTracking.off(),
      debugLabel: widget.debugLabel ?? 'MotionLayoutItem',
    )..addListener(() => record.owner?._flightTicked());
    if (controller.motion != motion) controller.motion = motion;
    return controller;
  }

  @override
  Widget build(BuildContext context) {
    _outside = _scrollablesOf(context);
    for (final scrollable in _outside) {
      _ScrollHistory.of(scrollable.position);
    }
    return LandingScope(
      registry: _landings,
      child: _GroupScope(
        state: this,
        child: _GroupBox(state: this, child: widget.child),
      ),
    );
  }
}

/// An item's flight, kept by id so that it carries over when the item is
/// built anew.
class _Record {
  /// The render object that has the id now, or last had it.
  _RenderItem? owner;

  /// The flight. Its value is the painted position, its target the layout
  /// position, both in the group's content coordinates.
  MotionController<Offset>? controller;

  /// The layout position the flight heads for.
  Offset? target;

  bool get flying => controller?.isAnimating ?? false;

  void dispose() {
    controller?.dispose();
    controller = null;
  }
}

List<ScrollableState> _scrollablesOf(BuildContext context) => [
  for (
    var scrollable = Scrollable.maybeOf(context);
    scrollable != null;
    scrollable = Scrollable.maybeOf(scrollable.context)
  )
    scrollable,
];

class _GroupScope extends InheritedWidget {
  const _GroupScope({required this.state, required super.child});

  final _MotionLayoutGroupState state;

  @override
  bool updateShouldNotify(_GroupScope oldWidget) =>
      !identical(state, oldWidget.state);
}

class _GroupBox extends SingleChildRenderObjectWidget {
  const _GroupBox({required this.state, super.child});

  final _MotionLayoutGroupState state;

  @override
  _RenderGroup createRenderObject(BuildContext context) => _RenderGroup(state);

  @override
  void updateRenderObject(BuildContext context, _RenderGroup renderObject) {
    renderObject.state = state;
  }
}

/// The group's repaint boundary, whose coordinates its items measure
/// themselves in, and the landing scope of a drop over it.
class _RenderGroup extends RenderProxyBox implements LandingScopeBox {
  _RenderGroup(this.state);

  _MotionLayoutGroupState state;

  @override
  LandingRegistry get landingRegistry => state._landings;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    LandingScopeBox.mounted.add(this);
  }

  @override
  void detach() {
    LandingScopeBox.mounted.remove(this);
    super.detach();
  }

  @override
  bool get isRepaintBoundary => true;

  @override
  OffsetLayer updateCompositedLayer({
    required covariant _GroupLayer? oldLayer,
  }) => (oldLayer ?? _GroupLayer())..state = state;
}

class _GroupLayer extends OffsetLayer {
  _MotionLayoutGroupState? state;
}

/// The scroll offset of a [ScrollPosition] as of the last composited frame.
///
/// An item that is rebuilt reads where it was painted from the last frame's
/// layers, which show that frame's scroll offsets. A scroll since then has
/// moved the position already, so the offsets of that frame are kept here.
/// They are recorded after every frame, not from the position's listeners,
/// which miss the corrections layout makes.
final class _ScrollHistory {
  _ScrollHistory._(this._position)
    : composited = _position.hasPixels ? _position.pixels : 0 {
    _all.add(WeakReference(this));
    if (_recording) return;
    _recording = true;
    // Persistent callbacks run in the order they were added, so this one
    // runs after the frame's layout, paint and compositing.
    SchedulerBinding.instance.addPersistentFrameCallback((_) => _recordAll());
  }

  factory _ScrollHistory.of(ScrollPosition position) =>
      _histories[position] ??= _ScrollHistory._(position);

  static final _histories = Expando<_ScrollHistory>('ScrollHistory');
  static final _all = <WeakReference<_ScrollHistory>>[];
  static bool _recording = false;

  static void _recordAll() => _all.removeWhere((reference) {
    final history = reference.target;
    if (history == null) return true;
    final position = history._position;
    if (position.hasPixels) history.composited = position.pixels;
    return false;
  });

  final ScrollPosition _position;

  /// The pixels of the last composited frame.
  double composited;
}

/// The offset that turns a position into content coordinates: the sum of
/// [scrollables]' offsets along their axes, as of the last composited frame
/// with [composited], else now.
Offset _scrollOffset(
  List<ScrollableState> scrollables, {
  required bool composited,
}) {
  var dx = 0.0;
  var dy = 0.0;
  for (final scrollable in scrollables) {
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

/// The state of a [MotionLayoutItem]: the landing site of a [MotionDraggable]
/// with its id.
class MotionLayoutItemState extends State<MotionLayoutItem>
    with FixedTickerProviderStateMixin
    implements LandingSite {
  LandingRegistry? _registry;
  Object? _registeredId;
  _MotionLayoutGroupState? _group;

  /// Continues a handed-off landing's scale, rotation and opacity.
  TrackController? _visuals;

  /// The draggable that drags this item, which a landing grabbed again
  /// passes its pointer to.
  LandingSite? grabber;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _group = context.getInheritedWidgetOfExactType<_GroupScope>()?.state;
    assert(
      _group != null,
      'A MotionLayoutItem must be below a MotionLayoutGroup.',
    );
    _register();
  }

  @override
  void didUpdateWidget(MotionLayoutItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    _register();
  }

  void _register() {
    final registry = LandingRegistry.maybeOf(context);
    final id = widget.id;
    if (registry == _registry && id == _registeredId) return;
    _unregister();
    _registry = registry?..add(id, this);
    _registeredId = id;
  }

  void _unregister() {
    if (_registeredId case final id?) _registry?.remove(id, this);
    _registry = null;
    _registeredId = null;
  }

  @override
  void dispose() {
    _unregister();
    _visuals?.dispose();
    super.dispose();
  }

  _RenderItem? get _box {
    if (!mounted) return null;
    final box = context.findRenderObject();
    return box is _RenderItem && box.attached && box.hasSize ? box : null;
  }

  // Landing.

  @override
  bool get holdsLanding => mounted && LandingHold.of(context);

  @override
  Rect? get globalRect {
    final box = _box;
    if (box == null) return null;
    return landingRect(box, includeOwn: true);
  }

  @override
  final LayerLink landingLink = LayerLink();

  @override
  FlightReceiver? get flightReceiver {
    // A held landing waits in the overlay for the item it stands in for.
    if (holdsLanding) return null;
    final box = _box;
    return box != null && box.canReceiveFlight ? box : null;
  }

  @override
  Rect? get visibleRect => mounted ? visibleRectOf(context) : null;

  @override
  void receiveVisuals(List<TrackValue<double>> values) {
    if (!mounted) return;
    if (_visuals == null) {
      setState(() {
        _visuals = TrackController(
          vsync: this,
          debugLabel: 'MotionLayoutItem',
        );
      });
    }
    final motion = widget.motion ?? _group?.widget.motion;
    _visuals!
      ..set(values)
      ..animate(
        feedbackToRest((_) => motion ?? MotionLayoutGroup.defaultMotion),
      );
  }

  @override
  void landingChanged() {
    if (mounted) setState(() {});
  }

  @override
  bool grab(PointerDownEvent event, DragFlight flight) =>
      grabber?.grab(event, flight) ?? false;

  @override
  void endGrab(DragFlight flight) => grabber?.endGrab(flight);

  @override
  Widget build(BuildContext context) {
    final group = _group!;
    final id = widget.id;
    final landing = _registry?.isLanding(id) ?? false;
    final fading = _registry?.isFading(id) ?? false;
    final outside = group._outside;
    final scrollables = [
      for (final scrollable in _scrollablesOf(context))
        if (!outside.contains(scrollable)) scrollable,
    ];
    // Their offsets are recorded after every frame from now on, so they
    // are there for the first read after a scroll.
    for (final scrollable in scrollables) {
      _ScrollHistory.of(scrollable.position);
    }
    final visuals = _visuals;
    return _ItemBox(
      group: group,
      id: id,
      enabled: widget.enabled,
      landing: landing,
      motion: widget.motion ?? group.widget.motion,
      scrollables: scrollables,
      // While a flight lands here, the child is hidden and the flight
      // follows where it is painted. The leader sits outside the
      // Visibility, which doesn't paint its child while hidden.
      child: LeaderWhile(
        link: landing || fading ? landingLink : null,
        child: PaintedVisuals(
          listenable: visuals,
          scale: () => visuals?.value(MotionDraggableTrack.scale) ?? 1,
          turns: () => visuals?.value(MotionDraggableTrack.rotation) ?? 0,
          opacity: () => visuals?.value(MotionDraggableTrack.opacity) ?? 1,
          child: Visibility.maintain(visible: !landing, child: widget.child),
        ),
      ),
    );
  }
}

class _ItemBox extends SingleChildRenderObjectWidget {
  const _ItemBox({
    required this.group,
    required this.id,
    required this.enabled,
    required this.landing,
    required this.motion,
    required this.scrollables,
    super.child,
  });

  final _MotionLayoutGroupState group;
  final Object id;
  final bool enabled;
  final bool landing;
  final Motion motion;
  final List<ScrollableState> scrollables;

  @override
  _RenderItem createRenderObject(BuildContext context) => _RenderItem(
    group: group,
    id: id,
    enabled: enabled,
    landing: landing,
    motion: motion,
    scrollables: scrollables,
  );

  @override
  void updateRenderObject(BuildContext context, _RenderItem renderObject) {
    // A child of a list without keys is reused for another item, so it may
    // get another id: it then flies from where that item was.
    if (renderObject.id != id) {
      renderObject.reassign(id);
    } else {
      renderObject.rebuilt();
    }
    renderObject
      ..group = group
      ..enabled = enabled
      ..landing = landing
      ..motion = motion
      ..scrollables = scrollables;
  }
}

/// Paints its child at the flight's offset from its layout position.
///
/// It is a repaint boundary, so its [_ItemLayer] keeps where it was painted
/// in the last frame until it is painted again. When it is rebuilt, or
/// built anew for an id another item had, it reads that position, before
/// anything is laid out again. When it is painted next, it compares that
/// with where it is laid out now and flies if they differ. Hit testing
/// stays at the layout position.
class _RenderItem extends RenderProxyBox
    implements PaintOffset, FlightReceiver {
  _RenderItem({
    required this.group,
    required this.id,
    required this.enabled,
    required this.landing,
    required this.motion,
    required this.scrollables,
  });

  _MotionLayoutGroupState group;
  Object id;
  bool enabled;

  /// Whether a drag's landing flies to this item in the overlay. The item
  /// is hidden meanwhile and takes its place without flying: the landing
  /// is its flight.
  bool landing;
  Motion motion;
  List<ScrollableState> scrollables;

  /// Where it was painted in the last frame, in the group's content
  /// coordinates, read when it was rebuilt, until it is painted.
  Offset? _origin;

  /// The flight's offset as last painted.
  Offset _visual = Offset.zero;

  @override
  bool get isRepaintBoundary => true;

  @override
  OffsetLayer updateCompositedLayer({
    required covariant _ItemLayer? oldLayer,
  }) {
    return (oldLayer ?? _ItemLayer())..visual = _resolve();
  }

  /// How far from its layout position the child is painted: from the
  /// flight as it is now, also while the item isn't painted, such as in a
  /// list's cache extent, where the last painted offset would be stale.
  @override
  Offset get paintOffset {
    if (!group.mounted) return Offset.zero;
    final record = group._records[id];
    final target = record?.target;
    if (record == null || target == null || !record.flying) return Offset.zero;
    return record.controller!.value - target;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    final record = group._recordFor(id);
    final previous = record.owner;
    group._checkDuplicates(id, this);
    // Built anew for an id that was on screen: it flies from there.
    if (previous != null && !identical(previous, this)) {
      _arm(previous._lastPainted());
    }
    record.owner = this;
  }

  @override
  void detach() {
    group._release(id, this);
    super.detach();
  }

  /// Gives this item [newId], which another item may have had: it flies
  /// from where that item was painted.
  void reassign(Object newId) {
    if (!attached) {
      id = newId;
      return;
    }
    group._release(id, this);
    id = newId;
    final record = group._recordFor(newId);
    final previous = record.owner;
    group._checkDuplicates(newId, this);
    record.owner = this;
    if (previous != null && !identical(previous, this)) {
      _arm(previous._lastPainted());
    } else {
      _origin = null;
    }
  }

  /// Called when the item is rebuilt: the widgets around it may have put it
  /// somewhere else.
  void rebuilt() {
    if (!attached) return;
    _arm(_lastPainted());
  }

  void _arm(Offset? origin) {
    if (origin == null) return;
    _origin = origin;
    markNeedsCompositedLayerUpdate();
    // If it isn't painted in this frame, such as in a list's cache extent,
    // it doesn't fly: where it was is out of date by the next frame.
    SchedulerBinding.instance.addPostFrameCallback((_) => _origin = null);
  }

  void _flightTicked() {
    if (attached) markNeedsCompositedLayerUpdate();
  }

  /// Where this item was painted in the last frame, in content coordinates,
  /// read from its layer, which still shows that frame. Null when it wasn't
  /// painted then.
  Offset? _lastPainted() {
    final layer = this.layer;
    if (layer is! _ItemLayer || !layer.attached) return null;
    final chain = <ContainerLayer>[];
    var node = layer.parent;
    while (node != null && node is! _GroupLayer) {
      chain.add(node);
      node = node.parent;
    }
    if (node is! _GroupLayer || !identical(node.state, group)) return null;
    final transform = Matrix4.identity();
    for (var i = chain.length - 1; i >= 0; i--) {
      final parent = chain[i];
      final child = i == 0 ? layer : chain[i - 1];
      if (parent is _ItemLayer) {
        // An item around this one flies it along, but that isn't where
        // this item is.
        transform.translateByDouble(parent.offset.dx, parent.offset.dy, 0, 1);
      } else {
        parent.applyTransform(child, transform);
      }
    }
    return MatrixUtils.transformPoint(transform, layer.offset) +
        layer.visual +
        _scrollOffset(scrollables, composited: true);
  }

  /// Where layout puts it now, in content coordinates.
  Offset _layoutPosition() =>
      localToGlobal(Offset.zero, ancestor: _groupBox()) +
      _scrollOffset(scrollables, composited: false);

  RenderObject? _groupBox() {
    final box = group.context.findRenderObject();
    return box != null && box.attached ? box : null;
  }

  /// Starts, redirects or moves the flight, and returns its offset. Runs
  /// while the item is painted, once layout is done.
  Offset _resolve() {
    final group = this.group;
    if (!group.mounted || !hasSize) return _visual = Offset.zero;
    final record = group._recordFor(id);
    final target = _layoutPosition();
    final origin = _origin;
    _origin = null;
    final flies = enabled && !landing && group.widget.enabled;
    final previous = record.target;
    if (!flies) {
      record.controller?.stop(canceled: true);
    } else if (origin != null && (origin - target).distanceSquared > 1e-4) {
      final controller = group._controllerFor(record, motion);
      if (controller.isAnimating) {
        controller.animateTo(target);
      } else {
        controller.animateTo(target, from: origin);
      }
    } else if (record.flying &&
        previous != null &&
        (previous - target).distanceSquared > 1e-4) {
      // Layout moved it while it flies, without a rebuild: both ends of
      // the spring move along, so its motion is kept exactly.
      final controller = record.controller!;
      controller.animateTo(target, from: controller.value + target - previous);
    }
    record.target = target;
    return _visual = record.flying
        ? record.controller!.value - target
        : Offset.zero;
  }

  @override
  bool get canReceiveFlight =>
      enabled && attached && hasSize && group.mounted && layer is _ItemLayer;

  @override
  Rect? get layoutRect => attached && hasSize ? layoutGlobalRect(this) : null;

  @override
  void receiveFlight({required Offset offset, required Offset velocity}) {
    if (!group.mounted || !hasSize) return;
    final record = group._recordFor(id);
    final controller = group._controllerFor(record, motion);
    final target = _layoutPosition();
    final painted = controller.isAnimating
        ? controller.value
        : target + _visual;
    final carried = controller.isAnimating ? controller.velocity : Offset.zero;
    record.target = target;
    controller.animateTo(
      target,
      from: painted + offset,
      withVelocity: carried + velocity,
    );
    markNeedsCompositedLayerUpdate();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child != null) context.paintChild(child, offset);
  }
}

/// The layer of an item: its offset, shifted by the flight.
class _ItemLayer extends OffsetLayer {
  /// The flight's offset.
  Offset get visual => _visual;
  Offset _visual = Offset.zero;
  set visual(Offset value) {
    if (value == _visual) return;
    _visual = value;
    markNeedsAddToScene();
  }

  @override
  void addToScene(ui.SceneBuilder builder) {
    final offset = this.offset + _visual;
    engineLayer = builder.pushOffset(
      offset.dx,
      offset.dy,
      oldLayer: engineLayer as ui.OffsetEngineLayer?,
    );
    addChildrenToScene(builder);
    builder.pop();
  }

  @override
  void applyTransform(Layer? child, Matrix4 transform) {
    final offset = this.offset + _visual;
    transform.translateByDouble(offset.dx, offset.dy, 0, 1);
  }
}
