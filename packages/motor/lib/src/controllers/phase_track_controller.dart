import 'package:flutter/animation.dart';
import 'package:motor/src/controllers/track_controller.dart';
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
  void Function(P phase)? _onPhaseChanged;
  P? _currentPhase;
  bool _isPlayingPhases = false;

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
    void Function(P phase)? onPhaseChanged,
  }) {
    _activeTimeline = timeline;
    _onPhaseChanged = onPhaseChanged;
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
    void Function(P phase)? onPhaseChanged,
  }) {
    _activeTimeline = timeline;
    _onPhaseChanged = onPhaseChanged;
    _isPlayingPhases = true;

    final startIndex = atPhase != null ? timeline.phases.indexOf(atPhase) : 0;
    final effectiveIndex = startIndex < 0 ? 0 : startIndex;

    _currentPhase = timeline.phases[effectiveIndex];

    play(timeline);
    final phase = _currentPhase;
    if (phase != null) _onPhaseChanged?.call(phase);
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
    _currentPhase = phase;

    final anims = timeline.phaseAnimations[phase]!;
    animate(anims, from: timeline.from);
    _onPhaseChanged?.call(phase);
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
      _currentPhase = token;
      _onPhaseChanged?.call(token);
    }
  }

  void _onStatusChanged(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    if (!_isPlayingPhases) return;

    final timeline = _activeTimeline;
    if (timeline == null) return;
    if (!timeline.phaseLoop.isLooping) return;

    // Restart from the first phase
    _currentPhase = timeline.phases.first;
    play(timeline);
    _onPhaseChanged?.call(_currentPhase!);
  }

  @override
  void dispose() {
    removeStatusListener(_onStatusChanged);
    super.dispose();
  }
}
