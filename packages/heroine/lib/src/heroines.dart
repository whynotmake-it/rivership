import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:heroine/heroine.dart';
import 'package:motor/motor.dart';

part 'flight_controller.dart';
part 'flight_spec.dart';
part 'heroine_location.dart';
part 'heroine_velocity_tracker.dart';
part 'heroine_widget.dart';

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
  final Map<int, _TransitionBarrier> _transitionBarriers =
      <int, _TransitionBarrier>{};
  int _nextTransitionId = 0;

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
    // onGestureEnd can synchronously complete a flight and mutate _flights.
    for (final flight in _flights.values.toList()) {
      flight.onGestureEnd();
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
    final transitionId = _nextTransitionId++;

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
              handoffMotionBuilder: toHero.widget.handoffMotionBuilder,
              zIndex: toHero.widget.zIndex ?? fromHero.widget.zIndex,
              transitionId: transitionId,
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
    if (isUserGestureTransition && specs.isNotEmpty) {
      _transitionBarriers[transitionId] = _TransitionBarrier(
        transitionId: transitionId,
        tags: {for (final spec in specs) spec.tag!},
      );
    }
    for (final spec in specs) {
      final existingFlight = specsToExistingFlights[spec];
      if (existingFlight != null) {
        final oldTransitionId = existingFlight._spec.transitionId;
        if (oldTransitionId != spec.transitionId) {
          final oldBarrier = _transitionBarriers[oldTransitionId];
          if (oldBarrier != null && oldBarrier.removeTag(spec.tag!)) {
            _transitionBarriers.remove(oldTransitionId);
          }
        }
        existingFlight.divert(spec);
      } else {
        _flights[spec.tag!] = _FlightController(
          spec,
          _handleFlightEnded,
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

  void _handleFlightEnded(_FlightController flight) {
    final spec = flight._spec;
    final tag = spec.tag;
    if (tag == null) {
      flight.dispose();
      return;
    }
    if (!spec.isUserGestureTransition) {
      _flights.remove(tag)?.dispose();
      return;
    }
    final barrier = _transitionBarriers[spec.transitionId];
    if (barrier == null) {
      _flights.remove(tag)?.dispose();
      return;
    }
    if (barrier.markComplete(tag)) {
      _transitionBarriers.remove(spec.transitionId);
      for (final barrierTag in barrier.tags) {
        _flights.remove(barrierTag)?.dispose();
      }
    }
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

      // For user gestures, only include heroes that explicitly opt in.
      if (!isUserGestureTransition ||
          (hero.widget as Heroine).animateOnUserGestures) {
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

class _TransitionBarrier {
  _TransitionBarrier({
    required this.transitionId,
    required this.tags,
  })  : _remaining = Set<Object>.from(tags);

  final int transitionId;
  final Set<Object> tags;
  final Set<Object> _remaining;

  bool markComplete(Object tag) {
    _remaining.remove(tag);
    return _remaining.isEmpty;
  }

  bool removeTag(Object tag) {
    _remaining.remove(tag);
    return _remaining.isEmpty;
  }
}
