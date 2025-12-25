part of 'heroines.dart';

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

  _FlightDriver? _driver;


  bool _waitingOnRoute = false;
  bool _waitingOnSpring = false;

  _FlightDriver _makeDriver(_FlightSpec spec) => spec.isUserGestureTransition
      ? _GestureDriver(this, spec)
      : _SpringDriver(this, spec);

  void startFlight({bool resetBoundingBox = false}) {
    // Prepare both heroes.
    _spec.toHero._startFlight(_spec);
    _spec.fromHero._startFlight(_spec);

    if (overlayEntry == null) {
      overlayEntry = OverlayEntry(builder: _buildOverlay);
      _spec.overlay.insert(overlayEntry!);
    }

    // Route is always required; spring becomes required once we start it.
    _waitingOnRoute = true;
    _waitingOnSpring = false;

    _driver?.dispose();
    _driver = _makeDriver(_spec)..start(resetBoundingBox: resetBoundingBox);
  }

  void onGestureEnd() => _driver?.onGestureEnd();

  void divert(_FlightSpec toSpec) {
    final fromSpec = _spec;

    _driver?.dispose();
    _driver = null;

    _setTargetTracking(false);
    _currentTargetLocation = null;

    fromSpec.dispose();

    _spec = toSpec;

    if (fromSpec.controllingHero != toSpec.controllingHero) {
      toSpec.controllingHero._linkRedirectedMotionController(
        fromSpec.controllingHero._motionController!,
      );
      fromSpec.controllingHero._unlinkMotionControllers();
    }

    final fromChanged = toSpec.fromHero == fromSpec.toHero &&
        toSpec.fromHeroLocation != fromSpec.toHeroLocation;

    startFlight(resetBoundingBox: fromChanged);
  }


  // Starts or restarts the spring animation towards [target].
  void _kickSpring({
    required HeroineLocation target,
    required Motion motion,
    required bool enableTargetTracking,
    HeroineLocation? from,
    HeroineLocation? withVelocity,
  }) {
    _currentTargetLocation = target;

    _setTargetTracking(
        enableTargetTracking && _spec.shouldContinuouslyTrackTarget,);

    // From this point on, spring completion matters.
    _waitingOnSpring = true;

    _spec.controllingHero._motionController
      ?..motion = motion
      ..animateTo(target, from: from, withVelocity: withVelocity);
  }

  void _routeSettled() {
    if (!_waitingOnRoute) return;
    _waitingOnRoute = false;

    // Preserve original behavior: auto-handoff only for non-gesture flights.
    if (!_spec.isUserGestureTransition) {
      _performHandoff();
    }

    _tryEnd();
  }

  void _onSpringAnimationStatusChanged(AnimationStatus status) {
    if (!_waitingOnSpring) return;
    if (status.isAnimating) return;

    _waitingOnSpring = false;
    _tryEnd();
  }

  void _tryEnd() {
    if (_waitingOnRoute || _waitingOnSpring) return;
    onEnd(this);
  }

  void _setTargetTracking(bool enabled) {
    final controller = _spec.controllingHero._motionController;
    if (controller == null) return;

    controller.removeListener(_onMotionControllerUpdate);
    if (enabled) controller.addListener(_onMotionControllerUpdate);
  }

  void _onMotionControllerUpdate() {
    if (!_waitingOnRoute) return;

    final newTargetLocation = _FlightSpec._locationFor(
      _spec.toHero,
      _spec.toRoute.subtreeContext,
    );

    if (newTargetLocation != _currentTargetLocation &&
        newTargetLocation.isValid) {
      _currentTargetLocation = newTargetLocation;
      _spec.controllingHero._motionController?.animateTo(newTargetLocation);
    }
  }

  void _performHandoff() {
    _removeOverlay();
    _setTargetTracking(false);

    final controller = _spec.controllingHero._motionController;
    if (controller == null) return;

    final target = _currentTargetLocation ?? _spec.toHeroLocation;

    _spec.fromHero
        ._completeRouteTransition(controller: controller, target: target);
    _spec.toHero
        ._completeRouteTransition(controller: controller, target: target);
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

  void dispose() {
    _setTargetTracking(false);

    _driver?.dispose();
    _driver = null;

    _removeOverlay();

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

/// Flight driver abstraction.
abstract class _FlightDriver {
  _FlightDriver(this.controller, this.spec);

  final _FlightController controller;
  final _FlightSpec spec;

  void start({required bool resetBoundingBox});
  void onGestureEnd(); // no-op for non-gesture
  void dispose();
}

/// Spring-based flight driver.
class _SpringDriver extends _FlightDriver {
  _SpringDriver(super.controller, super.spec);

  void _onRouteStatus(AnimationStatus status) {
    if (status.isAnimating) return;
    controller._routeSettled();
  }

  @override
  void start({required bool resetBoundingBox}) {
    spec.routeAnimation
      ..removeStatusListener(_onRouteStatus)
      ..addStatusListener(_onRouteStatus);

    final fromHeroVelocity = HeroineVelocity.of(spec.fromHero.context);

    controller._kickSpring(
      target: spec.toHeroLocation,
      motion: spec.motion,
      from: resetBoundingBox ? spec.fromHeroLocation : null,
      withVelocity: switch (fromHeroVelocity) {
        final v? => HeroineLocation._velocity(v),
        null => null,
      },
      enableTargetTracking: true,
    );

    // Route might already be settled.
    _onRouteStatus(spec.routeAnimation.status);
  }

  @override
  void onGestureEnd() {/* no-op */}

  @override
  void dispose() {
    spec.routeAnimation.removeStatusListener(_onRouteStatus);
  }
}

/// Gesture-based flight driver.
class _GestureDriver extends _FlightDriver {
  _GestureDriver(super.controller, super.spec);

  HeroineVelocityTracker? _velocity;
  bool _gestureEnded = false;

  void _driveFromRoute() {
    var t = spec.routeAnimation.value;
    if (spec.direction == HeroFlightDirection.pop) t = 1.0 - t;

    final currentRect = Rect.lerp(
      spec.fromHeroLocation.boundingBox,
      spec.toHeroLocation.boundingBox,
      t,
    )!;

    final loc = HeroineLocation(
      boundingBox: currentRect,
      rotation: 0.0, // TODO: rotation lerp
    );

    spec.controllingHero._motionController?.value = loc;
    _velocity?.addSample(loc);
  }

  void _onRouteStatus(AnimationStatus status) {
    // Route completion "counts" only after gesture ends.
    if (!_gestureEnded) return;
    if (status.isAnimating) return;
    controller._routeSettled();
  }

  @override
  void start({required bool resetBoundingBox}) {
    _gestureEnded = false;
    _velocity = HeroineVelocityTracker();

    // Tracking intentionally disabled during gesture.
    controller
      .._setTargetTracking(false)
      .._currentTargetLocation = null;

    spec.routeAnimation
      ..removeStatusListener(_onRouteStatus)
      ..addStatusListener(_onRouteStatus)
      ..removeListener(_driveFromRoute)
      ..addListener(_driveFromRoute);

    // Sync immediately.
    _driveFromRoute();
  }

  @override
  void onGestureEnd() {
    if (_gestureEnded) return;
    _gestureEnded = true;

    spec.routeAnimation.removeListener(_driveFromRoute);

    final status = spec.routeAnimation.status;
    final isPush = spec.direction == HeroFlightDirection.push;

    final proceeding = isPush
        ? (status == AnimationStatus.forward ||
            status == AnimationStatus.completed)
        : (status == AnimationStatus.reverse ||
            status == AnimationStatus.dismissed);

    final progress = switch (spec.direction) {
      HeroFlightDirection.pop => 1.0 - spec.routeAnimation.value,
      HeroFlightDirection.push => spec.routeAnimation.value,
    }
        .clamp(0.0, 1.0);

    final target = proceeding ? spec.toHeroLocation : spec.fromHeroLocation;
    final remainingFraction = proceeding ? 1.0 - progress : progress;

    final handoffMotion = spec.handoffMotionBuilder(
      HeroineGestureHandoffContext(
        progress: progress,
        remainingFraction: remainingFraction,
        proceeding: proceeding,
        motion: spec.motion,
        direction: spec.direction,
        velocity: _velocity?.velocity,
      ),
    );

    controller._kickSpring(
      target: target,
      motion: handoffMotion,
      withVelocity: _velocity?.velocity,
      enableTargetTracking: true,
    );

    _velocity = null;

    // Route might already be settled.
    _onRouteStatus(status);
  }

  @override
  void dispose() {
    spec.routeAnimation
      ..removeListener(_driveFromRoute)
      ..removeStatusListener(_onRouteStatus);
    _velocity = null;
  }
}
