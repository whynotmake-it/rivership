import 'package:flutter/widgets.dart';

abstract class SuperheroShuttleBuilder {
  HeroFlightShuttleBuilder flip() => (flightContext, animation, flightDirection,
          fromHeroContext, toHeroContext) {
        final toHero = toHeroContext.widget as Hero;

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
      };
}
