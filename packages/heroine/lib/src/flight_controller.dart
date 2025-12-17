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
    _spec.controllingHero._initMotionControllers(
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

  /// Starts the flight animation.
  ///
  /// If [resetBoundingBox] is true, the controllers will restart from the
  /// current hero position/size instead of continuing from their previous
  /// animation state.
  /// This is useful when diverting a flight in certain cases, see
  /// [_FlightController.divert].
  void startFlight({bool resetBoundingBox = false}) {
    _spec.toHero._startFlight(_spec);

    // For user gesture transitions, we don't show the overlay yet
    // (the hero is still being dragged by the user)
    if (_spec.isUserGestureTransition) {
      return;
    }

    _spec.fromHero._startFlight(_spec);
    if (overlayEntry == null) {
      _spec.overlay.insert(
        overlayEntry = OverlayEntry(builder: _buildOverlay),
      );
    }

    // Get any velocity from a preceding gesture (e.g., drag-to-dismiss)
    final fromHeroVelocity = HeroineVelocity.of(_spec.fromHero.context);
    _spec.routeAnimation.addStatusListener(_onRouteAnimationStatusChanged);

    // Initialize the current target location
    _currentTargetLocation = _spec.toHeroLocation;

    // Set up continuous target tracking if enabled
    if (_spec.shouldContinuouslyTrackTarget) {
      _spec.controllingHero._motionController
          ?.addListener(_onMotionControllerUpdate);
    }

    // Animate position and size to the destination
    _spec.controllingHero._motionController
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
      _spec.controllingHero._motionController?.animateTo(newTargetLocation);
    }
  }

  /// Diverts this flight to a new destination.
  ///
  /// This happens when navigation direction changes mid-flight
  /// (e.g., user swipes back during a push transition).
  void divert(_FlightSpec toSpec) {
    final fromSpec = _spec;
    _spec = toSpec;

    // Clean up continuous target tracking from the previous spec
    if (fromSpec.shouldContinuouslyTrackTarget) {
      fromSpec.controllingHero._motionController
          ?.removeListener(_onMotionControllerUpdate);
    }

    // Reset the tracked target location for the new flight
    _currentTargetLocation = null;

    fromSpec.dispose();
    fromSpec.routeAnimation
        .removeStatusListener(_onRouteAnimationStatusChanged);

    _transferMotionControllers(
      from: fromSpec.controllingHero,
      to: toSpec.controllingHero,
    );

    // Reset completion flags for the new flight
    _springAnimationComplete = false;
    _routeAnimationComplete = false;

    final fromChanged = toSpec.fromHero == fromSpec.toHero &&
        toSpec.fromHeroLocation != fromSpec.toHeroLocation;

    /// If the position of the new source hero is different from when it was
    /// the toHero in the previous flight, we need to reset the bounding box
    /// of the motion controllers to avoid visual glitches.
    startFlight(
      resetBoundingBox: fromChanged,
    );
  }

  /// Transfers motion controller ownership between hero states.
  void _transferMotionControllers({
    required _HeroineState from,
    required _HeroineState to,
  }) {
    if (from == to) return;
    to._linkRedirectedMotionController(
      from._motionController!,
    );
    from._unlinkMotionControllers();
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
      _spec.controllingHero._motionController
          ?.removeListener(_onMotionControllerUpdate);
    }

    final controller = _spec.controllingHero._motionController;

    if (controller == null) return;

    // Use the tracked target location (which may have been updated during
    // the flight) to ensure the handoff animates to the correct final position.
    final targetLocation = _currentTargetLocation ?? _spec.toHeroLocation;

    _spec.toHero._performHandoff(
      controller: controller,
      target: targetLocation,
    );
  }

  // ---------------------------------------------------------------------------
  // Animation Status Handlers
  // ---------------------------------------------------------------------------

  void _onRouteAnimationStatusChanged(AnimationStatus status) {
    if (_spec.isUserGestureTransition) return;

    if (status.isAnimating) return;

    _spec.routeAnimation.removeStatusListener(_onRouteAnimationStatusChanged);
    _routeAnimationComplete = true;
    _performHandoff();
    _endFlightIfBothAnimationsComplete();
  }

  void _onSpringAnimationStatusChanged(AnimationStatus status) {
    if (_spec.isUserGestureTransition) return;

    if (status.isAnimating) return;

    _springAnimationComplete = true;
    _endFlightIfBothAnimationsComplete();
  }

  void _endFlightIfBothAnimationsComplete() {
    if (_springAnimationComplete && _routeAnimationComplete) {
      onEnd();
    }
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

    final controller = _spec.controllingHero._motionController;

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
      _spec.controllingHero._motionController
          ?.removeListener(_onMotionControllerUpdate);
    }

    _spec.toHero._endFlight();
    _spec.controllingHero._disposeMotionControllers();

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
