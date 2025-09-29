import 'package:flutter/cupertino.dart';
import 'package:motor/motor.dart';
import 'package:scroll_drag_detector/scroll_drag_detector.dart';
import 'package:stupid_simple_sheet/src/clamped_animation.dart';
import 'package:stupid_simple_sheet/src/snapping_point.dart';

export 'package:motor/src/motion.dart';

export 'src/snapping_point.dart';
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
    with StupidSimpleSheetTransitionMixin<T>, StupidSimpleSheetController<T> {
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
    this.clipBehavior = Clip.antiAlias,
    this.clearBarrierImmediately = true,
    this.onlyDragWhenScrollWasAtTop = true,
    this.callNavigatorUserGestureMethods = false,
    this.snappingConfig = const SheetSnappingConfig.relative([1.0]),
  });

  @override
  final Motion motion;

  /// The widget to display in the sheet.
  final Widget child;

  /// The shape that the sheet should have.
  ///
  /// The child will be clipped to fit that shape, if [clipBehavior] is not
  /// [Clip.none].
  /// Defaults to a rounded superellipse with 24px radius at the top.
  final ShapeBorder shape;

  /// The [Clip] behavior to use for the sheet's content.
  ///
  /// Defaults to [Clip.antiAlias].
  /// If you set this to [Clip.none], the sheet's content will not be clipped.
  final Clip clipBehavior;

  @override
  final Color? barrierColor;

  @override
  final bool barrierDismissible;

  @override
  final String? barrierLabel;

  @override
  final bool clearBarrierImmediately;

  @override
  final bool onlyDragWhenScrollWasAtTop;

  @override
  final bool callNavigatorUserGestureMethods;

  /// The snapping configuration for the sheet.
  @override
  final SheetSnappingConfig snappingConfig;

  @override
  Widget buildContent(BuildContext context) => DecoratedBox(
        decoration: ShapeDecoration(shape: shape),
        child: ClipPath(
          clipBehavior: clipBehavior,
          clipper: ShapeBorderClipper(shape: shape),
          child: child,
        ),
      );
}

class _RelativeGestureDetector extends StatelessWidget {
  const _RelativeGestureDetector({
    required this.scrollableCanMoveBack,
    required this.onlyDragWhenScrollWasAtTop,
    required this.onRelativeDragStart,
    required this.onRelativeDragUpdate,
    required this.onRelativeDragEnd,
    required this.child,
  });

  final bool scrollableCanMoveBack;
  final bool onlyDragWhenScrollWasAtTop;
  final VoidCallback onRelativeDragStart;
  final ValueChanged<double> onRelativeDragUpdate;
  final ValueChanged<double> onRelativeDragEnd;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ScrollDragDetector(
      onlyDragWhenScrollWasAtTop: onlyDragWhenScrollWasAtTop,
      scrollableCanMoveBack: scrollableCanMoveBack,
      onVerticalDragStart: (details) => onRelativeDragStart(),
      onVerticalDragEnd: (details) {
        onRelativeDragEnd(
          details.velocity.pixelsPerSecond.dy / context.size!.height,
        );
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

  /// {@template clearBarrierImmediately}
  /// Whether this route should clear the modal barrier immediately when
  /// dismissed.
  ///
  /// This can make your app feel more responsive by letting the user interact
  /// with the underlying content, while this sheet is still animating out.
  ///
  /// Defaults to true.
  /// {@endtemplate}
  bool get clearBarrierImmediately => true;

  /// {@template onlyDragWhenScrollWasAtTop}
  /// Whether the sheet should only start being draggable when its scrollable
  /// content was at the top whenever the user initiates a drag.
  ///
  /// If this is true, and the user starts scrolling up from somewhere other
  /// than the top, the scroll view will perform a normal overscroll.
  ///
  /// This matches iOS sheet behavior and defaults to true.
  /// {@endtemplate}
  bool get onlyDragWhenScrollWasAtTop => true;

  /// Whether the navigator's user gesture methods should be called when
  /// dragging starts and ends.
  ///
  /// Defaults to false.
  bool get callNavigatorUserGestureMethods => false;

  /// The snapping configuration for the sheet.
  ///
  /// Defaults to only containing a relative point at 1.0 (fully open).
  ///
  /// A fully closed point of 0.0 is always added implicitly.
  SheetSnappingConfig get snappingConfig =>
      const SheetSnappingConfig.relative([1.0]);

  double? _dragEndVelocity;

  double? _animationTargetValue;

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

    // Get the appropriate end value
    double endValue;
    if (forward) {
      // Opening: use initial snap point or default
      if (navigator?.context != null) {
        final sheetHeight = MediaQuery.sizeOf(navigator!.context).height;
        endValue = snappingConfig.resolve(sheetHeight).initialSnap;
      } else {
        // Fallback if context is not available
        endValue = 1.0;
      }
    } else {
      // Closing
      endValue = 0.0;
    }
    _animationTargetValue = endValue;
    return motion.createSimulation(
      end: endValue,
      start: animation?.value ?? 0,
      velocity: -(v ?? 0),
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
        onlyDragWhenScrollWasAtTop: onlyDragWhenScrollWasAtTop,
        scrollableCanMoveBack: (_animationTargetValue ?? animation.value) <
            snappingConfig.resolveWith(context).maxExtent,
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

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(
              child: FractionalTranslation(
                translation: Offset(0, 1 - value),
                child: child,
              ),
            ),
          ],
        );
      },
    );
  }

  final _poppedNotifier = ValueNotifier(false);

  @override
  Widget buildModalBarrier() {
    return ValueListenableBuilder(
      valueListenable: _poppedNotifier,
      builder: (context, value, child) {
        return IgnorePointer(
          ignoring: value && clearBarrierImmediately,
          child: super.buildModalBarrier(),
        );
      },
    );
  }

  @override
  @mustCallSuper
  bool didPop(T? result) {
    _poppedNotifier.value = true;
    return super.didPop(result);
  }

  void _handleDragStart(
    BuildContext context,
  ) {
    if (callNavigatorUserGestureMethods) {
      Navigator.of(context).didStartUserGesture();
    }
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
    _animationTargetValue = newValue;
  }

  void _handleDragEnd(
    BuildContext context,
    double velocity,
  ) {
    final currentValue = controller!.value;
    if (callNavigatorUserGestureMethods) {
      Navigator.of(context).didStopUserGesture();
    }

    _dragEndVelocity = velocity;

    // Get the sheet height for pixel-based calculations
    final sheetHeight = MediaQuery.sizeOf(context).height;

    // If dragged past fully open, always snap back to 1.0
    if (currentValue > 1.0) {
      // Scale the velocity by the same resistance factor that was applied
      //during dragging
      final overshoot = currentValue - 1.0;
      final resistance = 1.0 / (1.0 + overshoot * overshootResistance);
      final adjustedVelocity = velocity * resistance;

      final backSim = motion.createSimulation(
        start: currentValue,
        velocity: -adjustedVelocity,
      );
      controller!.animateWith(backSim);
      _dragEndVelocity = null;
    } else {
      // Find the target snap point based on position and velocity
      final targetValue =
          snappingConfig.resolve(sheetHeight).findTargetSnapPoint(
                currentValue,
                velocity,
              );

      // If target is 0 (closed), dismiss the sheet
      if (targetValue <= 0.001) {
        Navigator.of(context).pop();
      } else {
        // Animate to the target snap point
        final snapSim = motion.createSimulation(
          start: currentValue,
          end: targetValue,
          velocity: -_dragEndVelocity!,
        );
        controller!.animateWith(snapSim);
        _dragEndVelocity = null;
      }
    }
  }

  @override
  @mustCallSuper
  void dispose() {
    _poppedNotifier.dispose();
    super.dispose();
  }
}

/// A mixin that provides imperative control over a sheet's animation.
///
/// Mix this into your [PopupRoute] that also uses
/// [StupidSimpleSheetTransitionMixin] to allow children of the sheet to
/// imperatively control the sheet's position.
mixin StupidSimpleSheetController<T> on StupidSimpleSheetTransitionMixin<T> {
  /// Retrieves the current [StupidSimpleSheetController] from the given
  /// [BuildContext].
  ///
  /// This will only work if called from a context that is inside the
  /// [StupidSimpleSheetRoute].
  static StupidSimpleSheetController<T>? maybeOf<T>(BuildContext context) {
    final route = ModalRoute.of(context);
    if (route case final StupidSimpleSheetController<T> route) {
      return route;
    }

    return null;
  }

  /// Can be used to imperatively animate the sheet to a relative position, but
  /// can't close it.
  ///
  /// The [relativePosition] must be larger than 0.0 (fully closed) and
  /// lower than or equal to 1.0 (fully open).
  ///
  /// If [snap] is true, the sheet will snap to the nearest snapping point
  /// after reaching the target position.
  ///
  /// If you want to close the sheet, use [Navigator.pop] instead.
  TickerFuture animateToRelative(double relativePosition, {bool snap = false}) {
    assert(
      relativePosition > 0.0 && relativePosition <= 1.0,
      'Relative position must be larger than 0.0 and less than or equal to 1.0',
    );

    assert(
      controller != null,
      'Controller is null. Make sure the route is pushed before calling.',
    );

    final double target;

    if (snap) {
      final config = snappingConfig.resolveWith(navigator!.context);
      // Find the closest snapping point that isn't 0.0
      target = switch (config.findTargetSnapPoint(relativePosition, 0)) {
        0.0 => config.points.first,
        final v => v,
      };
    } else {
      target = relativePosition;
    }

    final simulation = motion.createSimulation(
      start: controller!.value,
      end: target,
      velocity: controller!.velocity,
    );

    return controller!.animateWith(simulation);
  }
}
