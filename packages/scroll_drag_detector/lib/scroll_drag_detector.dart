// ignore_for_file: avoid_positional_boolean_parameters

import 'dart:convert';
import 'dart:io';

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

// #region agent log
void _writeDebugLog({
  required String hypothesisId,
  required String location,
  required String message,
  required Map<String, Object?> data,
}) {
  try {
    File('/opt/cursor/logs/debug.log').writeAsStringSync(
      '${jsonEncode(<String, Object?>{
            'hypothesisId': hypothesisId,
            'location': location,
            'message': message,
            'data': data,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          })}\n',
      mode: FileMode.append,
    );
  } catch (_) {}
}
// #endregion

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
        onVerticalDragEnd: hasVertical
            ? (details) => _handleGestureEnd(Axis.vertical, details)
            : null,
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
        onHorizontalDragEnd: hasHorizontal
            ? (details) => _handleGestureEnd(Axis.horizontal, details)
            : null,
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

    // #region agent log
    _writeDebugLog(
      hypothesisId: 'A,C,E',
      location:
          'packages/scroll_drag_detector/lib/scroll_drag_detector.dart:_onScrollNotification',
      message: 'received scroll notification',
      data: {
        'type': notification.runtimeType.toString(),
        'isDragging': _isDragging.value,
        'axis': notification.metrics.axis.name,
        'axisDirection': notification.metrics.axisDirection.name,
        'pixels': notification.metrics.pixels,
        'extentBefore': notification.metrics.extentBefore,
        'extentAfter': notification.metrics.extentAfter,
        'dragDetailsPresent': switch (notification) {
          ScrollStartNotification(:final dragDetails) => dragDetails != null,
          ScrollUpdateNotification(:final dragDetails) => dragDetails != null,
          OverscrollNotification(:final dragDetails) => dragDetails != null,
          _ => false,
        },
      },
    );
    // #endregion

    switch (notification) {
      case ScrollStartNotification(:final dragDetails, :final metrics):
        _scrollStartedAtLeadingEdge = metrics.extentBefore <= kTouchSlop;
        _scrollStartedAtTrailingEdge = metrics.extentAfter <= kTouchSlop;
        _dragStartDetails = dragDetails;
        // #region agent log
        _writeDebugLog(
          hypothesisId: 'E',
          location:
              'packages/scroll_drag_detector/lib/scroll_drag_detector.dart:ScrollStartNotification',
          message: 'captured gesture edge state',
          data: {
            'leadingAtStart': _scrollStartedAtLeadingEdge,
            'trailingAtStart': _scrollStartedAtTrailingEdge,
            'extentBefore': metrics.extentBefore,
            'extentAfter': metrics.extentAfter,
            'dragDetailsPresent': dragDetails != null,
            'leadingHandoff': _leadingEdgeHandoff.name,
            'trailingHandoff': _trailingEdgeHandoff.name,
            'onlyLeadingAtStart': _onlyDragWhenScrollWasAtLeadingEdge,
            'onlyTrailingAtStart': _onlyDragWhenScrollWasAtTrailingEdge,
          },
        );
      // #endregion
      case ScrollUpdateNotification(
          :final metrics,
          :final dragDetails,
        ):
        final isScrollActuallyDrag =
            dragDetails != null && _isScrollActuallyDrag(metrics, dragDetails);
        // #region agent log
        _writeDebugLog(
          hypothesisId: 'B,C',
          location:
              'packages/scroll_drag_detector/lib/scroll_drag_detector.dart:ScrollUpdateNotification',
          message: 'classified scroll update',
          data: {
            'isScrollActuallyDrag': isScrollActuallyDrag,
            'isDragging': _isDragging.value,
            'primaryDelta': dragDetails?.primaryDelta,
            'pixels': metrics.pixels,
            'extentBefore': metrics.extentBefore,
            'extentAfter': metrics.extentAfter,
            'leadingHandoff': _leadingEdgeHandoff.name,
            'trailingHandoff': _trailingEdgeHandoff.name,
          },
        );
        // #endregion
        if (isScrollActuallyDrag) {
          // When we are overscrolling at the top

          if (!_isDragging.value) {
            _isDragging.value = true;
            _handleDragStart(metrics.axis);
          } else {
            _handleDragUpdate(metrics.axis, dragDetails);
          }
        } else if (_isDragging.value) {
          // #region agent log
          _writeDebugLog(
            hypothesisId: 'B',
            location:
                'packages/scroll_drag_detector/lib/scroll_drag_detector.dart:ScrollUpdateNotification.nonHandoff',
            message: 'active parent drag ignored non-handoff update',
            data: {
              'primaryDelta': dragDetails?.primaryDelta,
              'pixels': metrics.pixels,
              'extentBefore': metrics.extentBefore,
              'extentAfter': metrics.extentAfter,
            },
          );
          // #endregion
        }
      case OverscrollNotification(
          :final metrics,
          :final dragDetails,
          :final velocity,
        ):
        final isScrollActuallyDrag =
            dragDetails != null && _isScrollActuallyDrag(metrics, dragDetails);
        // #region agent log
        _writeDebugLog(
          hypothesisId: 'A,B,C',
          location:
              'packages/scroll_drag_detector/lib/scroll_drag_detector.dart:OverscrollNotification',
          message: 'classified overscroll notification',
          data: {
            'isScrollActuallyDrag': isScrollActuallyDrag,
            'isDragging': _isDragging.value,
            'primaryDelta': dragDetails?.primaryDelta,
            'velocity': velocity,
            'pixels': metrics.pixels,
            'extentBefore': metrics.extentBefore,
            'extentAfter': metrics.extentAfter,
          },
        );
        // #endregion
        if (isScrollActuallyDrag) {
          // When we are overscrolling at the top

          if (!_isDragging.value) {
            _isDragging.value = true;
            _handleDragStart(metrics.axis);
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
              DragEndDetails(
                primaryVelocity: -velocity,
                velocity: Velocity(
                  pixelsPerSecond: switch (metrics.axis) {
                    Axis.vertical => Offset(0, -velocity),
                    Axis.horizontal => Offset(-velocity, 0),
                  },
                ),
              ),
              gestureActive,
            );
          }
        }

      case final ScrollEndNotification n:
        // #region agent log
        _writeDebugLog(
          hypothesisId: 'A,C',
          location:
              'packages/scroll_drag_detector/lib/scroll_drag_detector.dart:ScrollEndNotification',
          message: 'received scroll end notification',
          data: {
            'isDragging': _isDragging.value,
            'pixels': n.metrics.pixels,
            'extentBefore': n.metrics.extentBefore,
            'extentAfter': n.metrics.extentAfter,
            'dragDetailsPresent': n.dragDetails != null,
          },
        );
        // #endregion
        if (_isDragging.value) {
          _isDragging.value = false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
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
    // #region agent log
    _writeDebugLog(
      hypothesisId: 'A,C',
      location:
          'packages/scroll_drag_detector/lib/scroll_drag_detector.dart:_handleDragStart',
      message: 'forwarded parent drag start',
      data: {
        'axis': axis.name,
        'hasStartDetails': _dragStartDetails != null,
      },
    );
    // #endregion
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

  void _handleGestureEnd(Axis axis, DragEndDetails details) {
    // #region agent log
    _writeDebugLog(
      hypothesisId: 'G',
      location:
          'packages/scroll_drag_detector/lib/scroll_drag_detector.dart:_handleGestureEnd',
      message: 'outer gesture ended',
      data: {
        'axis': axis.name,
        'primaryVelocity': details.primaryVelocity,
        'isDragging': _isDragging.value,
      },
    );
    // #endregion
    if (axis == Axis.vertical) {
      widget.onVerticalDragEnd?.call(details, false);
    } else {
      widget.onHorizontalDragEnd?.call(details, false);
    }
  }

  void _handleDragEnd(Axis axis, DragEndDetails details, bool willScroll) {
    // #region agent log
    _writeDebugLog(
      hypothesisId: 'A,C',
      location:
          'packages/scroll_drag_detector/lib/scroll_drag_detector.dart:_handleDragEnd',
      message: 'forwarded parent drag end',
      data: {
        'axis': axis.name,
        'willScroll': willScroll,
        'primaryVelocity': details.primaryVelocity,
      },
    );
    // #endregion
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
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final simulation = super.createBallisticSimulation(position, velocity);
    // #region agent log
    _writeDebugLog(
      hypothesisId: 'G',
      location:
          'packages/scroll_drag_detector/lib/scroll_drag_detector.dart:_OverscrollScrollPhysics.createBallisticSimulation',
      message: 'created ballistic simulation',
      data: {
        'pixels': position.pixels,
        'velocity': velocity,
        'outOfRange': position.outOfRange,
        'simulation': simulation?.runtimeType.toString(),
      },
    );
    // #endregion
    return simulation;
  }

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
    // #region agent log
    _writeDebugLog(
      hypothesisId: 'F',
      location:
          'packages/scroll_drag_detector/lib/scroll_drag_detector.dart:_OverscrollScrollPhysics.applyBoundaryConditions',
      message: 'evaluated boundary condition',
      data: {
        'pixels': position.pixels,
        'value': value,
        'min': position.minScrollExtent,
        'max': position.maxScrollExtent,
        'blockLeading': blockLeadingScroll,
        'blockTrailing': blockTrailingScroll,
        'recovering': isRecoveringFromOutOfRangePosition,
      },
    );
    // #endregion
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
