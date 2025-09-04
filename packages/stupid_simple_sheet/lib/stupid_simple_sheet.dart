import 'package:flutter/cupertino.dart';
import 'package:motor/motor.dart';
import 'package:scroll_drag_detector/scroll_drag_detector.dart';
import 'package:stupid_simple_sheet/src/clamped_animation.dart';

export 'package:motor/src/motion.dart';
export 'src/stupid_simple_cupertino_sheet.dart';

/// A modal route that displays a sheet that slides up from the bottom.
///
/// The sheet can be dismissed by dragging down or by tapping the barrier.
/// The animation supports spring physics for natural motion using the
///
///
/// By default, when a modal route is replaced by another, the previous route
/// remains in memory. To free all the resources when this is not necessary, set
/// [maintainState] to false.
///
/// The type `T` specifies the return type of the route which can be supplied as
/// the route is popped from the stack via [Navigator.pop] when an optional
/// `result` can be provided.
///
/// See also:
///
///  * [StupidSimpleSheetTransitionMixin], for a mixin that provides sheet
/// transition
///    behavior for this modal route.
///  * [CupertinoModalPopupRoute], for a similar iOS-style modal popup.
class StupidSimpleSheetRoute<T> extends PopupRoute<T>
    with StupidSimpleSheetTransitionMixin<T> {
  /// Creates a sheet route for displaying modal content.
  ///
  /// The [motion] and [child] arguments must not be null.
  StupidSimpleSheetRoute({
    required this.child,
    super.settings,
    this.motion = const CupertinoMotion.smooth(snapToEnd: true),
    this.barrierColor = const Color.fromRGBO(0, 0, 0, 0.2),
    this.barrierDismissible = true,
    this.barrierLabel,
    this.shape = const RoundedSuperellipseBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
  }) : super();

  @override
  final Motion motion;

  /// The widget to display in the sheet.
  final Widget child;

  /// The shape that the sheet should have.
  ///
  /// The child will be clipped to fit that shape.
  /// Defaults to a rounded superellipse with 24px radius at the top.
  final ShapeBorder shape;

  @override
  final Color? barrierColor;

  @override
  final bool barrierDismissible;

  @override
  final String? barrierLabel;

  @override
  Widget buildContent(BuildContext context) => DecoratedBox(
        decoration: ShapeDecoration(shape: shape),
        child: ClipPath(
          clipper: ShapeBorderClipper(shape: shape),
          child: child,
        ),
      );
}

class _RelativeGestureDetector extends StatelessWidget {
  const _RelativeGestureDetector({
    required this.scrollableCanMoveBack,
    required this.onRelativeDragStart,
    required this.onRelativeDragUpdate,
    required this.onRelativeDragEnd,
    required this.child,
  });

  final bool scrollableCanMoveBack;
  final VoidCallback onRelativeDragStart;
  final ValueChanged<double> onRelativeDragUpdate;
  final ValueChanged<double> onRelativeDragEnd;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ScrollDragDetector(
      scrollableCanMoveBack: scrollableCanMoveBack,
      onVerticalDragStart: (details) => onRelativeDragStart(),
      onVerticalDragEnd: (details) {
        onRelativeDragEnd(details.velocity.pixelsPerSecond.dy);
      },
      onVerticalDragUpdate: (details) {
        onRelativeDragUpdate(details.primaryDelta! / context.size!.height);
      },
      child: child,
    );
  }
}

/// A mixin that provides sheet transition behavior for a [PopupRoute].
///
/// This mixin handles the slide-up animation, drag gesture detection,
/// and dismissal logic for sheet-style popups.
///
/// The sheet slides in from the bottom and can be dismissed by dragging down
/// or by tapping the barrier. The animation supports spring physics for
/// natural motion.
///
/// See also:
///
///  * [StupidSimpleSheetRoute], which is a [PopupRoute] that leverages this
/// mixin.
mixin StupidSimpleSheetTransitionMixin<T> on PopupRoute<T> {
  /// Builds the primary contents of the sheet.
  @protected
  Widget buildContent(BuildContext context);

  /// The motion configuration for the sheet animation.
  Motion get motion;

  /// How much resistance the sheet should give when the user tries to drag
  /// it past it's fully opened state.
  double get overshootResistance => 100;

  double? _dragEndVelocity;

  bool _shouldDismiss(double velocity, double currentValue) {
    // Constants for dismissal logic
    const dismissThreshold = 0.5; // Dismiss if dragged more than 50% down
    const velocityThreshold = 300.0; // Pixels per second

    // High downward velocity should dismiss regardless of position
    if (velocity > velocityThreshold) {
      return true;
    }

    // High upward velocity should not dismiss regardless of position
    if (velocity < -velocityThreshold) {
      return false;
    }

    // For low velocities, use position-based logic
    return currentValue < dismissThreshold;
  }

  @override
  Duration get transitionDuration => switch (motion) {
        CurvedMotion(:final duration) => duration,
        CupertinoMotion(:final duration) => duration,
        _ => const Duration(milliseconds: 500),
      };

  @override
  Animation<double>? get animation => super.animation?.clamped;

  @override
  Animation<double>? get secondaryAnimation =>
      super.secondaryAnimation?.clamped;

  @override
  Simulation? createSimulation({required bool forward}) {
    final v = _dragEndVelocity;
    _dragEndVelocity = null;
    return motion.createSimulation(
      end: forward ? 1.0 : 0.0,
      start: animation?.value ?? 0,
      velocity: v ?? 0,
    );
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => _RelativeGestureDetector(
        scrollableCanMoveBack: animation.value < 1,
        onRelativeDragStart: () => _handleDragStart(context),
        onRelativeDragUpdate: (delta) => _handleDragUpdate(context, delta),
        onRelativeDragEnd: (velocity) => _handleDragEnd(context, velocity),
        child: child!,
      ),
      child: buildContent(context),
    );
  }

  @override
  AnimationController createAnimationController() {
    assert(
      !debugTransitionCompleted(),
      'Cannot reuse a $runtimeType after disposing it.',
    );
    final duration = transitionDuration;
    final reverseDuration = reverseTransitionDuration;
    return AnimationController.unbounded(
      duration: duration,
      reverseDuration: reverseDuration,
      debugLabel: debugLabel,
      vsync: navigator!,
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return AnimatedBuilder(
      animation: controller!,
      builder: (context, _) {
        final value = controller!.value;

        var transformedChild = child;
        // Normal slide up transition
        transformedChild = FractionalTranslation(
          translation: Offset(0, 1 - value),
          child: transformedChild,
        );

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(child: transformedChild),
          ],
        );
      },
    );
  }

  void _handleDragStart(
    BuildContext context,
  ) {
    Navigator.of(context).didStartUserGesture();
  }

  void _handleDragUpdate(BuildContext context, double delta) {
    final currentValue = controller?.value ?? 0;
    var adjustedDelta = delta;

    if (currentValue > 1.0 && delta < 0) {
      // When dragging up past fully open, reduce the delta with diminishing
      // returns
      final overshoot = currentValue - 1.0;
      final resistance = 1.0 /
          (1.0 + overshoot * overshootResistance); // Exponential resistance
      adjustedDelta = delta * resistance;
    }

    final newValue = currentValue - adjustedDelta;
    controller?.value = newValue;
  }

  void _handleDragEnd(
    BuildContext context,
    double velocity,
  ) {
    final currentValue = controller!.value;

    _dragEndVelocity = -velocity / context.size!.height;

    // If dragged past fully open, always snap back to 1.0
    if (currentValue > 1.0) {
      final backSim = motion.createSimulation(
        start: currentValue,
        velocity: _dragEndVelocity!,
      );
      controller!.animateWith(backSim);
      _dragEndVelocity = null;
    } else {
      // Determine if we should dismiss based on velocity and position
      final shouldDismiss = _shouldDismiss(velocity, currentValue);

      if (shouldDismiss) {
        Navigator.of(context).pop();
      } else {
        final backSim = motion.createSimulation(
          start: currentValue,
          velocity: _dragEndVelocity!,
        );
        controller!.animateWith(backSim);
        _dragEndVelocity = null;
      }
    }
    Navigator.of(context).didStopUserGesture();
  }
}
