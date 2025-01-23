import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

/// A convenience class that can be extended to create your own shuttle
/// builders more easily.
///
/// Basically a callable class that matches the signature of
/// [HeroFlightShuttleBuilder] and offers a convenience method.
abstract class HeroineShuttleBuilder with EquatableMixin {
  /// Creates a new [HeroineShuttleBuilder].
  const HeroineShuttleBuilder({
    this.curve = Curves.fastOutSlowIn,
  });

  /// Can be used to use your existing [HeroFlightShuttleBuilder]
  /// implementations with Heroine.
  const factory HeroineShuttleBuilder.fromHero({
    required HeroFlightShuttleBuilder flightShuttleBuilder,
  }) = _FromHeroFlightShuttleBuilder;

  /// The curve to use for the shuttle transition.
  ///
  /// Defaults to [Curves.fastOutSlowIn].
  final Curve curve;

  /// Builds the hero in flight.
  ///
  /// This will be called each frame of the transition with a [valueFromTo] that
  /// ranges from 0 to 1.
  /// If that value is at 0, we are still at the [fromHero] and if it
  /// is at 1, we are at the [toHero].
  ///
  /// Access the widgets using [fromHero] and [toHero].
  Widget buildHero({
    required BuildContext flightContext,
    required Widget fromHero,
    required Widget toHero,
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
          fromHero: fromHeroContext.widget,
          toHero: toHeroContext.widget,
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
          fromHero: fromHeroContext.widget,
          toHero: toHeroContext.widget,
          valueFromTo: remapValue(),
          flightDirection: flightDirection,
        ),
      ),
    );
  }
}

class _FromHeroFlightShuttleBuilder extends HeroineShuttleBuilder {
  const _FromHeroFlightShuttleBuilder({
    required this.flightShuttleBuilder,
  });

  final HeroFlightShuttleBuilder flightShuttleBuilder;

  @override
  Widget call(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection flightDirection,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) =>
      flightShuttleBuilder(
        flightContext,
        animation,
        flightDirection,
        fromHeroContext,
        toHeroContext,
      );

  @override
  Widget buildHero({
    required BuildContext flightContext,
    required Widget fromHero,
    required Widget toHero,
    required double valueFromTo,
    required HeroFlightDirection flightDirection,
  }) =>
      const SizedBox.shrink();

  @override
  List<Object?> get props => [flightShuttleBuilder];
}

/// A shuttle builder that fades the heroes between each other smoothly.
class FadeShuttleBuilder extends HeroineShuttleBuilder {
  /// Creates a new [FadeShuttleBuilder].
  const FadeShuttleBuilder({
    super.curve = Curves.fastOutSlowIn,
  });

  @override
  Widget buildHero({
    required BuildContext flightContext,
    required Widget fromHero,
    required Widget toHero,
    required double valueFromTo,
    required HeroFlightDirection flightDirection,
  }) =>
      Stack(
        fit: StackFit.expand,
        children: [
          if (valueFromTo < 1)
            Opacity(
              opacity: 1 - valueFromTo.clamp(0, 1),
              child: fromHero,
            ),
          if (valueFromTo > 0)
            Opacity(
              opacity: valueFromTo.clamp(0, 1),
              child: toHero,
            ),
        ],
      );

  @override
  List<Object?> get props => [];
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
    required Widget fromHero,
    required Widget toHero,
    required double valueFromTo,
    required HeroFlightDirection flightDirection,
  }) =>
      useFromHero ? fromHero : toHero;

  @override
  List<Object?> get props => [useFromHero];
}

/// A shuttle builder that flips the hero widget horizontally or vertically.
class FlipShuttleBuilder extends HeroineShuttleBuilder {
  /// Creates a new [FlipShuttleBuilder].
  const FlipShuttleBuilder({
    this.axis = Axis.vertical,
    this.flipForward = true,
    this.invertFlipOnReturn = false,
    this.halfFlips = 1,
    super.curve = Curves.fastOutSlowIn,
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
    required Widget fromHero,
    required Widget toHero,
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
              child: toHero,
            )
          : fromHero,
    );
  }

  @override
  List<Object?> get props => [axis, flipForward, invertFlipOnReturn, halfFlips];
}

/// A shuttle builder that fades through a given color.
class FadeThroughShuttleBuilder extends HeroineShuttleBuilder {
  /// Creates a new [FadeThroughShuttleBuilder].
  const FadeThroughShuttleBuilder({
    this.fadeColor = const Color.from(alpha: 1, red: 1, blue: 1, green: 1),
    super.curve = Curves.fastOutSlowIn,
  });

  /// The color to fade through.
  final Color fadeColor;

  @override
  Widget buildHero({
    required BuildContext flightContext,
    required Widget fromHero,
    required Widget toHero,
    required double valueFromTo,
    required HeroFlightDirection flightDirection,
  }) {
    final alphaFactor = (0.5 - (valueFromTo - 0.5).abs()) * 2;
    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        fadeColor.withValues(
          alpha: fadeColor.a * alphaFactor,
        ),
        BlendMode.srcATop,
      ),
      child: valueFromTo > 0.5 ? toHero : fromHero,
    );
  }

  @override
  List<Object?> get props => [fadeColor];
}

/// A shuttle builder that combines multiple [HeroineShuttleBuilder]s into a
/// single chain.
///
/// The builders are applied in order, with each builder's output being used as
/// both the `fromHero` and `toHero` for the previous builder in the chain.
/// The last builder in the chain receives the actual hero widgets.
///
/// This allows for complex transitions by combining multiple effects.
///
/// For example:
///
/// ```dart
/// ChainedShuttleBuilder(
///   builders: [
///     FlipShuttleBuilder(),
///     FadeShuttleBuilder(),
///   ],
/// )
/// ```
///
/// In this example, the fade effect will be applied first, and then the result
/// will be flipped. This creates a combined effect where the hero both fades
/// and flips during the transition.
class ChainedShuttleBuilder extends HeroineShuttleBuilder {
  /// Creates a new [ChainedShuttleBuilder] with the given list of builders.
  ///
  /// The [builders] are applied in order, with each builder's output being used
  /// as input for the previous builder. If [builders] is empty, the builder
  /// will simply return the destination hero widget.
  const ChainedShuttleBuilder({
    required List<HeroineShuttleBuilder> builders,
  }) : _builders = builders;

  /// The list of [HeroineShuttleBuilder]s to chain together.
  ///
  /// The builders are applied in order, with the last builder getting the
  /// actual hero widgets as input.
  final List<HeroineShuttleBuilder> _builders;

  @override
  Widget buildHero({
    required BuildContext flightContext,
    required Widget fromHero,
    required Widget toHero,
    required double valueFromTo,
    required HeroFlightDirection flightDirection,
  }) {
    if (_builders.isEmpty) {
      return toHero;
    }

    Widget buildChain(int index) {
      // If we're at the last builder, use the actual hero widgets
      if (index == _builders.length - 1) {
        return _builders[index].buildHero(
          flightContext: flightContext,
          fromHero: fromHero,
          toHero: toHero,
          valueFromTo: valueFromTo,
          flightDirection: flightDirection,
        );
      }

      // For other builders, use the next builder's result as both from and to
      // heroes
      final nextResult = buildChain(index + 1);
      return _builders[index].buildHero(
        flightContext: flightContext,
        fromHero: nextResult,
        toHero: nextResult,
        valueFromTo: valueFromTo,
        flightDirection: flightDirection,
      );
    }

    return buildChain(0);
  }

  @override
  List<Object?> get props => [..._builders];
}

/// Provides the [chain] extension method for easy chaining of
/// [HeroineShuttleBuilder]s.
extension Chain on HeroineShuttleBuilder {
  /// Chains this builder with another builder.
  ///
  /// This allows for a more fluent API when combining multiple shuttle
  /// builders.
  ///
  /// ```dart
  /// FlipShuttleBuilder()
  ///   .chain(FadeShuttleBuilder())
  ///   .chain(AnotherShuttleBuilder());
  /// ```
  HeroineShuttleBuilder chain(HeroineShuttleBuilder builder) => switch (this) {
        ChainedShuttleBuilder(_builders: final builders) =>
          ChainedShuttleBuilder(builders: [...builders, builder]),
        _ => ChainedShuttleBuilder(builders: [this, builder]),
      };
}
