part of 'superheroes.dart';

class _FlightManifest {
  _FlightManifest({
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
    required this.spring,
    required this.adjustToRouteTransitionDuration,
  }) : assert(
          fromHero.widget.tag == toHero.widget.tag,
          'fromHero and toHero must have the same tag',
        );

  final HeroFlightDirection direction;
  final OverlayState overlay;
  final Size navigatorSize;
  final PageRoute<dynamic> fromRoute;
  final PageRoute<dynamic> toRoute;
  final _SuperheroState fromHero;
  final _SuperheroState toHero;
  final HeroFlightShuttleBuilder shuttleBuilder;
  final bool isUserGestureTransition;
  final bool isDiverted;
  final bool adjustToRouteTransitionDuration;
  final SimpleSpring spring;

  Object? get tag => fromHero.widget.tag;

  Duration get duration => direction == HeroFlightDirection.push
      ? toRoute.transitionDuration
      : fromRoute.transitionDuration;

  SimpleSpring get adjustedSpring => adjustToRouteTransitionDuration
      ? spring.copyWith(durationSeconds: duration.inMilliseconds / 1000)
      : spring;

  CurvedAnimation? _routeAnimation;

  Animation<double> get routeAnimation {
    return _routeAnimation ??= CurvedAnimation(
      parent: (direction == HeroFlightDirection.push)
          ? toRoute.animation!
          : fromRoute.animation!,
      curve: (direction == HeroFlightDirection.push)
          ? Curves.fastOutSlowIn
          : Curves.fastOutSlowIn.flipped,
      reverseCurve: isDiverted ? null : Curves.fastOutSlowIn.flipped,
    );
  }

  // The bounding box for `context`'s render object,  in `ancestorContext`'s
  // render object's coordinate space.
  static Rect _boundingBoxFor(
    BuildContext context,
    BuildContext? ancestorContext,
  ) {
    final box = context.findRenderObject()! as RenderBox;

    assert(
      box.hasSize && box.size.isFinite,
      'RenderObject must have a finite size to be used as a hero',
    );
    return MatrixUtils.transformRect(
      box.getTransformTo(ancestorContext?.findRenderObject()),
      Offset.zero & box.size,
    );
  }

  /// The bounding box of [fromHero], in [fromRoute]'s coordinate space.

  late final Rect fromHeroLocation =
      _boundingBoxFor(fromHero.context, fromRoute.subtreeContext);

  /// The bounding box of [toHero], in [toRoute]'s coordinate space.
  late final Rect toHeroLocation =
      _boundingBoxFor(toHero.context, toRoute.subtreeContext);

  /// Whether this [_FlightManifest] is valid and can be used to start or
  /// divert a [_SuperheroFlight].
  ///
  /// When starting or diverting a [_SuperheroFlight] with a brand new
  /// [_FlightManifest], this flag must be checked to ensure the [RectTween]
  /// the [_FlightManifest] produces does not contain coordinates that have
  /// [double.infinity] or [double.nan].
  late final bool isValid =
      toHeroLocation.isFinite && (isDiverted || fromHeroLocation.isFinite);

  @override
  String toString() {
    return '_HeroFlightManifest($direction tag: $tag from route: '
        '${fromRoute.settings} to route: ${toRoute.settings} with hero: '
        '$fromHero to $toHero)${isValid ? '' : ', INVALID'}';
  }

  @mustCallSuper
  void dispose() {
    _routeAnimation?.dispose();
  }
}