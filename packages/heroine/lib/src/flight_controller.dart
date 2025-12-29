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
    _spec.controllingHero._createMotionController(_spec);
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

    _waitingOnRoute = true;

    _driver?.dispose();
    _driver = _makeDriver(_spec)..start(resetBoundingBox: resetBoundingBox);
  }

  void onGestureEnd() => _driver?.onGestureEnd();

  void divert(_FlightSpec toSpec) {
    final fromSpec = _spec;
    final fromMotionController = fromSpec.controllingHero._motionController;

    _driver?.dispose();
    _driver = null;

    _setTargetTracking(false);
    _currentTargetLocation = null;

    fromSpec.dispose();

    _spec = toSpec;

    if (fromSpec.controllingHero != toSpec.controllingHero) {
      if (fromMotionController == null) {
        toSpec.controllingHero._createMotionController(toSpec);
      } else {
        toSpec.controllingHero._linkRedirectedMotionController(
          fromMotionController,
        );
        fromSpec.controllingHero._unlinkMotionControllers();
      }
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
      enableTargetTracking && _spec.shouldContinuouslyTrackTarget,
    );

    final controller = _spec.controllingHero._motionController;
    if (controller == null) return;

    controller.motion = motion;
    _animateToWithEnd(
      controller,
      target,
      from: from,
      withVelocity: withVelocity,
    );
  }

  void _routeSettled() {
    if (!_waitingOnRoute) return;
    _waitingOnRoute = false;

    // Proceeding gestures and non-gesture flights: handoff to hero widget.
    // Cancelled gestures: skip handoff, let spring finish in overlay.
    if (_driver?.shouldHandoffOnRouteSettled ?? true) {
      _performHandoff();
    }

    _tryEnd();
  }

  void _tryEnd() {
    if (_waitingOnRoute) return;

    final controller = _spec.controllingHero._motionController;
    if (controller?.status.isAnimating ?? false) {
      return;
    }

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

    final controller = _spec.controllingHero._motionController;
    if (newTargetLocation != _currentTargetLocation &&
        newTargetLocation.isValid &&
        controller != null) {
      _currentTargetLocation = newTargetLocation;
      _animateToWithEnd(controller, newTargetLocation);
    }
  }

  void _performHandoff() {
    _removeOverlay();
    _setTargetTracking(false);

    final controller = _spec.controllingHero._motionController;
    if (controller == null) return;

    // Normal handoff: transfer the in-progress spring to the hero widgets
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

    _spec.fromHero._endFlight();
    _spec.toHero._endFlight();
    _spec.controllingHero._disposeMotionController();
    _spec.dispose();
  }

  void _removeOverlay() {
    overlayEntry?.remove();
    overlayEntry?.dispose();
    overlayEntry = null;
  }

  void _animateToWithEnd(
    MotionController<HeroineLocation> controller,
    HeroineLocation target, {
    HeroineLocation? from,
    HeroineLocation? withVelocity,
  }) {
    controller
        .animateTo(target, from: from, withVelocity: withVelocity)
        .whenComplete(_tryEnd);
  }
}

/// Flight driver abstraction.
abstract class _FlightDriver {
  _FlightDriver(this.controller, this.spec);

  final _FlightController controller;
  final _FlightSpec spec;

  bool get shouldHandoffOnRouteSettled => true;

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
  bool? _proceeding;

  @override
  bool get shouldHandoffOnRouteSettled => _proceeding ?? true;

  void _driveFromRoute() {
    var t = spec.routeAnimation.value;
    if (spec.direction == HeroFlightDirection.pop) t = 1.0 - t;

    final currentRect = Rect.lerp(
      spec.fromHeroLocation.boundingBox,
      spec.toHeroLocation.boundingBox,
      t,
    )!;

    // TODO(Jesper): rotation lerp
    final loc = HeroineLocation(
      boundingBox: currentRect,
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

    final status = spec.routeAnimation.status;
    final isPush = spec.direction == HeroFlightDirection.push;

    final proceeding = isPush
        ? (status == AnimationStatus.forward ||
            status == AnimationStatus.completed)
        : (status == AnimationStatus.reverse ||
            status == AnimationStatus.dismissed);
    _proceeding = proceeding;

    final progress = switch (spec.direction) {
      HeroFlightDirection.pop => 1.0 - spec.routeAnimation.value,
      HeroFlightDirection.push => spec.routeAnimation.value,
    }
        .clamp(0.0, 1.0);

    if (proceeding) {
      spec.routeAnimation.removeListener(_driveFromRoute);

      final target = spec.toHeroLocation;
      final remainingFraction = 1.0 - progress;

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
    }

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
