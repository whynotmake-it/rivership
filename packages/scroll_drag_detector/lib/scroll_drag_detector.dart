import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

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
/// {@endtemplate}
class ScrollDragDetector extends StatefulWidget {
  ///{@macro scroll_drag_detector}
  const ScrollDragDetector({
    required this.child,
    this.scrollableCanMoveBack = true,
    this.onlyDragWhenScrollWasAtTop = true,
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

  /// The widget below this widget in the tree.
  final Widget child;

  /// Whether the scrollable can still move backwards (towards the direction
  /// of its leading edge).
  ///
  /// Set this to false when your scrollable cannot move backwards (e.g. a
  /// sheet) is fully expanded to allow this child's scrollable to transition
  /// back to scrolling instead of dragging.
  ///
  /// It will then send an [onVerticalDragEnd] callback.
  final bool scrollableCanMoveBack;

  /// If true, scrolls will only transition to drags, when the initial drag
  /// started at the top of the scrollable.
  ///
  /// This matches iOS sheet default behavior and defaults to true.
  final bool onlyDragWhenScrollWasAtTop;

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
  final GestureDragStartCallback? onVerticalDragStart;

  /// A pointer that is in contact with the screen with a primary button and
  /// moving vertically has moved in the vertical direction.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  final GestureDragUpdateCallback? onVerticalDragUpdate;

  /// A pointer that was previously in contact with the screen with a primary
  /// button and moving vertically is no longer in contact with the screen and
  /// was moving at a specific velocity when it stopped contacting the screen.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  final GestureDragEndCallback? onVerticalDragEnd;

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
  final GestureDragStartCallback? onHorizontalDragStart;

  /// A pointer that is in contact with the screen with a primary button and
  /// moving horizontally has moved in the horizontal direction.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  final GestureDragUpdateCallback? onHorizontalDragUpdate;

  /// A pointer that was previously in contact with the screen with a primary
  /// button and moving horizontally is no longer in contact with the screen and
  /// was moving at a specific velocity when it stopped contacting the screen.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  final GestureDragEndCallback? onHorizontalDragEnd;

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
  final _isDragging = ValueNotifier(false);

  var _scrollStartedAtTop = false;

  DragStartDetails? _dragStartDetails;
  late ScrollMetrics _startMetrics;

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

  @override
  void dispose() {
    _isDragging.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: GestureDetector(
        onVerticalDragStart: widget.onVerticalDragStart,
        onVerticalDragUpdate: widget.onVerticalDragUpdate,
        onVerticalDragEnd: widget.onVerticalDragEnd,
        onVerticalDragCancel: widget.onVerticalDragCancel,
        onHorizontalDragStart: widget.onHorizontalDragStart,
        onHorizontalDragUpdate: widget.onHorizontalDragUpdate,
        onHorizontalDragEnd: widget.onHorizontalDragEnd,
        onHorizontalDragCancel: widget.onHorizontalDragCancel,
        child: ValueListenableBuilder(
          valueListenable: _isDragging,
          builder: (context, value, child) {
            return ScrollConfiguration(
              behavior: value
                  ? _DraggingScrollBehavior(
                      parent: ScrollConfiguration.of(context),
                      axes: dragAxes,
                      startMetrics: _startMetrics,
                    )
                  : ScrollConfiguration.of(context),
              child: child!,
            );
          },
          child: widget.child,
        ),
      ),
    );
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (!dragAxes.contains(notification.metrics.axis)) return true;

    switch (notification) {
      case ScrollStartNotification(:final dragDetails, :final metrics):
        _scrollStartedAtTop = notification.metrics.extentBefore <= kTouchSlop;
        _dragStartDetails = dragDetails;
        _startMetrics = metrics;
      case ScrollUpdateNotification(
          :final metrics,
          :final dragDetails,
        ):
        if (dragDetails != null &&
            _isScrollActuallyDrag(metrics, dragDetails)) {
          // When we are overscrolling at the top

          if (!_isDragging.value) {
            _isDragging.value = true;
            _handleDragStart(metrics.axis);
          } else {
            _handleDragUpdate(metrics.axis, dragDetails);
          }
        }
      case OverscrollNotification(
          :final metrics,
          :final dragDetails,
          :final velocity,
        ):
        if (dragDetails != null &&
            _isScrollActuallyDrag(metrics, dragDetails)) {
          // When we are overscrolling at the top

          if (!_isDragging.value) {
            _isDragging.value = true;
            _handleDragStart(metrics.axis);
          } else if (dragDetails.primaryDelta case final delta?
              when delta < 0 && !widget.scrollableCanMoveBack) {
            _isDragging.value = false;
            _handleDragEnd(metrics.axis, DragEndDetails());
          } else {
            _handleDragUpdate(metrics.axis, dragDetails);
          }
        } else {
          if (_isDragging.value) {
            _isDragging.value = false;
            _handleDragEnd(
              metrics.axis,
              DragEndDetails(
                primaryVelocity: -velocity,
                velocity: Velocity(
                  pixelsPerSecond: switch (metrics.axis) {
                    Axis.vertical => Offset(0, -velocity),
                    Axis.horizontal => Offset(-velocity, 0),
                  },
                ),
              ),
            );
          }
        }

      case final ScrollEndNotification n:
        if (_isDragging.value) {
          _isDragging.value = false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _handleDragEnd(n.metrics.axis, n.dragDetails ?? DragEndDetails());
            }
          });
        }
    }
    return true;
  }

  /// Whether it is possible that the user could intend to drag backward
  /// (towards the direction of the leading edge).
  ///
  /// If `onlyDragWhenScrollWasAtTop` is true, this is only possible if the
  /// scroll started at the top.
  bool get _canDragBackward =>
      _scrollStartedAtTop || !widget.onlyDragWhenScrollWasAtTop;

  /// Whether it is possible that the user could intend to drag forward
  /// (towards the direction of the trailing edge).
  bool get _canDragForward => widget.scrollableCanMoveBack;

  /// Whether the given scroll metrics and drag details indicate that the user
  /// is trying to drag instead of scroll.
  bool _isScrollActuallyDrag(ScrollMetrics metrics, DragUpdateDetails details) {
    // We are at the top and trying to scroll further up
    if (metrics.extentBefore <= 0 &&
        details.primaryDelta != null &&
        details.primaryDelta! > 0) {
      return _canDragBackward;
    }

    // We aren't at the top and can move further forward
    if (details.primaryDelta != null && details.primaryDelta! < 0) {
      return _canDragForward;
    }

    return false;
  }

  void _handleDragStart(Axis axis) {
    if (_dragStartDetails case final details?) {
      if (axis == Axis.vertical) {
        widget.onVerticalDragStart?.call(details);
      } else {
        widget.onHorizontalDragStart?.call(details);
      }
    }
  }

  void _handleDragUpdate(Axis axis, DragUpdateDetails details) {
    if (axis == Axis.vertical) {
      widget.onVerticalDragUpdate?.call(details);
    } else {
      widget.onHorizontalDragUpdate?.call(details);
    }
  }

  void _handleDragEnd(Axis axis, DragEndDetails details) {
    if (axis == Axis.vertical) {
      widget.onVerticalDragEnd?.call(details);
    } else {
      widget.onHorizontalDragEnd?.call(details);
    }
  }
}

class _DraggingScrollBehavior extends ScrollBehavior {
  const _DraggingScrollBehavior({
    required this.startMetrics,
    required this.parent,
    required this.axes,
  });

  final ScrollMetrics startMetrics;

  final ScrollBehavior parent;

  final Set<Axis> axes;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      _OverscrollScrollPhysics(axes: axes, startMetrics: startMetrics);

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      parent.buildScrollbar(context, child, details);

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
  GestureVelocityTrackerBuilder velocityTrackerBuilder(BuildContext context) {
    return parent.velocityTrackerBuilder(context);
  }

  @override
  bool shouldNotify(covariant ScrollBehavior oldDelegate) {
    return parent.shouldNotify(oldDelegate);
  }
}

/// Scroll physics that don't allow moving from the current position and just
/// always send an overscroll notification.
class _OverscrollScrollPhysics extends ClampingScrollPhysics {
  const _OverscrollScrollPhysics({
    required this.axes,
    required this.startMetrics,
    super.parent,
  });

  final Set<Axis> axes;

  final ScrollMetrics startMetrics;

  @override
  _OverscrollScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _OverscrollScrollPhysics(
      axes: axes,
      startMetrics: startMetrics,
      parent: buildParent(ancestor),
    );
  }

  @override
  bool get allowUserScrolling => false;

  @override
  bool get allowImplicitScrolling => false;

  @override
  double applyBoundaryConditions(
    ScrollMetrics position,
    double value,
  ) {
    if (axes.contains(position.axis)) return value - position.pixels;

    return parent?.applyBoundaryConditions(position, value) ??
        super.applyBoundaryConditions(position, value);
  }
}
