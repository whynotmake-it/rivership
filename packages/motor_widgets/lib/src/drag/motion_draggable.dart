import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/src/converters.dart';
import 'package:motor_widgets/src/drag/flight.dart';
import 'package:motor_widgets/src/painted_position.dart';

/// What happened to a [MotionDraggable]'s drag.
enum MotionDragPhase {
  /// The pointer is down and the feedback follows it.
  dragging,

  /// A [DragTarget] accepted the drop.
  accepted,

  /// No [DragTarget] accepted the drop, or the drag was canceled.
  rejected,
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
  /// [MotionDraggable] whose [MotionDraggable.tag] matches, measured after
  /// the drop has been laid out. It becomes null if that draggable unmounts
  /// mid-flight.
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
/// a [Hero], it looks for a mounted [MotionDraggable] with the same [tag] in
/// the same [Overlay] once the drop has been laid out:
///
/// * After an accepted drop that moved the item, for example from one
///   column to another, it flies to the item's new place.
/// * After a rejected or canceled drop, it springs back to the source.
/// * When there is no such draggable, for example because the target
///   removed the item, it stays at the drop point and plays its exit:
///   by default it shrinks and fades out.
///
/// The landing starts with the release velocity and follows the destination
/// if it scrolls or resizes. While the feedback lands, the destination keeps
/// its place in the layout but hides its child. Grabbing the feedback while
/// it lands starts a new drag from where it is.
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
    this.tag,
    this.feedback,
    this.feedbackBuilder,
    this.childWhenDragging,
    this.motion = const CupertinoMotion.smooth(),
    this.motions,
    this.transitions,
    this.onLanded,
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
  final T? data;

  /// The identity of the item, which the feedback uses to find where to
  /// land, compared with `==` like [Hero.tag].
  ///
  /// Defaults to [data]. When both are null, the feedback lands back on
  /// this draggable.
  ///
  /// Within one [Overlay], only one mounted [MotionDraggable] should have a
  /// given tag at a time.
  final Object? tag;

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

  /// Called when the feedback has landed, or has finished its exit.
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
    super.tag,
    super.feedback,
    super.feedbackBuilder,
    super.childWhenDragging,
    super.motion,
    super.motions,
    super.transitions,
    super.onLanded,
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
    implements LandingSite {
  LandingRegistry? _registry;
  Object? _registeredTag;
  MultiDragGestureRecognizer? _recognizer;

  /// The flights started from this draggable that are still dragged.
  final Set<DragFlight> _dragging = {};

  /// The anchor that the last [_anchor] call returned.
  Offset _lastAnchor = Offset.zero;

  /// A landing flight that was grabbed and is waiting for its drag to start.
  ({DragFlight flight, Offset position})? _grab;

  /// The flight whose drag is ending, while Flutter reports the outcome.
  DragFlight? _ending;

  Object get _tag => widget.tag ?? widget.data ?? this;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _register();
  }

  @override
  void didUpdateWidget(MotionDraggable<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _register();
    for (final flight in _dragging) {
      flight.widget = widget;
    }
  }

  void _register() {
    final overlay = Overlay.maybeOf(context, rootOverlay: widget.rootOverlay);
    final registry = overlay == null ? null : LandingRegistry.of(overlay);
    final tag = _tag;
    if (registry == _registry && tag == _registeredTag) return;
    _unregister();
    _registry = registry?..add(tag, this);
    _registeredTag = tag;
  }

  void _unregister() {
    if (_registeredTag case final tag?) _registry?.remove(tag, this);
    _registry = null;
    _registeredTag = null;
  }

  @override
  void dispose() {
    _unregister();
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
    if (grab != null && grab.position == position && !grab.flight.isDone) {
      flight = grab.flight..regrab(widget, position, _lastAnchor);
    } else {
      final box = context.findRenderObject()! as RenderBox;
      final overlay = Overlay.of(context, rootOverlay: widget.rootOverlay);
      flight = DragFlight(
        overlay: overlay,
        registry: LandingRegistry.of(overlay),
        tag: _tag,
        widget: widget,
        pointer: position,
        anchor: _lastAnchor,
        size: box.size,
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
    final landing = _registry?.isLanding(_tag) ?? false;
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
    final child = LeaderWhile(
      link: landing ? landingLink : null,
      child: Visibility.maintain(visible: !landing, child: widget.child),
    );
    final childWhenDragging =
        widget.childWhenDragging ??
        Visibility.maintain(visible: false, child: widget.child);
    return _InnerDraggable<T>(
      state: this,
      callbacks: callbacks,
      data: widget.data,
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
  _FlightDrag(this._state, this._drag, this._flight);

  final _MotionDraggableState<Object> _state;
  final Drag _drag;
  final DragFlight _flight;

  @override
  void update(DragUpdateDetails details) {
    _drag.update(details);
    _flight.moveBy(details.delta);
  }

  @override
  void end(DragEndDetails details) =>
      _state._endDrag(_flight, () => _drag.end(details), details.velocity);

  @override
  void cancel() => _state._endDrag(_flight, _drag.cancel, Velocity.zero);
}
