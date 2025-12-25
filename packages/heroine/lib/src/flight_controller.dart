part of 'heroines.dart';

enum _FlightPhase { idle, routeDriving, springing, done }

/// Controls the lifecycle of a heroine flight animation.
///
/// A flight has two animations running in parallel:
/// 1) Route animation (Navigator)
/// 2) Spring animation (MotionController)
///
/// The flight ends only when BOTH complete.
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
    _spec.controllingHero._createMotionController(
      _spec,
      _onSpringAnimationStatusChanged,
    );
  }

  _FlightSpec _spec;

  /// The current target location, updated on each frame when
  /// [_FlightSpec.shouldContinuouslyTrackTarget] is true.
  ///
  /// This allows the flight to smoothly redirect if the target widget moves
  /// during the animation (e.g., keyboard appears/disappears).
  HeroineLocation? _currentTargetLocation;

  /// Called when the flight ends (both animations complete).
  final void Function(_FlightController controller) onEnd;

  /// The overlay entry displaying the flying hero.
  OverlayEntry? overlayEntry;

  _FlightPhase _phase = _FlightPhase.idle;
  bool get _isRouteDriving => _phase == _FlightPhase.routeDriving;

  /// Whether the spring animation has completed.
  bool _springAnimationComplete = false;

  /// Whether the route animation has completed.
  bool _routeAnimationComplete = false;

  HeroineVelocityTracker? _gestureVelocityTracker;

  Motion _motionForGestureHandoff({
    required double progress,
    required double remainingFraction,
    required bool proceeding,
  }) {
    return _spec.handoffMotionBuilder(
      HeroineGestureHandoffContext(
        progress: progress,
        remainingFraction: remainingFraction,
        proceeding: proceeding,
        motion: _spec.motion,
        direction: _spec.direction,
        velocity: _gestureVelocityTracker?.velocity,
      ),
    );
  }

  void _stopRouteDriving() {
    if (!_isRouteDriving) return;
    _spec.routeAnimation.removeListener(_driveFlightFromRoute);
    _gestureVelocityTracker = null;
    _phase = _FlightPhase.idle;
  }

  void _driveFlightFromRoute() {
    if (!_isRouteDriving) return;

    var t = _spec.routeAnimation.value;
    if (_spec.direction == HeroFlightDirection.pop) {
      t = 1.0 - t;
    }

    final fromRect = _spec.fromHeroLocation.boundingBox;
    final toRect = _spec.toHeroLocation.boundingBox;

    final currentRect = Rect.lerp(fromRect, toRect, t)!;

    final currentLocation = HeroineLocation(
      boundingBox: currentRect,
      rotation: 0.0, // TODO(timcreatedit): rotation lerp
    );

    _spec.controllingHero._motionController?.value = currentLocation;
    _gestureVelocityTracker?.addSample(currentLocation);
  }
  void startFlight({bool resetBoundingBox = false}) {
    // Prepare both heroes.
    _spec.toHero._startFlight(_spec);
    _spec.fromHero._startFlight(_spec);
    if (overlayEntry == null) {
      _spec.overlay.insert(
        overlayEntry = OverlayEntry(builder: _buildOverlay),
      );
    }

    // Always attach status listener up-front; ignore it while route-driving.
    _spec.routeAnimation.removeStatusListener(_onRouteAnimationStatusChanged);
    _spec.routeAnimation.addStatusListener(_onRouteAnimationStatusChanged);

    if (_spec.isUserGestureTransition) {
      // During gesture, we drive the controller value directly from the route.
      _currentTargetLocation = null;
      _phase = _FlightPhase.routeDriving;
      _gestureVelocityTracker = HeroineVelocityTracker();

      _spec.routeAnimation.removeListener(_driveFlightFromRoute);
      _spec.routeAnimation.addListener(_driveFlightFromRoute);
      return;
    }

    // Non-gesture: run spring immediately.
    _phase = _FlightPhase.springing;

    _currentTargetLocation = _spec.toHeroLocation;

    if (_spec.shouldContinuouslyTrackTarget) {
      _spec.controllingHero._motionController?.addListener(
        _onMotionControllerUpdate,
      );
    }

    final fromHeroVelocity = HeroineVelocity.of(_spec.fromHero.context);

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

  void onGestureEnd() {
    if (!_spec.isUserGestureTransition) return;

    _stopRouteDriving();
    _phase = _FlightPhase.springing;

    _gestureVelocityTracker ??= HeroineVelocityTracker();

    final status = _spec.routeAnimation.status;
    final isPush = _spec.direction == HeroFlightDirection.push;

    final proceeding = isPush
        ? (status == AnimationStatus.forward ||
            status == AnimationStatus.completed)
        : (status == AnimationStatus.reverse ||
            status == AnimationStatus.dismissed);

    final target = proceeding ? _spec.toHeroLocation : _spec.fromHeroLocation;

    final progress = switch (_spec.direction) {
      HeroFlightDirection.pop => 1.0 - _spec.routeAnimation.value,
      HeroFlightDirection.push => _spec.routeAnimation.value,
    }
        .clamp(0.0, 1.0);

    final remainingFraction = proceeding ? 1.0 - progress : progress;
    final handoffMotion = _motionForGestureHandoff(
      progress: progress,
      remainingFraction: remainingFraction,
      proceeding: proceeding,
    );

    _currentTargetLocation = target;

    // Tracking is intentionally disabled during gesture;
    // enable after gesture end.
    if (_spec.shouldContinuouslyTrackTarget) {
      _spec.controllingHero._motionController?.addListener(
        _onMotionControllerUpdate,
      );
    }

    _springAnimationComplete = false;
    _routeAnimationComplete = false;

    _spec.controllingHero._motionController
      ?..motion = handoffMotion
      ..animateTo(
        target,
        withVelocity: _gestureVelocityTracker?.velocity,
      );

    _gestureVelocityTracker = null;

    // If route is already settled, process completion immediately.
    if (!status.isAnimating) {
      _onRouteAnimationStatusChanged(status);
    }
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
      fromSpec.controllingHero._motionController?.removeListener(
        _onMotionControllerUpdate,
      );
    }
    _stopRouteDriving();

    // Reset the tracked target location for the new flight
    _currentTargetLocation = null;

    fromSpec.routeAnimation
        .removeStatusListener(_onRouteAnimationStatusChanged);
    fromSpec.dispose();

    // Transfer motion controller ownership if controlling hero changes.
    if (fromSpec.controllingHero != toSpec.controllingHero) {
      toSpec.controllingHero._linkRedirectedMotionController(
        fromSpec.controllingHero._motionController!,
      );
      fromSpec.controllingHero._unlinkMotionControllers();
    }

    _springAnimationComplete = false;
    _routeAnimationComplete = false;

    final fromChanged = toSpec.fromHero == fromSpec.toHero &&
        toSpec.fromHeroLocation != fromSpec.toHeroLocation;

    /// If the position of the new source hero is different from when it was
    /// the toHero in the previous flight, we need to reset the bounding box
    /// of the motion controllers to avoid visual glitches.
    startFlight(resetBoundingBox: fromChanged);
  }


  void _onRouteAnimationStatusChanged(AnimationStatus status) {
    // Ignore while user is actively dragging.
    if (_isRouteDriving) return;

    if (status.isAnimating) return;
    if (_routeAnimationComplete) return;

    _routeAnimationComplete = true;

    // Preserve original behavior: auto-handoff only for non-gesture flights.
    if (!_spec.isUserGestureTransition) {
      _performHandoff();
    }

    _endFlightIfBothAnimationsComplete();
  }

  void _onSpringAnimationStatusChanged(AnimationStatus status) {
    if (_isRouteDriving) return; 
    if (status.isAnimating) return;
    if (_springAnimationComplete) return;

    _springAnimationComplete = true;
    _endFlightIfBothAnimationsComplete();
  }

  void _endFlightIfBothAnimationsComplete() {
    if (_springAnimationComplete && _routeAnimationComplete) {
      _phase = _FlightPhase.done;
      onEnd(this);
    }
  }

  void _performHandoff() {
    _removeOverlay();

    if (_spec.shouldContinuouslyTrackTarget) {
      _spec.controllingHero._motionController?.removeListener(
        _onMotionControllerUpdate,
      );
    }

    final controller = _spec.controllingHero._motionController;

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

    final listenable = Listenable.merge([_spec.routeAnimation, controller]);

    return AnimatedBuilder(
      animation: listenable,
      builder: (context, child) {
        final rect = controller.value.boundingBox;
        return Positioned(
          top: rect.center.dy - rect.size.height / 2,
          left: rect.center.dx - rect.size.width / 2,
          width: rect.size.width,
          height: rect.size.height,
          child: child!,
        );
      },
      child: IgnorePointer(
        // TODO(timcreatedit): allow configuring this
        child: shuttle,
      ),
    );
  }


  /// Disposes of this flight controller and cleans up resources.
  void dispose() {
    if (_spec.shouldContinuouslyTrackTarget) {
      _spec.controllingHero._motionController?.removeListener(
        _onMotionControllerUpdate,
      );
    }

    _stopRouteDriving();
    _spec.routeAnimation.removeStatusListener(_onRouteAnimationStatusChanged);

    if (overlayEntry != null) {
      _removeOverlay();
    }

    _spec.toHero._endFlight();
    _spec.controllingHero._disposeMotionController();

    _spec.dispose();
  }

  void _removeOverlay() {
    overlayEntry?.remove();
    overlayEntry?.dispose();
    overlayEntry = null;
  }
}
