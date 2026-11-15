import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/src/converters.dart';
import 'package:motor_widgets/src/drag/flight.dart';
import 'package:motor_widgets/src/layout/motion_layout.dart';
import 'package:motor_widgets/src/painted_position.dart';
import 'package:motor_widgets/src/ticker_rate.dart';

/// What happened to a [MotionDraggable]'s drag.
enum MotionDragPhase {
  /// The pointer is down and the feedback follows it.
  dragging,

  /// A [DragTarget] accepted the drop.
  accepted,

  /// No [DragTarget] accepted the drop, or the drag was canceled.
  rejected,
}

/// When a [MotionDraggable]'s landing moves from the [Overlay] into the
/// tree, see [MotionDraggable.handoff].
///
/// A landing can only move into the tree when the destination is a
/// [MotionLayoutItem], which then flies the rest of it. On a draggable
/// that is its own landing site, every value behaves like [never].
enum MotionDragHandoff {
  /// As soon as the feedback's center is inside the destination's visible
  /// area and the destination's slot is in view. For most drops that is the
  /// frame after the drop. While the slot is out of view, the feedback stays
  /// in the overlay, clipped to the destination's visible area.
  onEnter,

  /// On the frame after the drop, wherever the feedback is. From then on the
  /// destination clips it, so a card dropped outside its column is cut off
  /// at the column's edge, and one whose slot is out of view isn't painted.
  immediate,

  /// Never: the whole landing flies in the overlay, above everything.
  never,
}

/// The tracks of a [MotionDraggable]'s feedback.
///
/// Use them in [MotionDraggable.transitions] to animate the feedback in each
/// phase, and as keys of [MotionDraggable.motions] to give a property its own
/// motion:
///
/// ```dart
/// MotionDraggable(
///   motion: const .smoothSpring(),
///   motions: {.scale: const .bouncySpring()},
///   …
/// )
/// ```
final class MotionDraggableTrack<T extends Object> extends Track<T> {
  MotionDraggableTrack._(
    super.converter, {
    required String super.debugLabel,
    this.rest,
  }) : super(initial: rest);

  /// Where the feedback is.
  ///
  /// The draggable owns this track: it follows the pointer while dragging
  /// and lands on the destination afterwards. Only its motion can be set,
  /// through [MotionDraggable.motions].
  static final offset = MotionDraggableTrack<Offset>._(
    MotionConverter.offset,
    debugLabel: 'MotionDraggable.offset',
  );

  /// The size the feedback is laid out at.
  ///
  /// The draggable owns this track: it starts at the child's measured size
  /// and lands on the destination's. Only its motion can be set, through
  /// [MotionDraggable.motions].
  static final size = MotionDraggableTrack<Size>._(
    const NonNegativeSizeMotionConverter(),
    debugLabel: 'MotionDraggable.size',
  );

  /// The feedback's scale around its center. Rests at 1.
  static final scale = MotionDraggableTrack<double>._(
    MotionConverter.single,
    debugLabel: 'MotionDraggable.scale',
    rest: 1,
  );

  /// The feedback's clockwise rotation around its center, in full turns.
  /// Rests at 0.
  static final rotation = MotionDraggableTrack<double>._(
    MotionConverter.single,
    debugLabel: 'MotionDraggable.rotation',
    rest: 0,
  );

  /// The feedback's opacity. Rests at 1.
  static final opacity = MotionDraggableTrack<double>._(
    MotionConverter.single,
    debugLabel: 'MotionDraggable.opacity',
    rest: 1,
  );

  /// The overlay copy fading out after a hand-off to the tree, from 1 to 0.
  ///
  /// The draggable owns this track. Its motion defaults to a short smooth
  /// spring and can be set through [MotionDraggable.motions].
  static final handoffFade = MotionDraggableTrack<double>._(
    MotionConverter.single,
    debugLabel: 'MotionDraggable.handoffFade',
    rest: 1,
  );

  /// The tracks that [MotionDraggable.transitions] may animate.
  static final List<MotionDraggableTrack<double>> visual = [
    scale,
    rotation,
    opacity,
  ];

  /// The value this track returns to when a transition doesn't mention it,
  /// or null for the tracks the draggable owns.
  final T? rest;

  /// This track's part of [animation], with [motion] for the steps that have
  /// none.
  ///
  /// It is a method of the track so that the steps it builds have the
  /// track's own value type.
  TrackAnimation<T> withDefaultMotion(
    TrackAnimation<Object> animation,
    Motion motion,
  ) {
    return this(
      [
        for (final step in animation.steps)
          switch (step) {
            StepTo(
              :final value,
              motion: null,
              motionPerDimension: null,
              :final until,
            ) =>
              TrackStep<T>.to(value as T, motion: motion, until: until),
            StepAt(
              :final at,
              :final value,
              motion: null,
              motionPerDimension: null,
            ) =>
              TrackStep<T>.at(at, value as T, motion: motion),
            _ => step as TrackStep<T>,
          },
      ],
      from: animation.from as T?,
      withVelocity: animation.withVelocity as T?,
      delay: animation.delay,
    );
  }

  /// An animation of this track back to [rest].
  TrackAnimation<T> toRest(Motion motion) =>
      this([TrackStep<T>.to(rest!, motion: motion)]);
}

/// The live state of a [MotionDraggable]'s feedback, passed to
/// [MotionDraggable.feedbackBuilder] and [MotionDraggable.transitions].
@immutable
final class MotionDragDetails {
  /// Creates a snapshot of a drag.
  const MotionDragDetails({
    required this.phase,
    required this.destination,
    required this.velocity,
    required TrackValueReader values,
  }) : _values = values;

  /// What happened to the drag.
  final MotionDragPhase phase;

  /// Where the feedback lands, in global coordinates, or null when there is
  /// nowhere to land.
  ///
  /// It is null while dragging. After a drop it is the rect of the mounted
  /// `MotionLayoutItem` with the draggable's [MotionDraggable.id], measured
  /// after the drop has been laid out. It becomes null if that item
  /// unmounts mid-flight.
  final Rect? destination;

  /// How fast the feedback moves, in logical pixels per second, in global
  /// axes, and restricted to [MotionDraggable.axis] when it is set.
  ///
  /// While dragging it is smoothed from the pointer's velocity and goes back
  /// to zero shortly after the pointer stops. After the drop it is the
  /// velocity of the landing spring, which starts with the release velocity.
  final Offset velocity;

  final TrackValueReader _values;

  /// The current value of [track]: one of [MotionDraggableTrack]'s, or a
  /// track of your own that [MotionDraggable.transitions] animates.
  ///
  /// A track of your own needs an `initial` value to be read before its
  /// first animation.
  T value<T extends Object>(Track<T> track) => _values(track);
}

/// Builds a [MotionDraggable]'s feedback from the live drag.
///
/// The [feedback] is already laid out at the animated size, and it already
/// has the [MotionDraggableTrack.scale], [MotionDraggableTrack.rotation] and
/// [MotionDraggableTrack.opacity] applied around it.
typedef MotionDraggableFeedbackBuilder =
    Widget Function(
      BuildContext context,
      MotionDragDetails drag,
      Widget feedback,
    );

/// The animations a [MotionDraggable]'s feedback plays when its drag
/// changes, see [MotionDraggable.transitions].
typedef MotionDraggableTransitions =
    List<TrackAnimation<Object>> Function(
      MotionDragDetails drag,
    );

/// A [Draggable] whose feedback is animated with Motor from the moment it is
/// picked up until it has landed.
///
/// It uses Flutter's [Draggable] underneath, so plain [DragTarget]s work
/// unchanged: they receive the same data and callbacks.
///
/// When the drag ends, the feedback flies to where the item now lives. Like
/// a [Hero], it looks for the `MotionLayoutItem` with the same [id] in the
/// same [Overlay] once the drop has been laid out:
///
/// * After an accepted drop that moved the item, for example from one
///   column to another, it flies to the item's new place.
/// * After a rejected or canceled drop, it springs back to the source.
/// * When there is no such item, for example because the target removed
///   it, it stays at the drop point and plays its exit: by default it
///   shrinks and fades out.
///
/// A draggable that isn't inside a `MotionLayoutItem` with its id is a
/// landing site itself, so a rejected drop still flies back to it.
///
/// The landing starts with the release velocity and follows where the
/// destination is painted, also while it scrolls, resizes or flies. While
/// the feedback lands, the destination keeps its place in the layout but
/// hides its child. Grabbing the feedback while it lands starts a new drag
/// from where it is.
///
/// The feedback flies in the [Overlay], above everything, only while it has
/// to. It hands the rest of the landing to the `MotionLayoutItem` as soon as
/// the feedback's center is inside the item's visible area (all of its
/// [Scrollable]s, or the overlay when it has none) and the item's slot is
/// in view. For most drops that is the frame after the drop, since the
/// pointer drops the card where its column can be seen. The item then
/// finishes in the tree, keeping its velocity: clipped by its scrollables,
/// stacked like itself, and redirected when its layout moves it. It
/// continues the [MotionDraggableTrack.scale],
/// [MotionDraggableTrack.rotation] and [MotionDraggableTrack.opacity] from
/// where they were, back to rest. [feedbackBuilder] stops applying, and the
/// position uses the item's motion.
///
/// A list doesn't paint an item whose slot is out of view. While the
/// destination's slot is scrolled out of view, the feedback stays in the
/// overlay but is clipped to the destination's visible area, as the list
/// would clip it.
///
/// Inside a `MotionDropZone`, [data] and [id] default to the item of the
/// slot it is in.
///
/// The feedback is laid out at the child's measured size. A [feedback] that
/// wants its own size loosens those constraints, for example with [Align].
///
/// [transitions] animates the feedback's [MotionDraggableTrack]s in each
/// [MotionDragPhase], and [feedbackBuilder] builds on the live
/// [MotionDragDetails], such as the drag's velocity:
///
/// ```dart
/// MotionDraggable<Task>(
///   data: task,
///   transitions: (drag) => switch ((drag.phase, drag.destination)) {
///     (.dragging, _) => [MotionDraggableTrack.scale([.to(1.05)])],
///     (.accepted, null) => [
///       MotionDraggableTrack.scale([.to(0)]),
///       MotionDraggableTrack.opacity([.to(0)]),
///     ],
///     _ => const [],
///   },
///   feedbackBuilder: (context, drag, feedback) => Transform.rotate(
///     angle: (drag.velocity.dx / 3000).clamp(-0.12, 0.12),
///     child: feedback,
///   ),
///   child: TaskCard(task),
/// )
/// ```
///
/// See also:
///
/// * [MotionLongPressDraggable], which starts the drag after a long press.
/// * [Draggable] and [DragTarget].
class MotionDraggable<T extends Object> extends StatefulWidget {
  /// Creates a widget that can be dragged to a [DragTarget], and whose
  /// feedback lands with a spring.
  ///
  /// If [maxSimultaneousDrags] is non-null, it must be non-negative.
  const MotionDraggable({
    required this.child,
    this.data,
    this.id,
    this.feedback,
    this.feedbackBuilder,
    this.childWhenDragging,
    this.motion = const CupertinoMotion.smooth(),
    this.motions,
    this.transitions,
    this.onLanded,
    this.handoff = MotionDragHandoff.onEnter,
    this.axis,
    this.affinity,
    this.feedbackOffset = Offset.zero,
    this.dragAnchorStrategy = childDragAnchorStrategy,
    this.ignoringFeedbackSemantics = true,
    this.ignoringFeedbackPointer = true,
    this.maxSimultaneousDrags,
    this.onDragStarted,
    this.onDragUpdate,
    this.onDraggableCanceled,
    this.onDragCompleted,
    this.onDragEnd,
    this.rootOverlay = false,
    this.hitTestBehavior = HitTestBehavior.deferToChild,
    this.allowedButtonsFilter,
    this.debugLabel,
    this.tickerRate,
    super.key,
  }) : assert(
         maxSimultaneousDrags == null || maxSimultaneousDrags >= 0,
         'maxSimultaneousDrags must be null or non-negative',
       );

  /// The data that will be dropped by this draggable.
  ///
  /// Inside a `MotionDropZone`, defaults to the item of the slot.
  final T? data;

  /// The identity of the item: the feedback lands on the
  /// `MotionLayoutItem` with this id, compared with `==` like [Hero.tag].
  ///
  /// Inside a `MotionDropZone`, defaults to the slot's id. Elsewhere it
  /// defaults to [data], and when both are null, the feedback lands back on
  /// this draggable.
  ///
  /// Within one [Overlay], only one landing site should have a given id at
  /// a time.
  final Object? id;

  /// The widget below this widget in the tree.
  ///
  /// It is shown when no drag is under way, and while the feedback lands on
  /// this draggable it keeps its place but is hidden.
  ///
  /// {@macro flutter.widgets.ProxyWidget.child}
  final Widget child;

  /// The widget to show instead of [child] while this widget is dragged.
  ///
  /// Defaults to [child], hidden but keeping its place in the layout.
  final Widget? childWhenDragging;

  /// The widget that flies under the pointer and lands. Defaults to [child].
  ///
  /// It gets tight constraints at the animated size: the child's measured
  /// size while dragging, then the destination's. Wrap it in an [Align] to
  /// give it its own size.
  final Widget? feedback;

  /// Wraps the [feedback] using the live drag, for example to tilt it with
  /// the velocity.
  final MotionDraggableFeedbackBuilder? feedbackBuilder;

  /// The motion the feedback lands with, and the motion of every track that
  /// [motions] has no entry for.
  ///
  /// Defaults to [CupertinoMotion.smooth].
  final Motion motion;

  /// {@macro motor_widgets.motions}
  ///
  /// For example `motions: {.offset: const .bouncySpring()}` lands with a
  /// bounce while every other property follows [motion].
  final Map<MotionDraggableTrack<Object>, Motion>? motions;

  /// The animations the feedback plays when the drag's phase changes, or
  /// when its destination is found or lost.
  ///
  /// It may animate [MotionDraggableTrack.scale],
  /// [MotionDraggableTrack.rotation] and [MotionDraggableTrack.opacity], and
  /// tracks of your own that [feedbackBuilder] reads with
  /// [MotionDragDetails.value]. Each redirect keeps the track's velocity. A
  /// step on one of the draggable's tracks without a motion uses [motions]
  /// or [motion]; your own tracks use their own motion. The draggable's
  /// visual tracks that the result doesn't mention spring back to rest.
  ///
  /// After a drop, it is first called once the destination has been looked
  /// up, a frame after the release.
  ///
  /// Defaults to resting while there is a destination, and to shrinking and
  /// fading out when there is none.
  final MotionDraggableTransitions? transitions;

  /// When the landing moves from the [Overlay] into the tree, where the
  /// destination's scrollables clip it and the widgets around it stack over
  /// it.
  ///
  /// Only a `MotionLayoutItem` can take it; a draggable that lands on
  /// itself stays in the overlay whatever this is.
  ///
  /// Defaults to [MotionDragHandoff.onEnter].
  final MotionDragHandoff handoff;

  /// Called when the feedback has landed, has finished its exit, or has
  /// handed the rest of its landing to a `MotionLayoutItem`.
  ///
  /// Unlike [onDragEnd], it is also called after this widget has been
  /// removed from the tree. It is not called when the feedback is grabbed
  /// again before it lands.
  final VoidCallback? onLanded;

  /// {@macro flutter.widgets.Draggable.axis}
  ///
  /// Restricts the drag to one axis, like [Draggable.axis].
  final Axis? axis;

  /// Controls how this widget competes with other gestures to start a drag,
  /// like [Draggable.affinity].
  final Axis? affinity;

  /// Moves the point used to find a [DragTarget], like
  /// [Draggable.feedbackOffset].
  final Offset feedbackOffset;

  /// Where the feedback is placed relative to the pointer, like
  /// [Draggable.dragAnchorStrategy].
  final DragAnchorStrategy dragAnchorStrategy;

  /// Whether the feedback is left out of the semantics tree, like
  /// [Draggable.ignoringFeedbackSemantics].
  final bool ignoringFeedbackSemantics;

  /// Whether the feedback ignores pointers while it is dragged, like
  /// [Draggable.ignoringFeedbackPointer].
  ///
  /// While it lands, the feedback takes pointer-downs so that it can be
  /// grabbed again.
  final bool ignoringFeedbackPointer;

  /// How many drags may run at once, like [Draggable.maxSimultaneousDrags].
  ///
  /// Grabbing a landing feedback counts as a drag of its destination.
  final int? maxSimultaneousDrags;

  /// Called when the draggable starts being dragged.
  final VoidCallback? onDragStarted;

  /// Called when the draggable is dragged, like [Draggable.onDragUpdate].
  final DragUpdateCallback? onDragUpdate;

  /// Called when the draggable is dropped without being accepted, like
  /// [Draggable.onDraggableCanceled].
  final DraggableCanceledCallback? onDraggableCanceled;

  /// Called when the draggable is dropped and accepted, like
  /// [Draggable.onDragCompleted].
  final VoidCallback? onDragCompleted;

  /// Called when the draggable is dropped while this widget is mounted, like
  /// [Draggable.onDragEnd].
  final DragEndCallback? onDragEnd;

  /// Whether the feedback flies in the root [Overlay] instead of the
  /// nearest one, like [Draggable.rootOverlay].
  final bool rootOverlay;

  /// How this widget behaves during hit testing, like
  /// [Draggable.hitTestBehavior].
  final HitTestBehavior hitTestBehavior;

  /// {@macro flutter.gestures.multidrag._allowedButtonsFilter}
  final AllowedButtonsFilter? allowedButtonsFilter;

  /// {@macro motor_widgets.debugLabel}
  final String? debugLabel;

  /// {@macro motor_widgets.tickerRate}
  final TickerRate? tickerRate;

  @override
  State<MotionDraggable<T>> createState() => _MotionDraggableState<T>();
}

/// A [MotionDraggable] that starts its drag after a long press, like
/// [LongPressDraggable].
class MotionLongPressDraggable<T extends Object> extends MotionDraggable<T> {
  /// Creates a widget that can be dragged after a long press.
  const MotionLongPressDraggable({
    required super.child,
    super.data,
    super.id,
    super.feedback,
    super.feedbackBuilder,
    super.childWhenDragging,
    super.motion,
    super.motions,
    super.transitions,
    super.onLanded,
    super.handoff,
    super.axis,
    super.feedbackOffset,
    super.dragAnchorStrategy,
    super.ignoringFeedbackSemantics,
    super.ignoringFeedbackPointer,
    super.maxSimultaneousDrags,
    super.onDragStarted,
    super.onDragUpdate,
    super.onDraggableCanceled,
    super.onDragCompleted,
    super.onDragEnd,
    super.rootOverlay,
    super.hitTestBehavior,
    super.allowedButtonsFilter,
    super.debugLabel,
    super.tickerRate,
    this.hapticFeedbackOnStart = true,
    this.delay = kLongPressTimeout,
    super.key,
  });

  /// Whether haptic feedback plays when the drag starts, like
  /// [LongPressDraggable.hapticFeedbackOnStart].
  final bool hapticFeedbackOnStart;

  /// How long the pointer must be down before the drag starts, like
  /// [LongPressDraggable.delay].
  final Duration delay;
}

class _MotionDraggableState<T extends Object> extends State<MotionDraggable<T>>
    with FixedTickerProviderStateMixin, WidgetTickerRateMixin
    implements LandingSite {
  /// Finishes the feedback's scale, rotation and opacity in the tree after a
  /// landing was handed off here. Created on the first hand-off.
  TrackController? _visuals;

  @override
  TickerRate? get widgetTickerRate => widget.tickerRate;

  @override
  void receiveVisuals(List<TrackValue<double>> values) {
    if (!mounted) return;
    if (_visuals == null) {
      setState(() {
        _visuals = TrackController(
          vsync: this,
          debugLabel: widget.debugLabel ?? 'MotionDraggable',
        );
      });
    }
    _visuals!
      ..set(values)
      ..animate([
        for (final track in MotionDraggableTrack.visual)
          track.toRest(widget.motions?[track] ?? widget.motion),
      ]);
  }

  LandingRegistry? _registry;
  Object? _registeredId;
  MultiDragGestureRecognizer? _recognizer;

  /// The flights started from this draggable that are still dragged.
  final Set<DragFlight> _dragging = {};

  /// The anchor that the last [_anchor] call returned.
  Offset _lastAnchor = Offset.zero;

  /// A landing flight that was grabbed and is waiting for its drag to start.
  ({DragFlight flight, Offset position})? _grab;

  /// The flight whose drag is ending, while Flutter reports the outcome.
  DragFlight? _ending;

  DraggableSlot? _slot;

  /// The item the drag lands on, when this draggable is inside the
  /// `MotionLayoutItem` with its id.
  MotionLayoutItemState? _item;

  T? get _data =>
      widget.data ??
      switch (_slot?.item) {
        final T item => item,
        _ => null,
      };

  Object get _id => widget.id ?? _slot?.id ?? widget.data ?? this;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _slot = context.dependOnInheritedWidgetOfExactType<DraggableSlot>();
    _register();
  }

  @override
  void didUpdateWidget(MotionDraggable<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tickerRate != oldWidget.tickerRate) updateTickerRate();
    _register();
    for (final flight in _dragging) {
      flight.widget = widget;
    }
  }

  /// Registers as the landing site of its id, unless the item around it
  /// has the id: then the item is the site, and passes grabs on to this.
  void _register() {
    final id = _id;
    final item = context.findAncestorStateOfType<MotionLayoutItemState>();
    final owner = item != null && item.widget.id == id ? item : null;
    if (!identical(owner, _item)) {
      if (identical(_item?.grabber, this)) _item?.grabber = null;
      _item = owner?..grabber = this;
    }
    final registry = owner != null
        ? null
        : LandingRegistry.maybeOf(context, rootOverlay: widget.rootOverlay);
    if (registry == _registry && id == _registeredId) return;
    _unregister();
    _registry = registry?..add(id, this);
    _registeredId = registry == null ? null : id;
  }

  void _unregister() {
    if (_registeredId case final id?) _registry?.remove(id, this);
    _registry = null;
    _registeredId = null;
  }

  @override
  void dispose() {
    _unregister();
    if (identical(_item?.grabber, this)) _item?.grabber = null;
    _visuals?.dispose();
    super.dispose();
  }

  @override
  Rect? get globalRect {
    if (!mounted) return null;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return paintedGlobalRect(box);
  }

  @override
  final LayerLink landingLink = LayerLink();

  @override
  FlightReceiver? get flightReceiver {
    if (!mounted) return null;
    final box = context.findRenderObject();
    return box == null || !box.attached ? null : flightReceiverAbove(box);
  }

  @override
  Rect? get visibleRect => mounted ? visibleRectOf(context) : null;

  @override
  bool get holdsLanding => false;

  @override
  void landingChanged() {
    if (mounted) setState(() {});
  }

  @override
  bool grab(PointerDownEvent event, DragFlight flight) {
    final recognizer = _recognizer;
    if (!mounted || recognizer == null) return false;
    final max = widget.maxSimultaneousDrags;
    if (max != null && _dragging.length >= max) return false;
    _grab = (flight: flight, position: event.position);
    recognizer.addPointer(event);
    return true;
  }

  @override
  void endGrab(DragFlight flight) {
    if (_grab?.flight == flight) _grab = null;
  }

  Offset _anchor(
    Draggable<Object> draggable,
    BuildContext context,
    Offset position,
  ) {
    final grab = _grab;
    return _lastAnchor = grab != null && grab.position == position
        ? position - grab.flight.globalTopLeft
        : widget.dragAnchorStrategy(draggable, context, position);
  }

  MultiDragGestureRecognizer _createRecognizer(
    GestureMultiDragStartCallback onStart,
  ) {
    Drag? start(Offset position) {
      final drag = onStart(position);
      if (drag == null) {
        if (_grab?.position == position) _grab = null;
        return null;
      }
      return _FlightDrag(this, drag, _startFlight(position));
    }

    // The same recognizers as Draggable and LongPressDraggable.
    final widget = this.widget;
    final filter = widget.allowedButtonsFilter;
    return _recognizer = switch (widget) {
      MotionLongPressDraggable(:final delay, :final hapticFeedbackOnStart) =>
        DelayedMultiDragGestureRecognizer(
            delay: delay,
            allowedButtonsFilter: filter,
          )
          ..onStart = (position) {
            final drag = start(position);
            if (drag != null && hapticFeedbackOnStart) {
              HapticFeedback.selectionClick();
            }
            return drag;
          },
      _ => switch (widget.affinity) {
        Axis.horizontal => HorizontalMultiDragGestureRecognizer(
          allowedButtonsFilter: filter,
        ),
        Axis.vertical => VerticalMultiDragGestureRecognizer(
          allowedButtonsFilter: filter,
        ),
        null => ImmediateMultiDragGestureRecognizer(
          allowedButtonsFilter: filter,
        ),
      }..onStart = start,
    };
  }

  DragFlight _startFlight(Offset position) {
    final grab = _grab;
    _grab = null;
    final DragFlight flight;
    // It lands in the scope it is dragged from, unless a target sets
    // another.
    final registry = LandingRegistry.maybeOf(
      context,
      listen: false,
      rootOverlay: widget.rootOverlay,
    )!;
    if (grab != null && grab.position == position && !grab.flight.isDone) {
      flight = grab.flight
        ..regrab(
          widget,
          position,
          _lastAnchor,
          source: this,
          registry: registry,
          data: _data,
        );
    } else {
      final box = context.findRenderObject()! as RenderBox;
      final overlay = Overlay.of(context, rootOverlay: widget.rootOverlay);
      flight = DragFlight(
        overlay: overlay,
        registry: registry,
        id: _id,
        data: _data,
        widget: widget,
        pointer: position,
        anchor: _lastAnchor,
        size: box.size,
        source: this,
      )..start();
    }
    _dragging.add(flight);
    return flight;
  }

  /// Ends Flutter's drag with [end], which reports whether a target
  /// accepted it, then lets [flight] land.
  void _endDrag(DragFlight flight, VoidCallback end, Velocity velocity) {
    _ending = flight;
    flight.accepted = false;
    try {
      end();
    } finally {
      _ending = null;
      _dragging.remove(flight);
    }
    flight.release(velocity.pixelsPerSecond);
  }

  @override
  Widget build(BuildContext context) {
    final widget = this.widget;
    // Only a draggable that is its own landing site hides while landed on.
    final id = _registeredId;
    final landing = id != null && (_registry?.isLanding(id) ?? false);
    // After a hand-off, the flight's overlay copy fades out over the child
    // and keeps following where it is painted.
    final fading = id != null && (_registry?.isFading(id) ?? false);
    final callbacks = _DraggableCallbacks(
      onDragCompleted: () {
        _ending?.accepted = true;
        widget.onDragCompleted?.call();
      },
      onDraggableCanceled: widget.onDraggableCanceled,
    );
    // While a flight lands here, the child is hidden and the flight follows
    // where it is painted. The leader sits outside the Visibility, which
    // doesn't paint its child while hidden.
    final visuals = _visuals;
    final child = LeaderWhile(
      link: landing || fading ? landingLink : null,
      child: PaintedVisuals(
        listenable: visuals,
        scale: () => visuals?.value(MotionDraggableTrack.scale) ?? 1,
        turns: () => visuals?.value(MotionDraggableTrack.rotation) ?? 0,
        opacity: () => visuals?.value(MotionDraggableTrack.opacity) ?? 1,
        child: Visibility.maintain(visible: !landing, child: widget.child),
      ),
    );
    final childWhenDragging =
        widget.childWhenDragging ??
        Visibility.maintain(visible: false, child: widget.child);
    return _InnerDraggable<T>(
      state: this,
      callbacks: callbacks,
      data: _data,
      childWhenDragging: childWhenDragging,
      child: child,
    );
  }
}

class _DraggableCallbacks {
  const _DraggableCallbacks({
    required this.onDragCompleted,
    required this.onDraggableCanceled,
  });

  final VoidCallback onDragCompleted;
  final DraggableCanceledCallback? onDraggableCanceled;
}

/// Flutter's [Draggable], which drives the [DragTarget]s, with an empty
/// feedback: the [DragFlight] paints the feedback instead.
class _InnerDraggable<T extends Object> extends Draggable<T> {
  _InnerDraggable({
    required this.state,
    required _DraggableCallbacks callbacks,
    required super.child,
    required super.childWhenDragging,
    super.data,
  }) : super(
         feedback: const SizedBox.shrink(),
         axis: state.widget.axis,
         affinity: state.widget.affinity,
         feedbackOffset: state.widget.feedbackOffset,
         dragAnchorStrategy: state._anchor,
         maxSimultaneousDrags: state.widget.maxSimultaneousDrags,
         onDragStarted: state.widget.onDragStarted,
         onDragUpdate: state.widget.onDragUpdate,
         onDraggableCanceled: callbacks.onDraggableCanceled,
         onDragCompleted: callbacks.onDragCompleted,
         onDragEnd: state.widget.onDragEnd,
         rootOverlay: state.widget.rootOverlay,
         hitTestBehavior: state.widget.hitTestBehavior,
         allowedButtonsFilter: state.widget.allowedButtonsFilter,
       );

  final _MotionDraggableState<T> state;

  @override
  MultiDragGestureRecognizer createRecognizer(
    GestureMultiDragStartCallback onStart,
  ) => state._createRecognizer(onStart);
}

/// The [Drag] Flutter's recognizer drives: it passes every event on to
/// Flutter's own drag, which talks to the [DragTarget]s, and moves the
/// [DragFlight].
///
/// It keeps working after the draggable has been removed from the tree,
/// unlike [Draggable.onDragUpdate].
class _FlightDrag extends Drag {
  _FlightDrag(this._state, this._drag, this._flight) {
    // Flutter's drag looks for its target only when the pointer moves. A
    // move of no distance makes it look again where the pointer is.
    _flight.retarget = () => _drag.update(
      DragUpdateDetails(globalPosition: _flight.pointer),
    );
  }

  final _MotionDraggableState<Object> _state;
  final Drag _drag;
  final DragFlight _flight;

  @override
  void update(DragUpdateDetails details) {
    // The feedback moves first, so a target that reads where it is, such as
    // a MotionDropZone, sees this move.
    _flight.moveBy(details.delta);
    _drag.update(details);
  }

  @override
  void end(DragEndDetails details) =>
      _state._endDrag(_flight, () => _drag.end(details), details.velocity);

  @override
  void cancel() => _state._endDrag(_flight, _drag.cancel, Velocity.zero);
}
