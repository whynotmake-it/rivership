import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:heroine/heroine.dart';
import 'package:motor/motor.dart';

part 'flight_controller.dart';
part 'flight_spec.dart';
part 'heroine_location.dart';

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
    this.motion = const CupertinoMotion.smooth(),
    this.placeholderBuilder,
    this.flightShuttleBuilder,
    this.zIndex,
    this.continuouslyTrackTarget = false,
  });

  /// The identifier for this particular hero. If the tag of this hero matches
  /// the tag of a hero on a [PageRoute] that we're navigating to or from, then
  /// a heroine animation will be triggered.
  ///
  /// Make sure that the tags on both heroines are equal using `==`.
  final Object tag;

  /// The widget subtree that will "fly" from one route to another during a
  /// [Navigator] push or pop transition.
  ///
  /// The appearance of this subtree should be similar to the appearance of
  /// the subtrees of any other heroines in the application with the same [tag].
  /// Changes in scale and aspect ratio work well in [Heroine] animations.
  ///
  /// {@macro flutter.widgets.ProxyWidget.child}
  final Widget child;

  /// The motion to use for transitions towards this heroine.
  ///
  /// Defaults to [SpringMotion] with a smooth spring,
  /// which is a smooth default without bounce.
  final Motion motion;

  /// The placeholder builder to use for this heroine.
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

  /// The z-index for this heroine's overlay during flight animations.
  ///
  /// Heroines with higher z-index values will appear above those with lower
  /// values. If not specified, defaults to 0.
  ///
  /// Heroines with the same z-index maintain their original order relative
  /// to each other (stable sorting), which means heroines that were built
  /// later, are higher in the z-index order.
  ///
  /// When transitioning between routes, the z-index from the destination
  /// heroine (toHero) is used. If the destination heroine doesn't have a
  /// z-index, the source heroine's (fromHero) z-index is used instead.
  final int? zIndex;

  /// Whether to continuously track the target widget's position during flight
  /// and redirect the animation if it moves.
  ///
  /// When enabled on the [Heroine] we are transitioning to,
  /// we will check the target widget's position on every animation frame and if
  /// it has moved (e.g., keyboard appears/disappears, device rotates, or any
  /// layout change occurs), the animation will smoothly redirect to the new
  /// target position.
  ///
  /// This works best with [motion]s like [CupertinoMotion] or other
  /// [SpringMotion]s, that can dynamically redirect while retaining velocity.
  ///
  /// It is useful for scenarios like pushing a route with an autofocus text
  /// field, where the keyboard appears mid-animation and shifts the target
  /// widget's position.
  ///
  /// Defaults to false for performance reasons. Enable this only when you
  /// need to handle dynamic layout changes during the animation.
  final bool continuouslyTrackTarget;

  @override
  State<Heroine> createState() => _HeroineState();
}

class _HeroineState extends State<Heroine> with TickerProviderStateMixin {
  final _key = GlobalKey();

  // ---------------------------------------------------------------------------
  // Flight State
  // ---------------------------------------------------------------------------

  /// The current flight specification, if this heroine is participating in one.
  _FlightSpec? _flightSpec;

  /// The size of this widget before the flight started (used for placeholder).
  Size? _placeholderSize;

  /// The handoff state for animating to final position after route completes.
  _FlightHandoff? _handoff;

  // ---------------------------------------------------------------------------
  // Motion Controllers
  // ---------------------------------------------------------------------------

  /// Controller for animating the center position.
  MotionController<HeroineLocation>? _motionController;

  /// Initializes motion controllers for this hero's flight.
  ///
  /// Called on the [_FlightSpec.controllingHero]'s state when a flight starts.
  void _initMotionControllers(
    _FlightSpec spec,
    AnimationStatusListener onSpringAnimationStatusChanged,
  ) {
    _disposeMotionControllers();
    _motionController = MotionController(
      vsync: this,
      motion: spec.motion,
      initialValue: HeroineLocation(
        boundingBox: spec.fromHeroLocation.boundingBox,
      ),
      converter: _HeroineLocationConverter(),
    )..addStatusListener(onSpringAnimationStatusChanged);
  }

  void _disposeMotionControllers() {
    _motionController?.dispose();

    _unlinkMotionControllers();
  }

  /// Links motion controllers from another hero state (for redirected flights).
  void _linkRedirectedMotionController(
    MotionController<HeroineLocation> motionController,
  ) {
    _motionController = motionController..resync(this);
  }

  void _unlinkMotionControllers() {
    if (_motionController == null) return;
    _motionController = null;
  }

  // ---------------------------------------------------------------------------
  // Flight Lifecycle Methods
  // ---------------------------------------------------------------------------

  /// Starts a flight for this heroine.
  void _startFlight(_FlightSpec spec) {
    _placeholderSize = switch (context.findRenderObject()) {
      final RenderBox box => box.size,
      _ => Size.zero,
    };

    setState(() {
      _flightSpec = spec;
      _handoff = null;
    });
  }

  /// Performs the handoff animation after the route transition completes.
  ///
  /// The overlay is removed and this widget continues animating from the
  /// current spring position to its final resting position using the provided
  /// controllers. This creates a smooth "landing" effect.
  void _performHandoff({
    required MotionController<HeroineLocation> controller,
    required HeroineLocation target,
  }) {
    if (!mounted) return;
    setState(() {
      _handoff = (
        controller: controller,
        target: target,
      );
    });
  }

  /// Ends the flight for this heroine.
  void _endFlight() {
    _placeholderSize = null;
    if (!mounted) return;

    if (this == _flightSpec?.toHero) {
      _flightSpec = null;
      _handoff = null;
    } else {
      setState(() {
        _flightSpec = null;
        _handoff = null;
      });
    }
  }

  bool _showsEmptyPlaceholderForFlight(_FlightSpec spec) {
    return spec.direction == HeroFlightDirection.pop && spec.fromHero == this;
  }

  @override
  Widget build(BuildContext context) {
    final spec = _flightSpec;
    if (spec != null &&
        widget.placeholderBuilder != null &&
        _placeholderSize != null) {
      return widget.placeholderBuilder!(
        context,
        _placeholderSize!,
        widget.child,
      );
    }

    if (spec != null && _showsEmptyPlaceholderForFlight(spec)) {
      return SizedBox.fromSize(
        size: _placeholderSize,
      );
    }

    return _HandoffBuilder(
      globalKey: _key,
      placeholderSize: _placeholderSize,
      handoff: _handoff,
      flightSpec: _flightSpec,
      child: widget.child,
    );
  }

  @override
  void dispose() {
    _disposeMotionControllers();
    super.dispose();
  }
}

// -----------------------------------------------------------------------------
// Flight Handoff
// -----------------------------------------------------------------------------

/// State for the handoff animation after the route transition completes.
///
/// When a flight's route animation completes, the overlay is removed and the
/// destination hero takes over. However, the spring animation may still be
/// in progress. This record holds the controllers and target values needed
/// to continue animating the hero to its final position.
typedef _FlightHandoff = ({
  MotionController<HeroineLocation> controller,
  HeroineLocation target,
});

extension on _FlightHandoff {
  /// The current offset from the target center.
  Offset get offset =>
      controller.value.boundingBox.center - target.boundingBox.center;

  double get sizeX => controller.value.boundingBox.width;

  double get sizeY => controller.value.boundingBox.height;
}

/// Builds the hero widget during the handoff phase.
///
/// Handles three states:
/// 1. **Normal**: No flight - just renders the child
/// 2. **In Flight**: Hero is flying - renders offstage (overlay shows the hero)
/// 3. **Handoff**: Route done, spring continuing - animates to final position
class _HandoffBuilder extends StatelessWidget {
  const _HandoffBuilder({
    required this.globalKey,
    required this.placeholderSize,
    required this.handoff,
    required this.flightSpec,
    required this.child,
  });

  final GlobalKey globalKey;

  final Size? placeholderSize;

  final _FlightHandoff? handoff;

  final _FlightSpec? flightSpec;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Offstage when in flight but before handoff
    final offstage = flightSpec != null && handoff == null;

    if (placeholderSize case final size?) {
      return AnimatedBuilder(
        animation: handoff?.controller ?? const AlwaysStoppedAnimation(0),
        builder: (context, child) {
          return Transform.translate(
            offset: handoff?.offset ?? Offset.zero,
            child: SizedBox.fromSize(
              size: size,
              child: OverflowBox(
                maxHeight: double.infinity,
                maxWidth: double.infinity,
                child: Center(
                  child: SizedBox.fromSize(
                    size: Size(
                      handoff?.sizeX ?? size.width,
                      handoff?.sizeY ?? size.height,
                    ),
                    child: Offstage(
                      offstage: offstage,
                      child: TickerMode(
                        enabled: !offstage,
                        child: child!,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        child: KeyedSubtree(
          key: globalKey,
          child: child,
        ),
      );
    }

    return KeyedSubtree(
      key: globalKey,
      child: child,
    );
  }
}

// -----------------------------------------------------------------------------
// HeroineController
// -----------------------------------------------------------------------------

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

  /// All active flight controllers, indexed by hero tag.
  final Map<Object, _FlightController> _flights = <Object, _FlightController>{};

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
    final flightType = switch ((
      isUserGestureTransition,
      oldRouteAnimation.status,
      newRouteAnimation.status
    )) {
      (true, _, _) ||
      (_, AnimationStatus.reverse, _) =>
        HeroFlightDirection.pop,
      (_, _, AnimationStatus.forward) => HeroFlightDirection.push,
      _ => null,
    };

    // A user gesture may have already completed the pop, or we might be the
    // initial route
    switch (flightType) {
      case HeroFlightDirection.pop when fromRoute.animation!.isDismissed:
        return;
      case HeroFlightDirection.push when toRoute.animation!.isCompleted:
        return;
      case HeroFlightDirection.push || HeroFlightDirection.pop || null:
        break;
    }

    // For pop transitions driven by a user gesture: if the "to" page has
    // maintainState = true, then the hero's final dimensions can be measured
    // immediately because their page's layout is still valid.
    // Unless due to directly
    // adding routes to the pages stack causing the route to never get laid out.
    final fromRouteRenderBox =
        toRoute.subtreeContext?.findRenderObject() as RenderBox?;
    final hasValidSize = (fromRouteRenderBox?.hasSize ?? false) &&
        fromRouteRenderBox!.size.isFinite;

    if (isUserGestureTransition &&
        flightType == HeroFlightDirection.pop &&
        toRoute.maintainState &&
        hasValidSize) {
      _startHeroTransition(
        fromRoute,
        toRoute,
        flightType,
        isUserGestureTransition,
      );
      toRoute.offstage = toRoute.animation!.value == 0.0;
    } else {
      // Otherwise, delay measuring until the end of the next frame to allow
      // the 'to' route to build and layout.
      WidgetsBinding.instance.addPostFrameCallback(
        (Duration value) {
          if (fromRoute.navigator == null || toRoute.navigator == null) {
            return;
          }
          toRoute.offstage = toRoute.animation!.value == 0.0;
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
    HeroFlightDirection? flightType,
    bool isUserGestureTransition,
  ) {
    final navigator = this.navigator;
    final overlay = navigator?.overlay;
    // If the navigator or the overlay was removed before this end-of-frame
    // callback was called, then don't actually start a transition, and we don't
    // have to worry about any Hero widget we might have hidden in a previous
    // flight, or ongoing flights.
    if (navigator == null || overlay == null) {
      return;
    }

    to.offstage = false;

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

    final allFromTags = fromHeroes.keys.toList();
    final allToTags = toHeroes.keys.toList();

    // Collect all valid specs first
    final specs = <_FlightSpec>[];
    final specsToExistingFlights = <_FlightSpec, _FlightController>{};
    final tagsToAbort = <Object>[];

    for (final MapEntry(key: tag, value: fromHero) in fromHeroes.entries) {
      final toHero = toHeroes[tag];

      assert(
        !_hasFlyingAncestor(fromHero, allToTags),
        'Heroine ${fromHero.widget.tag} (flying from a page to another) has a '
        'heroine ancestor that will be flying too. This is not supported',
      );

      assert(
        !_hasFlyingAncestor(toHero, allFromTags),
        'Heroine ${toHero?.widget.tag} (flying to a page from another) has a '
        'heroine ancestor that will be flying too. This is not supported',
      );

      final existingFlight = _flights[tag];
      final spec = toHero == null || flightType == null
          ? null
          : _FlightSpec(
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
              motion: toHero.widget.motion,
              zIndex: toHero.widget.zIndex ?? fromHero.widget.zIndex,
            );

      // Only proceed with a valid spec. Otherwise abort the existing
      // flight, and call endFlight when this for loop finishes.
      if (spec != null && spec.isValid) {
        toHeroes.remove(tag);
        specs.add(spec);
        if (existingFlight != null) {
          specsToExistingFlights[spec] = existingFlight;
        }
      } else {
        existingFlight?.dispose();
        tagsToAbort.add(tag);
      }
    }

    // Remove aborted flights
    for (final tag in tagsToAbort) {
      _flights.remove(tag);
    }

    // Sort specs by z-index (treating null as 0)
    // Dart's sort is stable, so heroines with the same z-index maintain their
    // original order
    specs.sort((a, b) {
      final aZIndex = a.zIndex ?? 0;
      final bZIndex = b.zIndex ?? 0;
      return aZIndex.compareTo(bZIndex);
    });

    // Create flights in the correct order
    for (final spec in specs) {
      final existingFlight = specsToExistingFlights[spec];
      if (existingFlight != null) {
        existingFlight.divert(spec);
      } else {
        _flights[spec.tag!] = _FlightController(
          spec,
          () => _handleFlightEnded(spec),
        )..startFlight();
      }
    }

    // The remaining entries in toHeroes are those failed to participate in a
    // new flight (for not having a valid spec).
    //
    // This can happen in a route pop transition when a fromHero is no longer
    // mounted, or kept alive by the [KeepAlive] mechanism but no longer
    // visible.
    // TODO(timcreatedit): resume aborted flights: https://github.com/flutter/flutter/issues/72947
    for (final toHero in toHeroes.values) {
      toHero._endFlight();
    }
  }

  bool _hasFlyingAncestor(
    _HeroineState? heroine,
    Iterable<Object> otherRouteHeroes,
  ) {
    final ownTag = heroine?.widget.tag;
    final parentTag =
        heroine?.context.findAncestorWidgetOfExactType<Heroine>()?.tag;
    if (parentTag == null || ownTag == null) return false;

    // If both the parent and the child are flying, then we don't support it.
    return otherRouteHeroes.contains(parentTag) &&
        otherRouteHeroes.contains(ownTag);
  }

  void _handleFlightEnded(_FlightSpec spec) {
    _flights.remove(spec.tag)?.dispose();
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

// -----------------------------------------------------------------------------
// Hero Discovery
// -----------------------------------------------------------------------------

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

      // final heroWidget = hero.widget as Heroine;
      final heroState = hero.state as _HeroineState;

      // TODO(timcreatedit): allow heroines to opt into user gesture transitions
      if (!isUserGestureTransition) {
        result[tag] = heroState;
      } else {
        // If transition is not allowed, we need to make sure hero is not
        // hidden.
        // A hero can be hidden previously due to hero transition.
        heroState._endFlight();
      }
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
      } else if (widget is HeroineMode && !widget.enabled) {
        return;
      }
      element.visitChildren(visitor);
    }

    visitChildElements(visitor);
    return result;
  }
}

// -----------------------------------------------------------------------------
// HeroineMode
// -----------------------------------------------------------------------------

/// Enables or disables [Heroine]es in the widget subtree.
///
///
/// When [enabled] is false, all [Heroine] widgets in this subtree will not be
/// involved in heroine animations.
///
/// When [enabled] is true (the default), [Heroine] widgets may be involved in
/// heroine animations, as usual.
class HeroineMode extends StatelessWidget {
  /// Creates a widget that enables or disables [Heroine]es.
  const HeroineMode({required this.child, super.key, this.enabled = true});

  /// The subtree to place inside the [HeroineMode].
  final Widget child;

  /// Whether or not [Heroine]es are enabled in this subtree.
  ///
  /// If this property is false, the [Heroine]es in this subtree will not
  /// animate on route changes. Otherwise, they will animate as usual.
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
