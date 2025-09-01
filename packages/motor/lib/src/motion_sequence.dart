import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'package:motor/src/motion.dart';

/// The mode in which the phase animation should loop.
enum LoopMode {
  /// Don't loop the animation.
  none,

  /// The animation will loop from the last phase back to the first phase.
  loop,

  /// The animation will play forward and then reverse back to the start.
  pingPong,

  /// The animation will loop seamlessly by treating the first and last phases
  /// as identical, creating smooth circular transitions without jarring jumps.
  seamless;

  /// Whether the animation should loop.
  bool get isLooping => this == loop || this == pingPong || this == seamless;
}

/// A value and its associated motion.
typedef ValueWithMotion<T> = (T value, Motion motion);

/// {@template MotionSequence}
/// Defines a sequence of phases and their corresponding property values
/// for phase-based animations.
///
/// Each phase [P] maps to a property value [T] that can be interpolated
/// using Motor's motion system.
/// {@endtemplate}
@immutable
abstract class MotionSequence<P, T extends Object> with EquatableMixin {
  /// {@macro PhaseSequence}
  const MotionSequence();

  /// {@macro StateSequence}
  const factory MotionSequence.states(
    Map<P, T> values, {
    required Motion motion,
    LoopMode loop,
  }) = StateSequence<P, T>;

  /// {@macro StateSequence}
  const factory MotionSequence.statesWithMotions(
    Map<P, ValueWithMotion<T>> values, {
    LoopMode loop,
  }) = StateSequence<P, T>.withMotions;

  /// {@macro Sequence}
  static MotionSequence<int, T> steps<T extends Object>(
    List<T> values, {
    required Motion motion,
    LoopMode loop = LoopMode.none,
  }) =>
      StepSequence<T>(values, motion: motion, loop: loop);

  /// {@macro Sequence}
  static MotionSequence<int, T> stepsWithMotions<T extends Object>(
    List<ValueWithMotion<T>> values, {
    LoopMode loop = LoopMode.none,
  }) =>
      StepSequence<T>.withMotions(values, loop: loop);

  /// {@macro SpanningSequence}
  static SpanningSequence<T> spanning<T extends Object>(
    Map<num, T> values, {
    required Motion motion,
    LoopMode loop = LoopMode.none,
  }) =>
      SpanningSequence<T>(values, motion: motion, loop: loop);

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

  /// The motion that should be used for transitioning to [toPhase] from
  /// [fromPhase].
  ///
  /// If [fromPhase] is null, this represents the initial motion to the phase.
  Motion motionForPhase({
    required P toPhase,
    P? fromPhase,
  });

  /// The manner in which the phase animation should loop.
  LoopMode get loop;

  /// Chains this [MotionSequence] with the given [sequence].
  ///
  /// Phases from [sequence] will take precedence over this sequence.
  ///
  /// If you don't provide a [loop], the loop mode from [sequence] will be
  /// used.
  MotionSequence<P, T> chain(
    MotionSequence<P, T> sequence, {
    LoopMode? loop,
  }) {
    return chainAll([sequence], loop: loop);
  }

  /// Chains this [MotionSequence] with the given [sequences].
  ///
  /// Phases from later sequences will take precedence over earlier ones.
  ///
  /// If you don't provide a [loop], the last sequence's loop mode will be
  /// used by default.
  MotionSequence<P, T> chainAll(
    List<MotionSequence<P, T>> sequences, {
    LoopMode? loop,
  }) {
    return StateSequence.withMotions(
      {
        for (final sequence in sequences)
          for (final phase in sequence.phases)
            phase: (
              sequence.valueForPhase(phase),
              sequence.motionForPhase(toPhase: phase),
            ),
      },
      loop: loop ?? sequences.lastOrNull?.loop ?? this.loop,
    );
  }

  @override
  List<Object?> get props => [
        ...phases,
        ...phases.map(valueForPhase),
        ...phases.map((p) => motionForPhase(toPhase: p)),
        loop,
      ];
}

/// {@template Sequence}
/// A phase sequence that uses a list of values and uses their indeces.
/// {@endtemplate}
class StepSequence<T extends Object> extends MotionSequence<int, T> {
  /// Creates a [StepSequence] with the given [steps], a [motion] and
  /// loop mode.
  const StepSequence(
    this._steps, {
    required Motion motion,
    this.loop = LoopMode.none,
  })  : _motion = motion,
        _stepsWithMotions = null;

  /// Creates a [StepSequence] with the given [ValueWithMotion]s and loop
  /// mode.
  const StepSequence.withMotions(
    this._stepsWithMotions, {
    this.loop = LoopMode.none,
  })  : _steps = null,
        _motion = null;

  final List<T>? _steps;

  final Motion? _motion;

  final List<ValueWithMotion<T>>? _stepsWithMotions;

  Map<int, ValueWithMotion<T>> get _valuesByPhase {
    if (_stepsWithMotions case final v?) {
      return {
        for (final (index, value) in v.indexed) index: value,
      };
    }
    return {
      for (final (index, value) in _steps!.indexed) index: (value, _motion!),
    };
  }

  @override
  final LoopMode loop;

  @override
  List<int> get phases => _valuesByPhase.keys.toList();

  @override
  T valueForPhase(int phase) => _valuesByPhase[phase]!.$1;

  @override
  Motion motionForPhase({required int toPhase, int? fromPhase}) {
    final value = _valuesByPhase[toPhase];
    return value!.$2;
  }

  @override
  MotionSequence<int, T> chainAll(
    List<MotionSequence<int, T>> sequences, {
    LoopMode? loop,
  }) {
    // We need to offset the phases of all other [Sequences]
    final s = <MotionSequence<int, T>>[];
    var offset = phases.length;
    for (final sequence in sequences) {
      if (sequence is StepSequence<T>) {
        s.add(
          StateSequence.withMotions({
            for (final phase in sequence.phases)
              phase + offset: (
                sequence.valueForPhase(phase),
                sequence.motionForPhase(toPhase: phase),
              ),
          }),
        );
        offset += sequence.phases.length;
      }
    }

    return super.chainAll(s, loop: loop);
  }
}

/// {@template StateSequence}
/// A phase sequence that uses a map of phases to their entries to define
/// the animation phases and their corresponding values.
/// {@endtemplate}
class StateSequence<P, T extends Object> extends MotionSequence<P, T> {
  /// Creates a [StateSequence] with a single motion for all phases.
  const StateSequence(
    this._states, {
    required Motion motion,
    this.loop = LoopMode.none,
  })  : _motion = motion,
        _statesWithMotions = null;

  /// Creates a [StateSequence] with the given values and loop mode.
  const StateSequence.withMotions(
    this._statesWithMotions, {
    this.loop = LoopMode.none,
  })  : _states = null,
        _motion = null;

  /// A map of phase values.
  final Map<P, T>? _states;

  final Motion? _motion;

  /// A map of phase values by their corresponding phases.
  final Map<P, ValueWithMotion<T>>? _statesWithMotions;

  @override
  final LoopMode loop;

  @override
  List<P> get phases =>
      _states?.keys.toList() ?? _statesWithMotions!.keys.toList();

  @override
  T valueForPhase(P phase) => _states?[phase] ?? _statesWithMotions![phase]!.$1;

  @override
  Motion motionForPhase({required P toPhase, P? fromPhase}) {
    return _statesWithMotions?[toPhase]?.$2 ?? _motion!;
  }
}

/// Provides methods to modify a given [MotionSequence].
extension SequenceModificationX<P, T extends Object> on MotionSequence<P, T> {
  /// Retains [phases] and values while using a single [motion] for all
  /// transitions.
  MotionSequence<P, T> withSingleMotion(Motion motion) {
    return SingleMotionPhaseSequence(this, motion);
  }
}

/// A phase sequence that wraps a [parent] uses a single motion for all
/// of its transitions.
class SingleMotionPhaseSequence<P, T extends Object>
    extends MotionSequence<P, T> {
  /// Creates a [SingleMotionPhaseSequence] with the given parent sequence
  /// and motion.
  const SingleMotionPhaseSequence(
    this.parent,
    this.motion,
  );

  /// The parent phase sequence.
  final MotionSequence<P, T> parent;

  /// A single motion to use for every phase transition.
  final Motion motion;

  @override
  LoopMode get loop => parent.loop;

  @override
  List<P> get phases => parent.phases;

  @override
  T valueForPhase(P phase) => parent.valueForPhase(phase);

  @override
  Motion motionForPhase({required P toPhase, P? fromPhase}) => motion;
}

/// {@template SpanningSequence}
/// A phase sequence that represents a timeline where phases are defined
/// as time values mapping to property values.
///
/// This is useful for creating complex animations with multiple keyframes
/// at specific points in time. The motion is automatically trimmed to
/// the relevant portion of the timeline for each phase transition.
/// {@endtemplate}
@immutable
class SpanningSequence<T extends Object> extends MotionSequence<double, T> {
  /// Creates a [SpanningSequence] with the given timeline values.
  ///
  /// The [values] map contains time values as keys and the corresponding
  /// property values as values. The [motion] defines the overall motion
  /// curve for the timeline.
  SpanningSequence(
    Map<num, T> values, {
    required this.motion,
    this.loop = LoopMode.none,
  }) : _values = values;

  final Map<num, T> _values;

  /// The original timeline values sorted by their time keys in ascending order.
  late final Map<num, T> _sortedValues = Map.fromEntries(
    _values.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );

  /// The normalized timeline values (0.0 to 1.0) for internal motion
  /// calculations.
  late final Map<double, T> _normalizedValues =
      _normalizeTimelineValues(_sortedValues);

  /// Cached list of original phase keys for performance.
  late final List<double> _phasesList =
      _sortedValues.keys.map((n) => n.toDouble()).toList();

  /// Cached list of normalized phase keys for performance.
  late final List<num> _normalizedPhasesList = _normalizedValues.keys.toList();

  /// The motion curve to use for the entire timeline.
  ///
  /// This motion will be trimmed to the relevant portion for each
  /// phase transition based on the timeline segments.
  final Motion motion;

  @override
  final LoopMode loop;

  @override
  List<double> get phases => _phasesList;

  @override
  T valueForPhase(num phase) => _sortedValues[phase]!;

  @override
  Motion motionForPhase({
    required double toPhase,
    double? fromPhase,
  }) {
    if (_normalizedPhasesList.length == 1) return motion;

    // Find the index of the current phase in the original (non-normalized)
    // phases
    final currentIndex = _phasesList.indexOf(toPhase);
    if (currentIndex == -1) return motion;

    // We're transitioning from a specific phase, so trim motion accordingly
    final fromIndex = switch (fromPhase) {
      null => _getBestPreviousIndex(currentIndex),
      _ => _phasesList.indexOf(fromPhase),
    };

    if (fromIndex != -1) {
      final fromNormalizedPos = _normalizedPhasesList[fromIndex];
      final toNormalizedPos = _normalizedPhasesList[currentIndex];

      // Trim the motion to use only the section between the two phases
      final segmentStart = min(fromNormalizedPos, toNormalizedPos);
      final segmentEnd = max(fromNormalizedPos, toNormalizedPos);

      return motion.trimmed(
        startTrim: segmentStart.toDouble(),
        endTrim: 1 - segmentEnd.toDouble(),
      );
    }

    return motion;
  }

  // Gets the next best previous index from [index]
  int _getBestPreviousIndex(int index) {
    int getNaive() {
      if (index == 0) {
        switch (loop) {
          case LoopMode.none || LoopMode.pingPong:
            return 1;
          case LoopMode.loop:
            return _phasesList.length - 1;
          case LoopMode.seamless:
            return _phasesList.length - 2;
        }
      } else {
        return index - 1;
      }
    }

    return getNaive().clamp(0, phases.length - 1);
  }
}

/// Normalizes timeline values to the range [0.0, 1.0].
Map<double, T> _normalizeTimelineValues<T extends Object>(
  Map<num, T> sortedValues,
) {
  if (sortedValues.isEmpty) return <double, T>{};

  final keys = sortedValues.keys;
  final min = keys.first;
  final max = keys.last;
  final range = max - min;

  if (range == 0) {
    return {0.0: sortedValues.values.first};
  }

  return Map.fromEntries(
    sortedValues.entries.map((entry) {
      final normalizedKey = (entry.key - min) / range;
      return MapEntry(normalizedKey, entry.value);
    }),
  );
}

/// Offers extension methods for [Map] to facilitate conversion to
/// [MotionSequence].
extension IterableMotionConversionX<T extends Object>
    on Iterable<ValueWithMotion<T>> {
  /// Creates a [MotionSequence] from this list of [ValueWithMotion].
  MotionSequence<int, T> toSteps({
    LoopMode loop = LoopMode.none,
  }) =>
      MotionSequence.stepsWithMotions(toList(), loop: loop);
}

/// Offers extension methods for [Map] to facilitate conversion to
/// [MotionSequence].
extension MapConversionX<P, T extends Object> on Map<P, T> {
  /// Creates a [MotionSequence] from this map.
  MotionSequence<P, T> toStates({
    required Motion motion,
    LoopMode loop = LoopMode.none,
  }) =>
      MotionSequence.states(
        this,
        motion: motion,
        loop: loop,
      );
}

/// Offers extension methods for [Map] to facilitate conversion to
/// [MotionSequence].
extension MapDoubleConversionX<P extends num, T extends Object> on Map<P, T> {
  /// Creates a [MotionSequence] from this map.
  SpanningSequence<T> spanning({
    required Motion motion,
    LoopMode loop = LoopMode.none,
  }) =>
      MotionSequence.spanning(
        this,
        motion: motion,
        loop: loop,
      );
}

/// Offers extension methods for [Iterable] to facilitate conversion to
/// [MotionSequence].
extension IterableConversionX<T extends Object> on Iterable<T> {
  /// Creates a [MotionSequence] from these values, where the phases are the
  /// indeces.
  MotionSequence<int, T> toSteps({
    required Motion motion,
    LoopMode loopMode = LoopMode.none,
  }) =>
      MotionSequence.steps(
        toList(),
        motion: motion,
        loop: loopMode,
      );

  /// Creates a [SpanningSequence] from these values, where each value is an
  /// equal distance apart.
  SpanningSequence<T> spanning({
    required Motion motion,
    LoopMode loopMode = LoopMode.none,
  }) =>
      MotionSequence.spanning(
        {
          for (final (index, value) in indexed) index.toDouble(): value,
        },
        motion: motion,
        loop: loopMode,
      );
}
