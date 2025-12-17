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

    // Animate position and size to the destination
    _spec.controllingHero._centerController
      ?..motion = _spec.motion
      ..animateTo(
        _spec.toHeroLocation.center,
        from: resetBoundingBox ? _spec.fromHeroLocation.center : null,
        withVelocity: fromHeroVelocity?.pixelsPerSecond,
      );

    _spec.controllingHero._sizeController
      ?..motion = _spec.motion
      ..animateTo(
        from: resetBoundingBox ? _spec.fromHeroLocation.size : null,
        _spec.toHeroLocation.size,
      );
  }

  /// Diverts this flight to a new destination.
  ///
  /// This happens when navigation direction changes mid-flight
  /// (e.g., user swipes back during a push transition).
  void divert(_FlightSpec toSpec) {
    final fromSpec = _spec;
    _spec = toSpec;

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
    to._linkRedirectedMotionControllers(
      from._centerController!,
      from._sizeController!,
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

    final centerController = _spec.controllingHero._centerController;
    final sizeController = _spec.controllingHero._sizeController;

    if (centerController == null || sizeController == null) return;

    _spec.toHero._performHandoff(
      centerController: centerController,
      targetCenter: _spec.toHeroLocation.center,
      sizeController: sizeController,
      targetSize: _spec.toHeroLocation.size,
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

    final centerController = _spec.controllingHero._centerController;
    final sizeController = _spec.controllingHero._sizeController;

    if (centerController == null || sizeController == null) return shuttle;

    return AnimatedBuilder(
      animation: _spec.routeAnimation,
      builder: (context, child) => Positioned(
        top: centerController.value.dy - sizeController.value.height / 2,
        left: centerController.value.dx - sizeController.value.width / 2,
        width: sizeController.value.width,
        height: sizeController.value.height,
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
