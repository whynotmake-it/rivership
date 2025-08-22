import 'package:flutter/widgets.dart';
import 'package:motor/src/motion.dart';

/// {@template PhaseSequence}
/// Defines a sequence of phases and their corresponding property values
/// for phase-based animations.
///
/// Each phase [P] maps to a property value [T] that can be interpolated
/// using Motor's motion system.
/// {@endtemplate}
@immutable
abstract class PhaseSequence<T extends Object, P> {
  /// {@macro PhaseSequence}
  const PhaseSequence();

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
}

/// A simple implementation of [PhaseSequence] that uses a map to define
/// phase-to-value relationships.
@immutable
class MapPhaseSequence<T extends Object, P> extends PhaseSequence<T, P> {
  /// Creates a [MapPhaseSequence] with the given phase-to-value mapping.
  const MapPhaseSequence({
    required this.phaseMap,
    required this.motion,
  });

  /// The mapping from phases to their corresponding property values.
  final Map<P, T> phaseMap;

  /// The motion to use for phase transitions.
  final Motion motion;

  @override
  List<P> get phases => phaseMap.keys.toList();

  @override
  T valueForPhase(P phase) {
    final value = phaseMap[phase];
    if (value == null) {
      throw ArgumentError('No value defined for phase: $phase');
    }
    return value;
  }

  @override
  Motion motionForPhase(P phase) => motion;
}

/// A phase sequence for simple value-based phases where the phase
/// itself IS the interpolatable value.
@immutable
class ValuePhaseSequence<T extends Object> extends PhaseSequence<T, T> {
  /// Creates a [ValuePhaseSequence] with the given values.
  const ValuePhaseSequence({
    required this.values,
    required this.motion,
  });

  /// The values to cycle through as both phases and property values.
  final List<T> values;

  /// The motion to use for phase transitions.
  final Motion motion;

  @override
  List<T> get phases => values;

  @override
  T valueForPhase(T phase) => phase;

  @override
  Motion motionForPhase(T phase) => motion;
}

/// Wraps a [PhaseSequence] and adds per-phase motion customization.
class MotionMapSequence<T extends Object, P> extends PhaseSequence<T, P> {
  /// Creates a [MotionMapSequence] with the given parent sequence and motion
  /// map.
  const MotionMapSequence({
    required this.parent,
    required this.motionByPhase,
  });

  /// The parent phase sequence that should be wrapped.
  final PhaseSequence<T, P> parent;

  /// The motion map that defines per-phase motion customizations.
  final Map<P, Motion> motionByPhase;

  @override
  List<P> get phases => parent.phases;

  @override
  T valueForPhase(P phase) => parent.valueForPhase(phase);

  @override
  Motion motionForPhase(P phase) {
    return motionByPhase[phase] ?? parent.motionForPhase(phase);
  }
}

/// Provides motion customization for each phase in the sequence.
extension MotionByPhaseExtension<T extends Object, P> on PhaseSequence<T, P> {
  /// Wraps the phase sequence in a [MotionMapSequence] with the given motion
  /// map.
  MotionMapSequence<T, P> withMotionPerPhase(Map<P, Motion> motionMap) {
    return MotionMapSequence<T, P>(
      parent: this,
      motionByPhase: motionMap,
    );
  }
}
