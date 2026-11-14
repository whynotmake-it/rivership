import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/src/drag/flight.dart';
import 'package:motor_widgets/src/drag/motion_drag_probe.dart';
import 'package:motor_widgets/src/drag/motion_draggable.dart';
import 'package:motor_widgets/src/painted_position.dart';

/// How a [MotionEdgeScroll] scrolls: how wide its edge bands are, and how
/// fast it scrolls in them.
@immutable
class MotionEdgeScrollSettings {
  /// Creates settings for scrolling near a viewport's edges.
  const MotionEdgeScrollSettings({
    this.extent = 64,
    this.maxSpeed = 1500,
    this.curve = quadratic,
    this.motion = const CupertinoMotion.smooth(
      duration: Duration(milliseconds: 200),
    ),
  }) : assert(extent > 0, 'extent must be positive'),
       assert(maxSpeed >= 0, 'maxSpeed must not be negative');

  /// How far into the viewport each edge band reaches, in logical pixels.
  ///
  /// A viewport shorter than three bands gets bands of a third of its
  /// length.
  final double extent;

  /// The speed at the edge itself, and beyond it, in logical pixels per
  /// second.
  final double maxSpeed;

  /// Maps how deep the probe is in a band, from 0 at its inner edge to 1 at
  /// the viewport's edge, to the share of [maxSpeed] to scroll at.
  ///
  /// It should start at 0, so that the speed doesn't jump when the probe
  /// enters a band. Defaults to [quadratic].
  final double Function(double depth) curve;

  /// The square of the depth: slow at a band's inner edge, so a drag that
  /// only grazes it barely scrolls.
  static double quadratic(double depth) => depth * depth;

  /// The depth itself: the speed grows evenly across the band.
  static double linear(double depth) => depth;

  /// The spring that the speed follows when the probe moves, so it never
  /// jumps.
  final Motion motion;

  @override
  bool operator ==(Object other) =>
      other is MotionEdgeScrollSettings &&
      other.extent == extent &&
      other.maxSpeed == maxSpeed &&
      other.curve == curve &&
      other.motion == motion;

  @override
  int get hashCode => Object.hash(extent, maxSpeed, curve, motion);
}

/// Scrolls the [Scrollable]s around it while a [MotionDraggable] is dragged
/// near one of their edges, faster the closer it gets to the edge.
///
/// Put it anywhere inside the scrollable: around the scroll view's child,
/// or around the items of a lazy list. It reacts to every
/// [MotionDraggable] drag, wherever the pointer is, so the drag doesn't
/// have to be over this widget, and the widget's size doesn't matter. The
/// edge bands are those of each scrollable's viewport as it is seen.
///
/// Every enclosing scrollable scrolls along its own axis. On a board, an
/// edge scroll inside a column's list scrolls the list near its top and
/// bottom, and the board near its left and right edges. Of two nested
/// scrollables on the same axis, the inner one scrolls first, and the outer
/// one only once the inner one has reached its end.
///
/// ```dart
/// ListView.builder(
///   itemCount: tasks.length,
///   itemBuilder: (context, i) => MotionEdgeScroll(
///     child: MotionDraggable<Task>(data: tasks[i], child: TaskCard(tasks[i])),
///   ),
/// )
/// ```
///
/// Holding the drag still in a band keeps scrolling. The speed follows a
/// spring as the probe moves, so it changes smoothly, starting from zero at
/// a band's inner edge. Scrolling stops at the scrollable's ends, and at
/// once when the drag ends.
///
/// Several edge scrolls inside one scrollable scroll it once; the first
/// one's settings apply.
///
/// Only [MotionDraggable] drags are seen, because Flutter's [Draggable]
/// doesn't tell anyone where it is.
class MotionEdgeScroll extends StatefulWidget {
  /// Scrolls the scrollables around [child] while a drag is near their
  /// edges.
  const MotionEdgeScroll({
    required this.child,
    this.settings = const MotionEdgeScrollSettings(),
    this.probe = MotionDragProbe.pointer,
    this.enabled = true,
    super.key,
  });

  /// How wide the edge bands are, and how fast they scroll.
  final MotionEdgeScrollSettings settings;

  /// The point of the drag that the bands react to.
  ///
  /// Defaults to [MotionDragProbe.pointer], the finger.
  final MotionDragProbe probe;

  /// Whether to scroll at all.
  final bool enabled;

  /// The widget below this widget in the tree.
  final Widget child;

  @override
  State<MotionEdgeScroll> createState() => _MotionEdgeScrollState();
}

class _MotionEdgeScrollState extends State<MotionEdgeScroll> {
  late final EdgeScrollSource _source = EdgeScrollSource(
    scrollables: () => mounted ? enclosingScrollables(context) : const [],
    settings: widget.settings,
    probe: widget.probe,
    explicit: true,
  );

  @override
  void initState() {
    super.initState();
    if (widget.enabled) EdgeScroller.add(_source);
  }

  @override
  void didUpdateWidget(MotionEdgeScroll oldWidget) {
    super.didUpdateWidget(oldWidget);
    _source
      ..settings = widget.settings
      ..probe = widget.probe;
    if (widget.enabled != oldWidget.enabled) {
      widget.enabled ? EdgeScroller.add(_source) : EdgeScroller.remove(_source);
    }
  }

  @override
  void dispose() {
    EdgeScroller.remove(_source);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The [Scrollable]s around [context], innermost first.
List<ScrollableState> enclosingScrollables(BuildContext context) => [
  for (
    var scrollable = Scrollable.maybeOf(context);
    scrollable != null;
    scrollable = Scrollable.maybeOf(scrollable.context)
  )
    scrollable,
];

/// Something that asks for its enclosing scrollables to scroll near their
/// edges: a [MotionEdgeScroll], or a drop zone.
class EdgeScrollSource {
  /// Creates a source of edge scrolling.
  EdgeScrollSource({
    required this.scrollables,
    required this.settings,
    required this.probe,
    required this.explicit,
  });

  /// The scrollables to scroll, innermost first.
  final List<ScrollableState> Function() scrollables;

  /// How wide the bands are and how fast they scroll.
  MotionEdgeScrollSettings settings;

  /// The point of a [MotionDraggable]'s drag that the bands react to.
  MotionDragProbe probe;

  /// Whether a [MotionEdgeScroll] asked for this, whose settings win over
  /// a drop zone's.
  final bool explicit;

  /// A point to react to besides the [MotionDraggable] drags, such as a
  /// plain [Draggable] over a drop zone, in global coordinates.
  Offset? get point => _point;
  Offset? _point;
  set point(Offset? value) {
    _point = value;
    if (value != null) EdgeScroller._wake();
  }
}

/// The speed of one scrollable's edge scroll.
class _Lane {
  double speed = 0;
  double target = 0;
  Simulation? simulation;
  double time = 0;
}

/// Runs every edge scroll, once per scrollable, on a frame callback while a
/// drag is under way or a scrollable is still scrolling.
abstract final class EdgeScroller {
  static final _sources = <EdgeScrollSource>[];
  static final _lanes = Expando<_Lane>('EdgeScroller');
  static final _scrolling = <ScrollableState>{};
  static final _observer = _FlightObserver();
  static bool _scheduled = false;
  static Duration? _lastFrame;

  /// Starts scrolling for [source].
  static void add(EdgeScrollSource source) {
    if (_sources.isEmpty) DragFlight.addObserver(_observer);
    _sources.add(source);
    _wake();
  }

  /// Stops scrolling for [source].
  static void remove(EdgeScrollSource source) {
    if (!_sources.remove(source)) return;
    if (_sources.isEmpty) DragFlight.removeObserver(_observer);
  }

  static void _wake() {
    if (_scheduled || _sources.isEmpty) return;
    _scheduled = true;
    SchedulerBinding.instance
      ..scheduleFrameCallback(_tick)
      ..scheduleFrame();
  }

  static Iterable<DragFlight> get _flights =>
      DragFlight.activeFlights.where((flight) => flight.isDragging);

  static void _tick(Duration timestamp) {
    _scheduled = false;
    final last = _lastFrame;
    _lastFrame = timestamp;
    final dt = last == null || timestamp <= last
        ? 0.0
        : (timestamp - last).inMicroseconds / Duration.microsecondsPerSecond;
    final flights = _flights.toList();

    // Each scrollable once, with the settings of the first explicit source,
    // else the first one, and the points of every source around it.
    final chains = <List<ScrollableState>>[];
    final owners = <ScrollableState, EdgeScrollSource>{};
    final points = <ScrollableState, List<Offset>>{};
    for (final source in List.of(_sources)) {
      final chain = source.scrollables();
      chains.add(chain);
      for (final scrollable in chain) {
        final owner = owners[scrollable];
        if (owner == null || (source.explicit && !owner.explicit)) {
          owners[scrollable] = source;
        }
        if (source.point case final point?) {
          (points[scrollable] ??= []).add(point);
        }
      }
    }

    // The speed each scrollable aims for, before nesting is resolved.
    final targets = <ScrollableState, double>{};
    for (final MapEntry(key: scrollable, value: source) in owners.entries) {
      final probes = [
        for (final flight in flights)
          switch (source.probe) {
            MotionDragProbe.pointer => flight.pointer,
            MotionDragProbe.feedbackCenter => flight.feedbackRect.center,
          },
        ...?points[scrollable],
      ];
      targets[scrollable] = _targetSpeed(scrollable, source.settings, probes);
    }

    // Of two nested scrollables on one axis, the inner one scrolls first.
    for (final chain in chains) {
      final claimed = <Axis, double>{};
      for (final scrollable in chain) {
        final target = targets[scrollable] ?? 0;
        final axis = scrollable.position.axis;
        final inner = claimed[axis];
        if (inner != null && inner.sign == target.sign) {
          targets[scrollable] = 0;
          continue;
        }
        if (target != 0 && _canScroll(scrollable, target)) {
          claimed[axis] = target;
        }
      }
    }

    final dragging = flights.isNotEmpty || points.isNotEmpty;
    for (final MapEntry(key: scrollable, value: target) in targets.entries) {
      _step(scrollable, owners[scrollable]!.settings, target, dt, dragging);
    }
    // Scrollables no source covers any more stop.
    _scrolling.removeWhere((scrollable) {
      if (targets.containsKey(scrollable)) return false;
      _lanes[scrollable] = null;
      return true;
    });

    // While nothing scrolls, a move of the drag wakes the next frame.
    if (_scrolling.isNotEmpty) {
      _wake();
    } else {
      _lastFrame = null;
    }
  }

  /// The speed toward which [scrollable] should scroll, in logical pixels
  /// per second, positive toward the end of its content.
  static double _targetSpeed(
    ScrollableState scrollable,
    MotionEdgeScrollSettings settings,
    List<Offset> probes,
  ) {
    if (probes.isEmpty || !scrollable.mounted) return 0;
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
    final band = settings.extent.clamp(0.0, (end - start) / 3);
    var best = 0.0;
    for (final probe in probes) {
      final (along, cross) = vertical
          ? (probe.dy, probe.dx)
          : (probe.dx, probe.dy);
      // Only a drag over this viewport, or just past its ends.
      if (cross < crossStart || cross > crossEnd) continue;
      if (along < start - band || along > end + band) continue;
      // Positive toward the screen's bottom or right.
      final double screen;
      if (along < start + band) {
        screen = -_speed(settings, (start + band - along) / band);
      } else if (along > end - band) {
        screen = _speed(settings, (along - (end - band)) / band);
      } else {
        continue;
      }
      if (screen.abs() > best.abs()) best = screen;
    }
    return axisDirectionIsReversed(direction) ? -best : best;
  }

  static double _speed(MotionEdgeScrollSettings settings, double depth) =>
      settings.maxSpeed * settings.curve(depth.clamp(0.0, 1.0));

  static bool _canScroll(ScrollableState scrollable, double speed) {
    final position = scrollable.position;
    if (!position.hasPixels || !position.hasContentDimensions) return false;
    return speed > 0
        ? position.pixels < position.maxScrollExtent
        : position.pixels > position.minScrollExtent;
  }

  static void _step(
    ScrollableState scrollable,
    MotionEdgeScrollSettings settings,
    double target,
    double dt,
    bool dragging,
  ) {
    final lane = _lanes[scrollable] ??= _Lane();
    if (!dragging || !scrollable.mounted) {
      // The drag ended: stop where the list is.
      _lanes[scrollable] = null;
      _scrolling.remove(scrollable);
      return;
    }
    if (target != lane.target) {
      final simulation = lane.simulation;
      final acceleration = simulation == null ? 0.0 : simulation.dx(lane.time);
      lane
        ..target = target
        ..simulation = settings.motion.createSimulation(
          start: lane.speed,
          end: target,
          velocity: acceleration,
        )
        ..time = 0;
    }
    final simulation = lane.simulation;
    if (simulation != null) {
      lane.time += dt;
      if (simulation.isDone(lane.time)) {
        lane
          ..speed = target
          ..simulation = null;
      } else {
        lane.speed = simulation.x(lane.time);
      }
    }
    if (lane.speed == 0 && target == 0) {
      _scrolling.remove(scrollable);
      return;
    }
    _scrolling.add(scrollable);
    final position = scrollable.position;
    if (!position.hasPixels || !position.hasContentDimensions) return;
    final pixels = position.pixels;
    final next = (pixels + lane.speed * dt).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (next == pixels && lane.speed != 0) {
      // At an end: stop cleanly instead of pushing into it. A lazy list
      // whose end was only an estimate has laid out more by now, so this is
      // its real end. The next move of the drag springs up from rest.
      lane
        ..speed = 0
        ..simulation = null
        ..target = double.nan;
      _scrolling.remove(scrollable);
      return;
    }
    position.jumpTo(next);
  }
}

class _FlightObserver implements DragFlightObserver {
  @override
  void flightStarted(DragFlight flight) => EdgeScroller._wake();

  @override
  void flightMoved(DragFlight flight) => EdgeScroller._wake();

  @override
  void flightReleased(DragFlight flight) => EdgeScroller._wake();
}
