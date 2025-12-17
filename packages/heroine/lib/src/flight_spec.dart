part of 'heroines.dart';

/// Specification for a heroine flight animation.
///
/// Contains all the immutable configuration needed to describe a flight:
/// - The [direction] (push or pop)
/// - The source ([fromHero]) and destination ([toHero]) heroines
/// - The routes being transitioned between
/// - The visual configuration ([shuttleBuilder], [motion], [zIndex])
///
/// Also provides computed properties for the flight:
/// - [fromHeroLocation] and [toHeroLocation]: the bounding boxes
/// - [routeAnimation]: the animation driving the route transition
/// - [isValid]: whether this flight can actually be executed
///
/// The [_FlightController] uses this specification to orchestrate the flight.
class _FlightSpec {
  _FlightSpec({
    required this.direction,
    required this.overlay,
    required this.navigatorSize,
    required this.fromRoute,
    required this.toRoute,
    required this.fromHero,
    required this.toHero,
    required this.shuttleBuilder,
    required this.isUserGestureTransition,
    required this.isDiverted,
    required this.motion,
    this.zIndex,
  })  : fromHeroLocation = _locationFor(fromHero, fromRoute.subtreeContext),
        toHeroLocation = _locationFor(toHero, toRoute.subtreeContext),
        assert(
          fromHero.widget.tag == toHero.widget.tag,
          'fromHero and toHero must have the same tag',
        );

  // ---------------------------------------------------------------------------
  // Flight Direction & Routes
  // ---------------------------------------------------------------------------

  /// Whether this is a push or pop transition.
  final HeroFlightDirection direction;

  /// The route we're transitioning from.
  final PageRoute<dynamic> fromRoute;

  /// The route we're transitioning to.
  final PageRoute<dynamic> toRoute;

  // ---------------------------------------------------------------------------
  // Heroes
  // ---------------------------------------------------------------------------

  /// The heroine widget state on the source route.
  final _HeroineState fromHero;

  /// The heroine widget state on the destination route.
  final _HeroineState toHero;

  /// The shared tag identifying this hero pair.
  Object? get tag => fromHero.widget.tag;

  /// The hero whose [TickerProvider] owns the animation controllers.
  ///
  /// For user gesture transitions, this is [fromHero] since the gesture
  /// originates from the source page. Otherwise, it's [toHero].
  _HeroineState get controllingHero =>
      isUserGestureTransition ? fromHero : toHero;

  // ---------------------------------------------------------------------------
  // Visual Configuration
  // ---------------------------------------------------------------------------

  /// The overlay where the flying heroine is rendered.
  final OverlayState overlay;

  /// The size of the navigator, used for positioning.
  final Size navigatorSize;

  /// Builds the visual representation of the hero during flight.
  final HeroineShuttleBuilder shuttleBuilder;

  /// The motion (spring/curve) for the position/size animation.
  final Motion motion;

  /// Z-index for layering multiple simultaneous flights.
  final int? zIndex;

  // ---------------------------------------------------------------------------
  // Flight State
  // ---------------------------------------------------------------------------

  /// Whether this flight was triggered by a user gesture (e.g., swipe back).
  final bool isUserGestureTransition;

  /// Whether this flight is a redirect from an existing flight.
  final bool isDiverted;

  // ---------------------------------------------------------------------------
  // Computed Properties
  // ---------------------------------------------------------------------------

  /// The duration of the route transition.
  Duration get duration => direction == HeroFlightDirection.push
      ? toRoute.transitionDuration
      : fromRoute.transitionDuration;

  /// The curve from the shuttle builder.
  Curve get curve => shuttleBuilder.curve;

  CurvedAnimation? _routeAnimation;

  /// The animation that drives the route transition progress.
  ///
  /// This is used to:
  /// 1. Animate the shuttle builder's visual transition
  /// 2. Know when the route transition completes
  Animation<double> get routeAnimation {
    return _routeAnimation ??= CurvedAnimation(
      parent: (direction == HeroFlightDirection.push)
          ? toRoute.animation!
          : fromRoute.animation!,
      curve: (direction == HeroFlightDirection.push) ? curve : curve.flipped,
      reverseCurve: isDiverted ? null : curve.flipped,
    );
  }

  /// The bounding box of [fromHero], in [fromRoute]'s coordinate space.
  final HeroineLocation fromHeroLocation;

  /// The bounding box of [toHero], in [toRoute]'s coordinate space.
  final HeroineLocation toHeroLocation;

  /// Whether this specification is valid and can be used to start a flight.
  ///
  /// A specification is invalid if the hero locations contain non-finite
  /// coordinates ([double.infinity] or [double.nan]).
  late final bool isValid =
      toHeroLocation.isValid && (isDiverted || fromHeroLocation.isValid);

  // ---------------------------------------------------------------------------
  // Helper Methods
  // ---------------------------------------------------------------------------

  /// Computes the bounding box for a context's render object,
  /// in an ancestor context's coordinate space.
  static HeroineLocation _locationFor(
    _HeroineState state,
    BuildContext? ancestorContext,
  ) {
    final box = state.context.findRenderObject()! as RenderBox;

    assert(
      box.hasSize && box.size.isFinite,
      'RenderObject must have a finite size to be used as a hero',
    );

    final rect = MatrixUtils.transformRect(
      box.getTransformTo(ancestorContext?.findRenderObject()),
      Offset.zero & box.size,
    );

    // TODO(tim): find rotation here
    return HeroineLocation(boundingBox: rect);
  }

  @override
  String toString() {
    return '_FlightSpec($direction tag: $tag from route: '
        '${fromRoute.settings} to route: ${toRoute.settings} with hero: '
        '$fromHero to $toHero)${isValid ? '' : ', INVALID'}';
  }

  /// Disposes of any resources held by this specification.
  @mustCallSuper
  void dispose() {
    _routeAnimation?.dispose();
  }
}
