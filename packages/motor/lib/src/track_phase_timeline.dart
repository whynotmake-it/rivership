import 'package:flutter/foundation.dart' show listEquals, objectRuntimeType;
import 'package:meta/meta.dart';
import 'package:motor/src/controllers/phase_track_controller.dart';
import 'package:motor/src/loop_mode.dart';
import 'package:motor/src/track.dart';
import 'package:motor/src/track_step.dart';

/// A multi-track timeline organized by phases.
///
/// Each phase maps to a list of [TrackAnimation]s that describe what happens
/// to each track during that phase. When played, the phases are compiled into
/// a single multi-track step plan with [StepSync] barriers at phase boundaries
/// and [TrackStep.loop] for looping, so all tracks advance together at the
/// exact boundary time.
///
/// The next phase starts once every track's last step has settled. Give a
/// step `until: .ended` to move on once it has ended instead, after its
/// motion's duration, while a spring keeps settling, as SwiftUI's
/// `PhaseAnimator` does.
///
/// ```dart
/// final timeline = TrackPhaseTimeline<Phase>({
///   .idle: [size([.to(Size(100, 40))]), color([.to(Colors.grey)])],
///   .active: [size([.to(Size(120, 48))]), color([.to(Colors.blue)])],
///   .disabled: [size([.to(Size(100, 40))]), color([.to(Colors.grey)])],
/// });
/// ```
///
/// A [TrackStep.at] in a phase counts from the start of that phase, however
/// playback got there.
///
/// Play it with a [PhaseTrackController] or `PhaseTrackBuilder`, which
/// interpret [loop] and [initialValues]. The flattened single-pass animations
/// are also available through [flattened].
///
/// Timelines compare by value, so an equal timeline on rebuild does not
/// restart playback.
@immutable
final class TrackPhaseTimeline<P extends Object> {
  /// Creates a phase timeline from a map of phases to track animations.
  ///
  /// The iteration order of [phaseAnimations] determines phase ordering.
  /// [loop] controls how [PhaseTrackController.playPhases] repeats after the
  /// last phase.
  ///
  /// Animations inside [phaseAnimations] must not set their own `from`,
  /// `withVelocity` or `delay` (asserted): phases continue from wherever the
  /// previous phase left off. Use [initialValues], which can carry velocities,
  /// to set where the timeline starts.
  TrackPhaseTimeline(
    Map<P, List<TrackAnimation>> phaseAnimations, {
    this.loop = LoopMode.none,
    List<TrackValue> initialValues = const [],
  })  : assert(
          phaseAnimations.values.every(
            (animations) => animations.every(
              (animation) =>
                  animation.from == null &&
                  animation.withVelocity == null &&
                  animation.delay == Duration.zero,
            ),
          ),
          'Animations inside a TrackPhaseTimeline cannot set from, '
          'withVelocity or delay. Use initialValues instead.',
        ),
        phaseAnimations = Map.unmodifiable({
          for (final MapEntry(:key, :value) in phaseAnimations.entries)
            key: List<TrackAnimation>.unmodifiable(value),
        }),
        initialValues = List.unmodifiable(initialValues),
        flattened = List<TrackAnimation>.unmodifiable(
          _flatten(phaseAnimations),
        );

  /// The phase-to-animation mapping as provided by the caller.
  final Map<P, List<TrackAnimation>> phaseAnimations;

  /// Values (and optionally velocities) the tracks jump to each time this
  /// timeline starts playing: on every `playPhases`, even with an equal
  /// timeline, on the first `goToPhase` after `setTimeline`, and when a
  /// `PhaseTrackBuilder` mounts or restarts.
  ///
  /// Moving between phases doesn't apply them, so it animates from the
  /// current values rather than snapping back.
  final List<TrackValue> initialValues;

  /// All phases in order, flattened into a single-pass list of
  /// [TrackAnimation]s with a sync barrier before each phase after the first.
  final List<TrackAnimation> flattened;

  /// How the phase sequence should loop while auto-advancing (`playPhases`):
  ///
  /// - [LoopMode.none] plays all phases once and settles.
  /// - [LoopMode.loop] animates from the last phase back to the first and
  ///   replays the timeline.
  /// - [LoopMode.seamless] jumps to the first phase's resting values and
  ///   continues with the second phase.
  /// - [LoopMode.pingPong] visits the phases in reverse order, then forward
  ///   again. Each phase's own steps still play forward.
  final LoopMode loop;

  /// The ordered list of phases.
  late final List<P> phases = phaseAnimations.keys.toList();

  /// The first phase in the timeline.
  P get initialPhase => phases.first;

  /// The resolved start value for every track in this timeline.
  List<TrackValue> get startValues => [
        for (final animation in flattened)
          animation.track.value(animation.resolveStartValue()),
      ];

  /// Compiles this timeline into a single multi-track step plan starting at
  /// [fromPhase] (or [initialPhase]), including its [loop] behavior.
  ///
  /// When [forward] is `false` (used during [LoopMode.pingPong] reverse passes
  /// by `updateTimeline`), playback continues in reverse from [fromPhase]
  /// before entering the repeating loop.
  @internal
  List<TrackAnimation> compile({P? fromPhase, bool forward = true}) {
    if (phases.isEmpty) return const [];

    final startIndex = switch (fromPhase) {
      final phase? => () {
          final index = phases.indexOf(phase);
          return index < 0 ? 0 : index;
        }(),
      null => 0,
    };

    final allTracks = <Track>[
      for (final animation in flattened) animation.track,
    ];
    if (allTracks.isEmpty) return const [];

    final intro = <Track, List<TrackStep<Object>>>{
      for (final track in allTracks) track: [],
    };
    final loopBody = <Track, List<TrackStep<Object>>>{
      for (final track in allTracks) track: [],
    };

    void addPhase(Map<Track, List<TrackStep<Object>>> target, P phase) {
      for (final animation in phaseAnimations[phase]!) {
        target[animation.track]!.addAll(animation.steps);
      }
    }

    void addBarrier(
      Map<Track, List<TrackStep<Object>>> target,
      _PhaseToken<P> token,
    ) {
      for (final track in allTracks) {
        target[track]!.add(PhaseBoundary(token: token));
      }
    }

    void addForwardRange(
      Map<Track, List<TrackStep<Object>>> target,
      int from,
      int toInclusive, {
      required bool leadingBarrier,
    }) {
      for (var i = from; i <= toInclusive; i++) {
        if (leadingBarrier || i > from) {
          addBarrier(target, _PhaseToken<P>(phases[i]));
        }
        addPhase(target, phases[i]);
      }
    }

    void addReverseRange(
      Map<Track, List<TrackStep<Object>>> target,
      int from,
      int toInclusive, {
      required bool leadingBarrier,
    }) {
      for (var i = from; i >= toInclusive; i--) {
        if (leadingBarrier || i < from) {
          addBarrier(target, _PhaseToken<P>(phases[i], forward: false));
        }
        addPhase(target, phases[i]);
      }
    }

    switch (loop) {
      case LoopMode.none:
        addForwardRange(
          intro,
          startIndex,
          phases.length - 1,
          leadingBarrier: false,
        );

      case LoopMode.loop:
        addForwardRange(
          intro,
          startIndex,
          phases.length - 1,
          leadingBarrier: false,
        );
        addForwardRange(
          loopBody,
          0,
          phases.length - 1,
          leadingBarrier: true,
        );

      case LoopMode.pingPong:
        if (phases.length < 2) {
          addPhase(intro, phases.first);
          addBarrier(loopBody, _PhaseToken<P>(phases.first));
          addPhase(loopBody, phases.first);
        } else if (forward) {
          addForwardRange(
            intro,
            startIndex,
            phases.length - 1,
            leadingBarrier: false,
          );
          addReverseRange(
            loopBody,
            phases.length - 2,
            0,
            leadingBarrier: true,
          );
          addForwardRange(
            loopBody,
            1,
            phases.length - 1,
            leadingBarrier: true,
          );
        } else {
          addReverseRange(intro, startIndex, 0, leadingBarrier: false);
          addForwardRange(
            loopBody,
            1,
            phases.length - 1,
            leadingBarrier: true,
          );
          addReverseRange(
            loopBody,
            phases.length - 2,
            0,
            leadingBarrier: true,
          );
        }

      case LoopMode.seamless:
        if (phases.length < 2) {
          addPhase(intro, phases.first);
          addBarrier(loopBody, _PhaseToken<P>(phases.first));
          addPhase(loopBody, phases.first);
        } else {
          addForwardRange(
            intro,
            startIndex,
            phases.length - 1,
            leadingBarrier: false,
          );
          addBarrier(
            loopBody,
            _PhaseToken<P>(phases.first, isSeamlessWrap: true),
          );
          final resting = <Track, TrackValue>{
            for (final value in restingValuesAt(phases.first))
              value.track: value,
          };
          for (final track in allTracks) {
            if (resting[track]?.instantStep case final jump?) {
              loopBody[track]!.add(jump);
            }
          }
          addForwardRange(
            loopBody,
            1,
            phases.length - 1,
            leadingBarrier: true,
          );
        }
    }

    final hasLoop = loop.isLooping;
    return [
      for (final track in allTracks)
        if (intro[track]!.isNotEmpty ||
            (hasLoop && loopBody[track]!.isNotEmpty))
          track.animationFromUntypedSteps([
            ...intro[track]!,
            if (hasLoop && loopBody[track]!.isNotEmpty)
              StepLoop<Object>(loopBody[track]!),
          ]),
    ];
  }

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
          stepsByTrack[track]!
              .add(PhaseBoundary(token: _PhaseToken<P>(nextPhase)));
        }
      }
    }

    return [
      for (final entry in stepsByTrack.entries)
        entry.key.animationFromUntypedSteps(entry.value),
    ];
  }

  /// Decodes a barrier [token] into the phase it starts and its playback
  /// direction, or null when [token] is not one of this timeline's phase
  /// barriers (such as a user's own sync token).
  @internal
  ({P phase, bool forward})? phaseInfoForToken(Object token) {
    if (token is! _PhaseToken<P>) return null;
    if (!phaseAnimations.containsKey(token.phase)) return null;
    return (phase: token.phase, forward: token.forward);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TrackPhaseTimeline<P> ||
        other.runtimeType != runtimeType ||
        other.loop != loop ||
        !listEquals(other.phases, phases) ||
        !listEquals(other.initialValues, initialValues)) {
      return false;
    }
    for (final phase in phases) {
      if (!listEquals(other.phaseAnimations[phase], phaseAnimations[phase])) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        runtimeType,
        loop,
        Object.hashAll([
          for (final phase in phases) ...[
            phase,
            Object.hashAll(phaseAnimations[phase]!),
          ],
        ]),
        Object.hashAll(initialValues),
      );

  @override
  String toString() =>
      '${objectRuntimeType(this, 'TrackPhaseTimeline')}($phaseAnimations, '
      'loop: $loop, initialValues: $initialValues)';
}

/// The [StepSync.token] of the barrier before [phase].
///
/// It is private to this library, so no token a caller passes to
/// `TrackStep.sync` can equal it, whatever the phase value is.
@immutable
class _PhaseToken<P extends Object> {
  const _PhaseToken(
    this.phase, {
    this.forward = true,
    this.isSeamlessWrap = false,
  });

  final P phase;
  final bool forward;
  final bool isSeamlessWrap;

  @override
  bool operator ==(Object other) =>
      other is _PhaseToken<P> &&
      other.phase == phase &&
      other.forward == forward &&
      other.isSeamlessWrap == isSeamlessWrap;

  @override
  int get hashCode => Object.hash(_PhaseToken, phase, forward, isSeamlessWrap);

  @override
  String toString() => 'PhaseToken($phase'
      '${forward ? '' : ', reverse'}'
      '${isSeamlessWrap ? ', seamlessWrap' : ''})';
}
