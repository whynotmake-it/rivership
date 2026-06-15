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
