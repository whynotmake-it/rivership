import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// A widget that works like [Draggable] but with a [Motion]-based animation
/// upon return.
///
/// This widget extends the functionality of [Draggable] by adding smooth
/// animations when the draggable returns to its original position. It uses the
/// provided [Motion] to create natural-feeling animations that respect physics
/// and velocity.
///
/// Key features:
/// * Smooth return animations using [Motion] when drag is canceled or rejected
/// * Configurable return behavior with [onlyReturnWhenCanceled]
/// * Automatic handling of feedback widget constraints with
/// [feedbackMatchesConstraints]
/// * Smart defaults for [feedback] and [childWhenDragging] that maintain layout
/// * Support for velocity-based animations during return
/// * Automatic handling of widget position changes during return animation
///
/// The widget provides sensible defaults:
/// * If [feedback] is not provided, it uses the [child] widget
/// * If [childWhenDragging] is not provided, it shows an invisible version of
/// [child]
/// * The return animation automatically adjusts if the widget's position
/// changes
///
/// See also:
///
/// * [Draggable]
/// * [DragTarget]
/// * [LongPressDraggable]
/// * [Motion]
/// * [SpringMotion]
class MotionDraggable<T extends Object> extends StatefulWidget {
  /// Creates a widget that can be dragged to a [DragTarget].
  ///
  /// If [maxSimultaneousDrags] is non-null, it must be non-negative.
  const MotionDraggable({
    required this.data,
    required this.child,
    this.feedback,
    this.motion = CupertinoMotion.interactive,
    this.onlyReturnWhenCanceled = false,
    this.axis,
    this.childWhenDragging,
    this.feedbackOffset = Offset.zero,
    this.dragAnchorStrategy = childDragAnchorStrategy,
    this.ignoringFeedbackSemantics = true,
    this.ignoringFeedbackPointer = true,
    this.affinity,
    this.maxSimultaneousDrags,
    this.onDragStarted,
    this.onDragUpdate,
    this.onDraggableCanceled,
    this.onDragCompleted,
    this.onDragEnd,
    this.rootOverlay = false,
    this.hitTestBehavior = HitTestBehavior.deferToChild,
    this.allowedButtonsFilter,
    this.feedbackMatchesConstraints = false,
    super.key,
  });

  /// The data that will be dropped by this draggable.
  final T? data;

  /// The [Axis] to restrict this draggable's movement, if specified.
  ///
  /// When axis is set to [Axis.horizontal], this widget can only be dragged
  /// horizontally. Behavior is similar for [Axis.vertical].
  ///
  /// Defaults to allowing drag on both [Axis.horizontal] and [Axis.vertical].
  ///
  /// When null, allows drag on both [Axis.horizontal] and [Axis.vertical].
  ///
  /// For the direction of gestures this widget competes with to start a drag
  /// event, see [Draggable.affinity].
  final Axis? axis;

  /// The widget below this widget in the tree.
  ///
  /// This widget displays [child] when zero drags are under way. If
  /// [childWhenDragging] is non-null, this widget instead displays
  /// [childWhenDragging] when one or more drags are underway. Otherwise, this
  /// widget always displays [child].
  ///
  /// The [feedback] widget is shown under the pointer when a drag is under way.
  ///
  /// To limit the number of simultaneous drags on multitouch devices, see
  /// [maxSimultaneousDrags].
  ///
  /// {@macro flutter.widgets.ProxyWidget.child}
  final Widget child;

  /// The widget to display instead of [child] when one or more drags are under
  /// way.
  ///
  /// If this is null, then this widget will always display [child] (and so the
  /// drag source representation will not change while a drag is under
  /// way).
  ///
  /// The [feedback] widget is shown under the pointer when a drag is under way.
  ///
  /// To limit the number of simultaneous drags on multitouch devices, see
  /// [maxSimultaneousDrags].
  final Widget? childWhenDragging;

  /// The widget to show under the pointer when a drag is under way.
  ///
  /// See [child] and [childWhenDragging] for information about what is shown
  /// at the location of the [Draggable] itself when a drag is under way.
  ///
  /// Defaults to [child].
  final Widget? feedback;

  /// The feedbackOffset can be used to set the hit test target point for the
  /// purposes of finding a drag target. It is especially useful if the feedback
  /// is transformed compared to the child.
  final Offset feedbackOffset;

  /// A strategy that is used by this draggable to get the anchor offset when it
  /// is dragged.
  ///
  /// The anchor offset refers to the distance between the users' fingers and
  /// the [feedback] widget when this draggable is dragged.
  ///
  /// This property's value is a function that implements [DragAnchorStrategy].
  /// There are two built-in functions that can be used:
  ///
  ///  * [childDragAnchorStrategy], which displays the feedback anchored at the
  ///    position of the original child.
  ///
  ///  * [pointerDragAnchorStrategy], which displays the feedback anchored at
  ///    the position of the touch that started the drag.
  ///
  /// Defaults to [childDragAnchorStrategy].
  final DragAnchorStrategy dragAnchorStrategy;

  /// Whether the semantics of the [feedback] widget is ignored when building
  /// the semantics tree.
  ///
  /// This value should be set to false when the [feedback] widget is intended
  /// to be the same object as the [child]. Placing a [GlobalKey] on this
  /// widget will ensure semantic focus is kept on the element as it moves in
  /// and out of the feedback position.
  ///
  /// Defaults to true.
  final bool ignoringFeedbackSemantics;

  /// Whether the [feedback] widget is ignored during hit testing.
  ///
  /// Regardless of whether this widget is ignored during hit testing, it will
  /// still consume space during layout and be visible during painting.
  ///
  /// Defaults to true.
  final bool ignoringFeedbackPointer;

  /// Controls how this widget competes with other gestures to initiate a drag.
  ///
  /// If affinity is null, this widget initiates a drag as soon as it recognizes
  /// a tap down gesture, regardless of any directionality. If affinity is
  /// horizontal (or vertical), then this widget will compete with other
  /// horizontal (or vertical, respectively) gestures.
  ///
  /// For example, if this widget is placed in a vertically scrolling region and
  /// has horizontal affinity, pointer motion in the vertical direction will
  /// result in a scroll and pointer motion in the horizontal direction will
  /// result in a drag. Conversely, if the widget has a null or vertical
  /// affinity, pointer motion in any direction will result in a drag rather
  /// than in a scroll because the draggable widget, being the more specific
  /// widget, will out-compete the [Scrollable] for vertical gestures.
  ///
  /// For the directions this widget can be dragged in after the drag event
  /// starts, see [Draggable.axis].
  final Axis? affinity;

  /// How many simultaneous drags to support.
  ///
  /// When null, no limit is applied. Set this to 1 if you want to only allow
  /// the drag source to have one item dragged at a time. Set this to 0 if you
  /// want to prevent the draggable from actually being dragged.
  ///
  /// If you set this property to 1, consider supplying an "empty" widget for
  /// [childWhenDragging] to create the illusion of actually moving [child].
  final int? maxSimultaneousDrags;

  /// Called when the draggable starts being dragged.
  final VoidCallback? onDragStarted;

  /// Called when the draggable is dragged.
  ///
  /// This function will only be called while this widget is still mounted to
  /// the tree (i.e. [State.mounted] is true), and if this widget has actually
  /// moved.
  final DragUpdateCallback? onDragUpdate;

  /// Called when the draggable is dropped without being accepted by a
  /// [DragTarget].
  ///
  /// This function might be called after this widget has been removed from the
  /// tree. For example, if a drag was in progress when this widget was removed
  /// from the tree and the drag ended up being canceled, this callback will
  /// still be called. For this reason, implementations of this callback might
  /// need to check [State.mounted] to check whether the state receiving the
  /// callback is still in the tree.
  final DraggableCanceledCallback? onDraggableCanceled;

  /// Called when the draggable is dropped and accepted by a [DragTarget].
  ///
  /// This function might be called after this widget has been removed from the
  /// tree. For example, if a drag was in progress when this widget was removed
  /// from the tree and the drag ended up completing, this callback will
  /// still be called. For this reason, implementations of this callback might
  /// need to check [State.mounted] to check whether the state receiving the
  /// callback is still in the tree.
  final VoidCallback? onDragCompleted;

  /// Called when the draggable is dropped.
  ///
  /// The velocity and offset at which the pointer was moving when it was
  /// dropped is available in the [DraggableDetails]. Also included in the
  /// `details` is whether the draggable's [DragTarget] accepted it.
  ///
  /// This function will only be called while this widget is still mounted to
  /// the tree (i.e. [State.mounted] is true).
  final DragEndCallback? onDragEnd;

  /// Whether the feedback widget will be put on the root [Overlay].
  ///
  /// When false, the feedback widget will be put on the closest [Overlay]. When
  /// true, the [feedback] widget will be put on the farthest (aka root)
  /// [Overlay].
  ///
  /// Defaults to false.
  final bool rootOverlay;

  /// How to behave during hit test.
  ///
  /// Defaults to [HitTestBehavior.deferToChild].
  final HitTestBehavior hitTestBehavior;

  /// {@macro flutter.gestures.multidrag._allowedButtonsFilter}
  final AllowedButtonsFilter? allowedButtonsFilter;

  /// Whether the draggable should only return when canceled.
  ///
  /// If set to true, the draggable will not play the return animation when it
  /// was successfully accepted by a [DragTarget].
  final bool onlyReturnWhenCanceled;

  /// The motion to use for the return animation.
  final Motion motion;

  /// Whether the feedback widget should be built with the same constraints as
  /// [child].
  ///
  /// This inserts a [LayoutBuilder] in the tree, which can have performance
  /// implications.
  ///
  /// Defaults to false.
  final bool feedbackMatchesConstraints;

  @override
  State<MotionDraggable> createState() => _MotionDraggableState();
}

class _MotionDraggableState<T extends Object> extends State<MotionDraggable<T>>
    with TickerProviderStateMixin {
  bool isReturning = false;

  late final MotionController<Offset> controller;

  OverlayEntry? currentEntry;

  Widget get feedbackChild => widget.feedback ?? widget.child;

  BoxConstraints? constraints;

  @override
  void initState() {
    controller = MotionController(
      motion: widget.motion,
      vsync: this,
      converter: const OffsetMotionConverter(),
      initialValue: Offset.zero,
    );
    controller.addListener(_redirectReturn);
    super.initState();
  }

  @override
  void didUpdateWidget(covariant MotionDraggable<T> oldWidget) {
    if (widget.motion != oldWidget.motion) {
      controller.motion = widget.motion;
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.feedbackMatchesConstraints) {
      return LayoutBuilder(
        builder: (context, constraints) {
          this.constraints = constraints;
          return _buildDraggable(
            context,
            feedback: ConstrainedBox(
              constraints: constraints,
              child: feedbackChild,
            ),
          );
        },
      );
    }

    return _buildDraggable(
      context,
      feedback: feedbackChild,
    );
  }

  Widget _buildDraggable(
    BuildContext context, {
    required Widget feedback,
  }) {
    final childWhenDragging = widget.childWhenDragging ??
        Visibility.maintain(
          visible: false,
          child: widget.child,
        );

    return Draggable(
      childWhenDragging: childWhenDragging,
      affinity: widget.affinity,
      axis: widget.axis,
      allowedButtonsFilter: widget.allowedButtonsFilter,
      feedbackOffset: widget.feedbackOffset,
      dragAnchorStrategy: widget.dragAnchorStrategy,
      ignoringFeedbackSemantics: widget.ignoringFeedbackSemantics,
      ignoringFeedbackPointer: widget.ignoringFeedbackPointer,
      maxSimultaneousDrags: widget.maxSimultaneousDrags,
      onDragStarted: () {
        widget.onDragStarted?.call();
        _cancelReturn();
      },
      onDragUpdate: widget.onDragUpdate,
      onDraggableCanceled: widget.onDraggableCanceled,
      onDragEnd: (details) {
        final shouldReturn =
            !details.wasAccepted || !widget.onlyReturnWhenCanceled;

        if (shouldReturn) {
          _onDragEnd(details.velocity, details.offset);
        } else {
          setState(_cancelReturn);
        }
        widget.onDragEnd?.call(details);
      },
      feedback: feedback,
      data: widget.data,
      child: Visibility.maintain(
        visible: !isReturning,
        child: widget.child,
      ),
    );
  }

  @override
  void dispose() {
    _cancelReturn();
    currentEntry?.dispose();
    controller.dispose();
    super.dispose();
  }

  void _cancelReturn() {
    if (currentEntry?.mounted ?? false) {
      currentEntry?.remove();
    }
    controller.stop(canceled: true);
    isReturning = false;
  }

  void _onDragEnd(Velocity velocity, Offset offset) {
    if (isReturning) {
      setState(_cancelReturn);
    }

    if (context.findRenderObject() case final RenderBox box) {
      setState(() {
        isReturning = true;
      });

      final overlay = Overlay.of(context);

      final targetPosition = box.localToGlobal(Offset.zero);

      currentEntry = OverlayEntry(
        builder: (context) => Stack(
          children: [
            ListenableBuilder(
              listenable: controller,
              builder: (context, child) => Positioned(
                left: controller.value.dx,
                top: controller.value.dy,
                child: IgnorePointer(
                  child: widget.feedbackMatchesConstraints
                      ? ConstrainedBox(
                          constraints: this.constraints!,
                          child: feedbackChild,
                        )
                      : feedbackChild,
                ),
              ),
            ),
          ],
        ),
      );

      overlay.insert(currentEntry!);

      final adjustedVelocity = velocity.pixelsPerSecond;

      controller
          .animateTo(
        targetPosition,
        from: offset,
        withVelocity: adjustedVelocity,
      )
          .then((value) {
        setState(_cancelReturn);
      });
    }
  }

  Offset? _targetPosition;

  void _redirectReturn() {
    if (!isReturning ||
        currentEntry?.mounted == false ||
        context.mounted == false) {
      return;
    }

    if (context.findRenderObject() case final RenderBox box) {
      final targetPosition = box.localToGlobal(Offset.zero);

      if (_targetPosition == targetPosition) {
        return;
      }

      _targetPosition = targetPosition;

      controller.animateTo(targetPosition).then((value) {
        setState(_cancelReturn);
      });
    }
  }
}
