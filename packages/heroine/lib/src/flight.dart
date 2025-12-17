part of 'heroines.dart';

class _HeroineFlight {
  _HeroineFlight(this.manifest, this.onEnd) {
    manifest.controllingHero._initSpringControllers(
      manifest,
      _onFlightAnimationStatusChanged,
    );
  }

  _FlightManifest manifest;

  final VoidCallback onEnd;

  OverlayEntry? overlayEntry;

  bool _flightAnimationComplete = false;
  bool _routeAnimationComplete = false;

  MotionController<Offset>? get centerController =>
      manifest.controllingHero._centerController;
  MotionController<Size>? get sizeController =>
      manifest.controllingHero._sizeController;

  void startFlight() {
    manifest.toHero._startFlight(manifest);

    if (manifest.isUserGestureTransition) {
      return;
    }

    manifest.fromHero._startFlight(manifest);
    if (overlayEntry == null) {
      manifest.overlay.insert(
        overlayEntry = OverlayEntry(builder: _buildOverlay),
      );
    }

    final fromHeroVelocity = HeroineVelocity.of(manifest.fromHero.context);
    manifest.routeAnimation
        .addStatusListener(_onProgressAnimationStatusChanged);

    centerController
      ?..motion = manifest.motion
      ..animateTo(
        manifest.toHeroLocation.center,
        withVelocity: fromHeroVelocity?.pixelsPerSecond,
      );

    sizeController
      ?..motion = manifest.motion
      ..animateTo(
        manifest.toHeroLocation.size,
      );
  }

  void divert(_FlightManifest newManifest) {
    // If we are diverting a user gesture transition to a non-user gesture
    // transition, we need to set the initial values of the controllers to
    // the values of the from hero to make sure the animation is smooth.
    if (manifest.isUserGestureTransition &&
        !newManifest.isUserGestureTransition) {
      centerController
        ?..value = newManifest.fromHeroLocation.center
        ..motion = manifest.motion;
      sizeController
        ?..value = newManifest.fromHeroLocation.size
        ..motion = manifest.motion;
    }

    manifest.dispose();
    manifest.routeAnimation
        .removeStatusListener(_onProgressAnimationStatusChanged);

    _transferSpringControllers(
      from: manifest.controllingHero,
      to: newManifest.controllingHero,
    );

    manifest = newManifest;

    // Reset completion flags for the new flight
    _flightAnimationComplete = false;
    _routeAnimationComplete = false;

    startFlight();
  }

  void _transferSpringControllers({
    required _HeroineState from,
    required _HeroineState to,
  }) {
    if (from == to) return;
    to._linkRedirectedSpringControllers(
      from._centerController!,
      from._sizeController!,
    );
    from._unlinkSpringControllers();
  }

  void handoverFlight() {
    _removeOverlay();

    final centerController = this.centerController;
    final sizeController = this.sizeController;

    if (centerController == null || sizeController == null) return;

    manifest.toHero._performSleightOfHand(
      centerController: centerController,
      targetCenter: manifest.toHeroLocation.center,
      sizeController: sizeController,
      targetSize: manifest.toHeroLocation.size,
    );
  }

  void _onProgressAnimationStatusChanged(AnimationStatus status) {
    if (manifest.isUserGestureTransition) return;

    if (status.isAnimating) return;

    manifest.routeAnimation
        .removeStatusListener(_onProgressAnimationStatusChanged);
    _routeAnimationComplete = true;
    handoverFlight();
    _endFlightIfBothAnimationsComplete();
  }

  void _onFlightAnimationStatusChanged(AnimationStatus status) {
    if (manifest.isUserGestureTransition) return;

    if (status.isAnimating) return;

    _flightAnimationComplete = true;
    _endFlightIfBothAnimationsComplete();
  }

  void _endFlightIfBothAnimationsComplete() {
    if (_flightAnimationComplete && _routeAnimationComplete) {
      onEnd();
    }
  }

  Widget _buildOverlay(BuildContext context) {
    final shuttle = manifest.shuttleBuilder(
      context,
      manifest.routeAnimation,
      manifest.direction,
      manifest.fromHero.context,
      manifest.toHero.context,
    );

    final centerController = this.centerController;
    final sizeController = this.sizeController;

    if (centerController == null || sizeController == null) return shuttle;

    return AnimatedBuilder(
      animation: manifest.routeAnimation,
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

  void dispose() {
    manifest.toHero._endFlight();
    manifest.controllingHero._disposeSpringControllers();

    manifest.dispose();

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
