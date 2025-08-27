import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/src/motion.dart';

/// A function that provides the motion for a specific phase.
typedef MotionFor<P> = Motion Function(P phase);

/// {@template PhaseSequence}
/// Defines a sequence of phases and their corresponding property values
/// for phase-based animations.
///
/// Each phase [P] maps to a property value [T] that can be interpolated
/// using Motor's motion system.
/// {@endtemplate}
@immutable
abstract class PhaseSequence<P, T extends Object> with EquatableMixin {
  /// {@macro PhaseSequence}
  const PhaseSequence();

  /// {@macro MapPhaseSequence}
  const factory PhaseSequence.map(
    Map<P, T> phaseMap, {
    required MotionFor<P> motion,
  }) = MapPhaseSequence<P, T>;

  /// {@macro ValuePhaseSequence}
  static PhaseSequence<T, T> values<T extends Object>(
    List<T> values, {
    required MotionFor<T> motion,
  }) =>
      ValuePhaseSequence<T>(
        values,
        motion: motion,
      );

  /// The list of phases in the sequence.
  ///
  /// The animation will cycle through these phases in order.
  List<P> get phases;

  /// Returns the property value for the given [phase].
  ///
  /// This value will be interpolated to when transitioning to this phase.
  T valueForPhase(P phase);

  /// The initial phase of the sequence.
  ///
  /// Defaults to the first phase in [phases].
  P get initialPhase => phases.first;

  /// The motion that should be used for transitioning to [phase].
  Motion motionForPhase(P phase);

  @override
  List<Object?> get props => [
        ...phases,
        ...phases.map(valueForPhase),
        ...phases.map(motionForPhase),
      ];
}

/// Allows setting a callback that will be used to obtain the motion for a given
/// phase.
mixin PhaseCallbackMixin<P, T extends Object> on PhaseSequence<P, T> {
  /// A function that provides the motion for a specific phase.
  MotionFor<P> get motion;

  @override
  Motion motionForPhase(P phase) => motion(phase);
}

/// {@template MapPhaseSequence}
/// A simple implementation of [PhaseSequence] that uses a map to define
/// phase-to-value relationships.
/// {@endtemplate}
@immutable
class MapPhaseSequence<P, T extends Object> extends PhaseSequence<P, T>
    with PhaseCallbackMixin<P, T> {
  /// Creates a [MapPhaseSequence] with the given phase-to-value mapping.
  const MapPhaseSequence(
    this.phaseMap, {
    required this.motion,
  });

  /// The mapping from phases to their corresponding property values.
  final Map<P, T> phaseMap;

  @override
  final MotionFor<P> motion;

  @override
  List<P> get phases => phaseMap.keys.toList();

  @override
  T valueForPhase(P phase) => phaseMap[phase]!;

  @override
  Motion motionForPhase(P phase) => motion(phase);
}

/// {@template ValuePhaseSequence}
/// A phase sequence for simple value-based phases where the phase
/// itself IS the interpolatable value.
/// {@endtemplate}
@immutable
class ValuePhaseSequence<T extends Object> extends PhaseSequence<T, T>
    with PhaseCallbackMixin<T, T> {
  /// Creates a [ValuePhaseSequence] with the given values.
  const ValuePhaseSequence(
    this.values, {
    required this.motion,
  });

  /// The values to cycle through as both phases and property values.
  final List<T> values;

  @override
  final MotionFor<T> motion;

  @override
  List<T> get phases => values;

  @override
  T valueForPhase(T phase) => phase;

  @override
  Motion motionForPhase(T phase) => motion(phase);
}

/// {@template TimelineSequence}
/// A phase sequence that represents a timeline where phases are defined
/// as normalized time values (0.0 to 1.0) mapping to property values.
///
/// This is useful for creating complex animations with multiple keyframes
/// at specific points in time. The motion is automatically trimmed to
/// the relevant portion of the timeline for each phase transition.
/// {@endtemplate}
@immutable
class TimelineSequence<T extends Object> extends PhaseSequence<double, T> {
  /// Creates a [TimelineSequence] with the given timeline values.
  ///
  /// The [values] map should contain normalized time values (0.0 to 1.0)
  /// as keys and the corresponding property values as values.
  /// The [motion] defines the overall motion curve for the timeline.
  TimelineSequence(
    this.values, {
    required this.motion,
  });

  /// The timeline mapping from normalized time values to property values.
  ///
  /// Keys should be normalized time values between 0.0 and 1.0,
  /// representing keyframes in the animation timeline.
  final Map<double, T> values;

  @visibleForTesting

  /// The timeline values sorted by their time keys in ascending order.
  late final sortedValues = Map.fromEntries(
    values.entries.toList()
      ..sort(
        (a, b) => a.key.compareTo(b.key),
      ),
  );

  /// The motion curve to use for the entire timeline.
  ///
  /// This motion will be trimmed to the relevant portion for each
  /// phase transition based on the timeline segments.
  final Motion motion;

  @override
  List<double> get phases => sortedValues.keys.toList();

  @override
  T valueForPhase(double phase) => sortedValues[phase]!;

  @override
  Motion motionForPhase(double phase) {
    final phaseList = phases;
    final currentIndex = phaseList.indexOf(phase);

    if (phaseList.length == 1) return motion;

    if (currentIndex == 0) {
      final next = phaseList[currentIndex + 1];

      return motion.subExtent(extent: (next - phase) / 2);
    }

    // If this is the last phase, use the motion from previous phase to 1.0
    if (currentIndex == phaseList.length - 1) {
      final previousPhase = phaseList[currentIndex - 1];
      return motion.trimmed(
        startTrim: previousPhase + (phase - previousPhase) / 2,
      );
    }

    // For middle phases, use the motion from previous phase to this phase
    final previousPhase = phaseList[currentIndex - 1];
    final next = phaseList[currentIndex + 1];
    return motion.subExtent(
      start: previousPhase + (phase - previousPhase) / 2,
      extent: (next - previousPhase) / 2,
    );
  }
}
