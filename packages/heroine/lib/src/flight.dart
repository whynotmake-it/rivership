part of 'heroines.dart';

class _HeroineFlight {
  _HeroineFlight(this._manifest, this.onEnd) {
    _manifest.toHero._initSpringControllersWithFromHero(
      _manifest,
      _onFlightAnimationStatusChanged,
    );
  }

  _FlightManifest _manifest;

  final VoidCallback onEnd;

  OverlayEntry? _overlayEntry;

  SpringSimulationController2D get _centerController =>
      _manifest.toHero._centerController!;
  SpringSimulationController2D get _sizeController =>
      _manifest.toHero._sizeController!;

  void startFlight() {
    _manifest.toHero._startFlight(_manifest);

    if (_manifest.isUserGestureTransition) {
      return;
    }

    _manifest.fromHero._startFlight(_manifest);
    if (_overlayEntry == null) {
      _manifest.overlay.insert(
        _overlayEntry = OverlayEntry(builder: _buildOverlay),
      );
    }

    final fromHeroVelocity = HeroineVelocity.of(_manifest.fromHero.context);
    _manifest.routeAnimation
        .addStatusListener(_onProgressAnimationStatusChanged);

    _centerController
      ..spring = _manifest.spring
      ..animateTo(
        (
          _manifest.toHeroLocation.center.dx,
          _manifest.toHeroLocation.center.dy,
        ),
        withVelocity: (
          fromHeroVelocity?.pixelsPerSecond.dx ?? 0,
          fromHeroVelocity?.pixelsPerSecond.dy ?? 0,
        ),
      );

    _sizeController
      ..spring = _manifest.spring
      ..animateTo(
        (
          _manifest.toHeroLocation.size.width,
          _manifest.toHeroLocation.size.height,
        ),
      );
  }

  void divert(_FlightManifest manifest) {
    // If we are diverting a user gesture transition to a non-user gesture
    // transition, we need to set the initial values of the controllers to
    // the values of the from hero to make sure the animation is smooth.
    if (_manifest.isUserGestureTransition &&
        !manifest.isUserGestureTransition) {
      _centerController.value = (
        manifest.fromHeroLocation.center.dx,
        manifest.fromHeroLocation.center.dy,
      );
      _sizeController.value = (
        manifest.fromHeroLocation.size.width,
        manifest.fromHeroLocation.size.height,
      );
    }

    _manifest.dispose();
    _manifest.routeAnimation
        .removeStatusListener(_onProgressAnimationStatusChanged);

    manifest.toHero._initRedirectedSpringControllers(
      _centerController,
      _sizeController,
    );
    _manifest.toHero._unlinkSpringControllers();
    _manifest.toHero._startFlight(manifest);

    _manifest = manifest;

    startFlight();
  }

  void handoverFlight() {
    _removeOverlay();

    _manifest.toHero._performSleightOfHand(
      centerController: _centerController,
      targetCenter: (
        _manifest.toHeroLocation.center.dx,
        _manifest.toHeroLocation.center.dy,
      ),
      sizeController: _sizeController,
      targetSize: (
        _manifest.toHeroLocation.size.width,
        _manifest.toHeroLocation.size.height,
      ),
    );
  }

  void _onProgressAnimationStatusChanged(AnimationStatus status) {
    if (_manifest.isUserGestureTransition) return;

    if (status.isAnimating) return;

    _manifest.routeAnimation
        .removeStatusListener(_onProgressAnimationStatusChanged);
    handoverFlight();
  }

  void _onFlightAnimationStatusChanged(AnimationStatus status) {
    if (_manifest.isUserGestureTransition) return;

    if (status.isAnimating) return;

    onEnd();
  }

  Widget _buildOverlay(BuildContext context) {
    final shuttle = _manifest.shuttleBuilder(
      context,
      _manifest.routeAnimation,
      _manifest.direction,
      _manifest.fromHero.context,
      _manifest.toHero.context,
    );
    return AnimatedBuilder(
      animation: _manifest.routeAnimation,
      builder: (context, child) => Positioned(
        top: _centerController.value.y - _sizeController.value.y / 2,
        left: _centerController.value.x - _sizeController.value.x / 2,
        width: _sizeController.value.x,
        height: _sizeController.value.y,
        child: child!,
      ),
      child: IgnorePointer(
        // TODO(timcreatedit): allow configuring this
        child: shuttle,
      ),
    );
  }

  void dispose() {
    _manifest.toHero._endFlight();

    _manifest.dispose();

    if (_overlayEntry != null) {
      _removeOverlay();
    }
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry?.dispose();
    _overlayEntry = null;
  }
}
