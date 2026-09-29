import 'package:meta/meta.dart';

/// A phase transition reported while a phased animation plays.
///
/// It is either [PhaseTransitioning] (a new phase began animating) or
/// [PhaseSettled] (the active phase came to rest).
@immutable
sealed class PhaseTransition<P> {
  const PhaseTransition();

  /// The phase where the animation is currently at or transitioning to.
  P get phase;

  /// The phase the animation is resting at ([PhaseSettled.phase]) or leaving
  /// ([PhaseTransitioning.from]).
  P get lastPhase => switch (this) {
        PhaseSettled(:final phase) => phase,
        PhaseTransitioning(from: final fromPhase) => fromPhase,
      };
}

/// The animation has settled: it is at rest at [phase].
@immutable
final class PhaseSettled<P> extends PhaseTransition<P> {
  /// Creates a settled phase transition.
  const PhaseSettled(this.phase);

  /// The phase where the animation has settled.
  @override
  final P phase;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PhaseSettled<P> &&
          runtimeType == other.runtimeType &&
          phase == other.phase);

  @override
  int get hashCode => phase.hashCode;

  @override
  String toString() => 'PhaseSettled($phase)';
}

/// The animation is moving from one phase to the next. It is reported when
/// the next phase starts.
@immutable
final class PhaseTransitioning<P> extends PhaseTransition<P> {
  /// Creates an animating phase transition.
  const PhaseTransitioning({
    required this.from,
    required this.to,
  });

  /// The phase the animation is transitioning from.
  final P from;

  /// The phase the animation is transitioning to.
  final P to;

  @override
  P get phase => to;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PhaseTransitioning<P> &&
          runtimeType == other.runtimeType &&
          from == other.from &&
          to == other.to);

  @override
  int get hashCode => Object.hash(from, to);

  @override
  String toString() => 'PhaseTransitioning(from: $from, to: $to)';
}
