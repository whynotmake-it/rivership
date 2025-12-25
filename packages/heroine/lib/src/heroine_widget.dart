part of 'heroines.dart';

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
    this.handoffMotionBuilder = Heroine.defaultHandoffMotionBuilder,
    this.placeholderBuilder,
    this.flightShuttleBuilder,
    this.zIndex,
    this.continuouslyTrackTarget = false,
    this.pauseTickersDuringFlight = false,
    this.animateOnUserGestures = false,
  });

  /// The default gesture handoff motion builder.
  ///
  /// This uses a trimmed [CupertinoMotion.smooth] spring based on the remaining
  /// progress, keeping the finish snappy when the user is close to the target.
  static Motion defaultHandoffMotionBuilder(
    HeroineGestureHandoffContext context,
  ) {
    final remaining = context.remainingFraction.clamp(0.1, 1.0);
    const smooth = CupertinoMotion.smooth();
    final scaledMicros =
        (smooth.duration.inMicroseconds * remaining).round().clamp(1, 1 << 31);
    return smooth.copyWith(
      duration: Duration(microseconds: scaledMicros),
    );
  }

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

  /// Builds the motion used to hand off a user gesture to a spring finish.
  ///
  /// This is only used for gesture-driven transitions.
  final HeroineHandoffMotionBuilder handoffMotionBuilder;

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

  /// Whether tickers should be paused while the heroine is in flight, defaults
  /// to false.
  ///
  /// Flutter [Hero]es pause their tickers while they
  /// are flying from A to B.
  ///
  /// By default, [Heroine]s behave differently and keep their tickers running
  /// during the flight.
  /// This can be very advantageous, when the [Heroine] contains a button with a
  /// press  animation for example.
  /// If we pause that as soon as we start flying, the animation will jankily
  /// complete after the route is popped.
  ///
  /// No matter the setting of this property, tickers will always be paused
  /// while the heroine is on an inactive route and waiting for a pop
  /// transition.
  final bool pauseTickersDuringFlight;

  /// Whether the heroine should animate during user gesture transitions (e.g.
  /// back swipe).
  ///
  /// Defaults to false.
  final bool animateOnUserGestures;

  @override
  State<Heroine> createState() => _HeroineState();
}

class _HeroineState extends State<Heroine> with TickerProviderStateMixin {
  final _key = GlobalKey();

  _Status _status = const _Idle();

  /// Controller for animating the center position.
  MotionController<HeroineLocation>? _motionController;

  /// Initializes motion controllers for this hero's flight.
  ///
  /// Called on the [_FlightSpec.controllingHero]'s state when a flight starts.
  void _createMotionController(
    _FlightSpec spec,
    AnimationStatusListener onSpringAnimationStatusChanged,
  ) {
    _disposeMotionController();
    _motionController = MotionController(
      vsync: this,
      motion: spec.motion,
      initialValue: HeroineLocation(
        boundingBox: spec.fromHeroLocation.boundingBox,
      ),
      converter: _HeroineLocationConverter(),
    )..addStatusListener(onSpringAnimationStatusChanged);
  }

  void _disposeMotionController() {
    _motionController?.dispose();

    _unlinkMotionControllers();
  }

  /// Links motion controllers from another hero state (for redirected flights).
  void _linkRedirectedMotionController(
    MotionController<HeroineLocation> motionController,
  ) {
    if (_motionController != null) {
      _disposeMotionController();
    }
    _motionController = motionController..resync(this);
  }

  void _unlinkMotionControllers() {
    _motionController = null;
  }

  /// Starts a flight for this heroine.
  void _startFlight(_FlightSpec spec) {
    final placeholderSize = switch (context.findRenderObject()) {
      final RenderBox box => box.size,
      _ => Size.zero,
    };
    if (spec.fromHero == this) {
      setState(() {
        _status = _FromFlyingTo(
          spec: spec,
          placeholderSize: placeholderSize,
        );
      });
    }

    if (spec.toHero == this) {
      setState(() {
        _status = _ToFlyingFrom(
          spec: spec,
          placeholderSize: placeholderSize,
        );
      });
    }
  }

  /// Should be called when the route transition animation completes.
  ///
  /// The overlay will have been removed, so if we are the toHero, we need to
  /// continue animating to the final position (landing).
  ///
  /// If we are the fromHero, we go to the cruising altitude state.
  void _completeRouteTransition({
    required MotionController<HeroineLocation> controller,
    required HeroineLocation target,
  }) {
    if (!mounted) return;

    if (_status case _InFlight(:final spec, :final placeholderSize)) {
      if (spec.toHero == this) {
        setState(() {
          _status = _ToLanding(
            spec: spec,
            controller: controller,
            target: target,
          );
        });
      } else if (spec.fromHero == this) {
        setState(() {
          _status = _FromAtCruisingAltitude(
            spec: spec,
            placeholderSize: placeholderSize,
          );
        });
      }
    }
  }

  /// Ends the flight for this heroine.
  void _endFlight() {
    if (!mounted) return;

    setState(() {
      _status = const _Idle();
    });
  }

  Widget _buildPlaceholder(
    BuildContext context,
    Size placeholderSize,
    _FlightSpec spec, {
    required bool pauseTickers,
    required Widget child,
  }) {
    final alwaysEmpty =
        spec.direction == HeroFlightDirection.pop && spec.fromHero == this;

    if (alwaysEmpty) {
      return SizedBox.fromSize(
        size: placeholderSize,
      );
    }

    if (widget.placeholderBuilder case final builder?) {
      return builder(
        context,
        placeholderSize,
        child,
      );
    }

    return SizedBox.fromSize(
      size: placeholderSize,
      child: Offstage(
        child: TickerMode(
          enabled: !pauseTickers,
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final child = KeyedSubtree(
      key: _key,
      child: widget.child,
    );

    switch (_status) {
      case _Idle():
        return child;
      case _FromFlyingTo(:final spec, :final placeholderSize) ||
            _ToFlyingFrom(:final spec, :final placeholderSize) ||
            _FromAtCruisingAltitude(:final spec, :final placeholderSize):
        return _buildPlaceholder(
          context,
          placeholderSize,
          spec,
          pauseTickers: _status is _FromAtCruisingAltitude ||
              widget.pauseTickersDuringFlight,
          child: child,
        );
      case final _ToLanding landing:
        return AnimatedBuilder(
          animation: landing.controller,
          builder: (context, child) {
            return Transform.translate(
              offset: landing.offset,
              child: SizedBox.fromSize(
                size: landing.placeholderSize,
                child: OverflowBox(
                  maxHeight: double.infinity,
                  maxWidth: double.infinity,
                  child: Center(
                    child: SizedBox.fromSize(
                      size: Size(
                        landing.sizeX,
                        landing.sizeY,
                      ),
                      child: child,
                    ),
                  ),
                ),
              ),
            );
          },
          child: child,
        );
    }
  }

  @override
  void dispose() {
    _disposeMotionController();
    super.dispose();
  }
}

sealed class _Status {
  const _Status();
}

/// Interface for in-flight states.
///
/// These happen while the routes are transitioning.
abstract interface class _InFlight {
  _FlightSpec get spec;
  Size get placeholderSize;
}

// Idle state when not in flight.
class _Idle extends _Status {
  const _Idle();
}

/// We are the fromHeroine and are currently flying to the toHeroine.
class _FromFlyingTo extends _Status implements _InFlight {
  const _FromFlyingTo({
    required this.spec,
    required this.placeholderSize,
  });

  @override
  final _FlightSpec spec;

  @override
  final Size placeholderSize;
}

/// We are the fromHeroine and have finished flying to the toHeroine, but are
/// still showing the placeholder, since we will fly back and land once the
/// route is popped.
class _FromAtCruisingAltitude extends _Status implements _InFlight {
  const _FromAtCruisingAltitude({
    required this.spec,
    required this.placeholderSize,
  });

  @override
  final _FlightSpec spec;

  @override
  final Size placeholderSize;
}

/// We are the toHeroine and are currently flying from the fromHeroine.
class _ToFlyingFrom extends _Status implements _InFlight {
  const _ToFlyingFrom({
    required this.spec,
    required this.placeholderSize,
  });

  @override
  final _FlightSpec spec;

  @override
  final Size placeholderSize;
}

class _ToLanding extends _Status {
  const _ToLanding({
    required this.spec,
    required this.controller,
    required this.target,
  });

  final _FlightSpec spec;

  Size get placeholderSize => target.boundingBox.size;

  final MotionController<HeroineLocation> controller;

  final HeroineLocation target;

  /// The current offset from the target center.
  Offset get offset =>
      controller.value.boundingBox.center - target.boundingBox.center;

  double get sizeX => controller.value.boundingBox.width;

  double get sizeY => controller.value.boundingBox.height;
}

/// Signature for building a gesture handoff motion.
typedef HeroineHandoffMotionBuilder = Motion Function(
  HeroineGestureHandoffContext context,
);

/// Provides context for building a gesture handoff motion.
@immutable
class HeroineGestureHandoffContext {
  /// Creates a [HeroineGestureHandoffContext].
  const HeroineGestureHandoffContext({
    required this.progress,
    required this.remainingFraction,
    required this.proceeding,
    required this.motion,
    required this.direction,
    required this.velocity,
  });

  /// The current gesture progress from 0.0 to 1.0.
  final double progress;

  /// The remaining fraction of progress toward the target.
  final double remainingFraction;

  /// Whether the gesture is completing (true) or canceling (false).
  final bool proceeding;

  /// The base motion configured on the heroine.
  final Motion motion;

  /// The direction of the flight.
  final HeroFlightDirection direction;

  /// The estimated release velocity for the flight, if available.
  final HeroineLocation? velocity;
}
