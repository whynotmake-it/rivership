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
    this.clipBehavior = Clip.antiAlias,
    this.clearBarrierImmediately = true,
    this.onlyDragWhenScrollWasAtTop = true,
    this.snappingPoints = const [
      SnappingPoint.relative(0),
      SnappingPoint.relative(1),
    ],
    this.initialSnap,
  }) : super();

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
  final List<SnappingPoint> snappingPoints;

  /// The initial snap point when the sheet opens.
  ///
  /// If null, defaults to the lowest non-zero snap point.
  @override
  final SnappingPoint? initialSnap;

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

  /// The snapping points for the sheet.
  ///
  /// Defaults to [SnappingPoint.relative(0.0)] (closed) and
  /// [SnappingPoint.relative(1.0)] (fully open).
  List<SnappingPoint> get snappingPoints => const [
        SnappingPoint.relative(0),
        SnappingPoint.relative(1),
      ];

  /// The initial snap point when the sheet opens.
  ///
  /// If null, defaults to the lowest non-zero snap point.
  /// If all snap points are zero or there are no snap points,
  /// defaults to 1.0 (fully open).
  SnappingPoint? get initialSnap => null;

  double? _dragEndVelocity;

  /// Gets the effective initial snap point, with fallback logic.
  double _getInitialSnapValue(double sheetHeight) {
    if (initialSnap != null) {
      return initialSnap!.toRelative(sheetHeight);
    }

    // Find the lowest non-zero snap point
    final relativeSnapPoints = snappingPoints
        .map((point) => point.toRelative(sheetHeight))
        .where((value) => value > 0.001) // Exclude values effectively zero
        .toList()
      ..sort();

    if (relativeSnapPoints.isNotEmpty) {
      return relativeSnapPoints.first;
    }

    // Fallback to fully open if no valid points found
    return 1;
  }

  /// Finds the closest snapping point based on current position and velocity.
  SnappingPoint _findTargetSnapPoint(
    double currentValue,
    double velocity,
    double sheetHeight,
  ) {
    // Convert all snap points to relative values for comparison
    final relativeSnapPoints = snappingPoints
        .map((point) => point.toRelative(sheetHeight))
        .toList()
      ..sort();

    // Remove duplicates and ensure they're within bounds
    final validSnapPoints = relativeSnapPoints
        .toSet()
        .where((point) => point >= 0.0 && point <= 1.0)
        .toList()
      ..sort();

    if (validSnapPoints.isEmpty) {
      // Fallback to default points if none are valid
      return const SnappingPoint.relative(1);
    }

    // For high velocity, predict where the sheet would naturally settle
    const velocityThreshold = 0.5;

    if (velocity.abs() > velocityThreshold) {
      // High velocity - predict the natural settling position
      final projectedPosition = currentValue - (velocity * 0.3);

      // Find the closest snap point to the projected position
      var minDistance = double.infinity;
      var targetSnapValue = validSnapPoints.first;

      for (final snapValue in validSnapPoints) {
        final distance = (projectedPosition - snapValue).abs();
        if (distance < minDistance) {
          minDistance = distance;
          targetSnapValue = snapValue;
        }
      }

      // Return the original snap point that matches this relative value
      return snappingPoints.firstWhere(
        (point) =>
            (point.toRelative(sheetHeight) - targetSnapValue).abs() < 0.001,
        orElse: () => SnappingPoint.relative(targetSnapValue),
      );
    } else {
      // Low velocity - snap to the closest point based on current position
      var minDistance = double.infinity;
      var targetSnapValue = validSnapPoints.first;

      for (final snapValue in validSnapPoints) {
        final distance = (currentValue - snapValue).abs();
        if (distance < minDistance) {
          minDistance = distance;
          targetSnapValue = snapValue;
        }
      }

      // Return the original snap point that matches this relative value
      return snappingPoints.firstWhere(
        (point) =>
            (point.toRelative(sheetHeight) - targetSnapValue).abs() < 0.001,
        orElse: () => SnappingPoint.relative(targetSnapValue),
      );
    }
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

    // Get the appropriate end value
    double endValue;
    if (forward) {
      // Opening: use initial snap point or default
      if (navigator?.context != null) {
        final sheetHeight = MediaQuery.sizeOf(navigator!.context).height;
        endValue = _getInitialSnapValue(sheetHeight);
      } else {
        // Fallback if context is not available
        endValue = 1.0;
      }
    } else {
      // Closing
      endValue = 0.0;
    }

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
        scrollableCanMoveBack: animation.value <
            snappingPoints.last.toRelative(
              MediaQuery.sizeOf(context).height,
            ),
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
    Navigator.of(context).didStopUserGesture();

    _dragEndVelocity = velocity;

    // Get the sheet height for pixel-based calculations
    final sheetHeight = MediaQuery.sizeOf(context).height;

    // If dragged past fully open, always snap back to 1.0
    if (currentValue > 1.0) {
      final backSim = motion.createSimulation(
        start: currentValue,
        velocity: -_dragEndVelocity!,
      );
      controller!.animateWith(backSim);
      _dragEndVelocity = null;
    } else {
      // Find the target snap point based on position and velocity
      final targetSnapPoint = _findTargetSnapPoint(
        currentValue,
        velocity,
        sheetHeight,
      );
      final targetValue = targetSnapPoint.toRelative(sheetHeight);

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
