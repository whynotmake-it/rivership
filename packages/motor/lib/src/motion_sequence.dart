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
/// A sequence of phases that smoothly animate between property values.
///
/// Create motion sequences using:
/// - [MotionSequence.states] for named phases (enums, strings)
/// - [MotionSequence.steps] for indexed progressions (0, 1, 2...)
/// - [MotionSequence.spanning] for time-based positioning
///
/// ```dart
/// // State-based sequence
/// final states = MotionSequence.states({
///   ButtonState.idle: Offset(0, 0),
///   ButtonState.pressed: Offset(0, 10),
/// }, motion: Motion.bouncySpring());
///
/// // Step sequence
/// final steps = MotionSequence.steps([
///   Colors.red, Colors.green, Colors.blue
/// ], motion: Motion.smoothSpring());
/// ```
/// {@endtemplate}
@immutable
abstract class MotionSequence<P, T extends Object> with EquatableMixin {
  /// {@macro MotionSequence}
  const MotionSequence();

  /// Creates a sequence from named phases to values.
  ///
  /// Perfect for state machines, enums, or any named phase system.
  ///
  /// ```dart
  /// enum ButtonState { idle, pressed, loading }
  ///
  /// final sequence = MotionSequence.states({
  ///   ButtonState.idle: Offset(0, 0),
  ///   ButtonState.pressed: Offset(0, 5),
  ///   ButtonState.loading: Offset(10, 0),
  /// }, motion: Motion.bouncySpring());
  /// ```
  const factory MotionSequence.states(
    Map<P, T> values, {
    required Motion motion,
    LoopMode loop,
  }) = StateSequence<P, T>;

  /// Creates a sequence from named phases to values, each with its own motion.
  ///
  /// ```dart
  /// final sequence = MotionSequence.statesWithMotions({
  ///   ButtonState.idle: (Offset(0, 0), Motion.smoothSpring()),
  ///   ButtonState.pressed: (Offset(0, 5), Motion.snappySpring()),
  /// });
  /// ```
  const factory MotionSequence.statesWithMotions(
    Map<P, ValueWithMotion<T>> values, {
    LoopMode loop,
  }) = StateSequence<P, T>.withMotions;

  /// Creates a sequence that steps through values by index (0, 1, 2...).
  ///
  /// The most common sequence type for ordered progressions.
  ///
  /// ```dart
  /// final positions = MotionSequence.steps([
  ///   Offset(0, 0),
  ///   Offset(100, 100),
  ///   Offset(200, 0),
  /// ], motion: Motion.smoothSpring(), loop: LoopMode.seamless);
  /// ```
  static MotionSequence<int, T> steps<T extends Object>(
    List<T> values, {
    required Motion motion,
    LoopMode loop = LoopMode.none,
  }) =>
      StepSequence<T>(values, motion: motion, loop: loop);

  /// Creates a sequence that steps through values, each with its own motion.
  ///
  /// ```dart
  /// final sequence = MotionSequence.stepsWithMotions([
  ///   (Offset(0, 0), Motion.smoothSpring()),
  ///   (Offset(100, 100), Motion.bouncySpring()),
  ///   (Offset(200, 0), Motion.smoothSpring()),
  /// ]);
  /// ```
  static MotionSequence<int, T> stepsWithMotions<T extends Object>(
    List<ValueWithMotion<T>> values, {
    LoopMode loop = LoopMode.none,
  }) =>
      StepSequence<T>.withMotions(values, loop: loop);

  /// Creates a sequence where a single motion spans across positioned phases.
  ///
  /// Phases are positioned proportionally like flexbox - a phase at position
  /// 2.0 takes twice as long to reach as one at 1.0.
  ///
  /// ```dart
  /// // 2-second animation with proportional timing
  /// final timeline = MotionSequence.spanning({
  ///   0.0: LogoState(opacity: 0),      // Start (0% of time)
  ///   1.0: LogoState(opacity: 1),      // 50% of time
  ///   2.0: LogoState(opacity: 0),      // 100% of time
  /// }, motion: LinearMotion(Duration(seconds: 2)));
  /// ```
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

/// {@template StepSequence}
/// A sequence that steps through values by index (0, 1, 2...).
///
/// Use [MotionSequence.steps] to create step sequences.
/// {@endtemplate}
class StepSequence<T extends Object> extends MotionSequence<int, T> {
  /// Creates a step sequence with a single motion for all steps.
  const StepSequence(
    this._steps, {
    required Motion motion,
    this.loop = LoopMode.none,
  })  : _motion = motion,
        _stepsWithMotions = null;

  /// Creates a step sequence with individual motions per step.
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
/// A sequence using named phases mapped to values.
///
/// Perfect for state machines, enums, or any named phase system.
/// Use [MotionSequence.states] to create state sequences.
/// {@endtemplate}
class StateSequence<P, T extends Object> extends MotionSequence<P, T> {
  /// Creates a state sequence with a single motion for all transitions.
  const StateSequence(
    this._states, {
    required Motion motion,
    this.loop = LoopMode.none,
  })  : _motion = motion,
        _statesWithMotions = null;

  /// Creates a state sequence with individual motions per phase.
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
/// A sequence where a single motion spans across positioned phases.
///
/// Phases are positioned proportionally like flexbox - higher position
/// values take more time to reach. The single motion is distributed
/// across all phases based on their relative positions.
///
/// ```dart
/// // A 2-second animation with proportional timing:
/// SpanningSequence({
///   0.0: startValue,  // 0% of animation time
///   1.0: midValue,    // 50% of animation time
///   3.0: endValue,    // 100% of animation time
/// }, motion: LinearMotion(Duration(seconds: 2)))
/// ```
/// {@endtemplate}
@immutable
class SpanningSequence<T extends Object> extends MotionSequence<double, T> {
  /// Creates a spanning sequence with positioned phases.
  ///
  /// [values] maps position numbers to property values. The [motion]
  /// spans across all phases proportionally based on their positions.
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

  /// The motion that spans across all phases.
  ///
  /// This motion is automatically trimmed for each phase transition
  /// based on the proportional positions.
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

/// Extension methods for creating step sequences from value-motion pairs.
extension IterableMotionConversionX<T extends Object>
    on Iterable<ValueWithMotion<T>> {
  /// Creates a step sequence from this list of values with motions.
  ///
  /// ```dart
  /// final sequence = [
  ///   (Colors.red, Motion.smoothSpring()),
  ///   (Colors.green, Motion.bouncySpring()),
  /// ].toSteps();
  /// ```
  MotionSequence<int, T> toSteps({
    LoopMode loop = LoopMode.none,
  }) =>
      MotionSequence.stepsWithMotions(toList(), loop: loop);
}

/// Extension methods for creating state sequences from maps.
extension MapConversionX<P, T extends Object> on Map<P, T> {
  /// Creates a state sequence from this phase-to-value mapping.
  ///
  /// ```dart
  /// final sequence = {
  ///   ButtonState.idle: Offset(0, 0),
  ///   ButtonState.pressed: Offset(0, 5),
  /// }.toStates(motion: Motion.bouncySpring());
  /// ```
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

/// Extension methods for creating spanning sequences from position maps.
extension MapDoubleConversionX<P extends num, T extends Object> on Map<P, T> {
  /// Creates a spanning sequence from this position-to-value mapping.
  ///
  /// Perfect for Dart 3.10 dot shorthand syntax.
  ///
  /// ```dart
  /// final timeline = {
  ///   0.0: startState,
  ///   1.5: midState,
  ///   3.0: endState,
  /// }.spanning(motion: LinearMotion(Duration(seconds: 2)));
  /// ```
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

/// Extension methods for creating sequences from lists.
extension IterableConversionX<T extends Object> on Iterable<T> {
  /// Creates a step sequence from this list using indices as phases.
  ///
  /// Perfect for Dart 3.10 dot shorthand syntax.
  ///
  /// ```dart
  /// final colors = [
  ///   Colors.red,
  ///   Colors.green,
  ///   Colors.blue,
  /// ].toSteps(motion: Motion.smoothSpring());
  /// ```
  MotionSequence<int, T> toSteps({
    required Motion motion,
    LoopMode loopMode = LoopMode.none,
  }) =>
      MotionSequence.steps(
        toList(),
        motion: motion,
        loop: loopMode,
      );

  /// Creates a spanning sequence where values are equally spaced.
  ///
  /// ```dart
  /// final positions = [
  ///   Offset(0, 0),
  ///   Offset(50, 50),
  ///   Offset(100, 0),
  /// ].spanning(motion: LinearMotion(Duration(seconds: 2)));
  /// // Equivalent to: {0.0: pos1, 1.0: pos2, 2.0: pos3}
  /// ```
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
