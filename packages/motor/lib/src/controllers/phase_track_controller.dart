import 'package:meta/meta.dart';
import 'package:motor/src/controllers/track_controller.dart';
import 'package:motor/src/phase_transition.dart';
import 'package:motor/src/track.dart';
import 'package:motor/src/track_phase_timeline.dart';

/// A [TrackController] extension that understands phases.
///
/// Wraps the standard sync-barrier playback with phase-level navigation:
///
/// - [playPhases] plays all phases in order (auto-advancing via sync
///   barriers and `TrackStep.loop` for looping timelines).
/// - [goToPhase] jumps to a specific phase by replaying only that phase's
///   animations.
/// - [currentPhase] reports the phase currently being played or settled.
///
/// Phase changes are reported through a [PhaseTransition] callback:
/// [PhaseTransitioning] when a new phase begins animating, and [PhaseSettled]
/// when playback for the active phase comes to rest.
///
/// With `LoopMode.pingPong`, phases are visited in reverse order after the
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

  /// Plays through all phases of [timeline], auto-advancing as each phase's
  /// steps complete.
  ///
  /// If [atPhase] is provided, playback starts from that phase (skipping
  /// earlier phases). Otherwise, playback starts from the first phase.
  ///
  /// Every call applies the timeline's `initialValues` first, also when
  /// [timeline] equals the one playing, so each throw keeps its velocity.
  ///
  /// Returns a [MotionFuture] for the timeline's tracks (see
  /// [TrackController.animate]): for a non-looping timeline it ends when the
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
    if (timeline.phases.isEmpty) return MotionFuture.complete();

    final startIndex = atPhase != null ? timeline.phases.indexOf(atPhase) : 0;
    final effectiveIndex = startIndex < 0 ? 0 : startIndex;

    final startPhase = timeline.phases[effectiveIndex];
    _currentPhase = startPhase;

    final future = animate(timeline.compile(fromPhase: startPhase));
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
          for (final animation in timeline.flattened)
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
            : of.compile(fromPhase: phase, forward: _phaseDirectionForward);
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

    final info = timeline.phaseInfoForToken(token);
    if (info != null) {
      final previous = _currentPhase;
      _currentPhase = info.phase;
      _phaseDirectionForward = info.forward;
      if (previous != null && previous != info.phase) {
        _onTransition?.call(PhaseTransitioning(from: previous, to: info.phase));
      }
    }
  }

  @override
  void onPlaybackSettled() {
    final phase = _currentPhase;
    if (phase != null) {
      _onTransition?.call(PhaseSettled(phase));
    }
  }
}
