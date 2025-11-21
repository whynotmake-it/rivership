import 'package:flutter/material.dart';
import 'package:heroine/heroine.dart';
import 'package:motor/motor.dart';
import 'package:scroll_drag_detector/scroll_drag_detector.dart';

/// Allows a scrollable [Heroine] (or any other widget) to be dragged to dismiss it.
///
/// This widget combines [ScrollDragDetector] with drag-to-dismiss functionality,
/// allowing scrollable content to transition smoothly between scrolling and dismissing.
/// When a child scroll view is at the top edge and the user drags down further,
/// the gesture transitions to a dismiss drag.
///
/// This is similar to how scrollable bottom sheets work - you can scroll within
/// the content, but when you reach the top and drag down, it starts dismissing.
///
/// If this is wrapped around a [Heroine], this will automatically take care
/// of updating a [HeroineVelocity], so that when the transition starts, the
/// current velocity of the gesture will be taken as the initial velocity of the
/// [Heroine]'s spring simulation.
class ScrollDragDismissable extends StatefulWidget {
  /// Creates a new [ScrollDragDismissable] widget that will pop the current route
  /// when dismissed and respects the current route's `popDisposition` property.
  const ScrollDragDismissable({
    required this.child,
    super.key,
    this.threshold = DragDismissable.defaultDismissThreshold,
    this.velocityThreshold = DragDismissable.defaultVelocityThreshold,
    this.motion = const CupertinoMotion.interactive(),
    this.scrollableCanMoveBack = true,
    this.onlyDragWhenScrollWasAtTop = true,
  })  : _popAsDismiss = true,
        onDismiss = null;

  /// Creates a new [ScrollDragDismissable] with a custom [onDismiss] callback.
  ///
  /// This will not respect the current route's `popDisposition` property, even
  /// if you pop the route in the [onDismiss] callback.
  const ScrollDragDismissable.custom({
    required this.child,
    required this.onDismiss,
    super.key,
    this.threshold = DragDismissable.defaultDismissThreshold,
    this.velocityThreshold = DragDismissable.defaultVelocityThreshold,
    this.motion = const CupertinoMotion.interactive(),
    this.scrollableCanMoveBack = true,
    this.onlyDragWhenScrollWasAtTop = true,
  }) : _popAsDismiss = false;

  /// The callback that will be called when the widget is dismissed.
  ///
  /// If this is set to null, the drag interaction will be disabled.
  final VoidCallback? onDismiss;

  /// The distance that needs to be dragged until the widget will be dismissed.
  ///
  /// If the user lets go before this distance is reached, the widget will
  /// cancel the dismiss.
  final double threshold;

  /// The velocity threshold for dismissing the widget.
  ///
  /// If the velocity of the gesture is greater than this threshold, the widget
  /// will be dismissed.
  final double velocityThreshold;

  /// The spring to use for when the dismissable is not dismissed and returns
  /// to its original position.
  ///
  /// Defaults to [CupertinoMotion.interactive].
  final Motion motion;

  /// Whether the scrollable can still move backwards (towards the direction
  /// of its leading edge).
  ///
  /// Set this to false when your scrollable cannot move backwards (e.g. a
  /// sheet is fully expanded) to allow this child's scrollable to transition
  /// back to scrolling instead of dragging.
  final bool scrollableCanMoveBack;

  /// If true, scrolls will only transition to drags when the initial drag
  /// started at the top of the scrollable.
  ///
  /// This matches iOS sheet default behavior and defaults to true.
  final bool onlyDragWhenScrollWasAtTop;

  /// The child of the widget.
  final Widget child;

  final bool _popAsDismiss;

  bool get _disabled => _popAsDismiss == false && onDismiss == null;

  @override
  State<ScrollDragDismissable> createState() => _ScrollDragDismissableState();
}

class _ScrollDragDismissableState extends State<ScrollDragDismissable> {
  Offset? _dragStartOffset;
  Offset _offset = Offset.zero;
  Velocity _velocity = Velocity.zero;

  VoidCallback? get onDismiss =>
      widget.onDismiss ??
      (widget._popAsDismiss ? () => Navigator.maybePop(context) : null);

  double get progress => (_offset.dy.abs() / widget.threshold).clamp(0, 1);

  @override
  void didUpdateWidget(covariant ScrollDragDismissable oldWidget) {
    if (widget._disabled && !oldWidget._disabled) {
      _cancel();
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return ScrollDragDetector(
      scrollableCanMoveBack: widget.scrollableCanMoveBack,
      onlyDragWhenScrollWasAtTop: widget.onlyDragWhenScrollWasAtTop,
      onVerticalDragStart: widget._disabled ? null : _start,
      onVerticalDragUpdate: widget._disabled ? null : _update,
      onVerticalDragCancel: widget._disabled ? null : _cancel,
      onVerticalDragEnd: widget._disabled ? null : _end,
      child: MotionBuilder(
        active: _dragStartOffset == null,
        motion: widget.motion,
        converter: const OffsetMotionConverter(),
        value: _offset,
        builder: (context, value, child) {
          return Transform.translate(
            offset: value,
            child: child,
          );
        },
        child: HeroineVelocity(
          velocity: _velocity,
          child: widget.child,
        ),
      ),
    );
  }

  void _start(DragStartDetails details) {
    Navigator.of(context).didStartUserGesture();
    HeroinePageRoute.maybeOf<dynamic>(context)?.updateDismiss(0, Offset.zero);
    setState(() {
      _dragStartOffset = details.globalPosition;
    });
  }

  void _update(DragUpdateDetails details) {
    if (_dragStartOffset case final startOffset?) {
      _offset = Offset(0, details.globalPosition.dy - startOffset.dy);
      HeroinePageRoute.maybeOf<dynamic>(context)?.updateDismiss(
        progress,
        _offset,
      );

      setState(() {});
    }
  }

  void _cancel() {
    HeroinePageRoute.maybeOf<dynamic>(context)?.cancelDismiss();
    _stopUserGesturePostFrame();
    setState(() {
      _dragStartOffset = null;
      _offset = Offset.zero;
    });
  }

  void _end(DragEndDetails details) {
    if (ModalRoute.of(context)?.popDisposition ==
            RoutePopDisposition.doNotPop &&
        widget._popAsDismiss) {
      _cancel();

      return;
    }

    final dismissVelocity = details.velocity.pixelsPerSecond.dy.abs();
    if (progress >= 1 || dismissVelocity > widget.velocityThreshold) {
      setState(() {
        _velocity = details.velocity;
        _dragStartOffset = null;
        onDismiss?.call();
      });
      _stopUserGesturePostFrame();
    } else {
      _cancel();
    }
  }

  void _stopUserGesturePostFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Navigator.of(context).userGestureInProgress) {
        Navigator.of(context).didStopUserGesture();
      }
    });
  }
}