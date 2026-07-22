import 'package:clock/clock.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/scheduler.dart';
import 'package:meta/meta.dart';
import 'package:motor/src/controllers/phase_track_controller.dart';
import 'package:motor/src/inspection/playback_snapshot.dart';
import 'package:motor/src/loop_mode.dart';
import 'package:motor/src/motion.dart';
import 'package:motor/src/motion_converter.dart';
import 'package:motor/src/motion_velocity_tracker.dart';
import 'package:motor/src/simulations/step_playback.dart';
import 'package:motor/src/track.dart';
import 'package:motor/src/track_step.dart';
import 'package:motor/src/track_timeline.dart';

part '_track_slot.dart';

/// Reads the current value of a [Track].
typedef TrackValueReader = T Function<T extends Object>(Track<T> track);

/// Controls a single active [TrackTimeline] from a ticker.
///
/// This is an `Animation<TrackValueReader>`, so [value] is a reader function:
/// call it with a [Track] to get that track's current value. This shape remains
/// usable with `ValueListenable` and `ListenableBuilder` infrastructure, but
/// does not compose with [Tween.animate] or [Animation.drive] like an
/// `Animation<double>` does. Read specific tracks with `value(track)` inside a
/// listener instead.
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
  var _playbackRevision = 0;

  /// The number of tracks this controller currently holds state for.
  @visibleForTesting
  int get debugTrackCount => _slots.length;

  /// A monotonic timestamp for velocity sampling, sourced from [clock] so it is
  /// driven by the fake clock under test (advancing with `tester.pump`) and by
  /// wall-clock time in production.
  Duration get _velocityNow =>
      Duration(microseconds: clock.now().microsecondsSinceEpoch);

  Ticker? _ticker;
  TickerFuture? _tickerFuture;
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

  /// Returns the tracked velocity estimate for [track], or null if velocity
  /// tracking is disabled or no samples have been recorded.
  ///
  /// The internal trackers are stored type-erased (`<Object>`), so the estimate
  /// is reconstructed with [track]'s value type rather than cast directly.
  MotionVelocityEstimate<T>? trackedVelocityEstimate<T extends Object>(
    Track<T> track,
  ) {
    final estimate = _velocityTrackers[track]?.getVelocityEstimate();
    if (estimate == null) return null;
    return MotionVelocityEstimate<T>(
      perSecond: estimate.perSecond as T,
      confidence: estimate.confidence,
      duration: estimate.duration,
      offset: estimate.offset as T,
    );
  }

  /// Clears velocity-tracking samples so future [set] calls start fresh.
  void resetVelocityTracking() {
    _velocityTrackers.clear();
  }

  /// The elapsed duration of the current run, or null when not animating.
  Duration? get lastElapsedDuration => isAnimating ? _lastElapsed : null;

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
    _playbackRevision++;
    for (final trackValue in values) {
      _setTrackValue(trackValue, withVelocity);
    }
    notifyListeners();
  }

  void _setTrackValue<T extends Object>(
    TrackValue<T> trackValue,
    List<TrackValue> withVelocity,
  ) {
    final slot = _slot(trackValue.track, initialOverride: trackValue.value);
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
    tracker.addPosition(_velocityNow, value);
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
    _velocityTrackers[track] = tracker;
    return tracker;
  }

  /// Plays [timeline].
  ///
  /// Returns a [TickerFuture] that reflects the **whole controller** settling:
  /// it completes when every active track has finished and the ticker stops on
  /// its own. This matches [AnimationController]; if other tracks are already
  /// running when this is called, the future waits for all of them too.
  ///
  /// Calling [stop] with `canceled: true` cancels the future. Looping playback
  /// ([LoopMode.loop]/[LoopMode.pingPong]/[LoopMode.seamless]) never stops the
  /// ticker, so the returned future never completes — do not `await` it.
  TickerFuture play(
    TrackTimeline timeline, {
    void Function(Track track, int stepIndex)? onStep,
  }) {
    return _startAnimations(
      animations: timeline.animations,
      loop: timeline.loop,
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
  /// Per-track start values and velocities are carried on each
  /// [TrackAnimation] (`from:` / `withVelocity:`). [loop] applies to every
  /// animation in this call.
  ///
  /// Returns a [TickerFuture] with **whole-controller** semantics: it completes
  /// when every active track settles and the ticker stops, not just the tracks
  /// named in [animations]. So animating one track while others run completes
  /// only once everything has settled. Passing an empty list returns an
  /// already-complete future. Calling [stop] with `canceled: true` cancels it.
  TickerFuture animate(
    List<TrackAnimation> animations, {
    LoopMode loop = LoopMode.none,
    void Function(Track track, int stepIndex)? onStep,
  }) {
    return _startAnimations(
      animations: animations,
      loop: loop,
      onStep: onStep,
    );
  }

  TickerFuture _startAnimations({
    required List<TrackAnimation> animations,
    required LoopMode loop,
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
    if (timelineTracks.isEmpty) return TickerFuture.complete();

    _playbackRevision++;

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
        startOffset: startOffset,
      );
    }

    _status = AnimationStatus.forward;
    final future = _startTicker();
    _checkStatusChanged();
    return future;
  }

  /// Evaluates active tracks at [t] without starting the ticker.
  ///
  /// Seeking treats sync barriers as zero-duration holds and passes through
  /// them freely (see [StepSync]); tracks scrubbed past a barrier will not wait
  /// for their peers.
  void scrubTo(Duration t) {
    _playbackRevision++;
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
  ///
  /// Unless [canceled] is true, each targeted track that is animating with a
  /// settle-capable default motion (one whose [Motion.needsSettle] is true)
  /// gracefully settles at its current value instead of freezing instantly —
  /// for example a spring keeps its momentum and eases to rest. Tracks whose
  /// default motion does not need settling (or that have no default motion)
  /// stop immediately. When [canceled] is true every targeted track stops
  /// immediately.
  ///
  /// Returns a [TickerFuture] that completes when the settling tracks come to
  /// rest, or an already-complete future when nothing keeps animating (see
  /// [play] for the whole-controller completion semantics).
  TickerFuture stop({
    List<Track>? tracks,
    bool canceled = false,
  }) {
    return canceled ? _hardStop(tracks) : _gracefulStop(tracks);
  }

  TickerFuture _hardStop(List<Track>? tracks) {
    _playbackRevision++;
    if (tracks == null) {
      for (final slot in _slots.values) {
        slot.stop(canceled: true);
      }
      _activeTracks.clear();
      _tokenParticipants.clear();
    } else {
      for (final track in tracks) {
        _slots[track]?.stop(canceled: true);
        _activeTracks.remove(track);
      }
      _pruneTokenParticipants(tracks);
    }
    _releaseWaitingSyncBarriers();
    if (_activeTracks.isEmpty) {
      _ticker?.stop(canceled: true);
    }
    notifyListeners();
    return TickerFuture.complete();
  }

  TickerFuture _gracefulStop(List<Track>? tracks) {
    _playbackRevision++;
    final targets = tracks ?? _slots.keys.toList();
    for (final track in targets) {
      final slot = _slots[track];
      if (slot == null) continue;
      if (slot.settle(startOffset: _lastElapsed)) {
        // Keep the track active so the ticker drives it to rest. Reset its
        // step bookkeeping so the settle segment doesn't re-fire onStep.
        _activeTracks.add(track);
        _lastStepByTrack.remove(track);
      } else {
        slot.stop(canceled: true);
        _activeTracks.remove(track);
      }
    }

    _pruneTokenParticipants(targets);
    _releaseWaitingSyncBarriers();
    if (_activeTracks.isEmpty) {
      _ticker?.stop();
      _status = AnimationStatus.completed;
      notifyListeners();
      _checkStatusChanged();
      return TickerFuture.complete();
    }

    // Settling tracks keep running; the (already active) ticker finishes them
    // via the normal _tick completion path.
    final future = _startTicker();
    notifyListeners();
    _checkStatusChanged();
    return future;
  }

  /// Removes all internal state for [track].
  ///
  /// Used when a track identity is being replaced (e.g. a converter swap
  /// creates a new track). Stops the track's slot first if it is animating.
  @internal
  void forgetTrack(Track track) {
    _playbackRevision++;
    _slots[track]?.stop(canceled: true);
    _slots.remove(track);
    _activeTracks.remove(track);
    _velocityTrackers.remove(track);
    _lastStepByTrack.remove(track);
    _pruneTokenParticipants([track]);
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

  /// Builds a read-only snapshot for `package:motor/inspection.dart`.
  @internal
  PlaybackSnapshot internalInspectPlayback() {
    final tracks = <TrackPlayback>[];
    for (final entry in _slots.entries) {
      final playback = entry.value._stepPlayback;
      if (playback == null) continue;
      tracks.add(
        TrackPlayback(
          track: entry.key,
          steps: [
            for (final step in playback.stepsView) step,
          ],
          hasSyntheticReturnStep: playback.hasSyntheticReturnStep,
          loop: playback.loop,
          currentStepIndex: playback.currentStepIndex,
          direction: playback.direction,
          cycle: playback.cycle,
          isWaitingForSync: playback.isWaitingForSync,
          syncToken: playback.syncToken,
          startOffset: entry.value._startOffset,
          playhead: _durationFromSeconds(playback.lastElapsedSeconds)!,
          cycleStart: _durationFromSeconds(playback.cycleStartSeconds)!,
          stepStarts: [
            for (final seconds in playback.stepStartSeconds)
              _durationFromSeconds(seconds),
          ],
          stepDurations: [
            for (final seconds in playback.forwardSegmentSeconds)
              _durationFromSeconds(seconds),
          ],
        ),
      );
    }
    return PlaybackSnapshot(
      revision: _playbackRevision,
      tickerElapsed: lastElapsedDuration,
      status: status,
      tracks: tracks,
    );
  }

  /// Exposes the plan-revision counter to the inspection extension.
  @internal
  int get internalPlaybackRevision => _playbackRevision;

  static Duration? _durationFromSeconds(double? seconds) => seconds == null
      ? null
      : Duration(
          microseconds: (seconds * Duration.microsecondsPerSecond).round(),
        );

  void _playAnimation<T extends Object>(
    TrackAnimation<T> animation, {
    required LoopMode loop,
    required Duration startOffset,
  }) {
    final slot = _slot(animation.track, forAnimation: animation);
    if (animation.from case final from?) {
      slot.setValue(from);
    }
    slot.play(
      animation.steps,
      loop: loop,
      startOffset: startOffset,
      velocity: animation.withVelocity,
    );
  }

  _TrackSlot _slot<T extends Object>(
    Track<T> track, {
    TrackAnimation<T>? forAnimation,
    T? initialOverride,
  }) {
    final existing = _slots[track];
    if (existing != null) return existing;

    final initialValue = _resolveInitialValue(
      track,
      forAnimation,
      initialOverride,
    );
    final slot = _TrackSlot(
      converter: track.converter,
      initialValue: initialValue,
      fallbackMotion: track.motion,
      fallbackMotionPerDimension: track.motionPerDimension,
    );
    _slots[track] = slot;
    return slot;
  }

  /// Resolves the initial value for a track that has never been seen before.
  ///
  /// Resolution order: an explicit [initialOverride] (used by [set]), then the
  /// constructor-level [_from] seeds, then the animation's own start value
  /// (`from` -> [Track.initial] -> zero-filled fallback), then [Track.initial].
  /// Asserts when none of these can supply a value.
  T _resolveInitialValue<T extends Object>(
    Track<T> track,
    TrackAnimation<T>? animation,
    T? initialOverride,
  ) {
    if (initialOverride != null) return initialOverride;
    for (final override in _from.reversed) {
      if (override case TrackValue<T>(track: final overrideTrack)
          when identical(overrideTrack, track)) {
        return override.value;
      }
    }
    if (animation != null) return animation.resolveStartValue();
    if (track.initial case final value?) return value;
    assert(
      false,
      'Tried to read a track value before it had any value. The track has no '
      'initial value and was never set or animated. Provide Track.initial, '
      'call set(), or animate it first.',
    );
    throw StateError(
      'Track has no value: provide Track.initial or set/animate it first.',
    );
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
    _pruneTokenParticipants(timelineTracks);
    for (final animation in animations) {
      for (final step in animation.steps) {
        if (step is StepSync) {
          (_tokenParticipants[step.token] ??= {}).add(animation.track);
        }
      }
    }
  }

  /// Removes [tracks] from every sync-token participant set, dropping tokens
  /// left without participants. Stopped/redirected tracks will never reach
  /// their old barriers, so they must not hold (or trivially satisfy) them.
  void _pruneTokenParticipants(Iterable<Track> tracks) {
    for (final participants in _tokenParticipants.values) {
      participants.removeAll(tracks);
    }
    _tokenParticipants.removeWhere((_, participants) => participants.isEmpty);
  }

  /// Releases barriers whose remaining participants are already waiting.
  ///
  /// Stop paths call this synchronously because the stopped track may have
  /// been the only participant keeping the ticker active.
  void _releaseWaitingSyncBarriers() {
    for (final entry in _tokenParticipants.entries.toList()) {
      final token = entry.key;
      final participants = entry.value;
      final allWaiting = participants.every((track) {
        final slot = _slots[track];
        return slot != null && slot.isWaitingForSync && slot.syncToken == token;
      });
      if (!allWaiting) continue;

      for (final track in participants) {
        _slots[track]?.releaseSync();
      }
      onSyncReleased(token);
    }
  }

  TickerFuture _startTicker() {
    final ticker = _ticker!;
    if (ticker.isActive) {
      // Already running: reuse the in-flight future so the whole controller
      // shares a single completion signal (whole-controller semantics).
      return _tickerFuture ??= TickerFuture.complete();
    }
    // A restarted Ticker reports elapsed from zero again (stop() nulls its
    // start time). Reset our mirror so animations started later in the same
    // frame use a correct zero start offset instead of a stale elapsed value.
    _lastElapsed = Duration.zero;
    return _tickerFuture = ticker.start();
  }

  /// Called when a group of tracks is released past a sync barrier.
  ///
  /// Subclasses (e.g. [PhaseTrackController]) override this to detect phase
  /// transitions. The [token] is the [StepSync.token] that was released.
  @protected
  @visibleForOverriding
  void onSyncReleased(Object token) {}

  /// Called after every active track finishes a non-looping playback run.
  ///
  /// Return true when a subclass synchronously starts a continuation and wants
  /// the run boundary hidden from status listeners. The controller then keeps
  /// its current status instead of reporting [AnimationStatus.completed].
  @protected
  @visibleForOverriding
  bool onPlaybackCompleted() => false;

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
      if (!onPlaybackCompleted()) {
        _status = AnimationStatus.completed;
        _checkStatusChanged();
      }
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
