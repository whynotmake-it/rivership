import 'package:flutter/widgets.dart';

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
}

/// A simple implementation of [PhaseSequence] that uses a map to define
/// phase-to-value relationships.
@immutable
class MapPhaseSequence<T extends Object, P> extends PhaseSequence<T, P> {
  /// Creates a [MapPhaseSequence] with the given phase-to-value mapping.
  const MapPhaseSequence({
    required this.phaseMap,
  });

  /// The mapping from phases to their corresponding property values.
  final Map<P, T> phaseMap;

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
}

/// A phase sequence that automatically cycles through enum values.
///
/// This is a convenience class for when your phases are defined as an enum
/// that implements [Enum].
@immutable
class EnumPhaseSequence<T extends Object, P extends Enum>
    extends PhaseSequence<T, P> {
  /// Creates an [EnumPhaseSequence] with enum values and a value provider.
  const EnumPhaseSequence({
    required this.enumValues,
    required this.valueProvider,
  });

  /// All the enum values to cycle through.
  final List<P> enumValues;

  /// Function that returns the property value for a given enum phase.
  final T Function(P phase) valueProvider;

  @override
  List<P> get phases => enumValues;

  @override
  T valueForPhase(P phase) => valueProvider(phase);
}

/// A phase sequence for simple value-based phases where the phase
/// itself IS the interpolatable value.
@immutable
class ValuePhaseSequence<T extends Object> extends PhaseSequence<T, T> {
  /// Creates a [ValuePhaseSequence] with the given values.
  const ValuePhaseSequence({
    required this.values,
  });

  /// The values to cycle through as both phases and property values.
  final List<T> values;

  @override
  List<T> get phases => values;

  @override
  T valueForPhase(T phase) => phase;
}

/// Utility extensions for creating common phase sequences.
extension PhaseSequenceUtils on Never {
  /// Creates a simple phase sequence from a list of values.
  static ValuePhaseSequence<T> fromValues<T extends Object>(
    List<T> values,
  ) {
    return ValuePhaseSequence<T>(
      values: values,
    );
  }

  /// Creates a phase sequence from a map of phase-to-value relationships.
  static MapPhaseSequence<T, P> fromMap<T extends Object, P>(
    Map<P, T> phaseMap,
  ) {
    return MapPhaseSequence<T, P>(
      phaseMap: phaseMap,
    );
  }

  /// Creates a phase sequence from enum values with a value provider function.
  static EnumPhaseSequence<T, P> fromEnum<T extends Object, P extends Enum>(
    List<P> enumValues,
    T Function(P phase) valueProvider,
  ) {
    return EnumPhaseSequence<T, P>(
      enumValues: enumValues,
      valueProvider: valueProvider,
    );
  }
}
