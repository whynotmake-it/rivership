import 'package:flutter/animation.dart';
import 'package:flutter/scheduler.dart';
import 'package:motor/src/controllers/phase_track_controller.dart';
import 'package:motor/src/loop_mode.dart';
import 'package:motor/src/motion.dart';
import 'package:motor/src/motion_converter.dart';
import 'package:motor/src/motion_velocity_tracker.dart';
import 'package:motor/src/simulations/step_playback.dart';
import 'package:motor/src/step.dart';
import 'package:motor/src/track.dart';
import 'package:motor/src/track_timeline.dart';

part '_track_slot.dart';

/// Reads the current value of a [Track].
typedef TrackValueReader = T Function<T extends Object>(Track<T> track);

/// Controls a single active [TrackTimeline] from a ticker.
class TrackController extends Animation<TrackValueReader>
    with
        AnimationLocalListenersMixin,
        AnimationLocalStatusListenersMixin,
        AnimationEagerListenerMixin {
  /// Creates a track controller.
  TrackController({
    required TickerProvider vsync,
    List<TrackValue>? from,
    this.velocityTracking = const VelocityTracking.on(),
  }) : _from = List<TrackValue>.of(from ?? const []) {
    _ticker = vsync.createTicker(_tick);
  }

  /// Controls whether [set] automatically tracks velocity from position
  /// samples. Explicit velocity on [TrackValue] always works regardless.
  final VelocityTracking velocityTracking;

  final List<TrackValue> _from;
  final Map<Track, _TrackSlot> _slots = {};
  final Map<Track, int> _lastStepByTrack = {};
  final Set<Track> _activeTracks = {};
  final Map<Object, Set<Track>> _tokenParticipants = {};
  final Map<Track, MotionVelocityTracker<Object>> _velocityTrackers = {};
  final Stopwatch _velocityTime = Stopwatch();

  Ticker? _ticker;
  Duration _lastElapsed = Duration.zero;
  void Function(Track track, int stepIndex)? _onStep;
  AnimationStatus _status = AnimationStatus.dismissed;
  AnimationStatus _lastReportedStatus = AnimationStatus.dismissed;

  /// Whether any track is currently animating.
  @override
  bool get isAnimating => _ticker?.isActive ?? false;

  /// Returns a reader for the current track values.
  @override
  TrackValueReader get value => _read;

  @override
  AnimationStatus get status => _status;

  T _read<T extends Object>(Track<T> track) => _slot(track).value as T;

  /// Returns the current velocity for [track].
  T velocity<T extends Object>(Track<T> track) => _slot(track).velocity as T;

  /// Sets one or more track values without starting an animation.
  ///
  /// For each [TrackValue] in [values]:
  /// - If a matching entry is present in [withVelocity], that velocity is set
  ///   directly (the entry's [TrackValue.value] is the velocity).
  /// - Otherwise, the position is recorded in a [MotionVelocityTracker] to
  ///   estimate velocity from the history of samples (unless
  ///   [velocityTracking] is off).
  ///
  /// Subsequent [play] or [animate] calls inherit the velocity.
  void set(
    List<TrackValue> values, {
    List<TrackValue> withVelocity = const [],
  }) {
    for (final trackValue in values) {
      _setTrackValue(trackValue, withVelocity);
    }
    notifyListeners();
  }

  void _setTrackValue<T extends Object>(
    TrackValue<T> trackValue,
    List<TrackValue> withVelocity,
  ) {
    final slot = _slot(trackValue.track);
    final explicitVelocity = _velocityFor(trackValue.track, withVelocity);
    if (explicitVelocity != null) {
      slot.setValueWithVelocity(trackValue.value, explicitVelocity.value);
    } else {
      slot.setValue(trackValue.value);
      _trackVelocitySample(trackValue.track, trackValue.value);
    }
  }

  void _trackVelocitySample<T extends Object>(Track<T> track, T value) {
    final tracker = _trackerFor(track);
    if (tracker == null) return;
    tracker.addPosition(_velocityTime.elapsed, value);
    final estimate =
        (tracker as MotionVelocityTracker<T>).getVelocityEstimate();
    if (estimate != null) {
      _slots[track]!._velocityValues =
          track.converter.normalize(estimate.perSecond);
    }
  }

  MotionVelocityTracker<Object>? _trackerFor(Track track) {
    final existing = _velocityTrackers[track];
    if (existing != null) return existing;
    final tracker = velocityTracking(track.converter);
    if (tracker == null) return null;
    _velocityTime.start();
    _velocityTrackers[track] = tracker;
    return tracker;
  }

  /// Plays [timeline].
  void play(
    TrackTimeline timeline, {
    void Function(Track track, int stepIndex)? onStep,
  }) {
    _startAnimations(
      animations: timeline.animations,
      loop: timeline.loop,
      from: timeline.from,
      withVelocity: timeline.withVelocity,
      onStep: onStep,
    );
  }

  /// Animates a list of track [animations].
  ///
  /// This works like [set] but animates to the target values instead of
  /// jumping. Only the tracks named in [animations] are (re)started; any other
  /// tracks already animating keep running untouched. Use [stop] to halt
  /// specific tracks. Passing an empty list is a no-op.
  ///
  /// [from] starts a track from a different value (jumping to it first).
  /// [withVelocity] provides per-track initial velocities (each entry's
  /// [TrackValue.value] is the velocity) without moving the value.
  void animate(
    List<TrackAnimation> animations, {
    List<TrackValue> from = const [],
    List<TrackValue> withVelocity = const [],
    void Function(Track track, int stepIndex)? onStep,
  }) {
    _startAnimations(
      animations: animations,
      loop: LoopMode.none,
      from: from,
      withVelocity: withVelocity,
      onStep: onStep,
    );
  }

  void _startAnimations({
    required List<TrackAnimation> animations,
    required LoopMode loop,
    required List<TrackValue> from,
    List<TrackValue> withVelocity = const [],
    void Function(Track track, int stepIndex)? onStep,
  }) {
    assert(
      () {
        final seen = <Track>{};
        for (final animation in animations) {
          if (!seen.add(animation.track)) return false;
        }
        return true;
      }(),
      'animate/play received multiple animations for the same track. '
      'To sequence steps on one track, use a single entry: '
      'track([.to(a), .to(b)]).',
    );
    final timelineTracks =
        animations.map((animation) => animation.track).toSet();

    // Naming no tracks is a no-op: tracks not named in this call are left
    // running untouched.
    if (timelineTracks.isEmpty) return;

    _onStep = onStep;

    // Only the named tracks restart; clearing their last-step bookkeeping lets
    // their fresh steps report from the start. Tracks that keep running from a
    // previous call retain their bookkeeping so they don't re-fire onStep.
    for (final track in timelineTracks) {
      _lastStepByTrack.remove(track);
    }

    // Previously-running tracks stay active; the named tracks (re)start.
    _activeTracks.addAll(timelineTracks);

    _mergeTokenParticipants(animations, timelineTracks);

    final startOffset = isAnimating ? _lastElapsed : Duration.zero;
    for (final animation in animations) {
      _playAnimation(
        animation,
        loop: loop,
        from: from,
        withVelocity: withVelocity,
        startOffset: startOffset,
      );
    }

    _status = AnimationStatus.forward;
    _startTicker();
    notifyListeners();
    _checkStatusChanged();
  }

  /// Evaluates active tracks at [t] without starting the ticker.
  void scrubTo(Duration t) {
    for (final track in _activeTracks) {
      _slots[track]?.scrubTo(t);
    }
    notifyListeners();
  }

  /// Resumes the ticker if any slots are active.
  void resume() {
    if (_activeTracks.any((track) => _slots[track]?.isAnimating ?? false)) {
      _status = AnimationStatus.forward;
      _startTicker();
      _checkStatusChanged();
    }
  }

  /// Stops the given [tracks], or all tracks when [tracks] is null.
  void stop({
    List<Track>? tracks,
    bool canceled = false,
  }) {
    if (tracks == null) {
      for (final slot in _slots.values) {
        slot.stop(canceled: canceled);
      }
      _activeTracks.clear();
    } else {
      for (final track in tracks) {
        _slots[track]?.stop(canceled: canceled);
        _activeTracks.remove(track);
      }
    }
    if (_activeTracks.isEmpty) {
      _ticker?.stop(canceled: canceled);
      _status = AnimationStatus.completed;
    }
    notifyListeners();
    _checkStatusChanged();
  }

  /// Recreates the ticker using [vsync].
  void resync(TickerProvider vsync) {
    final oldTicker = _ticker!;
    _ticker = vsync.createTicker(_tick);
    _ticker!.absorbTicker(oldTicker);
  }

  @override
  void dispose() {
    _ticker?.stop();
    _ticker?.dispose();
    _ticker = null;
    super.dispose();
  }

  void _playAnimation<T extends Object>(
    TrackAnimation<T> animation, {
    required LoopMode loop,
    required List<TrackValue> from,
    required List<TrackValue> withVelocity,
    required Duration startOffset,
  }) {
    final slot = _slot(animation.track);
    final fromValue = _explicitFromFor(animation.track, from);
    if (fromValue != null) {
      slot.setValue(fromValue.value);
    }
    final velocityValue = _velocityFor(animation.track, withVelocity);
    slot.play(
      animation.steps,
      loop: loop,
      startOffset: startOffset,
      velocity: velocityValue?.value,
    );
  }

  _TrackSlot _slot<T extends Object>(Track<T> track) {
    final existing = _slots[track];
    if (existing != null) return existing;

    final initialValue = _resolveInitialValue(track);
    final slot = _TrackSlot(
      converter: track.converter,
      initialValue: initialValue,
      fallbackMotion: track.motion,
    );
    _slots[track] = slot;
    return slot;
  }

  /// Resolves the initial value for a track that has never been seen before.
  ///
  /// Checks the constructor-level [_from] overrides first, then falls back to
  /// [Track.initial].
  T _resolveInitialValue<T extends Object>(Track<T> track) {
    for (final override in _from.reversed) {
      if (override case TrackValue<T>(track: final overrideTrack)
          when identical(overrideTrack, track)) {
        return override.value;
      }
    }
    return track.initial;
  }

  /// Finds an explicit `from` override for [track] in the given list.
  ///
  /// Unlike [_resolveInitialValue], this does NOT fall back to the
  /// constructor-level [_from] — it only matches explicit overrides passed
  /// to [play] or [animate].
  TrackValue<T>? _explicitFromFor<T extends Object>(
    Track<T> track,
    List<TrackValue> from,
  ) {
    for (final override in from.reversed) {
      if (override case TrackValue<T>(track: final overrideTrack)
          when identical(overrideTrack, track)) {
        return override;
      }
    }
    return null;
  }

  /// Finds an explicit velocity override for [track] in [withVelocity].
  ///
  /// The matched entry's [TrackValue.value] is the initial velocity.
  TrackValue<T>? _velocityFor<T extends Object>(
    Track<T> track,
    List<TrackValue> withVelocity,
  ) {
    for (final override in withVelocity.reversed) {
      if (override case TrackValue<T>(track: final overrideTrack)
          when identical(overrideTrack, track)) {
        return override;
      }
    }
    return null;
  }

  /// Merges sync-barrier participants for [animations] into
  /// [_tokenParticipants].
  ///
  /// The named [timelineTracks] are first removed from every existing token
  /// set (their old steps are being replaced), then the participants from the
  /// new animations are added. This keeps sync barriers established by earlier
  /// calls intact for tracks that keep running, while replacing the named
  /// tracks' barriers. Tokens left without participants are dropped.
  void _mergeTokenParticipants(
    List<TrackAnimation> animations,
    Set<Track> timelineTracks,
  ) {
    for (final participants in _tokenParticipants.values) {
      participants.removeAll(timelineTracks);
    }
    for (final animation in animations) {
      for (final step in animation.steps) {
        if (step is SyncStep) {
          (_tokenParticipants[step.token] ??= {}).add(animation.track);
        }
      }
    }
    _tokenParticipants.removeWhere((_, participants) => participants.isEmpty);
  }

  void _startTicker() {
    if (_ticker?.isActive ?? false) return;
    // A restarted Ticker reports elapsed from zero again (stop() nulls its
    // start time). Reset our mirror so animations started later in the same
    // frame use a correct zero start offset instead of a stale elapsed value.
    _lastElapsed = Duration.zero;
    _ticker!.start();
  }

  /// Called when a group of tracks is released past a sync barrier.
  ///
  /// Subclasses (e.g. [PhaseTrackController]) override this to detect phase
  /// transitions. The [token] is the [SyncStep.token] that was released.
  void onSyncReleased(Object token) {}

  void _tick(Duration elapsed) {
    _lastElapsed = elapsed;
    var allDone = true;
    final syncTokens = <Object>{};

    for (final track in _activeTracks.toList()) {
      final slot = _slots[track];
      if (slot == null) continue;
      if (!slot.tick(elapsed)) {
        allDone = false;
      }
      if (slot.isWaitingForSync) {
        final token = slot.syncToken;
        if (token != null) syncTokens.add(token);
      }
      _notifyStep(track, slot);
    }

    for (final token in syncTokens) {
      final participants = _tokenParticipants[token];
      if (participants == null) continue;

      // Release when every track that participates in this token is either
      // waiting at the barrier for this token, or no longer animating.
      final allReady = participants.every((track) {
        final slot = _slots[track];
        if (slot == null) return true;
        if (!slot.isAnimating) return true;
        return slot.isWaitingForSync && slot.syncToken == token;
      });
      if (allReady) {
        for (final track in participants) {
          final slot = _slots[track];
          if (slot != null &&
              slot.isWaitingForSync &&
              slot.syncToken == token) {
            slot.releaseSync();
          }
        }
        onSyncReleased(token);
      }
    }

    if (allDone) {
      _ticker?.stop();
      _activeTracks.clear();
      _status = AnimationStatus.completed;
      _checkStatusChanged();
    }

    notifyListeners();
  }

  void _checkStatusChanged() {
    if (_status == _lastReportedStatus) return;
    _lastReportedStatus = _status;
    notifyStatusListeners(_status);
  }

  void _notifyStep(
    Track track,
    _TrackSlot slot,
  ) {
    final onStep = _onStep;
    if (onStep == null) return;

    final stepIndex = slot.currentStepIndex;
    if (stepIndex < 0 || _lastStepByTrack[track] == stepIndex) return;

    _lastStepByTrack[track] = stepIndex;
    onStep(track, stepIndex);
  }
}
