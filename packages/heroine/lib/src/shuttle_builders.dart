import 'dart:math';

import 'package:flutter/widgets.dart';

/// A convenience class that can be extended to create your own shuttle
/// builders more easily.
///
/// Basically a callable class that matches the signature of
/// [HeroFlightShuttleBuilder] and offers a convenience method.
abstract class HeroineShuttleBuilder {
  /// Creates a new [HeroineShuttleBuilder].
  const HeroineShuttleBuilder();

  /// Builds the hero in flight.
  ///
  /// This will be called each frame of the transition with a [valueFromTo] that
  /// ranges from 0 to 1.
  /// If that value is at 0, we are still at the [fromHeroContext] and if it
  /// is at 1, we are at the [toHeroContext].
  ///
  /// Access the widgets using [fromHeroContext] and [toHeroContext].
  Widget buildHero({
    required BuildContext flightContext,
    required BuildContext fromHeroContext,
    required BuildContext toHeroContext,
    required double valueFromTo,
    required HeroFlightDirection flightDirection,
  });

  /// Builds the shuttle transition by wrapping the hero in a media query
  /// that transitions the padding around the hero.
  ///
  /// Relies on [buildHero] to build the actual content of the hero in flight.
  ///
  /// See [HeroFlightShuttleBuilder] for more information.
  Widget call(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection flightDirection,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    final toMediaQueryData = MediaQuery.maybeOf(toHeroContext);
    final fromMediaQueryData = MediaQuery.maybeOf(fromHeroContext);

    double remapValue() => flightDirection == HeroFlightDirection.push
        ? animation.value
        : 1 - animation.value;

    if (toMediaQueryData == null || fromMediaQueryData == null) {
      return AnimatedBuilder(
        animation: animation,
        builder: (BuildContext context, Widget? _) => buildHero(
          flightContext: flightContext,
          fromHeroContext: fromHeroContext,
          toHeroContext: toHeroContext,
          valueFromTo: remapValue(),
          flightDirection: flightDirection,
        ),
      );
    }

    final fromHeroPadding = fromMediaQueryData.padding;
    final toHeroPadding = toMediaQueryData.padding;

    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? _) => MediaQuery(
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
        child: buildHero(
          flightContext: flightContext,
          fromHeroContext: fromHeroContext,
          toHeroContext: toHeroContext,
          valueFromTo: remapValue(),
          flightDirection: flightDirection,
        ),
      ),
    );
  }
}

/// A shuttle builder that fades the heroes between each other smoothly.
class FadeShuttleBuilder extends HeroineShuttleBuilder {
  /// Creates a new [FadeShuttleBuilder].
  const FadeShuttleBuilder();

  @override
  Widget buildHero({
    required BuildContext flightContext,
    required BuildContext fromHeroContext,
    required BuildContext toHeroContext,
    required double valueFromTo,
    required HeroFlightDirection flightDirection,
  }) =>
      Stack(
        fit: StackFit.expand,
        children: [
          if (valueFromTo < 1)
            Opacity(
              opacity: 1 - valueFromTo.clamp(0, 1),
              child: fromHeroContext.widget,
            ),
          if (valueFromTo > 0)
            Opacity(
              opacity: valueFromTo.clamp(0, 1),
              child: toHeroContext.widget,
            ),
        ],
      );
}

/// A shuttle builder that shows either only the from hero or the to hero.
///
/// With [useFromHero] == false, this matches the default Flutter Hero behavior.
class SingleShuttleBuilder extends HeroineShuttleBuilder {
  /// Creates a new [SingleShuttleBuilder].
  const SingleShuttleBuilder({
    this.useFromHero = false,
  });

  /// Whether to use the from hero (ture) or the to hero (false).
  ///
  /// False by default.
  final bool useFromHero;

  @override
  Widget buildHero({
    required BuildContext flightContext,
    required BuildContext fromHeroContext,
    required BuildContext toHeroContext,
    required double valueFromTo,
    required HeroFlightDirection flightDirection,
  }) =>
      useFromHero ? fromHeroContext.widget : toHeroContext.widget;
}

/// A shuttle builder that flips the hero widget horizontally or vertically.
class FlipShuttleBuilder extends HeroineShuttleBuilder {
  /// Creates a new [FlipShuttleBuilder].
  const FlipShuttleBuilder({
    this.axis = Axis.vertical,
    this.flipForward = true,
    this.invertFlipOnReturn = false,
    this.halfFlips = 1,
  });

  /// Determines the axis of the flip.
  ///
  /// If set to [Axis.vertical], the hero widget will be flipped along the y
  /// axis.
  /// If set to [Axis.horizontal], the hero widget will be flipped along the
  /// x axis.
  final Axis axis;

  /// While flipping forward along the y axis, the hero widget will be flipped
  /// open towards the left, like flipping a page when reading left to right.
  /// While flipping forward along the x axis, the hero widget will be flipped
  /// open towards the bottom, like an old split-flap display.
  final bool flipForward;

  /// Determines if the flip should be inverted on the return trip.
  final bool invertFlipOnReturn;

  /// Determines the number of half flips in the transition.
  /// If set to 1 (default), the hero widget will be flipped 180 degrees.
  /// If set to 2, the hero widget will be flipped 360 degrees and so on.
  final int halfFlips;

  @override
  Widget buildHero({
    required BuildContext flightContext,
    required BuildContext fromHeroContext,
    required BuildContext toHeroContext,
    required double valueFromTo,
    required HeroFlightDirection flightDirection,
  }) {
    final angle = valueFromTo * pi * 2;

    final perspective = Matrix4.identity()..setEntry(3, 2, 0.001);

    final flip = switch ((flightDirection, flipForward, invertFlipOnReturn)) {
      (HeroFlightDirection.push, true, _) => 1,
      (HeroFlightDirection.pop, true, false) => 1,
      (HeroFlightDirection.pop, true, true) => -1,
      (HeroFlightDirection.push, false, _) => -1,
      (HeroFlightDirection.pop, false, false) => -1,
      (HeroFlightDirection.pop, false, true) => 1,
    };

    final times = halfFlips / 2;
    final doesFlip = halfFlips.isOdd;

    if (axis == Axis.vertical) {
      perspective.rotateY(flip * angle * times);
    } else {
      perspective.rotateX(flip * angle * times);
    }

    return Transform(
      alignment: FractionalOffset.center,
      filterQuality: FilterQuality.none,
      transform: perspective,
      child: valueFromTo > 0.5
          ? Transform.flip(
              flipX: doesFlip && axis == Axis.vertical,
              flipY: doesFlip && axis == Axis.horizontal,
              child: toHeroContext.widget,
            )
          : fromHeroContext.widget,
    );
  }
}
