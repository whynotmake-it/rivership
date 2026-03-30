part of 'heroines.dart';

/// Details about a potential heroine transition, passed to
/// [Heroine.shouldTransition] to determine whether the heroine should
/// participate in a flight.
class HeroineTransitionDetails {
  /// Creates a new [HeroineTransitionDetails].
  const HeroineTransitionDetails({
    required this.currentRoute,
    required this.otherRoute,
    required this.direction,
  });

  /// The route this heroine lives on.
  final Route<dynamic> currentRoute;

  /// The route on the other end of the transition.
  final Route<dynamic> otherRoute;

  /// The direction of the transition (push or pop).
  final HeroFlightDirection direction;
}
