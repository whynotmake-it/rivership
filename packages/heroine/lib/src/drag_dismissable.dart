import 'package:flutter/material.dart';
import 'package:heroine/heroine.dart';
import 'package:heroine/src/heroine_velocity.dart';
import 'package:springster/springster.dart';

/// Allows a [Heroine] (or any other widget for that matter) to be dragged to
/// dismiss it.
///
/// If this is wrapped around a [Heroine], this will automatically take care
/// of updating a [HeroineVelocity], so that when the transition starts, the
/// current velocity of the gesture will be taken as the initial velocity of the
/// [Heroine]'s spring simulation.
class DragDismissable extends StatefulWidget {
  /// Creates a new [DragDismissable] widget that will pop the current route
  /// when dismissed and respects the current route's `popDisposition` property.
  const DragDismissable({
    required this.child,
    super.key,
    this.threshold = defaultDismissThreshold,
    this.velocityThreshold = defaultVelocityThreshold,
    this.axisAffinity,
    this.constrainToAxis = true,
    this.spring = Spring.interactive,
  })  : _popAsDismiss = true,
        onDismiss = null;

  /// Creates a new [DragDismissable] with a custom [onDismiss] callback.
  ///
  /// This will not respect the current route's `popDisposition` property, even
  /// if you pop the route in the [onDismiss] callback.
  const DragDismissable.custom({
    required this.child,
    required this.onDismiss,
    super.key,
    this.threshold = defaultDismissThreshold,
    this.velocityThreshold = defaultVelocityThreshold,
    this.axisAffinity,
    this.constrainToAxis = true,
    this.spring = Spring.interactive,
  }) : _popAsDismiss = false;

  /// The default for [threshold].
  static const defaultDismissThreshold = 140.0;

  /// The default for [velocityThreshold].
  static const defaultVelocityThreshold = 1000.0;

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

  /// The axis that the drag gesture will be detected on.
  ///
  /// This can be used to prevent this widget from interfering with the
  /// gesture detection of other widgets, such as scrollable widgets.
  ///
  /// If this is set to null, the drag gesture will be detected on both axes.
  final Axis? axisAffinity;

  /// Whether the drag gesture should be constrained to [axisAffinity].
  ///
  /// If this is true, [child] will only visibly be dragged along the axis.
  /// If this is false, the gesture detection will still prefer the axis
  /// specified in [axisAffinity], but the widget will still visually follow
  /// the gesture on the other axis.
  ///
  /// This has no effect if [axisAffinity] is null.
  final bool constrainToAxis;

  /// The spring to use for when the dismissable is not dismissed and returns
  /// to its original position.
  ///
  /// Defaults to [Spring.interactive].
  final Spring spring;

  /// The child of the widget.
  final Widget child;

  final bool _popAsDismiss;

  bool get _disabled => _popAsDismiss == false && onDismiss == null;

  @override
  State<DragDismissable> createState() => _DragDismissableState();
}

class _DragDismissableState extends State<DragDismissable> {
  Offset? _dragStartOffset;
  Offset _offset = Offset.zero;
  Velocity _velocity = Velocity.zero;

  /// Whether we are waiting to stop the user gesture once the simulation
  /// completes.
  bool _waitingToStopUserGesture = false;

  VoidCallback? get onDismiss =>
      widget.onDismiss ??
      (widget._popAsDismiss ? () => Navigator.maybePop(context) : null);

  double get progress =>
      switch ((widget.axisAffinity, widget.constrainToAxis)) {
        (null, _) || (_, false) => _offset.distance / widget.threshold,
        (Axis.horizontal, true) => _offset.dx.abs() / widget.threshold,
        (Axis.vertical, true) => _offset.dy.abs() / widget.threshold,
      }
          .clamp(0, 1);

  double dismissVelocity(Velocity velocity) =>
      switch ((widget.axisAffinity, widget.constrainToAxis)) {
        (null, _) || (_, false) => velocity.pixelsPerSecond.distance,
        (Axis.horizontal, true) => velocity.pixelsPerSecond.dx.abs(),
        (Axis.vertical, true) => velocity.pixelsPerSecond.dy.abs(),
      };

  @override
  void didUpdateWidget(covariant DragDismissable oldWidget) {
    if (widget._disabled && !oldWidget._disabled) {
      _cancel();
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart:
          widget.axisAffinity == null && !widget._disabled ? _start : null,
      onPanUpdate:
          widget.axisAffinity == null && !widget._disabled ? _update : null,
      onPanCancel:
          widget.axisAffinity == null && !widget._disabled ? _cancel : null,
      onPanEnd: widget.axisAffinity == null && !widget._disabled ? _end : null,
      onVerticalDragStart:
          widget.axisAffinity == Axis.vertical && !widget._disabled
              ? _start
              : null,
      onVerticalDragUpdate:
          widget.axisAffinity == Axis.vertical && !widget._disabled
              ? _update
              : null,
      onVerticalDragCancel:
          widget.axisAffinity == Axis.vertical && !widget._disabled
              ? _cancel
              : null,
      onVerticalDragEnd:
          widget.axisAffinity == Axis.vertical && !widget._disabled
              ? _end
              : null,
      onHorizontalDragStart:
          widget.axisAffinity == Axis.horizontal && !widget._disabled
              ? _start
              : null,
      onHorizontalDragUpdate:
          widget.axisAffinity == Axis.horizontal && !widget._disabled
              ? _update
              : null,
      onHorizontalDragCancel:
          widget.axisAffinity == Axis.horizontal && !widget._disabled
              ? _cancel
              : null,
      onHorizontalDragEnd:
          widget.axisAffinity == Axis.horizontal && !widget._disabled
              ? _end
              : null,
      child: MotionBuilder(
        active: _dragStartOffset == null,
        motion: SpringMotion(widget.spring),
        converter: const OffsetMotionConverter(),
        value: _offset,
        onAnimationStatusChanged: (value) {
          if (!value.isAnimating && _waitingToStopUserGesture) {
            _stopUserGesturePostFrame();
          }
        },
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
      switch ((widget.axisAffinity, widget.constrainToAxis)) {
        case (null, _) || (_, false):
          _offset = details.globalPosition - startOffset;
        case (Axis.horizontal, true):
          _offset = Offset(details.globalPosition.dx - startOffset.dx, 0);
        case (Axis.vertical, true):
          _offset = Offset(0, details.globalPosition.dy - startOffset.dy);
      }
      HeroinePageRoute.maybeOf<dynamic>(context)?.updateDismiss(
        progress,
        _offset,
      );

      setState(() {});
    }
  }

  void _cancel() {
    HeroinePageRoute.maybeOf<dynamic>(context)?.cancelDismiss();
    _waitingToStopUserGesture = true;

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

    final dismissVelocity = this.dismissVelocity(details.velocity);
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
      _waitingToStopUserGesture = false;
    });
  }
}
