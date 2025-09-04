import 'package:flutter/gestures.dart';
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

  DragStartDetails? _dragStartDetails;

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
              behavior: ScrollConfiguration.of(context).copyWith(
                overscroll: false,
                physics:
                    value ? _OverscrollScrollPhysics(axes: dragAxes) : null,
              ),
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
      case ScrollStartNotification(:final dragDetails):
        _dragStartDetails = dragDetails;
      case ScrollUpdateNotification(
          :final metrics,
          :final dragDetails,
        ):
        if (dragDetails != null) {
          // When we are overscrolling at the top
          if (metrics.extentBefore <= 0 &&
              dragDetails.primaryDelta != null &&
              dragDetails.primaryDelta! > 0) {
            if (!_isDragging.value) {
              _isDragging.value = true;
              _handleDragStart(metrics.axis);
            } else {
              _handleDragUpdate(metrics.axis, dragDetails);
            }
          }
        }
      case OverscrollNotification(
          :final metrics,
          :final dragDetails,
          :final velocity,
        ):
        if (dragDetails != null) {
          // When we are overscrolling at the top
          if (metrics.extentBefore <= 0) {
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

/// Scroll physics that don't allow moving from the current position and just
/// always send an overscroll notification.
class _OverscrollScrollPhysics extends ClampingScrollPhysics {
  const _OverscrollScrollPhysics({
    required this.axes,
    super.parent,
  });

  final Set<Axis> axes;

  @override
  _OverscrollScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _OverscrollScrollPhysics(
      axes: axes,
      parent: buildParent(ancestor),
    );
  }

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
