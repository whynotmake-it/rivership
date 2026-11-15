import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/src/drag/flight.dart';
import 'package:motor_widgets/src/drag/motion_draggable.dart';
import 'package:motor_widgets/src/painted_position.dart';
import 'package:motor_widgets/src/ticker_rate.dart';

/// Animates its [MotionLayoutItem]s whenever their layout moves them.
///
/// Each item has an [MotionLayoutItem.id]. When an item is laid out
/// somewhere other than where it was in the previous frame, it flies from
/// where it was painted to its new place on a spring:
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
/// A reorder, an insert above an item, a neighbor that grows, and a wrap
/// that reflows all move items. An item is found by its id, not by its
/// widget, so it flies even when its widget is rebuilt elsewhere, such as
/// in another column of the same group, or by a lazy list.
///
/// ## What counts as a move
///
/// Positions are measured relative to the group, with the scroll offsets of
/// the [Scrollable]s between the group and the item taken out, once per
/// frame when the frame is composited. So:
///
/// * Scrolling never moves an item.
/// * The group can move, for example in a page transition, and its items
///   move with it.
/// * An item that wasn't on screen in the previous frame, such as one in a
///   list's cache extent, or one that was just built, appears in place.
///
/// Animated transforms between the group and an item, such as a
/// [Transform] that scales a column in, count as moves: put the group
/// inside them. Scrollables that don't move their content one-to-one with
/// their offset, such as pinned sliver headers, aren't supported.
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

  /// The item's identity, compared with `==`. Unique within the group, and
  /// within the [Overlay] for landings.
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

/// Where an item was in the last frame it was composited, in the group's
/// content coordinates, and its flight.
class _Record {
  /// The frame this was recorded in, or -1 before the first.
  int frame = -1;

  /// The layout position.
  Offset layout = Offset.zero;

  /// The painted position: the layout position plus the flight.
  Offset painted = Offset.zero;

  /// The flight. Its value is the painted position, its target the layout
  /// position.
  MotionController<Offset>? controller;

  bool get flying => controller?.isAnimating ?? false;

  void dispose() {
    controller?.dispose();
    controller = null;
  }
}

class _MotionLayoutGroupState extends State<MotionLayoutGroup>
    with FixedTickerProviderStateMixin, WidgetTickerRateMixin {
  final _records = <Object, _Record>{};

  /// The landing sites of the group's items: ids are unique within it.
  final _landings = LandingRegistry();

  /// Counts the frames in which the group was composited.
  int _frame = 0;

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

  /// Starts a frame: forgets the items that weren't composited in the last
  /// one, since where they were is out of date.
  void _beginFrame() {
    _frame++;
    final cutoff = _frame - 1;
    if (_records.values.every((record) => record.frame >= cutoff)) return;
    _afterFrame(() {
      _records.removeWhere((_, record) {
        if (record.frame >= cutoff) return false;
        record.dispose();
        return true;
      });
    });
  }

  final _actions = <VoidCallback>[];

  /// Runs [action] once this frame is done.
  ///
  /// Items find their flights while the frame is composited, and paint this
  /// frame from what they find. Anything that acts, such as starting a
  /// spring, waits until the frame is done.
  void _afterFrame(VoidCallback action) {
    _actions.add(action);
    if (_actions.length > 1) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      final actions = List.of(_actions);
      _actions.clear();
      if (!mounted) return;
      for (final action in actions) {
        action();
      }
    }, debugLabel: 'MotionLayoutGroup');
  }

  /// Flies [record] to [to], from [from] unless it is flying already, which
  /// keeps its velocity.
  void _fly(
    _Record record,
    Motion motion, {
    required Offset to,
    required Offset from,
  }) {
    final controller = _controllerFor(record, motion);
    if (controller.isAnimating) {
      controller.animateTo(to);
    } else {
      controller.animateTo(to, from: from);
    }
  }

  _Record _recordFor(Object id) => _records[id] ??= _Record();

  /// The record of [id] if it was composited in the latest frame, read
  /// between frames.
  _Record? _lastFrameRecord(Object id) {
    final record = _records[id];
    return record != null && record.frame == _frame ? record : null;
  }

  MotionController<Offset> _controllerFor(_Record record, Motion motion) {
    final controller = record.controller ??= MotionController<Offset>(
      motion: motion,
      vsync: this,
      converter: MotionConverter.offset,
      initialValue: record.painted,
      velocityTracking: const VelocityTracking.off(),
      debugLabel: widget.debugLabel ?? 'MotionLayoutItem',
    );
    if (controller.motion != motion) controller.motion = motion;
    return controller;
  }

  @override
  Widget build(BuildContext context) {
    _outside = _scrollablesOf(context);
    return LandingScope(
      registry: _landings,
      child: _GroupScope(
        state: this,
        child: _GroupBox(state: this, child: widget.child),
      ),
    );
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

/// The group's repaint boundary, whose layer its items measure themselves
/// against, and the landing scope of a drop over it.
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

  @override
  void addToScene(ui.SceneBuilder builder) {
    final state = this.state;
    if (state != null && state.mounted) state._beginFrame();
    super.addToScene(builder);
  }
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
    return paintedGlobalRect(box).shift(box.paintOffset);
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
      ..animate([
        for (final track in MotionDraggableTrack.visual)
          track.toRest(motion ?? MotionLayoutGroup.defaultMotion),
      ]);
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
    final visuals = _visuals;
    return _ItemBox(
      group: group,
      id: id,
      enabled: widget.enabled,
      landing: landing,
      motion: widget.motion ?? group.widget.motion,
      scrollables: [
        for (final scrollable in _scrollablesOf(context))
          if (!outside.contains(scrollable)) scrollable,
      ],
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
  _RenderItem createRenderObject(BuildContext context) => _RenderItem()
    ..group = group
    ..id = id
    ..enabled = enabled
    ..landing = landing
    ..motion = motion
    ..scrollables = scrollables;

  @override
  void updateRenderObject(BuildContext context, _RenderItem renderObject) {
    renderObject
      ..group = group
      ..id = id
      ..enabled = enabled
      ..landing = landing
      ..motion = motion
      ..scrollables = scrollables;
  }
}

/// Paints its child at the flight's offset from its layout position.
///
/// It paints its child into an [_ItemLayer], which measures where the item
/// is each time the frame is composited, when layout, paint offsets and
/// scroll offsets are final, and compares that with the previous frame.
/// Hit testing stays at the layout position.
class _RenderItem extends RenderProxyBox
    implements PaintOffset, FlightReceiver {
  late _MotionLayoutGroupState group;
  late Object id;
  late bool enabled;

  /// Whether a drag's landing flies to this item in the overlay. The item
  /// is hidden meanwhile and takes its place without flying: the landing
  /// is its flight.
  late bool landing;
  late Motion motion;
  List<ScrollableState> scrollables = const [];

  /// The flight's offset in the last composited frame.
  Offset _visual = Offset.zero;

  /// Where the child is painted in the item's layer, which is where its
  /// parent layer is.
  Offset _paintedAt = Offset.zero;

  final _layer = LayerHandle<_ItemLayer>();

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  void dispose() {
    _layer.layer = null;
    super.dispose();
  }

  @override
  Offset get paintOffset => _visual;

  @override
  bool get canReceiveFlight =>
      enabled &&
      attached &&
      hasSize &&
      group.mounted &&
      group._lastFrameRecord(id) != null;

  @override
  Rect? get layoutRect =>
      attached && hasSize ? localToGlobal(Offset.zero) & size : null;

  @override
  void receiveFlight({required Offset offset, required Offset velocity}) {
    final record = group._lastFrameRecord(id);
    if (record == null) return;
    final controller = group._controllerFor(record, motion);
    final flying = controller.isAnimating;
    controller.animateTo(
      record.layout,
      from: record.painted + offset,
      withVelocity: (flying ? controller.velocity : Offset.zero) + velocity,
    );
  }

  /// The scroll offsets between the group and this item, along their axes.
  Offset _scrollOffset() {
    var dx = 0.0;
    var dy = 0.0;
    for (final scrollable in scrollables) {
      final position = scrollable.position;
      if (!position.hasPixels) continue;
      final pixels = position.pixels;
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

  /// Finds where [layer] is in the group, starts, redirects or ends the
  /// flight, records it for the next frame, and returns the flight's
  /// offset. Runs while the frame is composited.
  Offset _compose(_ItemLayer layer) {
    final group = this.group;
    if (!group.mounted) return Offset.zero;
    final position = _positionInGroup(layer);
    if (position == null) return Offset.zero;
    final now = position + _scrollOffset();
    final record = group._recordFor(id);
    final frame = group._frame;
    if (record.frame == frame) {
      assert(() {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: FlutterError(
              'Two MotionLayoutItems in one MotionLayoutGroup have the id '
              '$id.',
            ),
            library: 'motor_widgets',
          ),
        );
        return true;
      }(), 'never fails: it only reports duplicate ids');
      return record.painted - now;
    }
    final controller = record.controller;
    final flying = controller?.isAnimating ?? false;
    final continues = record.frame == frame - 1;
    final Offset painted;
    if (!continues || !enabled || landing || !group.widget.enabled) {
      // Where it was is out of date, or it shouldn't fly: it is where its
      // layout puts it.
      painted = now;
      if (controller != null) {
        group._afterFrame(() {
          if (identical(record.controller, controller)) record.dispose();
        });
      }
    } else if ((record.layout - now).distanceSquared > 1e-4) {
      // It moved: this frame paints it where it was, and its spring starts,
      // or redirects, from there once the frame is done.
      painted = flying ? controller!.value : record.painted;
      final motion = this.motion;
      group._afterFrame(
        () => group._fly(record, motion, to: now, from: painted),
      );
    } else {
      painted = flying ? controller!.value : now;
    }
    record
      ..frame = frame
      ..layout = now
      ..painted = painted;
    return _visual = painted - now;
  }

  /// Where the child is painted in its group's layer, without the flights
  /// of the items around it, or null when [layer] isn't in the group's
  /// layer tree.
  Offset? _positionInGroup(_ItemLayer layer) {
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
      // An item around this one flies it along, but that isn't a move of
      // this item.
      if (parent is! _ItemLayer) parent.applyTransform(child, transform);
    }
    return MatrixUtils.transformPoint(transform, _paintedAt);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) {
      _layer.layer = null;
      return;
    }
    _paintedAt = offset;
    context.pushLayer(
      (_layer.layer ??= _ItemLayer())..item = this,
      (context, offset) => context.paintChild(child, offset),
      offset,
    );
  }
}

/// The layer of an item: it shifts the child by the flight's offset. Like a
/// [FollowerLayer], it is added to every frame's scene, and finds its
/// offset while it is.
class _ItemLayer extends ContainerLayer {
  _RenderItem? item;
  Offset _visual = Offset.zero;

  @override
  bool get alwaysNeedsAddToScene => true;

  @override
  void addToScene(ui.SceneBuilder builder) {
    _visual = item?._compose(this) ?? Offset.zero;
    engineLayer = builder.pushOffset(
      _visual.dx,
      _visual.dy,
      oldLayer: engineLayer as ui.OffsetEngineLayer?,
    );
    addChildrenToScene(builder);
    builder.pop();
  }

  @override
  void applyTransform(Layer? child, Matrix4 transform) {
    transform.translateByDouble(_visual.dx, _visual.dy, 0, 1);
  }
}
