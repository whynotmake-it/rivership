import 'package:flutter/material.dart';

/// A [HeroFlightShuttleBuilder] that smoothly transitions between two widgets
/// by stretching both of them to fill the constraints and fading between them.
Widget fadeShuttle(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection flightDirection,
  BuildContext fromHeroContext,
  BuildContext toHeroContext,
) {
  final toHero = toHeroContext.widget as Hero;
  final fromHero = fromHeroContext.widget as Hero;

  final forward = (flightDirection == HeroFlightDirection.push);

  return SizedBox.expand(
    child: Stack(
      children: [
        SizedBox.expand(
          child: FadeTransition(
            opacity: animation,
            child: forward ? toHero : fromHero,
          ),
        ),
        SizedBox.expand(
          child: FadeTransition(
            opacity: ReverseAnimation(animation),
            child: forward ? fromHero : toHero,
          ),
        ),
      ],
    ),
  );
}
