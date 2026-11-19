import 'package:meta/meta.dart';
import 'package:motor/src/controllers/track_controller.dart';
import 'package:motor/src/loop_mode.dart';
import 'package:motor/src/phase_transition.dart';
import 'package:motor/src/track.dart';
import 'package:motor/src/track_phase_timeline.dart';

/// A [TrackController] extension that understands phases.
///
/// Wraps the standard sync-barrier playback with phase-level navigation:
///
/// - [playPhases] plays all phases in order (auto-advancing via sync
///   barriers).
/// - [goToPhase] jumps to a specific phase by replaying only that phase's
///   animations.
/// - [currentPhase] reports the phase currently being played or settled.
///
/// Phase changes are reported through a [PhaseTransition] callback:
/// [PhaseTransitioning] when a new phase begins animating, and [PhaseSettled]
/// when playback for the active phase comes to rest.
///
/// With [LoopMode.pingPong], phases are visited in reverse order after the
/// forward pass. Each phase's own steps still play forward.
class PhaseTrackController<P extends Object> extends TrackController {
  /// Creates a phase track controller.
  PhaseTrackController({
    required super.vsync,
    super.initialValues,
    super.velocityTracking,
    super.debugLabel,
  });

  TrackPhaseTimeline<P>? _activeTimeline;
  void Function(PhaseTransition<P> transition)? _onTransition;
  P? _currentPhase;
  bool _isPlayingPhases = false;
  bool _phaseDirectionForward = true;

  /// Whether the next [goToPhase] applies the timeline's `initialValues`.
  bool _initialValuesPending = false;

  /// The active phase timeline, if any.
  TrackPhaseTimeline<P>? get activeTimeline => _activeTimeline;

  /// The current phase during playback.
  P? get currentPhase => _currentPhase;

  /// Sets the timeline without starting playback.
  ///
  /// Use [goToPhase] after this to jump to a specific phase, which applies
  /// the timeline's `initialValues` first, or [playPhases] to begin
  /// auto-advancing through all phases.
  void setTimeline(
    TrackPhaseTimeline<P> timeline, {
    void Function(PhaseTransition<P> transition)? onTransition,
  }) {
    _initialValuesPending = true;
    _activeTimeline = timeline;
    _onTransition = onTransition;
    _isPlayingPhases = false;
    _phaseDirectionForward = true;
  }

  /// Plays through all phases of [timeline], auto-advancing when each
  /// phase's animations settle.
  ///
  /// If [atPhase] is provided, playback starts from that phase (skipping
  /// earlier phases). Otherwise, playback starts from the first phase.
  ///
  /// Every call applies the timeline's `initialValues` first, also when
  /// [timeline] equals the one playing, so each throw keeps its velocity.
  ///
  /// Returns a [MotionFuture] for the timeline's tracks (see
  /// [TrackController.play]): for a non-looping timeline it ends when the
  /// last phase's motions have reached their duration, and settles when the
  /// last phase has settled. A looping phase timeline never ends or
  /// settles, so don't await it.
  MotionFuture playPhases(
    TrackPhaseTimeline<P> timeline, {
    P? atPhase,
    void Function(PhaseTransition<P> transition)? onTransition,
  }) =>
      _playPhases(
        timeline,
        atPhase: atPhase,
        onTransition: onTransition,
        applyInitialValues: true,
      );

  /// Like [playPhases], but without applying the timeline's
  /// `initialValues`, to go on auto-advancing from where the tracks are.
  @internal
  MotionFuture continuePhases(
    TrackPhaseTimeline<P> timeline, {
    P? atPhase,
    void Function(PhaseTransition<P> transition)? onTransition,
  }) =>
      _playPhases(
        timeline,
        atPhase: atPhase,
        onTransition: onTransition,
        applyInitialValues: false,
      );

  MotionFuture _playPhases(
    TrackPhaseTimeline<P> timeline, {
    required P? atPhase,
    required void Function(PhaseTransition<P> transition)? onTransition,
    required bool applyInitialValues,
  }) {
    _activeTimeline = timeline;
    _onTransition = onTransition;
    _isPlayingPhases = true;
    _phaseDirectionForward = true;
    _initialValuesPending = false;
    if (applyInitialValues) _applyInitialValues(timeline);

    final startIndex = atPhase != null ? timeline.phases.indexOf(atPhase) : 0;
    final effectiveIndex = startIndex < 0 ? 0 : startIndex;

    final startPhase = timeline.phases[effectiveIndex];
    _currentPhase = startPhase;

    // Starting partway plays only the animations from [startPhase] onward.
    // Looping (handled in [onPlaybackSettled]) still restarts from the full
    // timeline.
    final future = effectiveIndex == 0
        ? play(timeline.flattened)
        : animate(timeline.animationsFrom(startPhase));
    if (timeline.loop.isLooping) internalRepeat(future);
    _settleIfIdle();
    return future;
  }

  /// Jumps to [phase] in the active timeline.
  ///
  /// Plays only that phase's animations from the current track values,
  /// without playing preceding phases.
  ///
  /// Returns a [MotionFuture] for the phase's tracks (see
  /// [TrackController.animate]). Returns an already settled future when
  /// there is no active timeline or the phase is unknown.
  MotionFuture goToPhase(P phase) {
    final timeline = _activeTimeline;
    assert(timeline != null, 'Call setTimeline or playPhases first.');
    if (timeline == null) return MotionFuture.complete();

    final index = timeline.phases.indexOf(phase);
    assert(index >= 0, 'Phase $phase not found in timeline.');
    if (index < 0) return MotionFuture.complete();

    final wasPlayingPhases = _isPlayingPhases;
    _isPlayingPhases = false;
    if (_initialValuesPending) {
      _initialValuesPending = false;
      _applyInitialValues(timeline);
    }

    final previous = _currentPhase;
    _currentPhase = phase;
    if (previous != null && previous != phase) {
      _onTransition?.call(PhaseTransitioning(from: previous, to: phase));
    }

    final anims = timeline.phaseAnimations[phase]!;
    if (wasPlayingPhases) {
      // Tracks this phase doesn't name would otherwise keep playing the
      // whole timeline into later phases.
      final named = {for (final animation in anims) animation.track};
      stop(
        tracks: [
          for (final animation in timeline.flattened.animations)
            if (!named.contains(animation.track)) animation.track,
        ],
      );
    }
    final future = animate(anims);
    _settleIfIdle();
    return future;
  }

  /// Reports that the current phase settled when nothing plays, for example
  /// because every track already rests on its target, since no playback
  /// will settle to report it.
  void _settleIfIdle() {
    if (hasActiveTracks) return;
    if (_currentPhase case final phase?) {
      _onTransition?.call(PhaseSettled(phase));
    }
  }

  /// Swaps the active timeline for [timeline], an updated version of it, and
  /// unless [restartChanged] is false restarts only the tracks whose remaining
  /// animations changed. Other tracks keep playing, and the timeline's
  /// `initialValues` are not applied.
  ///
  /// While auto-advancing, a changed track restarts at the current phase and
  /// rejoins the others at the next phase; otherwise it plays the current
  /// phase's new animation. Returns false, changing nothing, when there is no
  /// active timeline or [timeline] lacks the current phase.
  @internal
  bool updateTimeline(
    TrackPhaseTimeline<P> timeline, {
    void Function(PhaseTransition<P> transition)? onTransition,
    bool restartChanged = true,
  }) {
    final old = _activeTimeline;
    final phase = _currentPhase;
    if (old == null || phase == null || !timeline.phases.contains(phase)) {
      return false;
    }
    _activeTimeline = timeline;
    _onTransition = onTransition;
    if (old == timeline || !restartChanged) return true;

    List<TrackAnimation> remaining(TrackPhaseTimeline<P> of) =>
        !_isPlayingPhases
            ? of.phaseAnimations[phase]!
            : _phaseDirectionForward
                ? of.animationsFrom(phase)
                : of.reversedAnimationsFrom(phase);
    final before = {
      for (final animation in remaining(old)) animation.track: animation,
    };
    final changed = [
      for (final animation in remaining(timeline))
        if (before[animation.track] != animation) animation,
    ];
    if (changed.isNotEmpty) animate(changed);
    return true;
  }

  /// Stops all tracks and moves them straight to where they rest at [phase]
  /// in [timeline], without animating, reporting the change and that [phase]
  /// settled. With [applyInitialValues], the timeline's `initialValues` apply
  /// first, for tracks [phase] gives no resting value.
  @internal
  void jumpToPhase(
    TrackPhaseTimeline<P> timeline,
    P phase, {
    void Function(PhaseTransition<P> transition)? onTransition,
    bool applyInitialValues = false,
  }) {
    final wasAnimating = isAnimating;
    stop(canceled: true);
    _activeTimeline = timeline;
    _onTransition = onTransition;
    _initialValuesPending = false;
    if (applyInitialValues) _applyInitialValues(timeline);
    final values = timeline.restingValuesAt(phase);
    if (values.isNotEmpty) internalSet(values);

    final previous = _currentPhase;
    _currentPhase = phase;
    if (previous != null && previous != phase) {
      _onTransition?.call(PhaseTransitioning(from: previous, to: phase));
    }
    if (wasAnimating || previous != phase) {
      _onTransition?.call(PhaseSettled(phase));
    }
  }

  /// Applies the timeline's `initialValues` and their velocities.
  void _applyInitialValues(TrackPhaseTimeline<P> timeline) {
    if (timeline.initialValues.isEmpty) return;
    internalSet(timeline.initialValues);
  }

  /// Like [TrackController.set]. Once no track is left playing, it also ends
  /// the automatic advance through the phases, as [stop] does.
  @override
  void set(List<TrackValue> values) {
    super.set(values);
    if (!hasActiveTracks) _isPlayingPhases = false;
  }

  @override
  MotionFuture stop({List<Track>? tracks, bool canceled = false}) {
    if (tracks == null) _isPlayingPhases = false;
    return super.stop(tracks: tracks, canceled: canceled);
  }

  @override
  void onSyncReleased(Object token) {
    final timeline = _activeTimeline;
    if (timeline == null) return;

    final phase = timeline.phaseForToken(token);
    if (phase != null) {
      final previous = _currentPhase;
      _currentPhase = phase;
      if (previous != null && previous != phase) {
        _onTransition?.call(PhaseTransitioning(from: previous, to: phase));
      }
    }
  }

  @override
  void onPlaybackSettled() {
    final timeline = _activeTimeline;

    if (_isPlayingPhases && timeline != null && timeline.loop.isLooping) {
      final previous = _currentPhase;
      final phases = timeline.phases;
      final first = phases.first;

      if (timeline.loop == LoopMode.pingPong && phases.length >= 2) {
        if (_phaseDirectionForward) {
          _phaseDirectionForward = false;
          final next = phases[phases.length - 2];
          _currentPhase = next;
          _onTransition?.call(
            PhaseTransitioning(from: phases.last, to: next),
          );
          internalContinueRepeating(
            timeline.reversedAnimationsFrom(phases[phases.length - 2]),
          );
        } else {
          _phaseDirectionForward = true;
          final next = phases[1];
          _currentPhase = next;
          _onTransition?.call(
            PhaseTransitioning(from: phases.first, to: next),
          );
          internalContinueRepeating(timeline.animationsFrom(next));
        }
        return;
      }

      if (timeline.loop == LoopMode.seamless && phases.length >= 2) {
        // seamless: jump straight back to the first phase (invisible when the
        // last phase matches the first), then animate on to the second phase
        // immediately. Replaying from the second phase avoids re-animating
        // into the first phase, which would otherwise stall for the first
        // step's full duration.

        final second = phases[1];
        final values = timeline.restingValuesAt(first);
        if (values.isNotEmpty) internalJumpRepeating(values);

        if (previous != null && previous != first) {
          _onTransition?.call(PhaseTransitioning(from: previous, to: first));
        }
        _currentPhase = second;
        _onTransition?.call(PhaseTransitioning(from: first, to: second));
        internalContinueRepeating(timeline.animationsFrom(second));
        return;
      }

      // loop (and single-phase seamless): animate from the current values back
      // to the first phase and replay the whole timeline. Unlike `play`, this
      // does not re-apply `timeline.initialValues`, so the loop animates back
      // to the first phase rather than snapping to them each cycle.
      _currentPhase = first;
      if (previous != null && previous != first) {
        _onTransition?.call(PhaseTransitioning(from: previous, to: first));
      }
      internalContinueRepeating(timeline.flattened.animations);
      return;
    }

    final phase = _currentPhase;
    if (phase != null) {
      _onTransition?.call(PhaseSettled(phase));
    }
  }
}
