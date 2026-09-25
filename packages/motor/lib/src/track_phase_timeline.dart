import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';
import 'package:motor/src/controllers/phase_track_controller.dart';
import 'package:motor/src/loop_mode.dart';
import 'package:motor/src/track.dart';
import 'package:motor/src/track_step.dart';
import 'package:motor/src/track_timeline.dart';

/// A multi-track timeline organized by phases.
///
/// Each phase maps to a list of [TrackAnimation]s that describe what happens
/// to each track during that phase. When played, the phases are flattened into
/// a single [TrackTimeline] with [StepSync] barriers inserted at phase
/// boundaries so all tracks advance together.
///
/// ```dart
/// final timeline = TrackPhaseTimeline<Phase>({
///   .idle: [size.to(Size(100, 40)), color.to(Colors.grey)],
///   .active: [size.to(Size(120, 48)), color.to(Colors.blue)],
///   .disabled: [size.to(Size(100, 40)), color.to(Colors.grey)],
/// });
/// ```
///
/// The barrier inserted before each phase uses that phase value as its
/// [StepSync.token], so your own sync tokens must not equal a phase value
/// (asserted).
///
/// Play it with a [PhaseTrackController] or `PhaseTrackBuilder`, which
/// interpret [phaseLoop], [initialValues], and [initialVelocities]. The
/// flattened phases are also available as a plain clip through [flattened].
///
/// Timelines compare by value, so an equal timeline on rebuild does not
/// restart playback.
// ignore: deprecated_member_use
class TrackPhaseTimeline<P extends Object> with EquatableMixin {
  /// Creates a phase timeline from a map of phases to track animations.
  ///
  /// The iteration order of [phaseAnimations] determines phase ordering.
  /// [phaseLoop] controls what the [PhaseTrackController] does after the last
  /// phase completes.
  ///
  /// Animations inside [phaseAnimations] must not set their own `from` or
  /// `withVelocity` (asserted): phases continue from wherever the previous
  /// phase left off. Use [initialValues] and [initialVelocities] to set
  /// where the timeline starts.
  TrackPhaseTimeline(
    Map<P, List<TrackAnimation>> phaseAnimations, {
    this.phaseLoop = LoopMode.none,
    List<TrackValue> initialValues = const [],
    List<TrackValue> initialVelocities = const [],
  })  : assert(
          phaseAnimations.values.every(
            (animations) => animations.every(
              (animation) =>
                  animation.from == null && animation.withVelocity == null,
            ),
          ),
          'Animations inside a TrackPhaseTimeline cannot set from or '
          'withVelocity. Use initialValues and initialVelocities instead.',
        ),
        assert(
          phaseAnimations.values.every(
            (animations) => animations.every(
              (animation) => animation.steps.every(
                (step) =>
                    step is! StepSync ||
                    !phaseAnimations.containsKey(step.token),
              ),
            ),
          ),
          'A sync token inside a TrackPhaseTimeline equals a phase value. '
          'Phase barriers use the phase values as tokens; use other tokens.',
        ),
        phaseAnimations = Map.unmodifiable({
          for (final MapEntry(:key, :value) in phaseAnimations.entries)
            key: List<TrackAnimation>.unmodifiable(value),
        }),
        initialValues = List.unmodifiable(initialValues),
        initialVelocities = List.unmodifiable(initialVelocities),
        flattened = TrackTimeline(_flatten(phaseAnimations));

  /// The phase-to-animation mapping as provided by the caller.
  final Map<P, List<TrackAnimation>> phaseAnimations;

  /// Values the tracks jump to when this timeline first starts playing.
  ///
  /// They are applied once per timeline, so navigating between phases
  /// animates from the current values rather than snapping back.
  final List<TrackValue> initialValues;

  /// Velocities the tracks start with when this timeline first starts
  /// playing.
  ///
  /// Each entry's [TrackValue.value] is interpreted as that track's starting
  /// velocity.
  final List<TrackValue> initialVelocities;

  /// All phases in order, flattened into one clip with a sync barrier before
  /// each phase after the first. It plays once ([LoopMode.none]).
  final TrackTimeline flattened;

  /// How the phase sequence should loop.
  ///
  /// This is handled by [PhaseTrackController] rather than by internal
  /// step playback looping, and only while auto-advancing (`playPhases`):
  ///
  /// - [LoopMode.loop] animates from the last phase back to the first and
  ///   replays the timeline.
  /// - [LoopMode.seamless] jumps to the first phase's values and continues
  ///   with the second phase.
  /// - [LoopMode.pingPong] visits the phases in reverse order, then forward
  ///   again. Each phase's own steps still play forward.
  final LoopMode phaseLoop;

  /// The ordered list of phases.
  late final List<P> phases = phaseAnimations.keys.toList();

  /// The first phase in the timeline.
  P get initialPhase => phases.first;

  /// Returns the flattened animations starting at [startPhase], skipping all
  /// phases before it.
  ///
  /// The returned list has no leading sync barrier, so playback begins
  /// immediately at [startPhase] and then advances through the remaining
  /// phases in order. Returns all of [flattened]'s animations when
  /// [startPhase] is the
  /// first phase (or not found).
  @internal
  List<TrackAnimation> animationsFrom(P startPhase) {
    final index = phases.indexOf(startPhase);
    if (index <= 0) return flattened.animations;

    final subset = <P, List<TrackAnimation>>{
      for (final phase in phases.skip(index)) phase: phaseAnimations[phase]!,
    };
    return _flatten(subset);
  }

  /// The flattened animations for playing phases in reverse order, starting
  /// from the second-to-last phase (the last phase's values are the current
  /// resting state when a pingPong reversal begins).
  ///
  /// Phase order is reversed; each phase's own steps still play forward. Sync
  /// barriers between phases carry the target phase as their token, so phase
  /// transitions are still reported through [PhaseTrackController].
  @internal
  List<TrackAnimation> reversedAnimations() {
    final reversedMap = <P, List<TrackAnimation>>{
      for (final phase in phases.reversed.skip(1))
        phase: phaseAnimations[phase]!,
    };
    return _flatten(reversedMap);
  }

  /// The flattened animations for playing phases in reverse order, starting
  /// at [startPhase], without a leading sync barrier.
  @internal
  List<TrackAnimation> reversedAnimationsFrom(P startPhase) {
    final reversed = phases.reversed.toList();
    final index = reversed.indexOf(startPhase);
    return _flatten({
      for (final phase in reversed.skip(index < 0 ? 0 : index))
        phase: phaseAnimations[phase]!,
    });
  }

  /// The resting values each track settles to at the end of the first phase.
  ///
  /// Used by [PhaseTrackController] to jump back to the start when [phaseLoop]
  /// is [LoopMode.seamless]. Tracks whose first-phase animation has no concrete
  /// target (e.g. only holds) are omitted.
  @internal
  List<TrackValue> get firstPhaseValues => [
        for (final animation
            in phaseAnimations[initialPhase] ?? const <TrackAnimation>[])
          if (animation.endValue case final value?) value,
      ];

  /// Where each track rests once [phase] has played after the phases before
  /// it: its last target up to and including [phase]. Tracks without one
  /// are omitted.
  @internal
  List<TrackValue> restingValuesAt(P phase) {
    final values = <Track, TrackValue>{};
    for (final current in phases) {
      for (final animation in phaseAnimations[current]!) {
        if (animation.endValue case final value?) {
          values[animation.track] = value;
        }
      }
      if (current == phase) break;
    }
    return values.values.toList();
  }

  static List<TrackAnimation> _flatten<P extends Object>(
    Map<P, List<TrackAnimation>> phaseAnimations,
  ) {
    final phases = phaseAnimations.keys.toList();
    if (phases.isEmpty) return const [];

    final allTracks = <Track>{};
    for (final anims in phaseAnimations.values) {
      for (final anim in anims) {
        allTracks.add(anim.track);
      }
    }

    final stepsByTrack = <Track, List<TrackStep>>{
      for (final track in allTracks) track: [],
    };

    for (var i = 0; i < phases.length; i++) {
      final phase = phases[i];
      final anims = phaseAnimations[phase]!;

      for (final anim in anims) {
        stepsByTrack[anim.track]!.addAll(anim.steps);
      }

      // Insert sync barrier after each phase except the last.
      if (i < phases.length - 1) {
        final nextPhase = phases[i + 1];
        for (final track in allTracks) {
          stepsByTrack[track]!.add(StepSync(token: nextPhase));
        }
      }
    }

    return [
      for (final entry in stepsByTrack.entries)
        entry.key.animationFromUntypedSteps(entry.value),
    ];
  }

  @override
  List<Object?> get props => [
        phases,
        [for (final phase in phases) phaseAnimations[phase]],
        phaseLoop,
        initialValues,
        initialVelocities,
      ];
}
