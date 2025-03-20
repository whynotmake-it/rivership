import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:heroine/src/heroine_velocity.dart';
import 'package:heroine/src/shuttle_builders.dart';
import 'package:springster/springster.dart';

part 'flight.dart';
part 'manifest.dart';

/// An equivalent of [Hero] that is animated across routes using spring
/// simulations.
///
/// This widget is mostly a drop-in replacement for [Hero], so you can expect
/// most things to work the same way.
class Heroine extends StatefulWidget {
  /// Creates a new [Heroine] widget.
  const Heroine({
    required this.child,
    required this.tag,
    super.key,
    this.spring = const Spring(),
    this.placeholderBuilder,
    this.flightShuttleBuilder,
    this.adjustToRouteTransitionDuration = false,
  });

  /// The identifier for this particular hero. If the tag of this hero matches
  /// the tag of a hero on a [PageRoute] that we're navigating to or from, then
  /// a hero animation will be triggered.
  ///
  /// Make sure that the tags on both heroes are equal using `==`.
  final Object tag;

  /// The widget subtree that will "fly" from one route to another during a
  /// [Navigator] push or pop transition.
  ///
  /// The appearance of this subtree should be similar to the appearance of
  /// the subtrees of any other heroes in the application with the same [tag].
  /// Changes in scale and aspect ratio work well in [Heroine] animations.
  ///
  /// {@macro flutter.widgets.ProxyWidget.child}
  final Widget child;

  /// The spring simulation to use for transitions towards this hero.
  ///
  /// Defaults to [Spring], which is a smooth default without bounce.
  final Spring spring;

  ///
  final HeroPlaceholderBuilder? placeholderBuilder;

  /// The shuttle builder to use for this heroine.
  ///
  /// If not given, [FadeShuttleBuilder] will be used as default, which
  /// fades the hero widget between each other smoothly.
  ///
  /// To use your existing [HeroFlightShuttleBuilder] implementations with
  /// Heroine, use [HeroineShuttleBuilder.fromHero].
  ///
  /// ## Limitations
  ///
  /// If a widget built by [flightShuttleBuilder] takes part in a [Navigator]
  /// push transition, that widget or its descendants must not have any
  /// [GlobalKey] that is used in the source Heroine's descendant widgets. That
  /// is because both subtrees will be included in the widget tree during the
  /// Heroine flight animation, and [GlobalKey]s must be unique across the
  /// entire widget tree.
  ///
  /// If the said [GlobalKey] is essential to your application, consider
  /// providing a custom [placeholderBuilder] for the source Heroine, to avoid
  /// the [GlobalKey] collision, such as a builder that builds an empty
  /// [SizedBox], keeping the Heroine [child]'s original size.
  ///
  /// See also:
  ///
  /// * [HeroineShuttleBuilder]
  final HeroineShuttleBuilder? flightShuttleBuilder;

  /// If true, [spring] will be adjusted to the duration of the route
  /// transition.
  final bool adjustToRouteTransitionDuration;

  @override
  State<Heroine> createState() => _HeroineState();
}

class _HeroineState extends State<Heroine> with TickerProviderStateMixin {
  final _key = GlobalKey();

  _FlightManifest? _manifest;
  Size? _placeholderSize;

  _SleightOfHand? _sleightOfHand;

  MotionController<Offset>? _centerController;
  MotionController<Size>? _sizeController;

  /// Should be called on the toHero's state.
  void _initSpringControllers(
    _FlightManifest manifest,
    AnimationStatusListener onFlightAnimationStatusChanged,
  ) {
    _disposeSpringControllers();
    _centerController = MotionController(
      vsync: this,
      motion: SpringMotion(manifest.adjustedSpring),
      initialValue: manifest.fromHeroLocation.center,
      converter: const OffsetMotionConverter(),
    )..addStatusListener(onFlightAnimationStatusChanged);

    _sizeController = MotionController(
      vsync: this,
      motion: SpringMotion(manifest.adjustedSpring),
      initialValue: manifest.fromHeroLocation.size,
      converter: const SizeMotionConverter(),
    );
  }

  void _disposeSpringControllers() {
    _centerController?.dispose();
    _sizeController?.dispose();
    _unlinkSpringControllers();
  }

  void _linkRedirectedSpringControllers(
    MotionController<Offset> centerController,
    MotionController<Size> sizeController,
  ) {
    _centerController = centerController..resync(this);
    _sizeController = sizeController..resync(this);
  }

  void _unlinkSpringControllers() {
    if (_centerController == null && _sizeController == null) return;
    _centerController = null;
    _sizeController = null;
  }

  bool _showsEmptyPlaceholderForFlight(_FlightManifest flight) {
    return flight.direction == HeroFlightDirection.pop &&
        flight.fromHero == this;
  }

  @override
  Widget build(BuildContext context) {
    assert(
      context.findAncestorWidgetOfExactType<Heroine>() == null,
      'A Heroine widget cannot be the descendant of another Heroine widget.',
    );

    final flight = _manifest;
    if (flight != null &&
        widget.placeholderBuilder != null &&
        _placeholderSize != null) {
      return widget.placeholderBuilder!(
        context,
        _placeholderSize!,
        widget.child,
      );
    }

    if (flight != null && _showsEmptyPlaceholderForFlight(flight)) {
      return SizedBox.fromSize(
        size: _placeholderSize,
      );
    }

    return _SleightOfHandBuilder(
      globalKey: _key,
      placeholderSize: _placeholderSize,
      sleightOfHand: _sleightOfHand,
      manifest: _manifest,
      child: widget.child,
    );
  }

  void _startFlight(_FlightManifest manifest) {
    _placeholderSize = switch (context.findRenderObject()) {
      final RenderBox box => box.size,
      _ => Size.zero,
    };

    setState(() {
      _manifest = manifest;
      _sleightOfHand = null;
    });
  }

  void _performSleightOfHand({
    required MotionController<Offset> centerController,
    required Offset targetCenter,
    required MotionController<Size> sizeController,
    required Size targetSize,
  }) {
    if (!mounted) return;
    setState(() {
      _sleightOfHand = (
        centerController: centerController,
        targetCenter: targetCenter,
        sizeController: sizeController,
        targetSize: targetSize,
      );
    });
  }

  void _endFlight() {
    _placeholderSize = null;
    if (!mounted) return;
    setState(() {
      _manifest = null;
      _sleightOfHand = null;
    });
  }

  @override
  void dispose() {
    _disposeSpringControllers();
    super.dispose();
  }
}

typedef _SleightOfHand = ({
  MotionController<Offset> centerController,
  Offset targetCenter,
  MotionController<Size> sizeController,
  Size targetSize,
});

extension on _SleightOfHand {
  Offset get offset => centerController.value - targetCenter;

  double get sizeX => sizeController.value.width;

  double get sizeY => sizeController.value.height;
}

class _SleightOfHandBuilder extends StatelessWidget {
  const _SleightOfHandBuilder({
    required this.globalKey,
    required this.placeholderSize,
    required this.sleightOfHand,
    required this.manifest,
    required this.child,
  });

  final GlobalKey globalKey;

  final Size? placeholderSize;

  final _SleightOfHand? sleightOfHand;

  final _FlightManifest? manifest;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (placeholderSize case final size?) {
      return AnimatedBuilder(
        animation:
            sleightOfHand?.centerController ?? const AlwaysStoppedAnimation(0),
        builder: (context, child) {
          return Transform.translate(
            offset: sleightOfHand?.offset ?? Offset.zero,
            child: SizedBox.fromSize(
              size: size,
              child: OverflowBox(
                maxHeight: double.infinity,
                maxWidth: double.infinity,
                child: Center(
                  child: SizedBox.fromSize(
                    size: Size(
                      sleightOfHand?.sizeX ?? size.width,
                      sleightOfHand?.sizeY ?? size.height,
                    ),
                    child: Offstage(
                      offstage: manifest != null && sleightOfHand == null,
                      child: TickerMode(
                        enabled: manifest == null || sleightOfHand != null,
                        child: KeyedSubtree(
                          key: globalKey,
                          child: child!,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        child: child,
      );
    }
    return child;
  }
}

/// The controller for [Heroine] transitions.
///
/// Add this as a [NavigatorObserver] to your [Navigator] to enable
/// heroine transitions across your app.
///
/// Example:
///
/// ```dart
/// class MyApp extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     return MaterialApp(
///       navigatorObservers: [HeroineController()],
///       ...
///     );
///   }
/// }
/// ```
///
/// **Note:**
///
/// In some cases with nested navigation, you need to make sure to add a
/// [HeroineController] to all of the navigators in your app.
class HeroineController extends NavigatorObserver {
  /// Creates a heroine controller.
  HeroineController() {
    if (kFlutterMemoryAllocationsEnabled) {
      FlutterMemoryAllocations.instance.dispatchObjectCreated(
        library: 'package:heroine/heroine.dart',
        className: '$HeroineController',
        object: this,
      );
    }
  }

  // All of the heroes that are currently in the overlay and in motion.
  // Indexed by the hero tag.
  final Map<Object, _HeroineFlight> _flights = <Object, _HeroineFlight>{};

  @override
  void didChangeTop(Route<dynamic> topRoute, Route<dynamic>? previousTopRoute) {
    assert(
      topRoute.isCurrent,
      'Top route $topRoute is not current in heroine transition.',
    );
    assert(
      navigator != null,
      'Navigator is null in heroine transition.',
    );
    if (previousTopRoute == null) {
      return;
    }
    // Don't trigger another flight when a pop is committed as a user gesture
    // back swipe is snapped.
    _maybeStartHeroTransition(
      fromRoute: previousTopRoute,
      toRoute: topRoute,
      isUserGestureTransition: false,
    );
  }

  @override
  void didStartUserGesture(
    Route<dynamic> route,
    Route<dynamic>? previousRoute,
  ) {
    assert(
      navigator != null,
      'Navigator is null. Aborting heroine transition.',
    );
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
        '${navigatorRenderObject.runtimeType}. Aborting heroine transition.',
      );
      return;
    }
    assert(
      navigatorRenderObject.hasSize,
      'Navigator $navigator does not have a size.',
    );

    // At this point, the toHeroes may have been built and laid out for the
    // first time.
    //
    // If `fromSubtreeContext` is null, call endFlight on all toHeroes, for good
    // measure.
    // If `toSubtreeContext` is null abort existingFlights.
    final fromSubtreeContext = from.subtreeContext;
    final fromHeroes = fromSubtreeContext != null
        ? fromSubtreeContext.allHeroesFor(
            navigator,
            isUserGestureTransition: isUserGestureTransition,
          )
        : const <Object, _HeroineState>{};
    final toSubtreeContext = to.subtreeContext;
    final toHeroes = toSubtreeContext != null
        ? toSubtreeContext.allHeroesFor(
            navigator,
            isUserGestureTransition: isUserGestureTransition,
          )
        : const <Object, _HeroineState>{};

    for (final fromHeroEntry in fromHeroes.entries) {
      final tag = fromHeroEntry.key;
      final fromHero = fromHeroEntry.value;
      final toHero = toHeroes[tag];
      final existingFlight = _flights[tag];
      final manifest = toHero == null
          ? null
          : _FlightManifest(
              direction: flightType,
              overlay: overlay,
              navigatorSize: navigatorRenderObject.size,
              fromRoute: from,
              toRoute: to,
              fromHero: fromHero,
              toHero: toHero,
              shuttleBuilder: toHero.widget.flightShuttleBuilder ??
                  fromHero.widget.flightShuttleBuilder ??
                  const FadeShuttleBuilder(),
              isUserGestureTransition: isUserGestureTransition,
              isDiverted: existingFlight != null,
              spring: toHero.widget.spring,
              adjustToRouteTransitionDuration:
                  toHero.widget.adjustToRouteTransitionDuration,
            );

      // Only proceed with a valid manifest. Otherwise abort the existing
      // flight, and call endFlight when this for loop finishes.
      if (manifest != null && manifest.isValid) {
        toHeroes.remove(tag);
        if (existingFlight != null) {
          existingFlight.divert(manifest);
        } else {
          _flights[tag] = _HeroineFlight(
            manifest,
            () => _handleFlightEnded(manifest),
          )..startFlight();
        }
      } else {
        existingFlight?.dispose();
        _flights.remove(tag);
      }
    }

    // The remaining entries in toHeroes are those failed to participate in a
    // new flight (for not having a valid manifest).
    //
    // This can happen in a route pop transition when a fromHero is no longer
    // mounted, or kept alive by the [KeepAlive] mechanism but no longer
    // visible.
    // TODO(timcreatedit): resume aborted flights: https://github.com/flutter/flutter/issues/72947
    for (final toHero in toHeroes.values) {
      toHero._endFlight();
    }
  }

  void _handleFlightEnded(_FlightManifest manifest) {
    _flights.remove(manifest.tag)?.dispose();
  }

  /// Releases resources.
  @mustCallSuper
  void dispose() {
    if (kFlutterMemoryAllocationsEnabled) {
      FlutterMemoryAllocations.instance.dispatchObjectDisposed(object: this);
    }

    for (final flight in _flights.values) {
      flight.dispose();
    }
  }
}

extension on BuildContext {
  // Returns a map of all of the heroes in `context` indexed by hero tag that
// should be considered for animation when `navigator` transitions from one
// PageRoute to another.
  Map<Object, _HeroineState> allHeroesFor(
    NavigatorState navigator, {
    required bool isUserGestureTransition,
  }) {
    final result = <Object, _HeroineState>{};

    void inviteHero(StatefulElement hero, Object tag) {
      // ignore: prefer_asserts_with_message
      assert(() {
        if (result.containsKey(tag)) {
          throw FlutterError.fromParts(<DiagnosticsNode>[
            ErrorSummary(
              'There are multiple heroines that share the same tag within a '
              'subtree.',
            ),
            ErrorDescription(
              'Within each subtree for which heroes are to be animated (i.e. a '
              'PageRoute subtree), each Heroine must have a unique non-null '
              'tag.\n'
              'In this case, multiple heroines had the following tag: $tag',
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

      // TODO(timcreatedit): we ignore transitionOnUserGestures for now, they're
      // handled differently

      // final heroWidget = hero.widget as Heroine;
      final heroState = hero.state as _HeroineState;
      // if (!isUserGestureTransition || heroWidget._transitionOnUserGestures) {
      result[tag] = heroState;
      // } else {
      //   // If transition is not allowed, we need to make sure hero is not
      //   // hidden.
      //   // A hero can be hidden previously due to hero transition.
      //   heroState._endFlight();
      // }
    }

    void visitor(Element element) {
      final widget = element.widget;
      if (widget is Heroine) {
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

    visitChildElements(visitor);
    return result;
  }
}
