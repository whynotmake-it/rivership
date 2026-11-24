/// @docImport 'package:motor_widgets/src/reorder/motion_reorderable.dart';
library;

import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/src/drag/flight.dart';
import 'package:motor_widgets/src/drag/motion_drag_point.dart';
import 'package:motor_widgets/src/drag/motion_draggable.dart';
import 'package:motor_widgets/src/painted_position.dart';

/// Scrolls the scroll view below it while a drag is near one of its edges,
/// faster the closer the drag gets to the edge.
///
/// ```dart
/// MotionDragToScroll(
///   child: ListView(children: [...]),
/// )
/// ```
///
/// It scrolls the nearest [Scrollable] below it, along that scrollable's
/// axis, and nothing else. Each scroll view that should scroll gets its
/// own: on a board, one around the board's horizontal scroll view and one
/// around each column's list. Of two on the same axis, the inner one
/// scrolls first, and the outer one only once the inner one has reached its
/// end.
///
/// The speed follows a spring, so it changes smoothly, starting from zero
/// at a band's inner edge. Holding the drag still in a band keeps
/// scrolling; scrolling stops at the scroll view's ends, and at once when
/// the drag ends. While content scrolls under a drag, the drag looks again
/// for the target under it.
///
/// It runs on frames only while a drag is in or past one of its edge bands,
/// or while its speed springs back to zero.
///
/// A [MotionDraggable]'s drag is seen wherever its pointer is, also outside
/// this widget, see [outside]. A plain [Draggable] doesn't tell anyone
/// where it is, so it is only seen while it is over this widget, and only
/// while no [DragTarget] inside takes it, except a [MotionReorderable],
/// which passes it on. It also needs [Draggable.data]: a [DragTarget] isn't
/// told where a [Draggable] without data is.
class MotionDragToScroll extends StatefulWidget {
  /// Scrolls the scroll view below [child] near its edges.
  const MotionDragToScroll({
    required this.child,
    this.extent = 64,
    this.maxSpeed = 1500,
    this.curve = quadratic,
    this.motion = const CupertinoMotion.smooth(
      duration: Duration(milliseconds: 200),
    ),
    this.outside = true,
    this.point = MotionDragPoint.pointer,
    super.key,
  }) : assert(extent > 0, 'extent must be positive'),
       assert(maxSpeed >= 0, 'maxSpeed must not be negative');

  /// How far into the viewport each edge band reaches, in logical pixels.
  ///
  /// A viewport shorter than three bands gets bands of a third of its
  /// length.
  final double extent;

  /// The speed at the edge itself, and past it, in logical pixels per
  /// second.
  final double maxSpeed;

  /// Maps how deep the drag is in a band, from 0 at its inner edge to 1 at
  /// the viewport's edge, to the share of [maxSpeed] to scroll at.
  ///
  /// It should start at 0, so that the speed doesn't jump when the drag
  /// enters a band. Defaults to [quadratic].
  final double Function(double depth) curve;

  /// The spring that the speed follows when the drag moves, so it never
  /// jumps.
  final Motion motion;

  /// Whether a drag outside the viewport keeps scrolling it.
  ///
  /// When true, a viewport that is already scrolling keeps scrolling at
  /// [maxSpeed] while the drag stays past the edge it scrolls toward,
  /// however far, also beside the viewport. Either way, a drag only starts
  /// scrolling over the viewport or within one band of its ends, so a drag
  /// elsewhere on the page never starts it.
  ///
  /// When false, it scrolls only while the drag is over the viewport, or
  /// at most one band past its ends, and stops once the drag leaves.
  ///
  /// Defaults to true.
  final bool outside;

  /// The point of the drag that scrolls.
  final MotionDragPoint point;

  /// The widget below this widget in the tree, with the scroll view.
  final Widget child;

  /// The square of the depth: slow at a band's inner edge, so a drag that
  /// only grazes it barely scrolls.
  static double quadratic(double depth) => depth * depth;

  /// The depth itself: the speed grows evenly across the band.
  static double linear(double depth) => depth;

  @override
  State<MotionDragToScroll> createState() => _MotionDragToScrollState();
}

/// Tells the [MotionDragToScroll]s around [context] where a plain
/// [Draggable] that [target] took is, or, with a null [point], that it left
/// or ended.
///
/// Flutter's drag enters the targets under it innermost first, and stops at
/// the first that takes it, so the drag-to-scrolls around a target that
/// takes it never hear of it themselves. A [MotionReorderable] reports for
/// them.
void reportPlainDrag(BuildContext context, Object target, Offset? point) {
  for (
    var scope = context.getInheritedWidgetOfExactType<_Scope>()?.state;
    scope != null;
    scope = scope._outer
  ) {
    if (point == null) {
      scope._reported.remove(target);
    } else {
      scope._reported[target] = point;
      scope._wake();
    }
  }
}

class _Scope extends InheritedWidget {
  const _Scope({required this.state, required super.child});

  final _MotionDragToScrollState state;

  @override
  bool updateShouldNotify(_Scope oldWidget) =>
      !identical(state, oldWidget.state);
}

class _MotionDragToScrollState extends State<MotionDragToScroll>
    with SingleTickerProviderStateMixin
    implements DragFlightObserver {
  /// Created on first use, not in [dispose]; see MotionReorderable.
  Ticker? _tickerOrNull;
  Ticker get _ticker => _tickerOrNull ??= createTicker(_tick);

  /// The scroll view it scrolls, found from its notifications.
  ScrollableState? _scrollable;

  /// The drag-to-scrolls around this one, and inside it.
  _MotionDragToScrollState? _outer;
  final _inner = <_MotionDragToScrollState>{};

  /// Where a plain [Draggable] is, while it is over this widget.
  Offset? _plainPoint;

  /// Where the plain [Draggable]s are that targets inside this widget took,
  /// by target, see [reportPlainDrag].
  final _reported = <Object, Offset>{};

  Duration? _lastTick;
  double _speed = 0;
  double _target = 0;
  Simulation? _simulation;
  double _time = 0;

  @override
  void initState() {
    super.initState();
    DragFlight.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final outer = context.dependOnInheritedWidgetOfExactType<_Scope>()?.state;
    if (!identical(outer, _outer)) {
      _outer?._inner.remove(this);
      _outer = outer?.._inner.add(this);
    }
  }

  @override
  void dispose() {
    DragFlight.removeObserver(this);
    _outer?._inner.remove(this);
    _tickerOrNull?.dispose();
    super.dispose();
  }

  // Drags.

  @override
  void flightStarted(DragFlight flight) => _wake();

  @override
  void flightMoved(DragFlight flight) => _wake();

  @override
  void flightReleased(DragFlight flight) => _wake();

  @override
  void flightFinished(DragFlight flight) {}

  static Iterable<DragFlight> get _flights =>
      DragFlight.activeFlights.where((flight) => flight.isDragging);

  /// The points of the drags under way.
  List<Offset> _points() => [
    for (final flight in _flights)
      switch (widget.point) {
        MotionDragPoint.pointer => flight.pointer,
        MotionDragPoint.feedbackCenter => flight.feedbackRect.center,
      },
    ?_plainPoint,
    ..._reported.values,
  ];

  /// Starts the ticker when a drag is near enough to scroll.
  void _wake() {
    if (!mounted || _ticker.isActive) return;
    if (_targetSpeed(_points()) == 0) return;
    _lastTick = null;
    unawaited(_ticker.start());
  }

  void _tick(Duration elapsed) {
    final last = _lastTick;
    _lastTick = elapsed;
    final dt = last == null
        ? 0.0
        : (elapsed - last).inMicroseconds / Duration.microsecondsPerSecond;
    final scrollable = _scrollable;
    final points = _points();
    if (scrollable == null || !scrollable.mounted || points.isEmpty) {
      _stop();
      return;
    }
    var target = _targetSpeed(points);
    // Of two on the same axis, the inner one scrolls first.
    final axis = scrollable.position.axis;
    for (final inner in _inner) {
      final innerScrollable = inner._scrollable;
      if (innerScrollable == null || !innerScrollable.mounted) continue;
      if (innerScrollable.position.axis != axis) continue;
      final claimed = inner._target;
      if (claimed != 0 &&
          claimed.sign == target.sign &&
          _canScroll(innerScrollable, claimed)) {
        target = 0;
      }
    }
    _step(scrollable, target, dt);
    if (_speed == 0 && _target == 0) {
      _stop();
      return;
    }
    // The content moved under the pointer. Once it is laid out, each held
    // drag looks again for the target under it, which may now be another.
    final flights = _flights.toList();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      for (final flight in flights) {
        flight.nudge();
      }
    });
  }

  void _stop() {
    _speed = 0;
    _target = 0;
    _simulation = null;
    _lastTick = null;
    _tickerOrNull?.stop();
  }

  /// The speed toward which the scroll view should scroll, in logical
  /// pixels per second, positive toward the end of its content.
  double _targetSpeed(List<Offset> points) {
    final scrollable = _scrollable;
    if (points.isEmpty || scrollable == null || !scrollable.mounted) return 0;
    final box = scrollable.context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return 0;
    var viewport = paintedGlobalRect(box);
    if (visibleRectOf(scrollable.context) case final outer?) {
      viewport = viewport.intersect(outer);
    }
    if (viewport.isEmpty) return 0;
    final direction = scrollable.axisDirection;
    final vertical = axisDirectionToAxis(direction) == Axis.vertical;
    final (start, end) = vertical
        ? (viewport.top, viewport.bottom)
        : (viewport.left, viewport.right);
    final (crossStart, crossEnd) = vertical
        ? (viewport.left, viewport.right)
        : (viewport.top, viewport.bottom);
    final band = widget.extent.clamp(0.0, (end - start) / 3);
    final reversed = axisDirectionIsReversed(direction);
    // How it scrolls now, positive toward the screen's bottom or right.
    final current = (reversed ? -1 : 1) * _speed;
    var best = 0.0;
    for (final point in points) {
      final (along, cross) = vertical
          ? (point.dy, point.dx)
          : (point.dx, point.dy);
      // A drag starts scrolling only over the viewport or within one band
      // of its ends. Outside, once it scrolls, it keeps scrolling while the
      // drag stays past the edge it scrolls toward, also beside it.
      final keeps =
          widget.outside &&
          ((along > end && current > 0) || (along < start && current < 0));
      final beside = cross < crossStart || cross > crossEnd;
      final beyond = along < start - band || along > end + band;
      if ((beside || beyond) && !keeps) continue;
      final double screen;
      if (along < start + band) {
        screen = -_speedAt((start + band - along) / band);
      } else if (along > end - band) {
        screen = _speedAt((along - (end - band)) / band);
      } else {
        continue;
      }
      if (screen.abs() > best.abs()) best = screen;
    }
    final speed = reversed ? -best : best;
    return speed != 0 && _canScroll(scrollable, speed) ? speed : 0;
  }

  double _speedAt(double depth) =>
      widget.maxSpeed * widget.curve(depth.clamp(0.0, 1.0));

  static bool _canScroll(ScrollableState scrollable, double speed) {
    final position = scrollable.position;
    if (!position.hasPixels || !position.hasContentDimensions) return false;
    return speed > 0
        ? position.pixels < position.maxScrollExtent
        : position.pixels > position.minScrollExtent;
  }

  /// Moves the speed toward [target] on its spring, and scrolls by it.
  void _step(ScrollableState scrollable, double target, double dt) {
    if (target != _target) {
      final simulation = _simulation;
      final acceleration = simulation == null ? 0.0 : simulation.dx(_time);
      _target = target;
      _simulation = widget.motion.createSimulation(
        start: _speed,
        end: target,
        velocity: acceleration,
      );
      _time = 0;
    }
    if (_simulation case final simulation?) {
      _time += dt;
      if (simulation.isDone(_time)) {
        _speed = target;
        _simulation = null;
      } else {
        _speed = simulation.x(_time);
      }
    }
    if (_speed == 0) return;
    final position = scrollable.position;
    if (!position.hasPixels || !position.hasContentDimensions) return;
    final pixels = position.pixels;
    final next = (pixels + _speed * dt).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (next == pixels && dt > 0) {
      // At an end: stop cleanly instead of pushing into it. The next move
      // of the drag springs up from rest.
      _speed = 0;
      _target = 0;
      _simulation = null;
      return;
    }
    position.jumpTo(next);
  }

  // Building.

  @override
  Widget build(BuildContext context) => _Scope(
    state: this,
    // A plain Draggable tells only the targets it is over where it is. This
    // one never accepts, so the targets inside it still get the drop.
    child: DragTarget<Object>(
      onWillAcceptWithDetails: (details) {
        _plainPoint = DragFlight.draggingWith(details.data) == null
            ? details.offset
            : null;
        _wake();
        return false;
      },
      onMove: (details) {
        if (DragFlight.draggingWith(details.data) != null) return;
        _plainPoint = details.offset;
        _wake();
      },
      onLeave: (_) => _plainPoint = null,
      builder: (context, _, _) =>
          NotificationListener<ScrollMetricsNotification>(
            onNotification: (notification) {
              // The nearest scroll view below: the one this scrolls.
              if (notification.depth == 0) {
                _scrollable = Scrollable.maybeOf(notification.context);
              }
              return false;
            },
            child: widget.child,
          ),
    ),
  );
}
