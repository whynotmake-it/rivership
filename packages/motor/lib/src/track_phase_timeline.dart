import 'package:meta/meta.dart';
import 'package:motor/src/controllers/phase_track_controller.dart';
import 'package:motor/src/loop_mode.dart';
import 'package:motor/src/step.dart';
import 'package:motor/src/track.dart';
import 'package:motor/src/track_timeline.dart';

/// A multi-track timeline organized by phases.
///
/// Each phase maps to a list of [TrackAnimation]s that describe what happens
/// to each track during that phase. When played, the phases are flattened into
/// a single [TrackTimeline] with [SyncStep] barriers inserted at phase
/// boundaries so all tracks advance together.
///
/// ```dart
/// final timeline = TrackPhaseTimeline({
///   Phase.idle: [size.to(Size(100, 40)), color.to(Colors.grey)],
///   Phase.active: [size.to(Size(120, 48)), color.to(Colors.blue)],
///   Phase.disabled: [size.to(Size(100, 40)), color.to(Colors.grey)],
/// });
/// ```
class TrackPhaseTimeline<P extends Object> extends TrackTimeline {
  /// Creates a phase timeline from a map of phases to track animations.
  ///
  /// The iteration order of [phaseAnimations] determines phase ordering.
  /// The [loop] parameter controls whether the [PhaseTrackController] will
  /// restart playback after the last phase completes.
  TrackPhaseTimeline(
    this.phaseAnimations, {
    this.phaseLoop = LoopMode.none,
    List<TrackValue> from = const [],
    List<TrackValue> withVelocity = const [],
  }) : super(
          _flatten(phaseAnimations),
          loop: LoopMode.none,
          from: from,
          withVelocity: withVelocity,
        );

  /// The phase-to-animation mapping as provided by the caller.
  final Map<P, List<TrackAnimation>> phaseAnimations;

  /// How the phase sequence should loop.
  ///
  /// This is handled by [PhaseTrackController] rather than by internal
  /// step playback looping. When [phaseLoop] is [LoopMode.loop], the
  /// controller replays the timeline from the first phase after the last
  /// phase completes.
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
  /// phases in order. Returns the full [animations] when [startPhase] is the
  /// first phase (or not found).
  @internal
  List<TrackAnimation> animationsFrom(P startPhase) {
    final index = phases.indexOf(startPhase);
    if (index <= 0) return animations;

    final subset = <P, List<TrackAnimation>>{
      for (final phase in phases.skip(index)) phase: phaseAnimations[phase]!,
    };
    return _flatten(subset);
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

    final stepsByTrack = <Track, List<Step>>{
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
          stepsByTrack[track]!.add(SyncStep(token: nextPhase));
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
        ...phases,
        for (final phase in phases) ...phaseAnimations[phase]!,
        phaseLoop,
        ...from,
        ...withVelocity,
      ];
}
