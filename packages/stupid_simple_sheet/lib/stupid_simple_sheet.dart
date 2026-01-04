import 'package:flutter/cupertino.dart';
import 'package:motor/motor.dart';
import 'package:scroll_drag_detector/scroll_drag_detector.dart';
import 'package:stupid_simple_sheet/src/clamped_animation.dart';
import 'package:stupid_simple_sheet/src/route_snapshot_mode.dart';
import 'package:stupid_simple_sheet/src/snapping_point.dart';

export 'package:motor/src/motion.dart';

export 'src/route_snapshot_mode.dart';
export 'src/sheet_background.dart';
export 'src/snapping_point.dart';
export 'src/stupid_simple_cupertino_sheet.dart';
export 'src/stupid_simple_glass_sheet.dart';

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
    this.motion = const CupertinoMotion.smooth(),
    this.barrierColor = const Color.fromRGBO(0, 0, 0, 0.2),
    this.barrierDismissible = true,
    this.barrierLabel,
    this.clearBarrierImmediately = true,
    this.onlyDragWhenScrollWasAtTop = true,
    this.callNavigatorUserGestureMethods = false,
    this.snappingConfig = SheetSnappingConfig.full,
    this.draggable = true,
    this.originateAboveBottomViewInset = false,
    this.backgroundSnapshotMode = RouteSnapshotMode.never,
  });

  @override
  final Motion motion;

  /// The widget to display in the sheet.
  final Widget child;

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

  /// The base snapping configuration for the sheet.
  @override
  final SheetSnappingConfig snappingConfig;

  @override
  final bool draggable;

  @override
  final bool originateAboveBottomViewInset;

  @override
  final RouteSnapshotMode backgroundSnapshotMode;

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      backgroundSnapshotMode == RouteSnapshotMode.never
          ? null
          : (context, animation, secondaryAnimation, canSnapshot, child) {
              return SnapshotWidget(
                controller: backgroundSnapshotController,
                mode: SnapshotMode.permissive,
                autoresize: true,
                child: child,
              );
            };

  @override
  Widget buildContent(BuildContext context) {
    return child;
  }
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
  // ignore: avoid_positional_boolean_parameters
  final void Function(double, bool) onRelativeDragUpdate;
  // ignore: avoid_positional_boolean_parameters
  final void Function(double, bool) onRelativeDragEnd;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ScrollDragDetector(
      onlyDragWhenScrollWasAtTop: onlyDragWhenScrollWasAtTop,
      scrollableCanMoveBack: scrollableCanMoveBack,
      onVerticalDragStart: (details, _) => onRelativeDragStart(),
      onVerticalDragEnd: (details, willScroll) {
        onRelativeDragEnd(
          details.velocity.pixelsPerSecond.dy / context.size!.height,
          willScroll,
        );
      },
      onVerticalDragUpdate: (details, wouldScroll) {
        onRelativeDragUpdate(
          details.primaryDelta! / context.size!.height,
          wouldScroll,
        );
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

  /// Whether the sheet can be dragged.
  ///
  /// When false, the sheet cannot be moved by dragging and applies
  /// resistance in both directions, similar to the resistance applied when
  /// dragging past 1.0.
  ///
  /// Defaults to true.
  bool get draggable => true;

  /// Whether the navigator's user gesture methods should be called when
  /// dragging starts and ends.
  ///
  /// Defaults to false.
  bool get callNavigatorUserGestureMethods => false;

  /// Whether the sheet's origin should be moved up by the bottom view inset of
  /// the current [MediaQuery].
  ///
  /// If this is true, and the keyboard is opened, the sheet will originate from
  /// above the keyboard.
  bool get originateAboveBottomViewInset => false;

  /// Controls when the route behind this sheet is rasterized to a GPU texture.
  ///
  /// When enabled, the previous route's widget tree is replaced with a frozen
  /// image during the configured phases, eliminating rebuild/paint costs.
  ///
  /// Defaults to [RouteSnapshotMode.never].
  ///
  /// To use this, subclasses must also provide a [delegatedTransition] that
  /// wraps the previous route's child in a [SnapshotWidget] using
  /// [backgroundSnapshotController]. See [StupidSimpleSheetRoute] for an
  /// example.
  RouteSnapshotMode get backgroundSnapshotMode => RouteSnapshotMode.never;

  /// The [SnapshotController] that toggles snapshotting of the background
  /// route.
  ///
  /// Subclasses should pass this to a [SnapshotWidget] wrapping the previous
  /// route's child inside their [delegatedTransition].
  @protected
  SnapshotController get backgroundSnapshotController =>
      _backgroundSnapshotController;

  late final SnapshotController _backgroundSnapshotController =
      SnapshotController();

  /// The [SnapshotController] from the sheet route stacked on top of this one.
  ///
  /// Set automatically when another [StupidSimpleSheetTransitionMixin] route
  /// pushes on top. Used by [maybeSnapshotChild] to wrap this route's content.
  SnapshotController? _coveredBySnapshotController;

  bool _isUserDragging = false;

  @override
  bool get allowSnapshotting =>
      backgroundSnapshotMode != RouteSnapshotMode.never;

  SheetSnappingConfig? _snappingConfigOverride;

  /// The base snapping configuration for the sheet, as provided by the
  /// implementing class.
  ///
  /// This is used as the fallback when no override is set via
  /// [StupidSimpleSheetController.overrideSnappingConfig].
  ///
  /// Defaults to only containing a relative point at 1.0 (fully open).
  ///
  /// A fully closed point of 0.0 is always added implicitly.
  @protected
  SheetSnappingConfig get snappingConfig;

  /// The currently active snapping configuration for the sheet.
  ///
  /// This will return the override if one has been set via
  /// [StupidSimpleSheetController.overrideSnappingConfig], otherwise it returns
  /// [snappingConfig].
  SheetSnappingConfig get effectiveSnappingConfig =>
      _snappingConfigOverride ?? snappingConfig;

  double? _dragEndVelocity;

  double? _animationTargetValue;

  /// Where the sheet should stick if [draggable] is false, or when
  /// overshooting.
  double? _stickingPoint;

  /// Updates [_backgroundSnapshotController] based on the current
  /// [backgroundSnapshotMode], animation state, and drag state.
  void _updateSnapshotState() {
    final mode = backgroundSnapshotMode;

    if (mode == RouteSnapshotMode.never) {
      _backgroundSnapshotController.allowSnapshotting = false;
      return;
    }
    if (mode == RouteSnapshotMode.always) {
      _backgroundSnapshotController.allowSnapshotting = true;
      return;
    }

    final isAnimating = controller?.isAnimating ?? false;
    final value = controller?.value ?? 0.0;
    final isVisible = value > 0.001;
    final isSettled = !isAnimating && !_isUserDragging && isVisible;
    final maxExtent = effectiveSnappingConfig.maxExtent;
    final isFullyOpen = (value - maxExtent).abs() < 0.001;

    final isTargetingMax = _animationTargetValue != null &&
        (_animationTargetValue! - maxExtent).abs() < 0.001;

    final isMovingForward = isTargetingMax &&
        ((controller?.status.isAnimating ?? false) ||
            (_animationTargetValue! > value));

    _backgroundSnapshotController.allowSnapshotting = switch (mode) {
      RouteSnapshotMode.animating => isAnimating || _isUserDragging,
      RouteSnapshotMode.settled => isSettled,
      RouteSnapshotMode.openAndForward => (isSettled && isFullyOpen) ||
          (isAnimating && isMovingForward && !_isUserDragging),
      _ => false, // never/always handled above
    };
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
      endValue = effectiveSnappingConfig.initialSnap;
    } else {
      // Closing
      endValue = 0.0;
    }
    _animationTargetValue = endValue;
    _stickingPoint = endValue;
    _updateSnapshotState();
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
      builder: (context, child) => MediaQuery.removeViewInsets(
        context: context,
        removeBottom: originateAboveBottomViewInset,
        // ^ The sheet is already moved up by the bottom view inset, so we make
        // sure the content inside the sheet doesn't add extra padding
        child: _RelativeGestureDetector(
          onlyDragWhenScrollWasAtTop: onlyDragWhenScrollWasAtTop,
          scrollableCanMoveBack: (_animationTargetValue ?? animation.value) <
              effectiveSnappingConfig.maxExtent,
          onRelativeDragStart: () => _handleDragStart(context),
          onRelativeDragUpdate: (delta, wouldScroll) =>
              _handleDragUpdate(context, delta, wouldScroll),
          onRelativeDragEnd: (velocity, willScroll) =>
              _handleDragEnd(context, velocity, willScroll),
          child: child!,
        ),
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
    final animationController = AnimationController.unbounded(
      duration: duration,
      reverseDuration: reverseDuration,
      debugLabel: debugLabel,
      vsync: navigator!,
    )..addStatusListener((_) => _updateSnapshotState());
    return animationController;
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
            if (originateAboveBottomViewInset)
              SizedBox(
                height: MediaQuery.viewInsetsOf(context).bottom,
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
    _updateSnapshotState();
    return super.didPop(result);
  }

  void _handleDragStart(
    BuildContext context,
  ) {
    _isUserDragging = true;
    _updateSnapshotState();
    if (callNavigatorUserGestureMethods) {
      navigator?.didStartUserGesture();
    }
  }

  void _handleDragUpdate(BuildContext context, double delta, bool wouldScroll) {
    if (_poppedNotifier.value) return;
    final currentValue = controller?.value ?? 0;
    var adjustedDelta = delta;

    final maxExtent = effectiveSnappingConfig.maxExtent;

    final applyResistance = !draggable || currentValue > maxExtent;

    if (wouldScroll && (currentValue - delta) > maxExtent) {
      // If the scrollable would scroll, and the sheet will be dragged past its
      // max, we don't allow that.
      adjustedDelta = currentValue - maxExtent;
    } else if (applyResistance && delta != 0) {
      final stickingPoint = _stickingPoint ?? 1.0;
      // When dragging up past fully open, reduce the delta with diminishing
      // returns

      final overshoot = (stickingPoint - currentValue).abs();

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
    bool willScroll,
  ) {
    _isUserDragging = false;
    final currentValue = controller!.value;
    if (callNavigatorUserGestureMethods) {
      navigator?.didStopUserGesture();
    }

    // If the route has been popped, don't interfere with the closing animation
    if (_poppedNotifier.value) return;

    _dragEndVelocity = velocity;

    final maxExtent = effectiveSnappingConfig.maxExtent;

    // If dragged past fully open, always snap back to 1.0
    if (currentValue > maxExtent || !draggable) {
      final stickingPoint = _stickingPoint ?? maxExtent;
      // Scale the velocity by the same resistance factor that was applied
      //during dragging
      final overshoot = (currentValue - stickingPoint).abs();
      final resistance = 1.0 / (maxExtent + overshoot * overshootResistance);
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
          _animationTargetValue = effectiveSnappingConfig.findTargetSnapPoint(
        currentValue,
        velocity,
      );

      // If target is 0 (closed), dismiss the sheet
      if (targetValue <= 0.001) {
        navigator?.pop();
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
    _updateSnapshotState();
  }

  /// Wraps [child] in a [SnapshotWidget] if another sheet route with
  /// snapshotting is stacked on top of this one.
  ///
  /// Call this in [buildTransitions] around the content that should be
  /// snapshotted when covered by another sheet. Returns [child] unchanged
  /// when no snapshotting is active.
  @protected
  Widget maybeSnapshotChild(Widget child) {
    final controller = _coveredBySnapshotController;
    if (controller == null) return child;
    return SnapshotWidget(
      controller: controller,
      mode: SnapshotMode.permissive,
      autoresize: true,
      child: child,
    );
  }

  @override
  @mustCallSuper
  void didChangeNext(Route<dynamic>? nextRoute) {
    super.didChangeNext(nextRoute);
    if (nextRoute is StupidSimpleSheetTransitionMixin) {
      _coveredBySnapshotController = nextRoute._backgroundSnapshotController;
    } else {
      _coveredBySnapshotController = null;
    }
  }

  @override
  @mustCallSuper
  void didPopNext(Route<dynamic> nextRoute) {
    super.didPopNext(nextRoute);
    _coveredBySnapshotController = null;
  }

  @override
  @mustCallSuper
  void dispose() {
    _backgroundSnapshotController.dispose();
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

    // We only animate if this route is still current
    if (!isCurrent) return TickerFuture.complete();

    final double target;

    if (snap) {
      // Find the closest snapping point that isn't 0.0
      final config = effectiveSnappingConfig;
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

    _animationTargetValue = target;
    return controller!.animateWith(simulation);
  }

  /// Updates the snapping configuration to an override for the sheet.
  ///
  /// Pass `null` to [newConfig] to reset the configuration to the one
  /// originally passed to the route constructor.
  ///
  /// If [animateToComply] is `true`, the sheet will immediately animate to
  /// comply with the new snapping configuration. This will snap the sheet to
  /// the nearest valid snapping point in the new configuration.
  ///
  /// Example:
  /// ```dart
  /// // Update to a new configuration and animate to comply
  /// controller.updateSheetSnappingConfig(
  ///   SheetSnappingConfig([0.3, 0.6, 1.0]),
  ///   animateToComply: true,
  /// );
  ///
  /// // Reset to the original configuration
  /// controller.updateSheetSnappingConfig(null);
  /// ```
  TickerFuture overrideSnappingConfig(
    SheetSnappingConfig? newConfig, {
    bool animateToComply = false,
  }) {
    assert(
      controller != null,
      'Controller is null. Make sure the route is pushed before calling.',
    );

    _snappingConfigOverride = newConfig;

    // Only animate to comply if requested and if this route is still current
    if (animateToComply && isCurrent) {
      final currentPosition = controller!.value;

      // Find the nearest snapping point in the new configuration
      final targetPosition = effectiveSnappingConfig.findTargetSnapPoint(
        currentPosition,
        controller!.velocity,
        includeClosed: false,
      );

      // If the current position is already at a valid snap point, don't animate
      if ((targetPosition - currentPosition).abs() < 0.001) {
        return TickerFuture.complete();
      }

      final simulation = motion.createSimulation(
        start: currentPosition,
        end: targetPosition,
        velocity: controller!.velocity,
      );

      _animationTargetValue = targetPosition;

      return controller!.animateWith(simulation);
    }

    return TickerFuture.complete();
  }
}
