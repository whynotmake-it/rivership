// ignore_for_file: prefer_asserts_with_message

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Hero;
import 'package:springster/springster.dart';

typedef _OnFlightEnded = void Function(_SuperheroFlight flight);

class Superhero extends StatefulWidget {
  /// Create a superhero.
  ///
  /// The [child] parameter and all of the its descendants must not be
  /// [Superhero]es.
  const Superhero({
    super.key,
    required this.tag,
    this.flightShuttleBuilder,
    this.placeholderBuilder,
    this.transitionOnUserGestures = false,
    required this.child,
  });

  /// The identifier for this particular hero. If the tag of this hero matches
  /// the tag of a hero on a [PageRoute] that we're navigating to or from, then
  /// a hero animation will be triggered.
  final Object tag;

  /// The widget subtree that will "fly" from one route to another during a
  /// [Navigator] push or pop transition.
  ///
  /// The appearance of this subtree should be similar to the appearance of
  /// the subtrees of any other heroes in the application with the same [tag].
  /// Changes in scale and aspect ratio work well in hero animations, changes
  /// in layout or composition do not.
  ///
  /// {@macro flutter.widgets.ProxyWidget.child}
  final Widget child;

  /// Optional override to supply a widget that's shown during the hero's flight.
  ///
  /// This in-flight widget can depend on the route transition's animation as
  /// well as the incoming and outgoing routes' [Superhero] descendants' widgets and
  /// layout.
  ///
  /// When both the source and destination [Superhero]es provide a [flightShuttleBuilder],
  /// the destination's [flightShuttleBuilder] takes precedence.
  ///
  /// If none is provided, the destination route's Hero child is shown in-flight
  /// by default.
  ///
  /// ## Limitations
  ///
  /// If a widget built by [flightShuttleBuilder] takes part in a [Navigator]
  /// push transition, that widget or its descendants must not have any
  /// [GlobalKey] that is used in the source Hero's descendant widgets. That is
  /// because both subtrees will be included in the widget tree during the Hero
  /// flight animation, and [GlobalKey]s must be unique across the entire widget
  /// tree.
  ///
  /// If the said [GlobalKey] is essential to your application, consider providing
  /// a custom [placeholderBuilder] for the source Hero, to avoid the [GlobalKey]
  /// collision, such as a builder that builds an empty [SizedBox], keeping the
  /// Hero [child]'s original size.
  final HeroFlightShuttleBuilder? flightShuttleBuilder;

  /// Placeholder widget left in place as the Hero's [child] once the flight takes
  /// off.
  ///
  /// By default the placeholder widget is an empty [SizedBox] keeping the Hero
  /// child's original size, unless this Hero is a source Hero of a [Navigator]
  /// push transition, in which case [child] will be a descendant of the placeholder
  /// and will be kept [Offstage] during the Hero's flight.
  final HeroPlaceholderBuilder? placeholderBuilder;

  /// Whether to perform the hero transition if the [PageRoute] transition was
  /// triggered by a user gesture, such as a back swipe on iOS.
  ///
  /// If [Superhero]es with the same [tag] on both the from and the to routes have
  /// [transitionOnUserGestures] set to true, a back swipe gesture will
  /// trigger the same hero animation as a programmatically triggered push or
  /// pop.
  ///
  /// The route being popped to or the bottom route must also have
  /// [PageRoute.maintainState] set to true for a gesture triggered hero
  /// transition to work.
  ///
  /// Defaults to false.
  final bool transitionOnUserGestures;

  // Returns a map of all of the heroes in `context` indexed by hero tag that
  // should be considered for animation when `navigator` transitions from one
  // PageRoute to another.
  static Map<Object, _SuperheroState> _allHeroesFor(
    BuildContext context,
    bool isUserGestureTransition,
    NavigatorState navigator,
  ) {
    final result = <Object, _SuperheroState>{};

    void inviteHero(StatefulElement hero, Object tag) {
      assert(() {
        if (result.containsKey(tag)) {
          throw FlutterError.fromParts(<DiagnosticsNode>[
            ErrorSummary(
              'There are multiple heroes that share the same tag within a subtree.',
            ),
            ErrorDescription(
              'Within each subtree for which heroes are to be animated (i.e. a PageRoute subtree), '
              'each Hero must have a unique non-null tag.\n'
              'In this case, multiple heroes had the following tag: $tag',
            ),
            DiagnosticsProperty<StatefulElement>(
              'Here is the subtree for one of the offending heroes',
              hero,
              linePrefix: '# ',
              style: DiagnosticsTreeStyle.dense,
            ),
          ]);
        }
        return true;
      }());
      final heroWidget = hero.widget as Superhero;
      final heroState = hero.state as _SuperheroState;
      if (!isUserGestureTransition || heroWidget.transitionOnUserGestures) {
        result[tag] = heroState;
      } else {
        // If transition is not allowed, we need to make sure hero is not hidden.
        // A hero can be hidden previously due to hero transition.
        heroState.endFlight();
      }
    }

    void visitor(Element element) {
      final widget = element.widget;
      if (widget is Superhero) {
        final hero = element as StatefulElement;
        final tag = widget.tag;
        if (Navigator.of(hero) == navigator) {
          inviteHero(hero, tag);
        } else {
          // The nearest navigator to the Hero is not the Navigator that is
          // currently transitioning from one route to another. This means
          // the Hero is inside a nested Navigator and should only be
          // considered for animation if it is part of the top-most route in
          // that nested Navigator and if that route is also a PageRoute.
          final heroRoute = ModalRoute.of(hero);
          if (heroRoute != null &&
              heroRoute is PageRoute &&
              heroRoute.isCurrent) {
            inviteHero(hero, tag);
          }
        }
      } else if (widget is HeroMode && !widget.enabled) {
        return;
      }
      element.visitChildren(visitor);
    }

    context.visitChildElements(visitor);
    return result;
  }

  @override
  State<Superhero> createState() => _SuperheroState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Object>('tag', tag));
  }
}

/// The [Superhero] widget displays different content based on whether it is in an
/// animated transition ("flight"), from/to another [Superhero] with the same tag:
///   * When [startFlight] is called, the real content of this [Superhero] will be
///     replaced by a "placeholder" widget.
///   * When the flight ends, the "toHero"'s [endFlight] method must be called
///     by the hero controller, so the real content of that [Superhero] becomes
///     visible again when the animation completes.
class _SuperheroState extends State<Superhero> {
  final GlobalKey _key = GlobalKey();
  Size? _placeholderSize;
  // Whether the placeholder widget should wrap the hero's child widget as its
  // own child, when `_placeholderSize` is non-null (i.e. the hero is currently
  // in its flight animation). See `startFlight`.
  bool _shouldIncludeChild = true;

  // The `shouldIncludeChildInPlaceholder` flag dictates if the child widget of
  // this hero should be included in the placeholder widget as a descendant.
  //
  // When a new hero flight animation takes place, a placeholder widget
  // needs to be built to replace the original hero widget. When
  // `shouldIncludeChildInPlaceholder` is set to true and `widget.placeholderBuilder`
  // is null, the placeholder widget will include the original hero's child
  // widget as a descendant, allowing the original element tree to be preserved.
  //
  // It is typically set to true for the *from* hero in a push transition,
  // and false otherwise.
  void startFlight({bool shouldIncludedChildInPlaceholder = false}) {
    _shouldIncludeChild = shouldIncludedChildInPlaceholder;
    assert(mounted);
    final box = context.findRenderObject()! as RenderBox;
    assert(box.hasSize);
    setState(() {
      _placeholderSize = box.size;
    });
  }

  // When `keepPlaceholder` is true, the placeholder will continue to be shown
  // after the flight ends. Otherwise the child of the Hero will become visible
  // and its TickerMode will be re-enabled.
  //
  // This method can be safely called even when this [Hero] is currently not in
  // a flight.
  void endFlight({bool keepPlaceholder = false}) {
    if (keepPlaceholder || _placeholderSize == null) {
      return;
    }

    _placeholderSize = null;
    if (mounted) {
      // Tell the widget to rebuild if it's mounted. _placeholderSize has already
      // been updated.
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    assert(
      context.findAncestorWidgetOfExactType<Superhero>() == null,
      'A Hero widget cannot be the descendant of another Hero widget.',
    );

    final showPlaceholder = _placeholderSize != null;

    if (showPlaceholder && widget.placeholderBuilder != null) {
      return widget.placeholderBuilder!(
        context,
        _placeholderSize!,
        widget.child,
      );
    }

    if (showPlaceholder && !_shouldIncludeChild) {
      return SizedBox(
        width: _placeholderSize!.width,
        height: _placeholderSize!.height,
      );
    }

    return SizedBox(
      width: _placeholderSize?.width,
      height: _placeholderSize?.height,
      child: Offstage(
        offstage: showPlaceholder,
        child: TickerMode(
          enabled: !showPlaceholder,
          child: KeyedSubtree(key: _key, child: widget.child),
        ),
      ),
    );
  }
}

// Everything known about a hero flight that's to be started or diverted.
class _HeroFlightManifest {
  _HeroFlightManifest({
    required this.type,
    required this.overlay,
    required this.navigatorSize,
    required this.fromRoute,
    required this.toRoute,
    required this.fromHero,
    required this.toHero,
    required this.shuttleBuilder,
    required this.isUserGestureTransition,
    required this.isDiverted,
  }) : assert(fromHero.widget.tag == toHero.widget.tag);

  final HeroFlightDirection type;
  final OverlayState overlay;
  final Size navigatorSize;
  final PageRoute<dynamic> fromRoute;
  final PageRoute<dynamic> toRoute;
  final _SuperheroState fromHero;
  final _SuperheroState toHero;
  final HeroFlightShuttleBuilder shuttleBuilder;
  final bool isUserGestureTransition;
  final bool isDiverted;

  Object get tag => fromHero.widget.tag;

  Duration get duration => type == HeroFlightDirection.push
      ? toRoute.transitionDuration
      : fromRoute.transitionDuration;

  SimpleSpring get spring => SimpleSpring.bouncy.copyWith(
        durationSeconds: duration.inMilliseconds / 1000,
      );

  CurvedAnimation? _routeAnimation;

  Animation<double> get routeAnimation {
    return _routeAnimation ??= CurvedAnimation(
      parent: (type == HeroFlightDirection.push)
          ? toRoute.animation!
          : fromRoute.animation!,
      curve: Curves.fastOutSlowIn,
      reverseCurve: isDiverted ? null : Curves.fastOutSlowIn.flipped,
    );
  }

  RectTween get tween {
    return switch (type) {
      HeroFlightDirection.push => RectTween(
          begin: fromHeroLocation,
          end: toHeroLocation,
        ),
      HeroFlightDirection.pop => RectTween(
          begin: toHeroLocation,
          end: fromHeroLocation,
        ),
    };
  }

  Rect get targetRect => isUserGestureTransition
      ? tween.evaluate(routeAnimation)!
      : toHeroLocation;

  // The bounding box for `context`'s render object,  in `ancestorContext`'s
  // render object's coordinate space.
  static Rect _boundingBoxFor(
    BuildContext context,
    BuildContext? ancestorContext,
  ) {
    final box = context.findRenderObject()! as RenderBox;

    assert(box.hasSize && box.size.isFinite);
    return MatrixUtils.transformRect(
      box.getTransformTo(ancestorContext?.findRenderObject()),
      Offset.zero & box.size,
    );
  }

  /// The bounding box of [fromHero], in [fromRoute]'s coordinate space.
  ///
  /// This property should only be accessed in [_SuperheroFlight.start].
  late final Rect fromHeroLocation =
      _boundingBoxFor(fromHero.context, fromRoute.subtreeContext);

  /// The bounding box of [toHero], in [toRoute]'s coordinate space.
  ///
  /// This property should only be accessed in [_SuperheroFlight.start] or
  /// [_SuperheroFlight.divert].
  late final Rect toHeroLocation =
      _boundingBoxFor(toHero.context, toRoute.subtreeContext);

  /// Whether this [_HeroFlightManifest] is valid and can be used to start or
  /// divert a [_SuperheroFlight].
  ///
  /// When starting or diverting a [_SuperheroFlight] with a brand new
  /// [_HeroFlightManifest], this flag must be checked to ensure the [RectTween]
  /// the [_HeroFlightManifest] produces does not contain coordinates that have
  /// [double.infinity] or [double.nan].
  late final bool isValid =
      toHeroLocation.isFinite && (isDiverted || fromHeroLocation.isFinite);

  @override
  String toString() {
    return '_HeroFlightManifest($type tag: $tag from route: ${fromRoute.settings} '
        'to route: ${toRoute.settings} with hero: $fromHero to $toHero)${isValid ? '' : ', INVALID'}';
  }

  @mustCallSuper
  void dispose() {
    _routeAnimation?.dispose();
  }
}

// Builds the in-flight hero widget.
class _SuperheroFlight {
  _SuperheroFlight(this.onFlightEnded) {
    // TODO(polina-c): stop duplicating code across disposables
    // https://github.com/flutter/flutter/issues/137435
    if (kFlutterMemoryAllocationsEnabled) {
      FlutterMemoryAllocations.instance.dispatchObjectCreated(
        library: 'package:flutter/widgets.dart',
        className: '$_SuperheroFlight',
        object: this,
      );
    }
  }

  final _OnFlightEnded onFlightEnded;

  // The manifest will be available once `start` is called, throughout the
  // flight's lifecycle.
  _HeroFlightManifest? _manifest;
  _HeroFlightManifest get manifest => _manifest!;

  set manifest(_HeroFlightManifest value) {
    _manifest?.dispose();
    _manifest = value;
  }

  OverlayEntry? overlayEntry;

  // The OverlayEntry WidgetBuilder callback for the hero's overlay.
  Widget _buildOverlay(BuildContext context) {
    return AnimatedBuilder(
      animation: manifest.routeAnimation,
      builder: (context, child) => SpringBuilder2D(
        onAnimationStatusChanged: _onSpringStatusChanged,
        spring: manifest.spring,
        value: (
          manifest.targetRect.topLeft.dx,
          manifest.targetRect.topLeft.dy,
        ),
        from: (
          manifest.fromHeroLocation.topLeft.dx,
          manifest.fromHeroLocation.topLeft.dy,
        ),
        builder: (context, center, child) => SpringBuilder2D(
          simulate: manifest.isUserGestureTransition == false,
          value: (
            manifest.targetRect.size.width,
            manifest.targetRect.size.height,
          ),
          from: (
            manifest.fromHeroLocation.size.width,
            manifest.fromHeroLocation.size.height,
          ),
          spring: manifest.spring,
          builder: (context, size, child) {
            final rect = center.toOffset() & Size(size.x, size.y);
            final offsets = RelativeRect.fromSize(rect, manifest.navigatorSize);
            return Positioned(
              top: offsets.top,
              right: offsets.right,
              bottom: offsets.bottom,
              left: offsets.left,
              child: IgnorePointer(
                child: FadeTransition(
                  opacity: AlwaysStoppedAnimation(1),
                  child: child,
                ),
              ),
            );
          },
          child: child,
        ),
        child: manifest.shuttleBuilder(
          context,
          manifest.routeAnimation,
          manifest.type,
          manifest.fromHero.context,
          manifest.toHero.context,
        ),
      ),
    );
  }

  void _onSpringStatusChanged(AnimationStatus status) {
    if (status.isAnimating || manifest.routeAnimation.isAnimating) {
      return;
    }

    assert(overlayEntry != null);
    assert(overlayEntry != null);
    overlayEntry!.remove();
    overlayEntry!.dispose();
    overlayEntry = null;
    // We want to keep the hero underneath the current page hidden. If
    // [AnimationStatus.completed], toHero will be the one on top and we keep
    // fromHero hidden. If [AnimationStatus.dismissed], the animation is
    // triggered but canceled before it finishes. In this case, we keep toHero
    // hidden instead.
    manifest.fromHero.endFlight(keepPlaceholder: status.isCompleted);
    manifest.toHero.endFlight(keepPlaceholder: status.isDismissed);
    onFlightEnded(this);
  }

  /// Releases resources.
  @mustCallSuper
  void dispose() {
    if (kFlutterMemoryAllocationsEnabled) {
      FlutterMemoryAllocations.instance.dispatchObjectDisposed(object: this);
    }
    if (overlayEntry != null) {
      overlayEntry!.remove();
      overlayEntry!.dispose();
      overlayEntry = null;
    }

    _manifest?.dispose();
  }

  // The simple case: we're either starting a push or a pop animation.
  void start(_HeroFlightManifest initialManifest) {
    manifest = initialManifest;

    final bool shouldIncludeChildInPlaceholder;
    switch (manifest.type) {
      case HeroFlightDirection.pop:
        shouldIncludeChildInPlaceholder = false;
      case HeroFlightDirection.push:
        shouldIncludeChildInPlaceholder = true;
    }

    manifest.fromHero.startFlight(
      shouldIncludedChildInPlaceholder: shouldIncludeChildInPlaceholder,
    );
    manifest.toHero.startFlight();
    manifest.overlay
        .insert(overlayEntry = OverlayEntry(builder: _buildOverlay));
  }

  // While this flight's hero was in transition a push or a pop occurred for
  // routes with the same hero. Redirect the in-flight hero to the new toRoute.
  void divert(_HeroFlightManifest newManifest) {
    assert(manifest.tag == newManifest.tag);
    if (manifest.type == HeroFlightDirection.push &&
        newManifest.type == HeroFlightDirection.pop) {
      assert(manifest.fromHero == newManifest.toHero);
      assert(manifest.toHero == newManifest.fromHero);
      assert(manifest.fromRoute == newManifest.toRoute);
      assert(manifest.toRoute == newManifest.fromRoute);
    } else if (manifest.type == HeroFlightDirection.pop &&
        newManifest.type == HeroFlightDirection.push) {
      assert(manifest.toHero == newManifest.fromHero);
      assert(manifest.toRoute == newManifest.fromRoute);

      if (manifest.fromHero != newManifest.toHero) {
        manifest.fromHero.endFlight(keepPlaceholder: true);
        newManifest.toHero.startFlight();
      }
    } else {
      // A push or a pop flight is heading to a new route, i.e.
      // manifest.type == _HeroFlightType.push && newManifest.type == _HeroFlightType.push ||
      // manifest.type == _HeroFlightType.pop && newManifest.type == _HeroFlightType.pop
      assert(manifest.fromHero != newManifest.fromHero);
      assert(manifest.toHero != newManifest.toHero);

      manifest.fromHero.endFlight(keepPlaceholder: true);
      manifest.toHero.endFlight(keepPlaceholder: true);

      // Let the heroes in each of the routes rebuild with their placeholders.
      newManifest.fromHero.startFlight(
        shouldIncludedChildInPlaceholder:
            newManifest.type == HeroFlightDirection.push,
      );
      newManifest.toHero.startFlight();

      // Let the transition overlay on top of the routes also rebuild since
      // we cleared the old shuttle.
      overlayEntry!.markNeedsBuild();
    }

    manifest = newManifest;
  }

  @override
  String toString() {
    final from = manifest.fromRoute.settings;
    final to = manifest.toRoute.settings;
    final tag = manifest.tag;
    return 'HeroFlight(for: $tag, from: $from, to: $to)';
  }
}

/// A [Navigator] observer that manages [Superhero] transitions.
///
/// An instance of [SuperheroController] should be used in [Navigator.observers].
/// This is done automatically by [MaterialApp].
class SuperheroController extends NavigatorObserver {
  /// Creates a hero controller.
  SuperheroController() {
    // TODO(polina-c): stop duplicating code across disposables
    // https://github.com/flutter/flutter/issues/137435
    if (kFlutterMemoryAllocationsEnabled) {
      FlutterMemoryAllocations.instance.dispatchObjectCreated(
        library: 'package:superhero/superhero.dart',
        className: '$SuperheroController',
        object: this,
      );
    }
  }

  // All of the heroes that are currently in the overlay and in motion.
  // Indexed by the hero tag.
  final Map<Object, _SuperheroFlight> _flights = <Object, _SuperheroFlight>{};

  @override
  void didChangeTop(Route<dynamic> topRoute, Route<dynamic>? previousTopRoute) {
    assert(topRoute.isCurrent);
    assert(navigator != null);
    if (previousTopRoute == null) {
      return;
    }
    // Don't trigger another flight when a pop is committed as a user gesture
    // back swipe is snapped.
    if (!navigator!.userGestureInProgress) {
      _maybeStartHeroTransition(
        fromRoute: previousTopRoute,
        toRoute: topRoute,
        isUserGestureTransition: false,
      );
    }
  }

  @override
  void didStartUserGesture(
    Route<dynamic> route,
    Route<dynamic>? previousRoute,
  ) {
    assert(navigator != null);
    _maybeStartHeroTransition(
      fromRoute: route,
      toRoute: previousRoute,
      isUserGestureTransition: true,
    );
  }

  @override
  void didStopUserGesture() {
    if (navigator!.userGestureInProgress) {
      return;
    }

    // When the user gesture ends, if the user horizontal drag gesture initiated
    // the flight (i.e. the back swipe) didn't move towards the pop direction at
    // all, the animation will not play and thus the status update callback
    // _handleAnimationUpdate will never be called when the gesture finishes. In
    // this case the initiated flight needs to be manually invalidated.
    bool isInvalidFlight(_SuperheroFlight flight) {
      return flight.manifest.isUserGestureTransition &&
          flight.manifest.type == HeroFlightDirection.pop &&
          ReverseAnimation(flight.manifest.routeAnimation).isDismissed;
    }

    final invalidFlights =
        _flights.values.where(isInvalidFlight).toList(growable: false);

    // Treat these invalidated flights as dismissed. Calling
    // _handleAnimationUpdate will also remove the flight from _flights.
    for (final flight in invalidFlights) {
      flight._onSpringStatusChanged(AnimationStatus.dismissed);
    }
  }

  // If we're transitioning between different page routes, start a hero
  // transition after the toRoute has been laid out with its animation's value
  // at 1.0.
  void _maybeStartHeroTransition({
    required Route<dynamic>? fromRoute,
    required Route<dynamic>? toRoute,
    required bool isUserGestureTransition,
  }) {
    if (toRoute == fromRoute ||
        toRoute is! PageRoute<dynamic> ||
        fromRoute is! PageRoute<dynamic>) {
      return;
    }
    final newRouteAnimation = toRoute.animation!;
    final oldRouteAnimation = fromRoute.animation!;
    final HeroFlightDirection flightType;
    switch ((
      isUserGestureTransition,
      oldRouteAnimation.status,
      newRouteAnimation.status
    )) {
      case (true, _, _):
      case (_, AnimationStatus.reverse, _):
        flightType = HeroFlightDirection.pop;
      case (_, _, AnimationStatus.forward):
        flightType = HeroFlightDirection.push;
      default:
        return;
    }

    // A user gesture may have already completed the pop, or we might be the
    // initial route
    switch (flightType) {
      case HeroFlightDirection.pop:
        if (fromRoute.animation!.value == 0.0) {
          return;
        }
      case HeroFlightDirection.push:
        if (toRoute.animation!.value == 1.0) {
          return;
        }
    }

    // For pop transitions driven by a user gesture: if the "to" page has
    // maintainState = true, then the hero's final dimensions can be measured
    // immediately because their page's layout is still valid.
    if (isUserGestureTransition &&
        flightType == HeroFlightDirection.pop &&
        toRoute.maintainState) {
      _startHeroTransition(
        fromRoute,
        toRoute,
        flightType,
        isUserGestureTransition,
      );
    } else {
      // Otherwise, delay measuring until the end of the next frame to allow
      // the 'to' route to build and layout.

      // Putting a route offstage changes its animation value to 1.0. Once this
      // frame completes, we'll know where the heroes in the `to` route are
      // going to end up, and the `to` route will go back onstage.
      toRoute.offstage = toRoute.animation!.value == 0.0;

      WidgetsBinding.instance.addPostFrameCallback(
        (Duration value) {
          if (fromRoute.navigator == null || toRoute.navigator == null) {
            return;
          }
          _startHeroTransition(
            fromRoute,
            toRoute,
            flightType,
            isUserGestureTransition,
          );
        },
        debugLabel: 'HeroController.startTransition',
      );
    }
  }

  // Find the matching pairs of heroes in from and to and either start or a new
  // hero flight, or divert an existing one.
  void _startHeroTransition(
    PageRoute<dynamic> from,
    PageRoute<dynamic> to,
    HeroFlightDirection flightType,
    bool isUserGestureTransition,
  ) {
    // If the `to` route was offstage, then we're implicitly restoring its
    // animation value back to what it was before it was "moved" offstage.
    to.offstage = false;

    final navigator = this.navigator;
    final overlay = navigator?.overlay;
    // If the navigator or the overlay was removed before this end-of-frame
    // callback was called, then don't actually start a transition, and we don't
    // have to worry about any Hero widget we might have hidden in a previous
    // flight, or ongoing flights.
    if (navigator == null || overlay == null) {
      return;
    }

    final navigatorRenderObject = navigator.context.findRenderObject();

    if (navigatorRenderObject is! RenderBox) {
      assert(
        false,
        'Navigator $navigator has an invalid RenderObject type '
        '${navigatorRenderObject.runtimeType}.',
      );
      return;
    }
    assert(navigatorRenderObject.hasSize);

    // At this point, the toHeroes may have been built and laid out for the
    // first time.
    //
    // If `fromSubtreeContext` is null, call endFlight on all toHeroes, for good
    // measure.
    // If `toSubtreeContext` is null abort existingFlights.
    final fromSubtreeContext = from.subtreeContext;
    final fromHeroes = fromSubtreeContext != null
        ? Superhero._allHeroesFor(
            fromSubtreeContext,
            isUserGestureTransition,
            navigator,
          )
        : const <Object, _SuperheroState>{};
    final toSubtreeContext = to.subtreeContext;
    final toHeroes = toSubtreeContext != null
        ? Superhero._allHeroesFor(
            toSubtreeContext,
            isUserGestureTransition,
            navigator,
          )
        : const <Object, _SuperheroState>{};

    for (final fromHeroEntry in fromHeroes.entries) {
      final tag = fromHeroEntry.key;
      final fromHero = fromHeroEntry.value;
      final toHero = toHeroes[tag];
      final existingFlight = _flights[tag];
      final manifest = toHero == null
          ? null
          : _HeroFlightManifest(
              type: flightType,
              overlay: overlay,
              navigatorSize: navigatorRenderObject.size,
              fromRoute: from,
              toRoute: to,
              fromHero: fromHero,
              toHero: toHero,
              shuttleBuilder: toHero.widget.flightShuttleBuilder ??
                  fromHero.widget.flightShuttleBuilder ??
                  _defaultHeroFlightShuttleBuilder,
              isUserGestureTransition: isUserGestureTransition,
              isDiverted: existingFlight != null,
            );

      // Only proceed with a valid manifest. Otherwise abort the existing
      // flight, and call endFlight when this for loop finishes.
      if (manifest != null && manifest.isValid) {
        toHeroes.remove(tag);
        if (existingFlight != null) {
          existingFlight.divert(manifest);
        } else {
          _flights[tag] = _SuperheroFlight(_handleFlightEnded)..start(manifest);
        }
      } else {
        existingFlight?._onSpringStatusChanged(AnimationStatus.dismissed);
      }
    }

    // The remaining entries in toHeroes are those failed to participate in a
    // new flight (for not having a valid manifest).
    //
    // This can happen in a route pop transition when a fromHero is no longer
    // mounted, or kept alive by the [KeepAlive] mechanism but no longer visible.
    // TODO(LongCatIsLooong): resume aborted flights: https://github.com/flutter/flutter/issues/72947
    for (final toHero in toHeroes.values) {
      toHero.endFlight();
    }
  }

  void _handleFlightEnded(_SuperheroFlight flight) {
    _flights.remove(flight.manifest.tag)?.dispose();
  }

  Widget _defaultHeroFlightShuttleBuilder(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection flightDirection,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    final toHero = toHeroContext.widget as Superhero;

    final toMediaQueryData = MediaQuery.maybeOf(toHeroContext);
    final fromMediaQueryData = MediaQuery.maybeOf(fromHeroContext);

    if (toMediaQueryData == null || fromMediaQueryData == null) {
      return toHero.child;
    }

    final fromHeroPadding = fromMediaQueryData.padding;
    final toHeroPadding = toMediaQueryData.padding;

    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: toMediaQueryData.copyWith(
            padding: (flightDirection == HeroFlightDirection.push)
                ? EdgeInsetsTween(
                    begin: fromHeroPadding,
                    end: toHeroPadding,
                  ).evaluate(animation)
                : EdgeInsetsTween(
                    begin: toHeroPadding,
                    end: fromHeroPadding,
                  ).evaluate(animation),
          ),
          child: toHero.child,
        );
      },
    );
  }

  /// Releases resources.
  @mustCallSuper
  void dispose() {
    // TODO(polina-c): stop duplicating code across disposables
    // https://github.com/flutter/flutter/issues/137435
    if (kFlutterMemoryAllocationsEnabled) {
      FlutterMemoryAllocations.instance.dispatchObjectDisposed(object: this);
    }

    for (final flight in _flights.values) {
      flight.dispose();
    }
  }
}

/// Enables or disables [Superhero]es in the widget subtree.
///
/// {@youtube 560 315 https://www.youtube.com/watch?v=AaIASk2u1C0}
///
/// When [enabled] is false, all [Superhero] widgets in this subtree will not be
/// involved in hero animations.
///
/// When [enabled] is true (the default), [Superhero] widgets may be involved in
/// hero animations, as usual.
class HeroMode extends StatelessWidget {
  /// Creates a widget that enables or disables [Superhero]es.
  const HeroMode({
    super.key,
    required this.child,
    this.enabled = true,
  });

  /// The subtree to place inside the [HeroMode].
  final Widget child;

  /// Whether or not [Superhero]es are enabled in this subtree.
  ///
  /// If this property is false, the [Superhero]es in this subtree will not animate
  /// on route changes. Otherwise, they will animate as usual.
  ///
  /// Defaults to true.
  final bool enabled;

  @override
  Widget build(BuildContext context) => child;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      FlagProperty(
        'mode',
        value: enabled,
        ifTrue: 'enabled',
        ifFalse: 'disabled',
        showName: true,
      ),
    );
  }
}
