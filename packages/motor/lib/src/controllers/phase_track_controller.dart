import 'package:flutter/animation.dart';
import 'package:motor/src/controllers/track_controller.dart';
import 'package:motor/src/phase_transition.dart';
import 'package:motor/src/track.dart';
import 'package:motor/src/track_phase_timeline.dart';
import 'package:motor/src/track_timeline.dart';

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
/// Because [TrackPhaseTimeline] extends [TrackTimeline], the standard [play]
/// method also works for non-phase playback.
class PhaseTrackController<P extends Object> extends TrackController {
  /// Creates a phase track controller.
  PhaseTrackController({
    required super.vsync,
    super.from,
    super.velocityTracking,
  }) {
    addStatusListener(_onStatusChanged);
  }

  TrackPhaseTimeline<P>? _activeTimeline;
  void Function(PhaseTransition<P> transition)? _onTransition;
  P? _currentPhase;
  bool _isPlayingPhases = false;
  bool _seededFrom = false;

  /// The active phase timeline, if any.
  TrackPhaseTimeline<P>? get activeTimeline => _activeTimeline;

  /// The current phase during playback.
  P? get currentPhase => _currentPhase;

  /// Sets the timeline without starting playback.
  ///
  /// Use [goToPhase] after this to jump to a specific phase, or
  /// [playPhases] to begin auto-advancing through all phases.
  void setTimeline(
    TrackPhaseTimeline<P> timeline, {
    void Function(PhaseTransition<P> transition)? onTransition,
  }) {
    _activeTimeline = timeline;
    _onTransition = onTransition;
    _isPlayingPhases = false;
  }

  /// Plays through all phases of [timeline], auto-advancing when each
  /// phase's animations settle.
  ///
  /// If [atPhase] is provided, playback starts from that phase (skipping
  /// earlier phases). Otherwise, playback starts from the first phase.
  ///
  /// Returns a [TickerFuture] with whole-controller semantics (see
  /// [TrackController.play]): for a non-looping timeline it completes when the
  /// whole phase sequence settles. Looping phase timelines restart the ticker
  /// each cycle, so the future resolves at the end of the first cycle — do not
  /// `await` a looping timeline.
  TickerFuture playPhases(
    TrackPhaseTimeline<P> timeline, {
    P? atPhase,
    void Function(PhaseTransition<P> transition)? onTransition,
  }) {
    _activeTimeline = timeline;
    _onTransition = onTransition;
    _isPlayingPhases = true;
    _seedFromIfNeeded(timeline);

    final startIndex = atPhase != null ? timeline.phases.indexOf(atPhase) : 0;
    final effectiveIndex = startIndex < 0 ? 0 : startIndex;

    final startPhase = timeline.phases[effectiveIndex];
    _currentPhase = startPhase;

    if (effectiveIndex == 0) {
      return play(timeline);
    } else {
      // Start partway through the timeline by playing only the animations
      // from [startPhase] onward. Looping (handled in [_onStatusChanged])
      // still restarts from the full timeline.
      return animate(
        timeline.animationsFrom(startPhase),
        withVelocity: timeline.withVelocity,
      );
    }
  }

  /// Jumps to [phase] in the active timeline.
  ///
  /// Plays only that phase's animations from the current track values,
  /// without playing preceding phases.
  ///
  /// Returns a [TickerFuture] with whole-controller semantics (see
  /// [TrackController.animate]). Returns an already-complete future when there
  /// is no active timeline or the phase is unknown.
  TickerFuture goToPhase(P phase) {
    final timeline = _activeTimeline;
    assert(timeline != null, 'Call setTimeline or playPhases first.');
    if (timeline == null) return TickerFuture.complete();

    final index = timeline.phases.indexOf(phase);
    assert(index >= 0, 'Phase $phase not found in timeline.');
    if (index < 0) return TickerFuture.complete();

    _isPlayingPhases = false;
    _seedFromIfNeeded(timeline);

    final previous = _currentPhase;
    _currentPhase = phase;
    if (previous != null && previous != phase) {
      _onTransition?.call(PhaseTransitioning(from: previous, to: phase));
    }

    final anims = timeline.phaseAnimations[phase]!;
    // Note: `from` is only applied once via [_seedFromIfNeeded]; re-applying it
    // on every phase change would snap tracks back to their initial values.
    return animate(anims, withVelocity: timeline.withVelocity);
  }

  /// Applies the timeline's `from` overrides exactly once, the first time a
  /// timeline begins playing.
  void _seedFromIfNeeded(TrackPhaseTimeline<P> timeline) {
    if (_seededFrom) return;
    _seededFrom = true;
    if (timeline.from.isNotEmpty) set(timeline.from);
  }

  @override
  void stop({List<Track>? tracks, bool canceled = false}) {
    if (tracks == null) _isPlayingPhases = false;
    super.stop(tracks: tracks, canceled: canceled);
  }

  @override
  void onSyncReleased(Object token) {
    final timeline = _activeTimeline;
    if (timeline == null) return;

    if (token is P && timeline.phases.contains(token)) {
      final previous = _currentPhase;
      _currentPhase = token;
      if (previous != null && previous != token) {
        _onTransition?.call(PhaseTransitioning(from: previous, to: token));
      }
    }
  }

  void _onStatusChanged(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;

    final timeline = _activeTimeline;

    if (_isPlayingPhases &&
        timeline != null &&
        timeline.phaseLoop.isLooping) {
      // Loop: wrap back to the first phase and replay.
      final previous = _currentPhase;
      final first = timeline.phases.first;
      _currentPhase = first;
      if (previous != null && previous != first) {
        _onTransition?.call(PhaseTransitioning(from: previous, to: first));
      }
      play(timeline);
      return;
    }

    final phase = _currentPhase;
    if (phase != null) {
      _onTransition?.call(PhaseSettled(phase));
    }
  }

  @override
  void dispose() {
    removeStatusListener(_onStatusChanged);
    super.dispose();
  }
}
