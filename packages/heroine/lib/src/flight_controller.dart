part of 'heroines.dart';

/// Controls the lifecycle of a heroine flight animation.
///
/// A flight has two animations running in parallel:
/// 1. **Route animation**: The page transition (managed by Navigator)
/// 2. **Spring animation**: The hero's position/size (managed by MotionControllers)
///
/// The controller is responsible for:
/// - Creating and managing the overlay entry showing the flying hero
/// - Coordinating the spring animations for position and size
/// - Handling flight diversions (when navigation direction changes mid-flight)
/// - Performing the "handoff" when the route animation completes
///
/// The flight ends only when both animations complete.
class _FlightController {
  _FlightController(this._spec, this.onEnd) {
    _spec.toHero._createMotionController(
      _spec,
      _onSpringAnimationStatusChanged,
    );
  }

  /// The current flight specification.
  _FlightSpec _spec;

  /// The current target location, updated on each frame when
  /// [_FlightSpec.shouldContinuouslyTrackTarget] is true.
  ///
  /// This allows the flight to smoothly redirect if the target widget moves
  /// during the animation (e.g., keyboard appears/disappears).
  HeroineLocation? _currentTargetLocation;

  /// Called when the flight ends (both animations complete).
  final VoidCallback onEnd;

  /// The overlay entry displaying the flying hero.
  OverlayEntry? overlayEntry;

  // ---------------------------------------------------------------------------
  // Animation Completion Tracking
  // ---------------------------------------------------------------------------

  /// Whether the spring animation has completed.
  bool _springAnimationComplete = false;

  /// Whether the route animation has completed.
  bool _routeAnimationComplete = false;

  // ---------------------------------------------------------------------------
  // Gesture Tracking
  // ---------------------------------------------------------------------------

  _HeroineVelocityTracker? _velocityTracker;
  bool _gestureEnded = false;

  /// null = not a gesture transition, true = proceeding, false = cancelled
  bool? _gestureProceeding;

  /// Starts the flight animation.
  ///
  /// If [resetBoundingBox] is true, the controllers will restart from the
  /// current hero position/size instead of continuing from their previous
  /// animation state.
  /// This is useful when diverting a flight in certain cases, see
  /// [_FlightController.divert].
  void startFlight({bool resetBoundingBox = false}) {
    _spec.toHero._startFlight(_spec);
    _spec.fromHero._startFlight(_spec);
    if (overlayEntry == null) {
      _spec.overlay.insert(
        overlayEntry = OverlayEntry(builder: _buildOverlay),
      );
    }

    // Reset completion flags
    _springAnimationComplete = false;
    _routeAnimationComplete = false;

    // Reset gesture state
    _gestureEnded = false;
    _gestureProceeding = null;
    _velocityTracker = null;

    _spec.routeAnimation.addStatusListener(_onRouteAnimationStatusChanged);

    if (_spec.isUserGestureTransition) {
      // Gesture mode: drive position from route animation value
      _velocityTracker = _HeroineVelocityTracker();
      _spec.routeAnimation.addListener(_driveFromRoute);
      _driveFromRoute();
    } else {
      // Normal mode: kick spring animation immediately
      final fromHeroVelocity = HeroineVelocity.of(_spec.fromHero.context);
      _currentTargetLocation = _spec.toHeroLocation;

      // Set up continuous target tracking if enabled
      if (_spec.shouldContinuouslyTrackTarget) {
        _spec.toHero._motionController
            ?.addListener(_onMotionControllerUpdate);
      }

      // Animate position and size to the destination
      _spec.toHero._motionController
        ?..motion = _spec.motion
        ..animateTo(
          _spec.toHeroLocation,
          from: resetBoundingBox ? _spec.fromHeroLocation : null,
          withVelocity: switch (fromHeroVelocity) {
            final v? => HeroineLocation._velocity(v),
            null => null,
          },
        );
    }
  }

  /// Called by HeroineController when a user gesture ends.
  void onGestureEnd() {
    if (!_spec.isUserGestureTransition || _gestureEnded) return;
    _gestureEnded = true;

    _gestureProceeding =
        switch ((_spec.direction, _spec.routeAnimation.status)) {
      (
        HeroFlightDirection.push,
        AnimationStatus.forward || AnimationStatus.completed
      ) =>
        true,
      (
        HeroFlightDirection.pop,
        AnimationStatus.reverse || AnimationStatus.dismissed
      ) =>
        true,
      _ => false,
    };

    final progress = switch (_spec.direction) {
      HeroFlightDirection.pop => 1.0 - _spec.routeAnimation.value,
      HeroFlightDirection.push => _spec.routeAnimation.value,
    }
        .clamp(0.0, 1.0);

    if (_gestureProceeding!) {
      // Stop driving from route, switch to spring animation
      _spec.routeAnimation.removeListener(_driveFromRoute);

      final handoffMotion = _spec.motion.trimmed(fromStart: progress);
      _currentTargetLocation = _spec.toHeroLocation;

      if (_spec.shouldContinuouslyTrackTarget) {
        _spec.toHero._motionController
            ?.addListener(_onMotionControllerUpdate);
      }

      _spec.toHero._motionController
        ?..motion = handoffMotion
        ..animateTo(
          _spec.toHeroLocation,
          withVelocity: _velocityTracker?.velocity,
        );
    }
    // If cancelled (!proceeding), keep driving from route until it settles
    _velocityTracker = null;

    // Route might already be settled
    _onRouteAnimationStatusChanged(_spec.routeAnimation.status);
  }

  /// Drives the hero position directly from the route animation value.
  void _driveFromRoute() {
    var t = _spec.routeAnimation.value;
    if (_spec.direction == HeroFlightDirection.pop) t = 1.0 - t;

    final currentRect = Rect.lerp(
      _spec.fromHeroLocation.boundingBox,
      _spec.toHeroLocation.boundingBox,
      t,
    )!;

    // TODO(Jesper): rotation lerp
    final loc = HeroineLocation(boundingBox: currentRect);

    _spec.toHero._motionController?.value = loc;
    _velocityTracker?.addSample(loc);
  }

  /// Called on every frame when continuous target tracking is enabled.
  ///
  /// Checks if the target widget has moved and redirects the animation
  /// to the new position if needed.
  void _onMotionControllerUpdate() {
    if (_routeAnimationComplete) return;

    final newTargetLocation = _FlightSpec._locationFor(
      _spec.toHero,
      _spec.toRoute.subtreeContext,
    );

    // Only redirect if the target has actually moved
    if (newTargetLocation != _currentTargetLocation &&
        newTargetLocation.isValid) {
      _currentTargetLocation = newTargetLocation;
      _spec.toHero._motionController?.animateTo(newTargetLocation);
    }
  }

  /// Diverts this flight to a new destination.
  ///
  /// This happens when navigation direction changes mid-flight
  /// (e.g., user swipes back during a push transition).
  void divert(_FlightSpec toSpec) {
    final fromSpec = _spec;
    final fromMotionController = fromSpec.toHero._motionController;

    // Clean up continuous target tracking from the previous spec
    if (fromSpec.shouldContinuouslyTrackTarget) {
      fromSpec.toHero._motionController
          ?.removeListener(_onMotionControllerUpdate);
    }
    fromSpec.routeAnimation
      ..removeStatusListener(_onRouteAnimationStatusChanged)
      ..removeListener(_driveFromRoute);

    // Reset the tracked target location for the new flight
    _currentTargetLocation = null;

    fromSpec.dispose();
    _spec = toSpec;

    // Transfer or create motion controller
    if (fromSpec.toHero != toSpec.toHero) {
      if (fromMotionController == null) {
        toSpec.toHero._createMotionController(
          toSpec,
          _onSpringAnimationStatusChanged,
        );
      } else {
        toSpec.toHero._linkRedirectedMotionController(
          fromMotionController,
        );
        fromSpec.toHero._unlinkMotionControllers();
      }
    }

    final fromChanged = toSpec.fromHero == fromSpec.toHero &&
        toSpec.fromHeroLocation != fromSpec.toHeroLocation;

    /// If the position of the new source hero is different from when it was
    /// the toHero in the previous flight, we need to reset the bounding box
    /// of the motion controllers to avoid visual glitches.
    startFlight(resetBoundingBox: fromChanged);
  }

  // ---------------------------------------------------------------------------
  // Flight Handoff
  // ---------------------------------------------------------------------------

  /// Hands off the flight to the destination hero.
  ///
  /// This is called when the route animation completes. The overlay is removed,
  /// but the destination hero continues animating from the current spring
  /// position to its final resting position. This creates a smooth "landing"
  /// effect where the hero settles into place.
  void _performHandoff() {
    _removeOverlay();

    // Stop listening for target updates
    if (_spec.shouldContinuouslyTrackTarget) {
      _spec.toHero._motionController
          ?.removeListener(_onMotionControllerUpdate);
    }

    final controller = _spec.toHero._motionController;

    if (controller == null) return;

    // Use the tracked target location (which may have been updated during
    // the flight) to ensure the handoff animates to the correct final position.
    final targetLocation = _currentTargetLocation ?? _spec.toHeroLocation;

    _spec.fromHero._completeRouteTransition(
      controller: controller,
      target: targetLocation,
    );
    _spec.toHero._completeRouteTransition(
      controller: controller,
      target: targetLocation,
    );
  }

  // ---------------------------------------------------------------------------
  // Animation Status Handlers
  // ---------------------------------------------------------------------------

  void _onRouteAnimationStatusChanged(AnimationStatus status) {
    // For gestures, only process after gesture ends
    if (_spec.isUserGestureTransition && !_gestureEnded) return;
    if (status.isAnimating) return;

    _spec.routeAnimation
      ..removeStatusListener(_onRouteAnimationStatusChanged)
      ..removeListener(_driveFromRoute);

    _routeAnimationComplete = true;

    // Proceeding gestures and non-gesture flights: perform handoff
    // Cancelled gestures: skip handoff, hero returns to original position
    if (_gestureProceeding ?? true) {
      _performHandoff();
    }

    _endFlightIfComplete();
  }

  void _onSpringAnimationStatusChanged(AnimationStatus status) {
    if (status.isAnimating) return;

    _springAnimationComplete = true;
    _endFlightIfComplete();
  }

  void _endFlightIfComplete() {
    if (!_routeAnimationComplete) return;

    final isComplete = switch (_gestureProceeding) {
      false => true,  // Cancelled gesture: route done is enough
      _ => _springAnimationComplete,  // All others: need spring too
    };

    if (isComplete) onEnd();
  }

  // ---------------------------------------------------------------------------
  // Overlay Building
  // ---------------------------------------------------------------------------

  /// Builds the overlay widget showing the flying hero.
  Widget _buildOverlay(BuildContext context) {
    final shuttle = _spec.shuttleBuilder(
      context,
      _spec.routeAnimation,
      _spec.direction,
      _spec.fromHero.context,
      _spec.toHero.context,
    );

    final controller = _spec.toHero._motionController;

    if (controller == null) return shuttle;

    return AnimatedBuilder(
      animation: _spec.routeAnimation,
      builder: (context, child) => Positioned(
        top: controller.value.boundingBox.center.dy -
            controller.value.boundingBox.size.height / 2,
        left: controller.value.boundingBox.center.dx -
            controller.value.boundingBox.size.width / 2,
        width: controller.value.boundingBox.size.width,
        height: controller.value.boundingBox.size.height,
        // TODO(timcreatedit): rotate here
        child: child!,
      ),
      child: IgnorePointer(
        // TODO(timcreatedit): allow configuring this
        child: shuttle,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Disposal
  // ---------------------------------------------------------------------------

  /// Disposes of this flight controller and cleans up resources.
  void dispose() {
    // Clean up continuous target tracking
    if (_spec.shouldContinuouslyTrackTarget) {
      _spec.toHero._motionController
          ?.removeListener(_onMotionControllerUpdate);
    }
    _spec.routeAnimation
      ..removeStatusListener(_onRouteAnimationStatusChanged)
      ..removeListener(_driveFromRoute);

    _spec.fromHero._endFlight();
    _spec.toHero._endFlight();
    _spec.toHero._disposeMotionController();

    _spec.dispose();

    if (overlayEntry != null) {
      _removeOverlay();
    }
  }

  void _removeOverlay() {
    overlayEntry?.remove();
    overlayEntry?.dispose();
    overlayEntry = null;
  }
}
