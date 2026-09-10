// ignore_for_file: avoid_positional_boolean_parameters

import 'package:flutter/gestures.dart';
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

/// Describes when a scrollable should hand a drag to its parent.
enum ScrollDragHandoff {
  /// Never hand the drag to the parent from this edge.
  none,

  /// Hand the drag to the parent after the scrollable reaches this edge.
  edge,

  /// Hand the drag to the parent before the scrollable moves in this
  /// direction.
  beforeScroll,
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
/// {@endtemplate}
class ScrollDragDetector extends StatefulWidget {
  ///{@macro scroll_drag_detector}
  const ScrollDragDetector({
    required this.child,
    this.leadingEdgeHandoff = ScrollDragHandoff.edge,
    this.trailingEdgeHandoff = ScrollDragHandoff.beforeScroll,
    this.onlyDragWhenScrollWasAtLeadingEdge = true,
    this.onlyDragWhenScrollWasAtTrailingEdge = false,
    @Deprecated(
      'Use trailingEdgeHandoff instead. '
      'This parameter will be removed in the next major version.',
    )
    this.scrollableCanMoveBack,
    @Deprecated(
      'Use onlyDragWhenScrollWasAtLeadingEdge instead. '
      'This parameter will be removed in the next major version.',
    )
    this.onlyDragWhenScrollWasAtTop,
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

  /// Controls handoff when the scrollable reaches its leading edge.
  ///
  /// The leading edge is the minimum scroll extent. Its physical location
  /// depends on the scrollable's [AxisDirection], so this works for vertical
  /// and horizontal scrollables, including reversed scroll views.
  ///
  /// Defaults to [ScrollDragHandoff.edge].
  final ScrollDragHandoff leadingEdgeHandoff;

  /// Controls handoff when the scrollable reaches its trailing edge.
  ///
  /// The trailing edge is the maximum scroll extent. Its physical location
  /// depends on the scrollable's [AxisDirection], so this works for vertical
  /// and horizontal scrollables, including reversed scroll views.
  ///
  /// Defaults to [ScrollDragHandoff.beforeScroll] to preserve the original
  /// bottom-sheet behavior. Use [ScrollDragHandoff.edge] when the scrollable
  /// should scroll to its trailing edge before the parent takes over.
  final ScrollDragHandoff trailingEdgeHandoff;

  /// If true, leading-edge handoff only occurs when the gesture started at the
  /// leading edge.
  ///
  /// If false, an eligible gesture can hand off after scrolling to the leading
  /// edge. Defaults to true, matching the original top-edge behavior.
  final bool onlyDragWhenScrollWasAtLeadingEdge;

  /// If true, trailing-edge handoff only occurs when the gesture started at the
  /// trailing edge.
  ///
  /// If false, an [ScrollDragHandoff.edge] handoff can occur after the
  /// scrollable reaches the trailing edge. Defaults to false so a scroll-first
  /// trailing-edge handoff is available by configuration.
  final bool onlyDragWhenScrollWasAtTrailingEdge;

  /// @deprecated Use [trailingEdgeHandoff] instead.
  ///
  /// This is retained as a source-compatible migration path for the original
  /// bottom-sheet API. A non-null value takes precedence over
  /// [trailingEdgeHandoff].
  @Deprecated(
    'Use trailingEdgeHandoff instead. '
    'This parameter will be removed in the next major version.',
  )
  final bool? scrollableCanMoveBack;

  /// @deprecated Use [onlyDragWhenScrollWasAtLeadingEdge] instead.
  ///
  /// This is retained as a source-compatible migration path for the original
  /// top-edge API.
  @Deprecated(
    'Use onlyDragWhenScrollWasAtLeadingEdge instead. '
    'This parameter will be removed in the next major version.',
  )
  final bool? onlyDragWhenScrollWasAtTop;

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
  final _isDragging = ValueNotifier(false);

  var _scrollStartedAtLeadingEdge = false;
  var _scrollStartedAtTrailingEdge = false;
  var _dragSegment = 0;

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

  ScrollDragHandoff get _leadingEdgeHandoff {
    return widget.leadingEdgeHandoff;
  }

  ScrollDragHandoff get _trailingEdgeHandoff {
    return switch (widget.scrollableCanMoveBack) {
      final value? =>
        value ? ScrollDragHandoff.beforeScroll : ScrollDragHandoff.none,
      null => widget.trailingEdgeHandoff,
    };
  }

  bool get _onlyDragWhenScrollWasAtLeadingEdge =>
      widget.onlyDragWhenScrollWasAtTop ??
      widget.onlyDragWhenScrollWasAtLeadingEdge;

  bool get _onlyDragWhenScrollWasAtTrailingEdge =>
      widget.onlyDragWhenScrollWasAtTrailingEdge;

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
        onVerticalDragDown: widget.onVerticalDragDown,
        onVerticalDragStart: switch (widget.onVerticalDragStart) {
          final callback? => (details) {
              callback(details, false);
            },
          null => null,
        },
        onVerticalDragUpdate: switch (widget.onVerticalDragUpdate) {
          final callback? => (details) {
              callback(details, false);
            },
          null => null,
        },
        onVerticalDragEnd: switch (widget.onVerticalDragEnd) {
          final callback? => (details) {
              callback(details, false);
            },
          null => null,
        },
        onVerticalDragCancel: widget.onVerticalDragCancel,
        onHorizontalDragDown: widget.onHorizontalDragDown,
        onHorizontalDragStart: switch (widget.onHorizontalDragStart) {
          final callback? => (details) {
              callback(details, false);
            },
          null => null,
        },
        onHorizontalDragUpdate: switch (widget.onHorizontalDragUpdate) {
          final callback? => (details) {
              callback(details, false);
            },
          null => null,
        },
        onHorizontalDragEnd: switch (widget.onHorizontalDragEnd) {
          final callback? => (details) {
              callback(details, false);
            },
          null => null,
        },
        onHorizontalDragCancel: widget.onHorizontalDragCancel,
        child: ValueListenableBuilder(
          valueListenable: _isDragging,
          builder: (context, value, child) {
            final blockLeadingScroll = !value &&
                _leadingEdgeHandoff == ScrollDragHandoff.beforeScroll &&
                !_onlyDragWhenScrollWasAtLeadingEdge;
            final blockTrailingScroll = !value &&
                _trailingEdgeHandoff == ScrollDragHandoff.beforeScroll &&
                !_onlyDragWhenScrollWasAtTrailingEdge;

            return ScrollConfiguration(
              behavior: value || blockLeadingScroll || blockTrailingScroll
                  ? _DraggingScrollBehavior(
                      parent: ScrollConfiguration.of(context),
                      axes: dragAxes,
                      blockLeadingScroll: value || blockLeadingScroll,
                      blockTrailingScroll: value || blockTrailingScroll,
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
        _scrollStartedAtLeadingEdge = metrics.extentBefore <= kTouchSlop;
        _scrollStartedAtTrailingEdge = metrics.extentAfter <= kTouchSlop;
        _dragStartDetails = dragDetails;
      case ScrollUpdateNotification(
          :final metrics,
          :final dragDetails,
        ):
        final isScrollActuallyDrag =
            dragDetails != null && _isScrollActuallyDrag(metrics, dragDetails);
        if (isScrollActuallyDrag) {
          if (!_isDragging.value) {
            _startDrag(metrics.axis);
          } else {
            _handleDragUpdate(metrics.axis, dragDetails);
          }
        } else if (_isDragging.value && dragDetails != null) {
          // The scrollable has resumed scrolling in the opposite direction.
          // End the parent drag while keeping the pointer gesture active.
          _isDragging.value = false;
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
          if (!_isDragging.value) {
            _startDrag(metrics.axis);
          } else {
            _handleDragUpdate(metrics.axis, dragDetails);
          }
        } else {
          if (_isDragging.value) {
            // Either the user let go, or the overscroll is part of normal
            // scrolling, not dragging.
            // In both cases, we end the drag, and if the user's gesture is
            // still active, we notify that we will continue scrolling.
            final gestureActive = dragDetails != null;
            _isDragging.value = false;
            _handleDragEnd(
              metrics.axis,
              _dragEndDetails(metrics, velocity),
              gestureActive,
            );
          }
        }

      case final ScrollEndNotification n:
        if (_isDragging.value) {
          _isDragging.value = false;
          final dragSegment = _dragSegment;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_isDragging.value && _dragSegment == dragSegment) {
              // The user stopped scrolling, so we also end the drag.
              _handleDragEnd(
                n.metrics.axis,
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
    _isDragging.value = true;
    _dragSegment++;
    _handleDragStart(axis);
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

    final isLeading = _isMovingTowardsLeadingEdge(
      metrics.axisDirection,
      primaryDelta,
    );
    final handoff = isLeading ? _leadingEdgeHandoff : _trailingEdgeHandoff;
    if (handoff == ScrollDragHandoff.none) return false;

    final startedAtEdge =
        isLeading ? _scrollStartedAtLeadingEdge : _scrollStartedAtTrailingEdge;
    final onlyWhenStartedAtEdge = isLeading
        ? _onlyDragWhenScrollWasAtLeadingEdge
        : _onlyDragWhenScrollWasAtTrailingEdge;
    if (onlyWhenStartedAtEdge && !startedAtEdge) return false;

    if (handoff == ScrollDragHandoff.edge) {
      final atEdge = isLeading
          ? metrics.extentBefore <= kTouchSlop
          : metrics.extentAfter <= kTouchSlop;
      if (!atEdge) return false;
    }

    return true;
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
    if (_dragStartDetails case final details?) {
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

class _DraggingScrollBehavior extends ScrollBehavior {
  const _DraggingScrollBehavior({
    required this.parent,
    required this.axes,
    required this.blockLeadingScroll,
    required this.blockTrailingScroll,
  });

  final ScrollBehavior parent;

  final Set<Axis> axes;

  /// Whether scrolls towards the leading edge should be blocked.
  final bool blockLeadingScroll;

  /// Whether scrolls towards the trailing edge should be blocked.
  final bool blockTrailingScroll;

  bool doesApplyToDetails(ScrollableDetails details) {
    return switch (details.direction) {
      AxisDirection.up || AxisDirection.down => axes.contains(Axis.vertical),
      AxisDirection.left ||
      AxisDirection.right =>
        axes.contains(Axis.horizontal),
    };
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      _OverscrollScrollPhysics(
        axes: axes,
        blockLeadingScroll: blockLeadingScroll,
        blockTrailingScroll: blockTrailingScroll,
        parent: parent.getScrollPhysics(context),
      );

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      doesApplyToDetails(details)
          ? child
          : parent.buildOverscrollIndicator(context, child, details);

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      doesApplyToDetails(details)
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
      parent.shouldNotify(oldDelegate) ||
      (oldDelegate is _DraggingScrollBehavior &&
          (oldDelegate.axes != axes ||
              oldDelegate.blockLeadingScroll != blockLeadingScroll ||
              oldDelegate.blockTrailingScroll != blockTrailingScroll));
}

/// Scroll physics that don't allow moving from the current position and just
/// always send an overscroll notification.
class _OverscrollScrollPhysics extends ScrollPhysics {
  const _OverscrollScrollPhysics({
    required this.axes,
    required this.blockLeadingScroll,
    required this.blockTrailingScroll,
    super.parent,
  });

  final Set<Axis> axes;

  final bool blockLeadingScroll;

  final bool blockTrailingScroll;

  @override
  _OverscrollScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _OverscrollScrollPhysics(
      axes: axes,
      blockLeadingScroll: blockLeadingScroll,
      blockTrailingScroll: blockTrailingScroll,
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

    final movingTowardsTrailingEdge = value > position.pixels;
    final isRecoveringFromOutOfRangePosition = (position.pixels <
                position.minScrollExtent &&
            value > position.pixels) ||
        (position.pixels > position.maxScrollExtent && value < position.pixels);
    if (isRecoveringFromOutOfRangePosition) {
      return super.applyBoundaryConditions(position, value);
    }

    final shouldBlock =
        movingTowardsTrailingEdge ? blockTrailingScroll : blockLeadingScroll;
    if (!shouldBlock) {
      return super.applyBoundaryConditions(position, value);
    }

    return value - position.pixels;
  }
}
