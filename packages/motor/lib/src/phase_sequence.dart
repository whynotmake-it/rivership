import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';
import 'package:motor/src/motion.dart';

/// A function that provides the motion for a specific phase.
typedef MotionFor<P> = Motion Function(P phase);

/// The mode in which the phase animation should loop.
enum PhaseLoopMode {
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
    PhaseLoopMode loopMode,
  }) = MapPhaseSequence<P, T>;

  /// {@macro ValuePhaseSequence}
  static PhaseSequence<T, T> values<T extends Object>(
    List<T> values, {
    required MotionFor<T> motion,
    PhaseLoopMode loopMode = PhaseLoopMode.none,
  }) =>
      ValuePhaseSequence<T>(
        values,
        motion: motion,
        loopMode: loopMode,
      );

  /// {@macro SingleValueSequence}
  static PhaseSequence<double, T> single<T extends Object>(
    T value, {
    required Motion motion,
    double phase = 0.0,
  }) =>
      SingleValueSequence<T>(
        value,
        motion: motion,
        phase: phase,
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

  /// The manner in which the phase animation should loop.
  PhaseLoopMode get loopMode;

  @override
  List<Object?> get props => [
        ...phases,
        ...phases.map(valueForPhase),
        ...phases.map(motionForPhase),
        loopMode,
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
    this.loopMode = PhaseLoopMode.none,
  });

  /// The mapping from phases to their corresponding property values.
  final Map<P, T> phaseMap;

  @override
  final MotionFor<P> motion;

  @override
  final PhaseLoopMode loopMode;

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
    this.loopMode = PhaseLoopMode.none,
  });

  /// The values to cycle through as both phases and property values.
  final List<T> values;

  @override
  final MotionFor<T> motion;

  @override
  final PhaseLoopMode loopMode;

  @override
  List<T> get phases => values;

  @override
  T valueForPhase(T phase) => phase;

  @override
  Motion motionForPhase(T phase) => motion(phase);
}

/// {@template SingleValueSequence}
/// A phase sequence containing a single value with a fixed motion.
///
/// This is useful for animations that need to animate to a single target
/// value with a specific motion, such as button press feedback or
/// simple state transitions.
/// {@endtemplate}
@immutable
class SingleValueSequence<T extends Object> extends PhaseSequence<double, T> {
  /// Creates a [SingleValueSequence] with the given value and motion.
  const SingleValueSequence(
    this.value, {
    required this.motion,
    this.phase = 0.0,
  });

  /// The single of the animation.
  final double phase;

  /// The single value to animate to.
  final T value;

  /// The motion to use for animations.
  final Motion motion;

  @override
  PhaseLoopMode get loopMode => PhaseLoopMode.none;

  @override
  List<double> get phases => [phase];

  @override
  T valueForPhase(double phase) => value;

  @override
  Motion motionForPhase(double phase) => motion;
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
    this.loopMode = PhaseLoopMode.none,
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
  final PhaseLoopMode loopMode;

  @override
  List<double> get phases => _phasesList;

  @override
  T valueForPhase(double phase) => _sortedValues[phase]!;

  @override
  Motion motionForPhase(double phase) {
    if (_normalizedPhasesList.length == 1) return motion;

    final currentIndex = _phasesList.indexOf(phase);
    final normalizedPhase = _normalizedPhasesList[currentIndex];

    if (currentIndex == 0) {
      final nextNormalized = _normalizedPhasesList[currentIndex + 1];
      return motion.subExtent(extent: (nextNormalized - normalizedPhase) / 2);
    }

    // If this is the last phase, use the motion from previous phase to 1.0
    if (currentIndex == _normalizedPhasesList.length - 1) {
      final previousNormalized = _normalizedPhasesList[currentIndex - 1];
      return motion.trimmed(
        startTrim:
            previousNormalized + (normalizedPhase - previousNormalized) / 2,
      );
    }

    // For middle phases, use the motion from previous phase to this phase
    final previousNormalized = _normalizedPhasesList[currentIndex - 1];
    return motion.subExtent(
      start: previousNormalized + (normalizedPhase - previousNormalized) / 2,
      extent: normalizedPhase - previousNormalized,
    );
  }
}
