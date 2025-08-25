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
abstract class PhaseSequence<T extends Object, P> with EquatableMixin {
  /// {@macro PhaseSequence}
  const PhaseSequence();

  /// {@macro MapPhaseSequence}
  const factory PhaseSequence.map(
    Map<P, T> phaseMap, {
    required MotionFor<P> motion,
  }) = MapPhaseSequence<T, P>;

  /// {@macro ValuePhaseSequence}
  static PhaseSequence<T, T> values<T extends Object>(
    List<T> values, {
    required MotionFor<T> motion,
  }) =>
      ValuePhaseSequence<T>(
        values,
        motion: motion,
      );

  /// Creates a seamless looping phase sequence where the first phase value
  /// is automatically duplicated at the end to ensure smooth transitions.
  /// 
  /// This is useful for creating circular animations where you want to loop
  /// back to the beginning without a jarring jump between the last and first values.
  static PhaseSequence<T, T> seamlessValues<T extends Object>(
    List<T> values, {
    required MotionFor<T> motion,
  }) {
    if (values.isEmpty) {
      throw ArgumentError('Values list cannot be empty');
    }
    
    // Add the first value at the end if it's not already there
    final seamlessValues = values.length == 1 || values.last == values.first
        ? values
        : [...values, values.first];
    
    return ValuePhaseSequence<T>(
      seamlessValues,
      motion: motion,
    );
  }

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
mixin PhaseCallbackMixin<T extends Object, P> on PhaseSequence<T, P> {
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
class MapPhaseSequence<T extends Object, P> extends PhaseSequence<T, P>
    with PhaseCallbackMixin<T, P> {
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
