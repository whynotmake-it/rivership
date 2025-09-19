import 'package:meta/meta.dart';

/// Represents the different states of phase transitions in a sequence
/// animation.
///
/// This sealed class models the various states a phase transition can be in:
/// - [PhaseSettled]: The animation has settled at a specific phase
/// - [PhaseTransitioning]: The animation is transitioning from one phase
///   to another
@immutable
sealed class PhaseTransition<P> {
  const PhaseTransition();

  const factory PhaseTransition.settled(P phase) = PhaseSettled<P>;

  const factory PhaseTransition.transitioning({
    required P from,
    required P to,
  }) = PhaseTransitioning<P>;

  /// Returns the last phase we were at.
  P get lastPhase => switch (this) {
        PhaseSettled(:final phase) => phase,
        PhaseTransitioning(from: final fromPhase) => fromPhase,
      };
}

/// Represents a settled state where the animation has completed and is at rest
/// at a specific phase.
@immutable
final class PhaseSettled<P> extends PhaseTransition<P> {
  /// Creates a settled phase transition.
  const PhaseSettled(this.phase);

  /// The phase where the animation has settled.
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

/// Represents an animating state where the animation is transitioning from
/// one phase to another.
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
