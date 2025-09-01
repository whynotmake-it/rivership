import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'package:motor/src/motion.dart';

/// The mode in which the phase animation should loop.
enum SequenceLoopMode {
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

  /// {@macro PhaseValue}
  const factory PhaseSequence.value(
    P phase,
    T value, [
    Motion? motion,
  ]) = PhaseValue<P, T>;

  /// {@macro ListPhaseSequence}
  factory PhaseSequence.list(
    List<PhaseValue<P, T>> values,
  ) = ListPhaseSequence<P, T>;

  /// {@macro MapPhaseSequence}
  factory PhaseSequence.map(
    Map<P, T> values, {
    required Motion motion,
    SequenceLoopMode loopMode,
  }) = MapPhaseSequence<P, T>;

  /// {@macro MapPhaseSequence}
  const factory PhaseSequence.mapWithMotionPerPhase(
    Map<P, ValueWithMotion<T>> values, {
    SequenceLoopMode loopMode,
  }) = MapPhaseSequence<P, T>.motionPerPhase;

  /// {@macro ValuesPhaseSequence}
  static PhaseSequence<int, T> values<T extends Object>(
    List<T> values, {
    required Motion motion,
    SequenceLoopMode loopMode = SequenceLoopMode.none,
  }) =>
      ValuesPhaseSequence<T>(values, motion: motion, loopMode: loopMode);

  /// {@macro ValuesPhaseSequence}
  static PhaseSequence<int, T> valuesWithMotionPerPhase<T extends Object>(
    List<ValueWithMotion<T>> values, {
    SequenceLoopMode loopMode = SequenceLoopMode.none,
  }) =>
      ValuesPhaseSequence<T>.motionPerPhase(values, loopMode: loopMode);

  /// {@macro TimelineSequence}
  static TimelineSequence<T> timeline<T extends Object>(
    Map<double, T> values, {
    required Motion motion,
    SequenceLoopMode loopMode = SequenceLoopMode.none,
  }) =>
      TimelineSequence<T>(values, motion: motion, loopMode: loopMode);

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
  SequenceLoopMode get loopMode;

  /// Chains this [PhaseSequence] with the given [sequence].
  ///
  /// Phases from [sequence] will take precedence over this sequence.
  ///
  /// If you don't provide a [loopMode], the loop mode from [sequence] will be
  /// used.
  PhaseSequence<P, T> chain(
    PhaseSequence<P, T> sequence, {
    SequenceLoopMode? loopMode,
  }) {
    return chainAll([sequence], loopMode: loopMode);
  }

  /// Chains this [PhaseSequence] with the given [sequences].
  ///
  /// Phases from later sequences will take precedence over earlier ones.
  ///
  /// If you don't provide a [loopMode], the last sequence's loop mode will be
  /// used by default.
  PhaseSequence<P, T> chainAll(
    List<PhaseSequence<P, T>> sequences, {
    SequenceLoopMode? loopMode,
  }) {
    return MapPhaseSequence.motionPerPhase(
      {
        for (final sequence in sequences)
          for (final phase in sequence.phases)
            phase: (
              sequence.valueForPhase(phase),
              sequence.motionForPhase(toPhase: phase),
            ),
      },
      loopMode: loopMode ?? sequences.lastOrNull?.loopMode ?? this.loopMode,
    );
  }

  @override
  List<Object?> get props => [
        ...phases,
        ...phases.map(valueForPhase),
        ...phases
            .map((p) => motionForPhase(fromPhase: initialPhase, toPhase: p)),
        loopMode,
      ];
}

/// {@template PhaseValue}
/// A single entry in a phase sequence.
///
/// Can also be used as a standalone phase sequence with a single phase, which
/// is useful if you want to react to live user input for example.
/// {@endtemplate}
@immutable
class PhaseValue<P, T extends Object> extends PhaseSequence<P, T> {
  /// Creates a [PhaseValue] with the given value and motion.
  const PhaseValue(
    this.phase,
    this.value, [
    this.motion,
  ]);

  /// The default motion that will be used if this is created as a single value
  /// without a specific motion.
  static const Motion defaultMotion = CurvedMotion(
    duration: Duration(milliseconds: 500),
  );

  /// The single of the animation.
  final P phase;

  /// The single value to animate to.
  final T value;

  /// The motion to use for animations.
  final Motion? motion;

  @override
  SequenceLoopMode get loopMode => SequenceLoopMode.none;

  @override
  List<P> get phases => [phase];

  @override
  T valueForPhase(P phase) => value;

  @override
  Motion motionForPhase({required P toPhase, P? fromPhase}) =>
      motion ?? defaultMotion;
}

/// {@template ListPhaseSequence}
/// A phase sequence that uses a list of [PhaseValue] entries to define
/// the animation phases and their corresponding values.
/// {@endtemplate}
class ListPhaseSequence<P, T extends Object> extends PhaseSequence<P, T> {
  /// Creates a [ListPhaseSequence] with the given values and loop mode.
  ListPhaseSequence(
    List<PhaseValue<P, T>> values, {
    this.loopMode = SequenceLoopMode.none,
  }) : _valuesByPhase = {for (final value in values) value.phase: value};

  /// A map of phase values by their corresponding phases.
  final Map<P, PhaseValue<P, T>> _valuesByPhase;

  @override
  final SequenceLoopMode loopMode;

  @override
  List<P> get phases => _valuesByPhase.keys.toList();

  @override
  T valueForPhase(P phase) => _valuesByPhase[phase]!.value;

  @override
  Motion motionForPhase({required P toPhase, P? fromPhase}) {
    final value = _valuesByPhase[toPhase];
    return value!.motionForPhase(toPhase: toPhase);
  }
}

/// {@template ValuesPhaseSequence}
/// A phase sequence that uses a list of values and uses their indexes as phase.
/// {@endtemplate}
class ValuesPhaseSequence<T extends Object> extends PhaseSequence<int, T> {
  /// Creates a [ValuesPhaseSequence] with the given [values], a [motion] and
  /// loop mode.
  ValuesPhaseSequence(
    List<T> values, {
    required Motion motion,
    this.loopMode = SequenceLoopMode.none,
  }) : _valuesByPhase = {
          for (final (index, value) in values.indexed)
            index: PhaseValue(index, value, motion),
        };

  /// Creates a [ValuesPhaseSequence] with the given [ValueWithMotion]s and loop
  /// mode.
  ValuesPhaseSequence.motionPerPhase(
    List<ValueWithMotion<T>> values, {
    this.loopMode = SequenceLoopMode.none,
  }) : _valuesByPhase = {
          for (final (index, value) in values.indexed)
            index: PhaseValue(index, value.$1, value.$2),
        };

  /// A map of phase values by their corresponding phases.
  final Map<int, PhaseValue<int, T>> _valuesByPhase;

  @override
  final SequenceLoopMode loopMode;

  @override
  List<int> get phases => _valuesByPhase.keys.toList();

  @override
  T valueForPhase(int phase) => _valuesByPhase[phase]!.value;

  @override
  Motion motionForPhase({required int toPhase, int? fromPhase}) {
    final value = _valuesByPhase[toPhase];
    return value!.motionForPhase(toPhase: toPhase);
  }

  @override
  PhaseSequence<int, T> chainAll(
    List<PhaseSequence<int, T>> sequences, {
    SequenceLoopMode? loopMode,
  }) {
    // We need to offset the phases of all other [ValuesPhaseSequences]
    final s = <PhaseSequence<int, T>>[];
    var offset = phases.length;
    for (final sequence in sequences) {
      if (sequence is ValuesPhaseSequence<T>) {
        s.add(
          MapPhaseSequence.motionPerPhase({
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

    return super.chainAll(s, loopMode: loopMode);
  }
}

/// {@template MapPhaseSequence}
/// A phase sequence that uses a map of [PhaseValue] entries to define
/// the animation phases and their corresponding values.
/// {@endtemplate}
class MapPhaseSequence<P, T extends Object> extends PhaseSequence<P, T> {
  /// Creates a [MapPhaseSequence] with a single motion for all phases.
  MapPhaseSequence(
    Map<P, T> values, {
    required Motion motion,
    this.loopMode = SequenceLoopMode.none,
  }) : _valuesByPhase = {
          for (final entry in values.entries) entry.key: (entry.value, motion),
        };

  /// Creates a [MapPhaseSequence] with the given values and loop mode.
  const MapPhaseSequence.motionPerPhase(
    this._valuesByPhase, {
    this.loopMode = SequenceLoopMode.none,
  });

  /// A map of phase values by their corresponding phases.
  final Map<P, ValueWithMotion<T>> _valuesByPhase;

  @override
  final SequenceLoopMode loopMode;

  @override
  List<P> get phases => _valuesByPhase.keys.toList();

  @override
  T valueForPhase(P phase) => _valuesByPhase[phase]!.$1;

  @override
  Motion motionForPhase({required P toPhase, P? fromPhase}) {
    final value = _valuesByPhase[toPhase];
    return value!.$2;
  }
}

/// Provides methods to modify a given [PhaseSequence].
extension SequenceModificationX<P, T extends Object> on PhaseSequence<P, T> {
  /// Retains [phases] and values while using a single [motion] for all
  /// transitions.
  PhaseSequence<P, T> withSingleMotion(Motion motion) {
    return SingleMotionPhaseSequence(this, motion);
  }
}

/// A phase sequence that wraps a [parent] uses a single motion for all
/// of its transitions.
class SingleMotionPhaseSequence<P, T extends Object>
    extends PhaseSequence<P, T> {
  /// Creates a [SingleMotionPhaseSequence] with the given parent sequence
  /// and motion.
  const SingleMotionPhaseSequence(
    this.parent,
    this.motion,
  );

  /// The parent phase sequence.
  final PhaseSequence<P, T> parent;

  /// A single motion to use for every phase transition.
  final Motion motion;

  @override
  SequenceLoopMode get loopMode => parent.loopMode;

  @override
  List<P> get phases => parent.phases;

  @override
  T valueForPhase(P phase) => parent.valueForPhase(phase);

  @override
  Motion motionForPhase({required P toPhase, P? fromPhase}) => motion;
}

/// {@template TimelineSequence}
/// A phase sequence that represents a timeline where phases are defined
/// as time values mapping to property values.
///
/// This is useful for creating complex animations with multiple keyframes
/// at specific points in time. The motion is automatically trimmed to
/// the relevant portion of the timeline for each phase transition.
/// {@endtemplate}
@immutable
class TimelineSequence<T extends Object> extends PhaseSequence<double, T> {
  /// Creates a [TimelineSequence] with the given timeline values.
  ///
  /// The [values] map contains time values as keys and the corresponding
  /// property values as values. The [motion] defines the overall motion
  /// curve for the timeline.
  TimelineSequence(
    Map<double, T> values, {
    required this.motion,
    this.loopMode = SequenceLoopMode.none,
  }) : _values = values;

  final Map<double, T> _values;

  /// The original timeline values sorted by their time keys in ascending order.
  late final Map<double, T> _sortedValues = Map.fromEntries(
    _values.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );

  /// The normalized timeline values (0.0 to 1.0) for internal motion
  /// calculations.
  late final Map<double, T> _normalizedValues =
      _normalizeTimelineValues(_sortedValues);

  /// Cached list of original phase keys for performance.
  late final List<double> _phasesList = _sortedValues.keys.toList();

  /// Cached list of normalized phase keys for performance.
  late final List<double> _normalizedPhasesList =
      _normalizedValues.keys.toList();

  @visibleForTesting
  // ignore: public_member_api_docs
  Map<double, T> get sortedValues => _sortedValues;

  /// The motion curve to use for the entire timeline.
  ///
  /// This motion will be trimmed to the relevant portion for each
  /// phase transition based on the timeline segments.
  final Motion motion;

  @override
  final SequenceLoopMode loopMode;

  @override
  List<double> get phases => _phasesList;

  @override
  T valueForPhase(double phase) => _sortedValues[phase]!;

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

      return motion.trimmed(startTrim: segmentStart, endTrim: 1 - segmentEnd);
    }

    return motion;
  }

  // Gets the next best previous index from [index]
  int _getBestPreviousIndex(int index) {
    int getNaive() {
      if (index == 0) {
        switch (loopMode) {
          case SequenceLoopMode.none || SequenceLoopMode.pingPong:
            return 1;
          case SequenceLoopMode.loop:
            return _phasesList.length - 1;
          case SequenceLoopMode.seamless:
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
  Map<double, T> sortedValues,
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
/// [PhaseSequence].
extension MapConversionX<P, T extends Object> on Map<P, T> {
  /// Creates a [PhaseSequence] from this map.
  PhaseSequence<P, T> asSequence({
    required Motion withMotion,
    SequenceLoopMode loopMode = SequenceLoopMode.none,
  }) =>
      PhaseSequence.map(
        this,
        motion: withMotion,
        loopMode: loopMode,
      );
}

/// Offers extension methods for [Iterable] to facilitate conversion to
/// [PhaseSequence].
extension IterableConversionX<T extends Object> on Iterable<T> {
  /// Creates a [PhaseSequence] from these values, where the phases are the
  /// indeces.
  PhaseSequence<int, T> asSequence({
    required Motion withMotion,
    SequenceLoopMode loopMode = SequenceLoopMode.none,
  }) =>
      PhaseSequence.values(
        toList(),
        motion: withMotion,
        loopMode: loopMode,
      );

  /// Creates a [TimelineSequence] from these values, where each value is an
  /// equal distance apart.
  PhaseSequence<double, T> asTimeline({
    required Motion withMotion,
    SequenceLoopMode loopMode = SequenceLoopMode.none,
  }) =>
      PhaseSequence.timeline(
        {
          for (final (index, value) in indexed) index.toDouble(): value,
        },
        motion: withMotion,
        loopMode: loopMode,
      );
}

/// Offers extension methods for [Map] to facilitate conversion to
/// [PhaseSequence].
extension IterableMotionConversionX<T extends Object>
    on Iterable<ValueWithMotion<T>> {
  /// Creates a [PhaseSequence] from this list of [ValueWithMotion].
  PhaseSequence<int, T> asSequence({
    SequenceLoopMode loopMode = SequenceLoopMode.none,
  }) =>
      PhaseSequence.valuesWithMotionPerPhase(
        toList(),
        loopMode: loopMode,
      );
}
