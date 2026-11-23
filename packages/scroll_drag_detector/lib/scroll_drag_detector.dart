// ignore_for_file: avoid_positional_boolean_parameters

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Works like [GestureDragStartCallback] but also tells whether the scrollable
/// did scroll before the drag started.
typedef ScrollDragStartCallback = void Function(
  DragStartDetails details,
  bool didScroll,
);

/// Works like [GestureDragUpdateCallback] but also tells whether the drag would
/// have been a scroll.
typedef ScrollDragUpdateCallback = void Function(
  DragUpdateDetails details,
  bool wouldScroll,
);

/// Works like [GestureDragEndCallback] but also tells whether the scrollable
/// will start scrolling after the drag ended.
typedef ScrollDragEndCallback = void Function(
  DragEndDetails details,
  bool willScroll,
);

/// Describes how movement in one physical direction is routed between a
/// descendant scrollable and this detector.
enum ScrollDragMode {
  /// The descendant scrollable keeps control in this direction.
  none,

  /// The descendant scrollable moves first, then the detector takes over at
  /// its boundary.
  scrollFirst,

  /// The detector takes over before the descendant scrollable moves.
  dragFirst,

  /// The detector takes over at the boundary only when the gesture also began
  /// at that boundary.
  boundaryStart,
}

/// {@template scroll_drag_detector}
/// A widget similar to GestureDetector that can smoothly transition between
/// dragging and scrolling.
///
/// This widget's events will behave like a normal [GestureDetector] in most
/// cases.
/// However, if a child widget is scrollable, this widget will understand
/// whenever that child overscrolls and transition to firing gesture events
/// instead while preventing the child from overscrolling.
///
/// This widget can be useful in scenarios where a scroll view is embedded in a
/// draggable view, and you want the outside view to be dragged whenever the
/// scrollable would overscroll.
/// The most common use would be a scrollable sheet.
///
/// Descendants that override their [ScrollBehavior] must wrap that behavior in
/// [ScrollDragBehavior] to preserve drag handoff.
/// {@endtemplate}
class ScrollDragDetector extends StatefulWidget {
  ///{@macro scroll_drag_detector}
  const ScrollDragDetector({
    required this.child,
    required this.up,
    required this.down,
    required this.left,
    required this.right,
    this.onVerticalDragDown,
    this.onVerticalDragStart,
    this.onVerticalDragUpdate,
    this.onVerticalDragEnd,
    this.onVerticalDragCancel,
    this.onHorizontalDragDown,
    this.onHorizontalDragStart,
    this.onHorizontalDragUpdate,
    this.onHorizontalDragEnd,
    this.onHorizontalDragCancel,
    super.key,
  });

  /// Creates a detector using the configuration supported before directional
  /// routing was introduced.
  ///
  /// Use this constructor to migrate without changing the coherent interaction
  /// behavior of a conventional, non-reversed scrollable. Reversed scrollables
  /// use the corrected physical-direction routing.
  const ScrollDragDetector.legacy({
    required this.child,
    bool scrollableCanMoveBack = true,
    bool onlyDragWhenScrollWasAtTop = true,
    this.onVerticalDragDown,
    this.onVerticalDragStart,
    this.onVerticalDragUpdate,
    this.onVerticalDragEnd,
    this.onVerticalDragCancel,
    this.onHorizontalDragDown,
    this.onHorizontalDragStart,
    this.onHorizontalDragUpdate,
    this.onHorizontalDragEnd,
    this.onHorizontalDragCancel,
    super.key,
  })  : up = scrollableCanMoveBack
            ? ScrollDragMode.dragFirst
            : ScrollDragMode.none,
        down = onlyDragWhenScrollWasAtTop
            ? ScrollDragMode.boundaryStart
            : ScrollDragMode.scrollFirst,
        left = scrollableCanMoveBack
            ? ScrollDragMode.dragFirst
            : ScrollDragMode.none,
        right = onlyDragWhenScrollWasAtTop
            ? ScrollDragMode.boundaryStart
            : ScrollDragMode.scrollFirst;

  /// The widget below this widget in the tree.
  final Widget child;

  /// How upward pointer movement is routed.
  final ScrollDragMode up;

  /// How downward pointer movement is routed.
  final ScrollDragMode down;

  /// How leftward pointer movement is routed.
  final ScrollDragMode left;

  /// How rightward pointer movement is routed.
  final ScrollDragMode right;

  /// A pointer has contacted the screen with a primary button and might begin
  /// to move vertically.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  final GestureDragDownCallback? onVerticalDragDown;

  /// A pointer has contacted the screen with a primary button and has begun to
  /// move vertically.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  final ScrollDragStartCallback? onVerticalDragStart;

  /// A pointer that is in contact with the screen with a primary button and
  /// moving vertically has moved in the vertical direction.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  final ScrollDragUpdateCallback? onVerticalDragUpdate;

  /// A pointer that was previously in contact with the screen with a primary
  /// button and moving vertically is no longer in contact with the screen and
  /// was moving at a specific velocity when it stopped contacting the screen.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  final ScrollDragEndCallback? onVerticalDragEnd;

  /// The pointer that previously triggered [onVerticalDragDown] did not
  /// complete.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  final GestureDragCancelCallback? onVerticalDragCancel;

  /// A pointer has contacted the screen with a primary button and might begin
  /// to move horizontally.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  final GestureDragDownCallback? onHorizontalDragDown;

  /// A pointer has contacted the screen with a primary button and has begun to
  /// move horizontally.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  final ScrollDragStartCallback? onHorizontalDragStart;

  /// A pointer that is in contact with the screen with a primary button and
  /// moving horizontally has moved in the horizontal direction.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  final ScrollDragUpdateCallback? onHorizontalDragUpdate;

  /// A pointer that was previously in contact with the screen with a primary
  /// button and moving horizontally is no longer in contact with the screen and
  /// was moving at a specific velocity when it stopped contacting the screen.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  final ScrollDragEndCallback? onHorizontalDragEnd;

  /// The pointer that previously triggered [onHorizontalDragDown] did not
  /// complete.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  final GestureDragCancelCallback? onHorizontalDragCancel;

  @override
  State<ScrollDragDetector> createState() => _ScrollDragDetectorState();
}

class _ScrollDragDetectorState extends State<ScrollDragDetector> {
  final _draggingAxes = ValueNotifier(<Axis>{});

  /// Pointers that went down inside an [ExcludeScrollDrag], with the axes it
  /// excludes them from. The exclusion fills this before this detector's
  /// recognizers see the down, and clears it once the pointer is up or
  /// cancelled, or the exclusion is gone.
  final _excludedPointers = <int, Set<Axis>>{};

  List<_ScrollDragDetectorState> _detectors = const [];

  void _excludePointer(int pointer, Set<Axis> axes) {
    (_excludedPointers[pointer] ??= <Axis>{}).addAll(axes);
  }

  void _releasePointer(int pointer) {
    _excludedPointers.remove(pointer);
  }

  bool _isExcluded(int pointer, Axis axis) =>
      _excludedPointers[pointer]?.contains(axis) ?? false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _detectors = [this, ..._ScrollDragDetectorScope.of(context)];
  }

  final _axisStates = <Axis, _AxisDragState>{
    Axis.vertical: _AxisDragState(),
    Axis.horizontal: _AxisDragState(),
  };

  bool get hasVertical =>
      widget.onVerticalDragStart != null ||
      widget.onVerticalDragUpdate != null ||
      widget.onVerticalDragEnd != null ||
      widget.onVerticalDragCancel != null;

  bool get hasHorizontal =>
      widget.onHorizontalDragStart != null ||
      widget.onHorizontalDragUpdate != null ||
      widget.onHorizontalDragEnd != null ||
      widget.onHorizontalDragCancel != null;

  Set<Axis> get dragAxes {
    return <Axis>{
      if (hasVertical) Axis.vertical,
      if (hasHorizontal) Axis.horizontal,
    };
  }

  ScrollDragMode _modeFor(AxisDirection direction) {
    return switch (direction) {
      AxisDirection.up => widget.up,
      AxisDirection.down => widget.down,
      AxisDirection.left => widget.left,
      AxisDirection.right => widget.right,
    };
  }

  @override
  void dispose() {
    _draggingAxes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gestureSettings = MediaQuery.maybeGestureSettingsOf(context);
    final multitouchDragStrategy =
        ScrollConfiguration.of(context).getMultitouchDragStrategy(context);

    // A GestureDetector with the same two drag recognizers, except they skip
    // pointers that went down inside an ExcludeScrollDrag.
    return NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: RawGestureDetector(
        gestures: {
          if (hasVertical || widget.onVerticalDragDown != null)
            _VerticalDragRecognizer:
                GestureRecognizerFactoryWithHandlers<_VerticalDragRecognizer>(
              () => _VerticalDragRecognizer(
                isExcluded: (pointer) => _isExcluded(pointer, Axis.vertical),
                debugOwner: this,
              ),
              (instance) => instance
                ..onDown = widget.onVerticalDragDown
                ..onStart = switch (widget.onVerticalDragStart) {
                  final callback? => (details) => callback(details, false),
                  null => null,
                }
                ..onUpdate = switch (widget.onVerticalDragUpdate) {
                  final callback? => (details) => callback(details, false),
                  null => null,
                }
                ..onEnd = switch (widget.onVerticalDragEnd) {
                  final callback? => (details) => callback(details, false),
                  null => null,
                }
                ..onCancel = widget.onVerticalDragCancel
                ..multitouchDragStrategy = multitouchDragStrategy
                ..gestureSettings = gestureSettings,
            ),
          if (hasHorizontal || widget.onHorizontalDragDown != null)
            _HorizontalDragRecognizer:
                GestureRecognizerFactoryWithHandlers<_HorizontalDragRecognizer>(
              () => _HorizontalDragRecognizer(
                isExcluded: (pointer) => _isExcluded(pointer, Axis.horizontal),
                debugOwner: this,
              ),
              (instance) => instance
                ..onDown = widget.onHorizontalDragDown
                ..onStart = switch (widget.onHorizontalDragStart) {
                  final callback? => (details) => callback(details, false),
                  null => null,
                }
                ..onUpdate = switch (widget.onHorizontalDragUpdate) {
                  final callback? => (details) => callback(details, false),
                  null => null,
                }
                ..onEnd = switch (widget.onHorizontalDragEnd) {
                  final callback? => (details) => callback(details, false),
                  null => null,
                }
                ..onCancel = widget.onHorizontalDragCancel
                ..multitouchDragStrategy = multitouchDragStrategy
                ..gestureSettings = gestureSettings,
            ),
        },
        child: ValueListenableBuilder<Set<Axis>>(
          valueListenable: _draggingAxes,
          builder: (context, draggingAxes, child) {
            final blockedDirections = <AxisDirection>{
              for (final direction in AxisDirection.values)
                if (dragAxes.contains(_axisFor(direction)) &&
                    (draggingAxes.contains(_axisFor(direction)) ||
                        _modeFor(direction) == ScrollDragMode.dragFirst))
                  direction,
            };
            final blockedAxes = blockedDirections.map(_axisFor).toSet();

            final parent = ScrollConfiguration.of(context);
            // Always a ScrollDragBehavior, even with nothing blocked: a
            // descendant that copies it (a text field's own scrollable)
            // would otherwise swap between it and the parent's type as a
            // drag starts and ends, and Flutter's wrapped behavior can't
            // compare itself to a different type.
            final behavior = ScrollDragBehavior._(
              parent: parent,
              axes: blockedAxes,
              blockedDirections: blockedDirections,
              owner: this,
            );
            return _ScrollDragBehaviorScope(
              behaviors: [
                if (blockedDirections.isNotEmpty) behavior,
                ..._ScrollDragBehaviorScope.of(context),
              ],
              child: ScrollConfiguration(
                behavior: behavior,
                child: child!,
              ),
            );
          },
          child: _ScrollDragDetectorScope(
            detectors: _detectors,
            child: widget.child,
          ),
        ),
      ),
    );
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (!dragAxes.contains(notification.metrics.axis)) return true;
    // A scrollable inside an ExcludeScrollDrag never hands off to us.
    if (_ScrollDragExclusionScope.excludedAxes(notification.context, this)
        .contains(notification.metrics.axis)) {
      return true;
    }

    switch (notification) {
      case ScrollStartNotification(:final dragDetails, :final metrics):
        _axisStates[metrics.axis]!
          ..scrollStartedAtLeadingEdge = metrics.extentBefore <= kTouchSlop
          ..scrollStartedAtTrailingEdge = metrics.extentAfter <= kTouchSlop
          ..dragStartDetails = dragDetails;
      case ScrollUpdateNotification(
          :final metrics,
          :final dragDetails,
        ):
        final isScrollActuallyDrag =
            dragDetails != null && _isScrollActuallyDrag(metrics, dragDetails);
        if (isScrollActuallyDrag) {
          if (!_axisStates[metrics.axis]!.isDragging) {
            _startDrag(metrics.axis);
          } else {
            _handleDragUpdate(metrics.axis, dragDetails);
          }
        } else if (_axisStates[metrics.axis]!.isDragging &&
            dragDetails != null) {
          // The scrollable has resumed scrolling in the opposite direction.
          // End the parent drag while keeping the pointer gesture active.
          _endDrag(metrics.axis);
          _handleDragEnd(metrics.axis, DragEndDetails(), true);
        }
      case OverscrollNotification(
          :final metrics,
          :final dragDetails,
          :final velocity,
        ):
        final isScrollActuallyDrag =
            dragDetails != null && _isScrollActuallyDrag(metrics, dragDetails);
        if (isScrollActuallyDrag) {
          if (!_axisStates[metrics.axis]!.isDragging) {
            _startDrag(metrics.axis);
          } else {
            _handleDragUpdate(metrics.axis, dragDetails);
          }
        } else {
          if (_axisStates[metrics.axis]!.isDragging) {
            // Either the user let go, or the overscroll is part of normal
            // scrolling, not dragging.
            // In both cases, we end the drag, and if the user's gesture is
            // still active, we notify that we will continue scrolling.
            final gestureActive = dragDetails != null;
            _endDrag(metrics.axis);
            _handleDragEnd(
              metrics.axis,
              _dragEndDetails(metrics, velocity),
              gestureActive,
            );
          }
        }

      case final ScrollEndNotification n:
        final axis = n.metrics.axis;
        if (_axisStates[axis]!.isDragging) {
          _endDrag(axis);
          final state = _axisStates[axis]!;
          final dragSegment = state.dragSegment;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted &&
                !state.isDragging &&
                state.dragSegment == dragSegment) {
              // The user stopped scrolling, so we also end the drag.
              _handleDragEnd(
                axis,
                n.dragDetails ?? DragEndDetails(),
                false,
              );
            }
          });
        }
    }
    return true;
  }

  void _startDrag(Axis axis) {
    _axisStates[axis]!
      ..isDragging = true
      ..dragSegment += 1;
    _updateDraggingAxes();
    _handleDragStart(axis);
  }

  void _endDrag(Axis axis) {
    _axisStates[axis]!
      ..isDragging = false
      ..dragSegment += 1;
    _updateDraggingAxes();
  }

  void _updateDraggingAxes() {
    void update() {
      if (!mounted) return;
      _draggingAxes.value = {
        for (final entry in _axisStates.entries)
          if (entry.value.isDragging) entry.key,
      };
    }

    // Scroll notifications can arrive during layout. Keep routing synchronous,
    // but only notify the builder when the widget tree can be marked dirty.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => update());
    } else {
      update();
    }
  }

  static DragEndDetails _dragEndDetails(
    ScrollMetrics metrics,
    double velocity,
  ) {
    final primaryVelocity = switch (metrics.axisDirection) {
      AxisDirection.up || AxisDirection.left => velocity,
      AxisDirection.down || AxisDirection.right => -velocity,
    };
    final pixelsPerSecond = switch (metrics.axis) {
      Axis.vertical => Offset(0, primaryVelocity),
      Axis.horizontal => Offset(primaryVelocity, 0),
    };

    return DragEndDetails(
      primaryVelocity: primaryVelocity,
      velocity: Velocity(pixelsPerSecond: pixelsPerSecond),
    );
  }

  /// Whether the given scroll metrics and drag details indicate that the user
  /// is trying to drag instead of scroll.
  bool _isScrollActuallyDrag(ScrollMetrics metrics, DragUpdateDetails details) {
    final primaryDelta = details.primaryDelta;
    if (primaryDelta == null || primaryDelta == 0) return false;

    final mode = _modeFor(_physicalDirection(metrics.axis, primaryDelta));
    if (mode == ScrollDragMode.none) return false;
    if (mode == ScrollDragMode.dragFirst) return true;

    final isLeading = _isMovingTowardsLeadingEdge(
      metrics.axisDirection,
      primaryDelta,
    );
    final atBoundary =
        isLeading ? metrics.extentBefore == 0 : metrics.extentAfter == 0;
    if (!atBoundary) return false;

    if (mode == ScrollDragMode.boundaryStart) {
      final state = _axisStates[metrics.axis]!;
      return isLeading
          ? state.scrollStartedAtLeadingEdge
          : state.scrollStartedAtTrailingEdge;
    }

    return true;
  }

  static AxisDirection _physicalDirection(Axis axis, double primaryDelta) {
    return switch ((axis, primaryDelta < 0)) {
      (Axis.vertical, true) => AxisDirection.up,
      (Axis.vertical, false) => AxisDirection.down,
      (Axis.horizontal, true) => AxisDirection.left,
      (Axis.horizontal, false) => AxisDirection.right,
    };
  }

  static Axis _axisFor(AxisDirection direction) {
    return switch (direction) {
      AxisDirection.up || AxisDirection.down => Axis.vertical,
      AxisDirection.left || AxisDirection.right => Axis.horizontal,
    };
  }

  static bool _isMovingTowardsLeadingEdge(
    AxisDirection axisDirection,
    double primaryDelta,
  ) {
    return switch (axisDirection) {
      AxisDirection.up || AxisDirection.left => primaryDelta < 0,
      AxisDirection.down || AxisDirection.right => primaryDelta > 0,
    };
  }

  void _handleDragStart(Axis axis) {
    if (_axisStates[axis]!.dragStartDetails case final details?) {
      if (axis == Axis.vertical) {
        widget.onVerticalDragStart?.call(details, true);
      } else {
        widget.onHorizontalDragStart?.call(details, true);
      }
    }
  }

  void _handleDragUpdate(Axis axis, DragUpdateDetails details) {
    if (axis == Axis.vertical) {
      widget.onVerticalDragUpdate?.call(details, true);
    } else {
      widget.onHorizontalDragUpdate?.call(details, true);
    }
  }

  void _handleDragEnd(Axis axis, DragEndDetails details, bool willScroll) {
    if (axis == Axis.vertical) {
      widget.onVerticalDragEnd?.call(details, willScroll);
    } else {
      widget.onHorizontalDragEnd?.call(details, willScroll);
    }
  }
}

class _AxisDragState {
  bool isDragging = false;
  bool scrollStartedAtLeadingEdge = false;
  bool scrollStartedAtTrailingEdge = false;
  int dragSegment = 0;
  DragStartDetails? dragStartDetails;
}

/// Preserves [ScrollDragDetector] handoff when overriding scroll behavior.
///
/// Use this wrapper when a descendant installs its own [ScrollConfiguration]
/// or passes a behavior directly to a scrollable, such as
/// [CustomScrollView.scrollBehavior]. An unwrapped override can hide the
/// detector's physics and allow its content to keep scrolling during a drag.
///
/// ```dart
/// ScrollConfiguration(
///   behavior: ScrollDragBehavior(
///     parent: const ScrollBehavior().copyWith(scrollbars: false),
///   ),
///   child: ListView.builder(itemBuilder: buildItem),
/// )
/// ```
///
/// Ancestor detectors' drag constraints are applied on top of [parent]'s
/// physics. Other behavior settings are delegated to [parent], except scroll
/// decorations are suppressed on axes currently controlled by a detector.
/// Outside a detector, this delegates to [parent] unchanged. [copyWith] retains
/// this wrapper, including when overriding physics.
class ScrollDragBehavior extends ScrollBehavior {
  /// Wraps [parent] while preserving ancestor detectors' drag constraints.
  const ScrollDragBehavior({required this.parent})
      : _axes = null,
        _blockedDirections = null,
        _owner = null;

  const ScrollDragBehavior._({
    required this.parent,
    required Set<Axis>? axes,
    required Set<AxisDirection>? blockedDirections,
    required _ScrollDragDetectorState? owner,
  })  : _axes = axes,
        _blockedDirections = blockedDirections,
        _owner = owner;

  /// The consumer's scroll behavior, including its physics and input settings.
  final ScrollBehavior parent;

  final Set<Axis>? _axes;
  final Set<AxisDirection>? _blockedDirections;
  final _ScrollDragDetectorState? _owner;

  List<ScrollDragBehavior> _behaviorsOf(BuildContext context) =>
      _axes != null ? [this] : _ScrollDragBehaviorScope.of(context);

  /// The axes this detector's behavior controls for a scrollable at
  /// [context], leaving out those an [ExcludeScrollDrag] in between excludes.
  Set<Axis> _axesAt(BuildContext context) => _axes!.difference(
        _ScrollDragExclusionScope.excludedAxes(
          context,
          _owner,
          listen: true,
        ),
      );

  bool _doesApplyToDetails(BuildContext context, ScrollableDetails details) =>
      _behaviorsOf(context).any(
        (behavior) => behavior
            ._axesAt(context)
            .contains(axisDirectionToAxis(details.direction)),
      );

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    var physics = parent.getScrollPhysics(context);
    for (final behavior in _behaviorsOf(context).reversed) {
      final axes = behavior._axesAt(context);
      if (axes.isEmpty) continue;
      physics = _OverscrollScrollPhysics(
        axes: axes,
        blockedDirections: behavior._blockedDirections!,
        parent: physics,
      );
    }
    return physics;
  }

  @override
  ScrollDragBehavior copyWith({
    bool? scrollbars,
    bool? overscroll,
    Set<PointerDeviceKind>? dragDevices,
    MultitouchDragStrategy? multitouchDragStrategy,
    Set<LogicalKeyboardKey>? pointerAxisModifiers,
    ScrollPhysics? physics,
    TargetPlatform? platform,
    ScrollViewKeyboardDismissBehavior? keyboardDismissBehavior,
  }) =>
      ScrollDragBehavior._(
        parent: parent.copyWith(
          scrollbars: scrollbars,
          overscroll: overscroll,
          dragDevices: dragDevices,
          multitouchDragStrategy: multitouchDragStrategy,
          pointerAxisModifiers: pointerAxisModifiers,
          physics: physics,
          platform: platform,
          keyboardDismissBehavior: keyboardDismissBehavior,
        ),
        axes: _axes,
        blockedDirections: _blockedDirections,
        owner: _owner,
      );

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      _doesApplyToDetails(context, details)
          ? child
          : parent.buildOverscrollIndicator(context, child, details);

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      _doesApplyToDetails(context, details)
          ? child
          : parent.buildScrollbar(context, child, details);

  @override
  Set<PointerDeviceKind> get dragDevices => parent.dragDevices;

  @override
  ScrollViewKeyboardDismissBehavior getKeyboardDismissBehavior(
    BuildContext context,
  ) =>
      parent.getKeyboardDismissBehavior(context);

  @override
  MultitouchDragStrategy getMultitouchDragStrategy(BuildContext context) =>
      parent.getMultitouchDragStrategy(context);

  @override
  TargetPlatform getPlatform(BuildContext context) =>
      parent.getPlatform(context);

  @override
  Set<LogicalKeyboardKey> get pointerAxisModifiers =>
      parent.pointerAxisModifiers;

  @override
  GestureVelocityTrackerBuilder velocityTrackerBuilder(BuildContext context) =>
      parent.velocityTrackerBuilder(context);

  @override
  bool shouldNotify(covariant ScrollBehavior oldDelegate) =>
      oldDelegate is! ScrollDragBehavior ||
      parent.runtimeType != oldDelegate.parent.runtimeType ||
      parent.shouldNotify(oldDelegate.parent) ||
      !setEquals(oldDelegate._axes, _axes) ||
      !setEquals(oldDelegate._blockedDirections, _blockedDirections) ||
      oldDelegate._owner != _owner;
}

class _ScrollDragBehaviorScope extends InheritedWidget {
  const _ScrollDragBehaviorScope({
    required this.behaviors,
    required super.child,
  });

  final List<ScrollDragBehavior> behaviors;

  static List<ScrollDragBehavior> of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_ScrollDragBehaviorScope>()
          ?.behaviors ??
      const [];

  @override
  bool updateShouldNotify(_ScrollDragBehaviorScope oldWidget) =>
      behaviors != oldWidget.behaviors;
}

/// Scroll physics that don't allow moving from the current position and just
/// always send an overscroll notification.
class _OverscrollScrollPhysics extends ScrollPhysics {
  const _OverscrollScrollPhysics({
    required this.axes,
    required this.blockedDirections,
    super.parent,
  });

  final Set<Axis> axes;

  final Set<AxisDirection> blockedDirections;

  @override
  _OverscrollScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _OverscrollScrollPhysics(
      axes: axes,
      blockedDirections: blockedDirections,
      parent: buildParent(ancestor),
    );
  }

  @override
  double applyBoundaryConditions(
    ScrollMetrics position,
    double value,
  ) {
    if (!axes.contains(position.axis)) {
      return super.applyBoundaryConditions(position, value);
    }

    final isRecoveringFromOutOfRangePosition = (position.pixels <
                position.minScrollExtent &&
            value > position.pixels) ||
        (position.pixels > position.maxScrollExtent && value < position.pixels);
    if (isRecoveringFromOutOfRangePosition) {
      return super.applyBoundaryConditions(position, value);
    }

    final direction = value < position.pixels
        ? position.axisDirection
        : flipAxisDirection(position.axisDirection);
    if (!blockedDirections.contains(direction)) {
      return super.applyBoundaryConditions(position, value);
    }

    return value - position.pixels;
  }
}

class _VerticalDragRecognizer extends VerticalDragGestureRecognizer {
  _VerticalDragRecognizer({required this.isExcluded, super.debugOwner});

  final bool Function(int pointer) isExcluded;

  @override
  bool isPointerAllowed(PointerEvent event) =>
      !isExcluded(event.pointer) && super.isPointerAllowed(event);

  @override
  bool isPointerPanZoomAllowed(PointerPanZoomStartEvent event) =>
      !isExcluded(event.pointer) && super.isPointerPanZoomAllowed(event);
}

class _HorizontalDragRecognizer extends HorizontalDragGestureRecognizer {
  _HorizontalDragRecognizer({required this.isExcluded, super.debugOwner});

  final bool Function(int pointer) isExcluded;

  @override
  bool isPointerAllowed(PointerEvent event) =>
      !isExcluded(event.pointer) && super.isPointerAllowed(event);

  @override
  bool isPointerPanZoomAllowed(PointerPanZoomStartEvent event) =>
      !isExcluded(event.pointer) && super.isPointerPanZoomAllowed(event);
}

/// The [ScrollDragDetector]s above a point in the tree, nearest first.
class _ScrollDragDetectorScope extends InheritedWidget {
  const _ScrollDragDetectorScope({
    required this.detectors,
    required super.child,
  });

  final List<_ScrollDragDetectorState> detectors;

  static List<_ScrollDragDetectorState> of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_ScrollDragDetectorScope>()
          ?.detectors ??
      const [];

  @override
  bool updateShouldNotify(_ScrollDragDetectorScope oldWidget) =>
      !listEquals(detectors, oldWidget.detectors);
}

/// {@template exclude_scroll_drag}
/// Keeps the [ScrollDragDetector]s above it out of drags that start inside
/// [child], so [child] gets them as if no detector were there.
///
/// A [ScrollDragDetector] competes for drags like any [GestureDetector], and
/// its drag usually wins against a pan or drag of its content. Wrap content
/// that needs its own drags in [ExcludeScrollDrag], such as a map or canvas in
/// a sheet, a draggable card on a drawer page, or any content of a route that
/// can be swiped back from anywhere:
///
/// ```dart
/// ScrollDragDetector(
///   // ...
///   child: Column(
///     children: [
///       const SheetHeader(),
///       Expanded(child: ExcludeScrollDrag(child: MapView())),
///     ],
///   ),
/// )
/// ```
///
/// A pointer that goes down inside [child] is never taken by an ancestor
/// [ScrollDragDetector] on the excluded [axes]: neither as its own drag, nor
/// through the handoff of a scrollable inside [child]. Such a scrollable
/// scrolls and overscrolls as if no detector were above it.
///
/// It applies to every [ScrollDragDetector] above it, so a drawer page inside
/// a sheet keeps both out. Detectors inside [child] work as usual. Drags that
/// start outside [child] are not affected.
/// {@endtemplate}
class ExcludeScrollDrag extends StatefulWidget {
  /// {@macro exclude_scroll_drag}
  const ExcludeScrollDrag({
    required this.child,
    this.axes = const {Axis.horizontal, Axis.vertical},
    this.excluding = true,
    super.key,
  });

  /// The widget below this widget in the tree.
  final Widget child;

  /// The drag axes ancestor detectors stay out of.
  ///
  /// Exclude only [Axis.horizontal] to keep a horizontally draggable child
  /// while a sheet above it can still be dragged down from it.
  final Set<Axis> axes;

  /// Whether the exclusion applies.
  ///
  /// When false, ancestor detectors treat [child] like any other content.
  final bool excluding;

  @override
  State<ExcludeScrollDrag> createState() => _ExcludeScrollDragState();
}

class _ExcludeScrollDragState extends State<ExcludeScrollDrag> {
  List<_ScrollDragDetectorState> _detectors = const [];

  /// The pointers this exclusion handed to [_detectors], with those detectors.
  final _pointers = <int, List<_ScrollDragDetectorState>>{};

  Set<Axis> get _axes => widget.excluding ? widget.axes : const {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _detectors = _ScrollDragDetectorScope.of(context);
  }

  // Hit-test entries get a pointer down deepest first, so this runs before
  // the recognizers of every ancestor detector decide whether to track it.
  void _onPointerDown(PointerEvent event) {
    final axes = _axes;
    if (axes.isEmpty) return;
    _pointers[event.pointer] = _detectors;
    for (final detector in _detectors) {
      detector._excludePointer(event.pointer, axes);
    }
  }

  void _onPointerEnd(PointerEvent event) => _release(event.pointer);

  void _release(int pointer) {
    for (final detector
        in _pointers.remove(pointer) ?? const <_ScrollDragDetectorState>[]) {
      detector._releasePointer(pointer);
    }
  }

  @override
  void dispose() {
    _pointers.keys.toList().forEach(_release);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final outer = _ScrollDragExclusionScope.maybeOf(context);
    final axes = _axes;
    final excluded = <_ScrollDragDetectorState, Set<Axis>>{
      ...?outer?.excluded,
      if (axes.isNotEmpty)
        for (final detector in _detectors)
          detector: {...?outer?.excluded[detector], ...axes},
    };
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerPanZoomStart: _onPointerDown,
      onPointerUp: _onPointerEnd,
      onPointerCancel: _onPointerEnd,
      onPointerPanZoomEnd: _onPointerEnd,
      child: _ScrollDragExclusionScope(
        excluded: excluded,
        child: widget.child,
      ),
    );
  }
}

/// Which ancestor detectors are excluded below an [ExcludeScrollDrag], and on
/// which axes.
class _ScrollDragExclusionScope extends InheritedWidget {
  const _ScrollDragExclusionScope({
    required this.excluded,
    required super.child,
  });

  final Map<_ScrollDragDetectorState, Set<Axis>> excluded;

  static _ScrollDragExclusionScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ScrollDragExclusionScope>();

  /// The axes on which [detector] is excluded for content at [context].
  static Set<Axis> excludedAxes(
    BuildContext? context,
    _ScrollDragDetectorState? detector, {
    bool listen = false,
  }) {
    if (context == null || detector == null) return const {};
    final scope = listen
        ? maybeOf(context)
        : context.getInheritedWidgetOfExactType<_ScrollDragExclusionScope>();
    return scope?.excluded[detector] ?? const {};
  }

  @override
  bool updateShouldNotify(_ScrollDragExclusionScope oldWidget) =>
      !_sameExclusions(excluded, oldWidget.excluded);

  static bool _sameExclusions(
    Map<_ScrollDragDetectorState, Set<Axis>> a,
    Map<_ScrollDragDetectorState, Set<Axis>> b,
  ) =>
      a.length == b.length &&
      a.entries.every((entry) => setEquals(b[entry.key], entry.value));
}
