part of 'superheroes.dart';

class _SuperheroFlight {
  _SuperheroFlight(this._manifest, this.onEnd) {
    _initSpringControllers();
  }

  _FlightManifest _manifest;

  final VoidCallback onEnd;

  OverlayEntry? _overlayEntry;

  late SpringSimulationController2D _centerController;
  late SpringSimulationController2D _sizeController;

  void startFlight() {
    print('startFlight');
    _manifest.fromHero._startFlight(_manifest);
    _manifest.toHero._startFlight(_manifest);

    if (_overlayEntry == null) {
      _manifest.overlay.insert(
        _overlayEntry = OverlayEntry(builder: _buildOverlay),
      );
    }
    _manifest.routeAnimation
        .addStatusListener(_onProgressAnimationStatusChanged);

    _centerController
      ..spring = _manifest.spring
      ..animateTo(
        (
          _manifest.toHeroLocation.center.dx,
          _manifest.toHeroLocation.center.dy,
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
    print('divert');

    _manifest.dispose();
    _manifest.routeAnimation
        .removeStatusListener(_onProgressAnimationStatusChanged);

    _manifest = manifest;

    startFlight();
  }

  void handoverFlight() {
    print('handoverFlight');
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
    if (status == AnimationStatus.completed ||
        status == AnimationStatus.dismissed) {
      _manifest.routeAnimation
          .removeStatusListener(_onProgressAnimationStatusChanged);
      handoverFlight();
    }
  }

  void _onFlightAnimationStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed ||
        status == AnimationStatus.dismissed) {
      onEnd();
    }
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
        ignoring: true,
        child: shuttle,
      ),
    );
  }

  void dispose() {
    _manifest.fromHero._endFlight();
    _manifest.toHero._endFlight();

    _manifest.dispose();
    _centerController.dispose();
    _sizeController.dispose();

    if (_overlayEntry != null) {
      _removeOverlay();
    }
  }

  void _initSpringControllers() {
    _centerController = SpringSimulationController2D(
      vsync: _manifest.overlay,
      spring: _manifest.adjustedSpring,
      initialValue: (
        _manifest.fromHeroLocation.center.dx,
        _manifest.fromHeroLocation.center.dy,
      ),
    )..addStatusListener(_onFlightAnimationStatusChanged);

    _sizeController = SpringSimulationController2D(
      vsync: _manifest.overlay,
      spring: _manifest.adjustedSpring,
      initialValue: (
        _manifest.fromHeroLocation.size.width,
        _manifest.fromHeroLocation.size.height,
      ),
    );
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry?.dispose();
    _overlayEntry = null;
  }
}
