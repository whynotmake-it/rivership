import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart' show VoidCallback, describeIdentity;
import 'package:flutter/scheduler.dart';
import 'package:meta/meta.dart';
import 'package:motor/src/controllers/frame_anchored_sync_token.dart';
import 'package:motor/src/controllers/phase_track_controller.dart';
import 'package:motor/src/loop_mode.dart';
import 'package:motor/src/motion.dart';
import 'package:motor/src/motion_converter.dart';
import 'package:motor/src/motion_velocity_tracker.dart';
import 'package:motor/src/playback/playback_clock.dart';
import 'package:motor/src/simulations/step_playback.dart';
import 'package:motor/src/track.dart';
import 'package:motor/src/track_step.dart';
import 'package:motor/src/track_timeline.dart';

part '_track_slot.dart';
part 'track_animation.dart';
part 'track_future.dart';

// A generic function called through a function-typed value ignores the
// bound of its type parameter when inferring from a nullable context (Dart
// 3.12, compiler only; a generic `call` method is inferred correctly):
//
//   typedef Reader = T Function<T extends Object>(Track<T> track);
//   void takesNullable({double? scale}) {}
//   final Reader value = <T extends Object>(Track<T> t) => t.initial!;
//   takesNullable(scale: value(Track<double>(...))); // error: 'double?'

/// Reads the current value of a [Track]: call it with the track.
///
/// ```dart
/// final Offset offset = value(offsetTrack);
/// Transform.scale(scale: value(scaleTrack), child: child);
/// ```
///
/// This is an extension type rather than a function type so that reading a
/// track into a nullable parameter, like `Transform.scale(scale:)`, infers
/// the track's type. With a function type, the Dart compiler infers the
/// nullable type instead and rejects the call, although the analyzer accepts
/// it.
extension type const TrackValueReader(
    T Function<T extends Object>(Track<T> track) _read) {
  /// Returns [track]'s current value.
  T call<T extends Object>(Track<T> track) => _read(track);
}

/// Controls a single active [TrackTimeline] from a ticker.
///
/// This is an `Animation<TrackValueReader>`, so [value] is a reader function:
/// call it with a [Track] to get that track's current value. It works with
/// `ListenableBuilder` and other `Listenable` infrastructure. To use a single
/// track with [Tween.animate], [Animation.drive], or transition widgets, get
/// an `Animation<T>` for it from [animationOf].
///
/// All tracks share one playback timeline that only advances while the
/// controller ticks; [pause], [resume], and [scrubTo] move along it.
class TrackController extends Animation<TrackValueReader>
    with
        AnimationLocalListenersMixin,
        AnimationLocalStatusListenersMixin,
        AnimationEagerListenerMixin {
  /// Creates a track controller.
  ///
  /// [initialValues] sets the value a track takes the first time this
  /// controller sees it, in place of [Track.initial]. They are consulted only
  /// when a track's state is first created; later [play]/[animate] calls do
  /// not re-apply them, and an animation's own `from` still jumps the track
  /// when it plays.
  ///
  /// [velocityTracking] controls whether [set] estimates velocity from
  /// successive position samples.
  TrackController({
    required TickerProvider vsync,
    List<TrackValue>? initialValues,
    VelocityTracking velocityTracking = const VelocityTracking.on(),
    this.debugLabel,
  })  : _initialValues = List<TrackValue>.of(initialValues ?? const []),
        _velocityTracking = velocityTracking {
    _ticker = vsync.createTicker(_tick);
  }

  /// Controls whether [set] automatically tracks velocity from position
  /// samples. Explicit velocity on [TrackValue] always works regardless.
  ///
  /// Changing it keeps the velocities estimated so far and starts sampling
  /// afresh.
  VelocityTracking get velocityTracking => _velocityTracking;
  VelocityTracking _velocityTracking;

  set velocityTracking(VelocityTracking value) {
    if (value == _velocityTracking) return;
    resetVelocityTracking();
    _velocityTracking = value;
  }

  /// A human-readable name shown by optional inspection tools.
  final String? debugLabel;

  final List<TrackValue> _initialValues;
  final Map<Track, _TrackSlot> _slots = {};
  final Map<Track, _TrackAnimation<Object>> _animations = {};
  final Set<Track> _activeTracks = {};

  /// The tracks moved since the controller was last idle, which make up
  /// [status].
  final Set<Track> _runTracks = {};
  var _statusDirty = false;
  var _holdStatus = false;
  final Map<Object, Set<Track>> _tokenParticipants = {};

  /// How often each track was released at each sync token.
  final Map<Object, Map<Track, int>> _syncPasses = {};

  /// When a sync token last lost a participant; it cannot release earlier,
  /// since the tracks waiting there were shown waiting until then.
  final Map<Object, Duration> _syncNotBefore = {};
  // Velocity estimates are computed only when needed, as of the latest
  // sample; each slot holds when that sample was taken.
  final Map<Track, MotionVelocityTracker<Object>> _velocityTrackers = {};
  final List<Track> _tickTracks = [];

  /// Upper bound on barrier releases handled within one frame.
  static const _maxBarrierPasses = 100;
  final _clock = PlaybackClock();

  /// The number of tracks this controller currently holds state for.
  @visibleForTesting
  int get debugTrackCount => _slots.length;

  Ticker? _ticker;

  /// The futures returned by [play], [animate] and [stop] that are still
  /// pending.
  final List<_TrackFuture> _futures = [];
  void Function(Track track, int stepIndex)? _onStep;
  AnimationStatus _status = AnimationStatus.dismissed;
  AnimationStatus _lastReportedStatus = AnimationStatus.dismissed;

  /// Whether any track is currently animating.
  @override
  bool get isAnimating => _ticker?.isActive ?? false;

  /// Returns a reader for the current track values.
  ///
  /// Reading a track this controller has never seen returns its entry in the
  /// constructor's `initialValues` or [Track.initial], and registers the
  /// track with the controller. Reading a track with neither throws.
  @override
  TrackValueReader get value => TrackValueReader(_read);

  /// The status of the tracks moved since this controller was last idle.
  ///
  /// While any of them moves, this is [AnimationStatus.reverse] if all
  /// moving tracks head down, otherwise [AnimationStatus.forward]. Once none
  /// moves, it is [AnimationStatus.dismissed] if all of them are dismissed,
  /// otherwise [AnimationStatus.completed]. See [animationOf] for the status
  /// of a single track; a track stopped with `canceled: true` counts as
  /// moving in its last direction.
  ///
  /// Pausing and scrubbing do not change it.
  @override
  AnimationStatus get status => _status;

  T _read<T extends Object>(Track<T> track) => _slot(track).value as T;

  /// An [Animation] of [track]'s value on this controller.
  ///
  /// Use it wherever Flutter expects an `Animation<T>`, for example
  /// `FadeTransition(opacity: controller.animationOf(opacity))` or
  /// `Tween(begin: 0.8, end: 1.0).animate(controller.animationOf(progress))`.
  ///
  /// The same instance is returned for the same track. It listens to this
  /// controller only while it has listeners, and notifies them only when
  /// this track's value or status changes. Its status is:
  ///
  /// - [AnimationStatus.dismissed] until the track first moves.
  /// - While it plays (including while paused), [AnimationStatus.reverse]
  ///   when heading for a smaller value, as judged by a
  ///   [DirectionalMotionConverter], otherwise [AnimationStatus.forward].
  ///   Steps without a direction (holds, barriers) keep the previous one.
  /// - Once its plan finished, it was stopped, or it jumped with [set]:
  ///   [AnimationStatus.dismissed] if its last move went down, otherwise
  ///   [AnimationStatus.completed]. For converters without a direction,
  ///   dismissed means exactly back at the track's initial value.
  /// - After [stop] with `canceled: true`, the direction it was moving in.
  ///
  /// Reading the value follows the same rules as [value].
  Animation<T> animationOf<T extends Object>(Track<T> track) =>
      (_animations[track] ??= _TrackAnimation<T>(this, track)) as Animation<T>;

  AnimationStatus _statusOf(Track track) =>
      _slots[track]?.status ?? AnimationStatus.dismissed;

  /// Returns the current velocity for [track].
  T velocity<T extends Object>(Track<T> track) {
    _applyPendingVelocity(track);
    return _slot(track).velocity as T;
  }

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
    for (final track in _velocityTrackers.keys) {
      _applyPendingVelocity(track, consume: true);
    }
    _velocityTrackers.clear();
  }

  /// The elapsed duration of the current run, or null when not animating.
  Duration? get lastElapsedDuration =>
      isAnimating ? _clock.sinceTickerStart : null;

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
    _sampledAt = null;
    if (_activeTracks.isEmpty) _runTracks.clear();
    for (final trackValue in values) {
      _runTracks.add(trackValue.track);
      _setTrackValue(trackValue, withVelocity);
    }
    notifyListeners();
    _updateStatus();
  }

  // When the values of the current [set] call were sampled; values set
  // together share one instant.
  DateTime? _sampledAt;

  void _setTrackValue<T extends Object>(
    TrackValue<T> trackValue,
    List<TrackValue> withVelocity,
  ) {
    final slot = _slot(trackValue.track, initialOverride: trackValue.value);
    final explicitVelocity = withVelocity.isEmpty
        ? null
        : _velocityFor(trackValue.track, withVelocity);
    if (explicitVelocity != null) {
      slot
        ..velocityFromTracker = false
        ..setValueWithVelocity(trackValue.value, explicitVelocity.value);
      return;
    }
    slot.setValue(trackValue.value);
    final tracker = _trackerFor(trackValue.track);
    if (tracker == null) return;
    // Sourced from [clock] so tests drive it with the fake clock.
    final sampledAt = _sampledAt ??= clock.now();
    tracker.addPositionAt(sampledAt, trackValue.value);
    slot.velocityFromTracker = true;
  }

  /// Sets [track]'s velocity to the estimate from its tracked samples, as of
  /// now, so it decays once the value holds still. Unless [consume], later
  /// reads estimate it again.
  void _applyPendingVelocity(Track track, {bool consume = false}) {
    final slot = _slots[track];
    final tracker = _velocityTrackers[track];
    if (slot == null || tracker == null || !slot.velocityFromTracker) return;
    if (consume) slot.velocityFromTracker = false;
    final estimate = tracker.getVelocityEstimate();
    if (estimate != null) slot.setVelocity(estimate.perSecond);
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
  /// {@template TrackController.future}
  /// Returns a [TickerFuture] for this call's tracks: it completes once all of
  /// them have finished, whatever other tracks are still running. Like
  /// [AnimationController], a later call that restarts one of these tracks,
  /// or a [stop] with `canceled: true` that halts one, cancels it instead:
  /// the future never completes, and its [TickerFuture.orCancel] fails with a
  /// [TickerCanceled]. A graceful [stop] lets it complete once the tracks
  /// come to rest. Looping playback ([LoopMode.loop]/[LoopMode.pingPong]/
  /// [LoopMode.seamless]) never finishes, so its future never completes — do
  /// not `await` it.
  /// {@endtemplate}
  ///
  /// {@template TrackController.onStep}
  /// [onStep] is called once for every step each track enters, in order,
  /// including steps shorter than a frame. It is not called while scrubbing,
  /// or for the internal step that returns a [LoopMode.loop] to its start.
  /// {@endtemplate}
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
  /// {@macro TrackController.future}
  ///
  /// Passing an empty list returns an already-complete future.
  ///
  /// {@macro TrackController.onStep}
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

    _cancelFutures(timelineTracks);

    _onStep = onStep;

    // Previously-running tracks stay active; the named tracks (re)start.
    _joinRun(timelineTracks);
    _activeTracks.addAll(timelineTracks);

    _mergeTokenParticipants(animations, timelineTracks);

    final startOffset = _clock.now;
    for (final animation in animations) {
      _playAnimation(animation, loop: loop, startOffset: startOffset);
    }

    final future = _futureFor(timelineTracks);
    _startTicker();
    _updateStatus();
    return future;
  }

  /// Evaluates retained track plans at [t] without starting the ticker.
  ///
  /// [t] is a position on the controller's timeline, which starts at zero and
  /// only advances while the controller is ticking. Each track is evaluated
  /// relative to the moment it was started on that timeline, so tracks started
  /// at different times stay aligned. Playback continues from [t] afterwards.
  /// Completed plans are retained, so scrubbing works after playback ends.
  ///
  /// Scrubbing resolves plans exactly like playback does, including sync
  /// barriers, so it shows what playback would show at [t]. Times already
  /// played are shown as they played. Looping plans that cannot repeat
  /// exactly, such as loops with sync steps (every looping phase timeline),
  /// keep only their two most recent cycles; earlier times show the start of
  /// the earliest cycle kept.
  ///
  /// Call [pause] before repeated interactive scrubs, then [resume] to
  /// continue from the selected position without rewinding.
  void scrubTo(Duration t) {
    _clock.seek(t);
    for (final entry in _slots.entries) {
      if (!entry.value.hasPlayback) continue;
      _activeTracks.add(entry.key);
      entry.value.reactivate();
    }
    _advanceTracks(t, scrubbing: true);
    _completeFinishedFutures();
    notifyListeners();
  }

  /// Pauses playback without clearing track plans or changing status.
  ///
  /// While paused, [isAnimating] is false because the ticker is stopped. No
  /// status event is dispatched: pausing is an inspection and authoring action,
  /// not a completed or canceled animation outcome. Use [scrubTo] to inspect a
  /// position and [resume] to continue from it. Starting any playback with
  /// [play] or [animate] also resumes the paused tracks from where they
  /// stopped.
  void pause() {
    final ticker = _ticker;
    if (ticker == null || !ticker.isActive) return;
    ticker.stop();
    notifyListeners();
  }

  /// Resumes paused playback from each track's current local playhead.
  ///
  /// Calling this while the ticker is already active, or when no track has
  /// anything left to play, is a no-op. Scrubbing a completed plan back with
  /// [scrubTo] makes it resumable again.
  void resume() {
    if (isAnimating) return;
    if (!_activeTracks.any((track) => _slots[track]?.isAnimating ?? false)) {
      return;
    }
    _startTicker();
    _updateStatus();
    notifyListeners();
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
  /// rest, or an already-complete future when none settles. Futures of
  /// earlier calls for the stopped tracks are canceled when [canceled] is
  /// true, and otherwise complete once those tracks come to rest.
  TickerFuture stop({
    List<Track>? tracks,
    bool canceled = false,
  }) {
    return canceled ? _hardStop(tracks) : _gracefulStop(tracks);
  }

  TickerFuture _hardStop(List<Track>? tracks) {
    _cancelFutures(tracks);
    if (tracks == null) {
      for (final slot in _slots.values) {
        slot.stop(canceled: true);
      }
      _activeTracks.clear();
      _tokenParticipants.clear();
      _syncPasses.clear();
      _syncNotBefore.clear();
      for (final slot in _slots.values) {
        slot.velocityFromTracker = false;
      }
    } else {
      for (final track in tracks) {
        final slot = _slots[track];
        slot?.stop(canceled: true);
        _activeTracks.remove(track);
        slot?.velocityFromTracker = false;
      }
      _pruneTokenParticipants(tracks);
    }
    _releaseArrivedBarriers(_clock.now);
    if (_activeTracks.isEmpty) {
      _ticker?.stop(canceled: true);
    }
    notifyListeners();
    _updateStatus();
    return TickerFuture.complete();
  }

  TickerFuture _gracefulStop(List<Track>? tracks) {
    final targets = tracks ?? _slots.keys.toList();
    for (final track in targets) {
      final slot = _slots[track];
      if (slot == null) continue;
      if (slot.settle(startOffset: _clock.now)) {
        // Keep the track active so the ticker drives it to rest.
        _activeTracks.add(track);
      } else {
        slot
          ..stop()
          ..velocityFromTracker = false;
        _activeTracks.remove(track);
      }
    }

    _pruneTokenParticipants(targets);
    _releaseArrivedBarriers(_clock.now);
    _completeFinishedFutures();
    if (_activeTracks.isEmpty) {
      _ticker?.stop();
      notifyListeners();
      _updateStatus();
      return TickerFuture.complete();
    }

    // Settling tracks keep running; the (already active) ticker finishes them
    // via the normal _tick completion path.
    final settling = {
      for (final track in targets)
        if (_slots[track]?.isAnimating ?? false) track,
    };
    final future =
        settling.isEmpty ? TickerFuture.complete() : _futureFor(settling);
    _startTicker();
    notifyListeners();
    _updateStatus();
    return future;
  }

  /// Removes all internal state for [track].
  ///
  /// Used when a track identity is being replaced (e.g. a converter swap
  /// creates a new track). Stops the track's slot first if it is animating.
  @internal
  void forgetTrack(Track track) {
    _cancelFutures([track]);
    _slots[track]?.stop(canceled: true);
    _slots.remove(track);
    _activeTracks.remove(track);
    _runTracks.remove(track);
    _velocityTrackers.remove(track);
    _pruneTokenParticipants([track]);
  }

  /// Replaces [old] with [replacement] at [value] and [velocity], keeping
  /// its status, e.g. for a converter swap with the same dimensions.
  @internal
  void replaceTrack<T extends Object>(
    Track old,
    Track<T> replacement, {
    required T value,
    required T velocity,
  }) {
    final oldSlot = _slots[old];
    final inRun = _runTracks.contains(old);
    forgetTrack(old);
    final slot = _slot(replacement, initialOverride: value);
    if (oldSlot != null) slot.adoptStatus(oldSlot);
    slot.setValueWithVelocity(value, velocity);
    if (inRun) _runTracks.add(replacement);
    notifyListeners();
  }

  /// Recreates the ticker using [vsync].
  void resync(TickerProvider vsync) {
    final oldTicker = _ticker!;
    _ticker = vsync.createTicker(_tick);
    _ticker!.absorbTicker(oldTicker);
  }

  @override
  void dispose() {
    // Like AnimationController, pending futures are canceled, not completed.
    _cancelFutures(null);
    _ticker?.stop(canceled: true);
    _ticker?.dispose();
    _ticker = null;
    super.dispose();
  }

  void _playAnimation<T extends Object>(
    TrackAnimation<T> animation, {
    required LoopMode loop,
    required Duration startOffset,
  }) {
    _applyPendingVelocity(animation.track, consume: true);
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
  /// constructor-level [_initialValues], then the animation's own start value
  /// (`from` -> [Track.initial] -> zero-filled fallback), then [Track.initial].
  /// Asserts when none of these can supply a value.
  T _resolveInitialValue<T extends Object>(
    Track<T> track,
    TrackAnimation<T>? animation,
    T? initialOverride,
  ) {
    if (initialOverride != null) return initialOverride;
    for (final override in _initialValues.reversed) {
      if (override case TrackValue<T>(track: final overrideTrack)
          when identical(overrideTrack, track)) {
        return override.value;
      }
    }
    if (animation != null) return animation.resolveStartValue();
    if (track.initial case final value?) return value;
    throw StateError(
      'Tried to read a track value before it had any value. The track has no '
      'initial value and was never set or animated. Provide Track.initial, '
      'call set(), or animate it first.',
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
      _joinSyncTokens(animation.track, animation.steps);
    }
  }

  /// Adds [track] as a participant of every sync token in [steps], joining
  /// the round the other participants are in.
  void _joinSyncTokens(Track track, Iterable<TrackStep<Object>> steps) {
    for (final step in steps) {
      if (step is! StepSync) continue;
      (_tokenParticipants[step.token] ??= {}).add(track);
      final counts = _syncPasses[step.token] ??= {};
      if (!counts.containsKey(track)) {
        counts[track] = counts.values.fold(0, math.max);
      }
    }
  }

  /// Removes [tracks] from every sync-token participant set, dropping tokens
  /// left without participants. Stopped/redirected tracks will never reach
  /// their old barriers, so they must not hold (or trivially satisfy) them.
  void _pruneTokenParticipants(Iterable<Track> tracks) {
    for (final MapEntry(key: token, value: participants)
        in _tokenParticipants.entries) {
      if (!participants.any(tracks.contains)) continue;
      participants.removeAll(tracks);
      _syncNotBefore[token] = _clock.now;
    }
    for (final counts in _syncPasses.values) {
      counts.removeWhere((track, _) => tracks.contains(track));
    }
    _tokenParticipants.removeWhere((_, participants) => participants.isEmpty);
    _syncPasses
        .removeWhere((token, _) => !_tokenParticipants.containsKey(token));
    _syncNotBefore
        .removeWhere((token, _) => !_tokenParticipants.containsKey(token));
  }

  /// Releases every barrier whose participants have all arrived, at the
  /// latest arrival. Returns whether any barrier was released.
  ///
  /// A track's arrivals at a token are counted in rounds: its next arrival is
  /// round `passes + 1`, where `passes` counts how often it was released at
  /// that token. A round releases once every other animating participant has
  /// arrived at the same round or already passed it, so in a loop a fast
  /// track cannot lap a slow one. Barriers with a [FrameAnchoredSyncToken]
  /// release at [now] when [anchorFrames] is true.
  bool _releaseArrivedBarriers(Duration now, {bool anchorFrames = true}) {
    var released = false;
    for (final MapEntry(key: token, value: participants)
        in _tokenParticipants.entries.toList()) {
      final counts = _syncPasses[token] ??= {};
      int? round;
      for (final track in participants) {
        if (_slots[track]?.pendingSyncToken != token) continue;
        final arrival = (counts[track] ?? 0) + 1;
        if (round == null || arrival < round) round = arrival;
      }
      if (round == null) continue;

      Duration? releaseAt;
      var allArrived = true;
      for (final track in participants) {
        final slot = _slots[track];
        if (slot == null || !slot.isAnimating) continue;
        final passed = counts[track] ?? 0;
        if (slot.pendingSyncToken == token && passed + 1 == round) {
          final arrival = slot.pendingSyncArrival;
          if (releaseAt == null || arrival > releaseAt) releaseAt = arrival;
        } else if (passed < round) {
          allArrived = false;
          break;
        }
      }
      if (!allArrived || releaseAt == null) continue;
      if (_syncNotBefore[token] case final notBefore?
          when notBefore > releaseAt) {
        releaseAt = notBefore;
      }
      if (anchorFrames && token is FrameAnchoredSyncToken) {
        releaseAt = now;
      }

      for (final track in participants) {
        final slot = _slots[track];
        if (slot == null || slot.pendingSyncToken != token) continue;
        if ((counts[track] ?? 0) + 1 != round) continue;
        slot.releaseSync(releaseAt);
        counts[track] = round;
      }
      released = true;
      onSyncReleased(token);
    }
    return released;
  }

  void _startTicker() {
    final ticker = _ticker!;
    if (ticker.isActive) return;
    _clock.tickerStarted();
    ticker.start();
  }

  _TrackFuture _futureFor(Set<Track> tracks) {
    final future = _TrackFuture(tracks);
    _futures.add(future);
    return future;
  }

  /// Cancels the pending futures of calls that played any of [tracks], or
  /// all of them when [tracks] is null.
  void _cancelFutures(Iterable<Track>? tracks) {
    if (_futures.isEmpty) return;
    final canceled = [
      for (final future in _futures)
        if (tracks == null || tracks.any(future.tracks.contains)) future,
    ];
    for (final future in canceled) {
      _futures.remove(future);
      future.cancel();
    }
  }

  /// Completes the pending futures whose tracks have all finished.
  void _completeFinishedFutures() {
    if (_futures.isEmpty) return;
    final finished = [
      for (final future in _futures)
        if (!future.tracks.any((track) => _slots[track]?.isAnimating ?? false))
          future,
    ];
    for (final future in finished) {
      _futures.remove(future);
      future.complete();
    }
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
  /// A subclass may synchronously start a continuation here. Status listeners
  /// then only see the continuation's status, not the run boundary.
  @protected
  @visibleForOverriding
  void onPlaybackCompleted() {}

  void _tick(Duration elapsed) {
    final now = _clock.tick(elapsed);
    final allDone = _advanceTracks(now);
    // Before a continuation started on completion restarts these tracks.
    _completeFinishedFutures();
    if (allDone) {
      _completePlayback();
    } else if (_statusDirty) {
      _updateStatus();
    }
    notifyListeners();
  }

  /// Advances every active track to [now] and returns whether all are done.
  ///
  /// Barriers released on the way are released at their exact time, and the
  /// released tracks advance again, so one large frame gap resolves the same
  /// way as many small ones.
  bool _advanceTracks(Duration now, {bool scrubbing = false}) {
    var allDone = true;
    for (var pass = 0; pass < _maxBarrierPasses; pass++) {
      allDone = true;
      // Snapshot the active set: onStep callbacks may start or stop tracks.
      final tracks = _tickTracks
        ..clear()
        ..addAll(_activeTracks);
      for (final track in tracks) {
        final slot = _slots[track];
        if (slot == null) continue;
        final wasAnimating = slot.isAnimating;
        if (slot.tick(now)) {
          if (wasAnimating) _statusDirty = true;
        } else {
          allDone = false;
        }
        _notifyStep(track, slot, notify: !scrubbing);
      }
      if (!_releaseArrivedBarriers(now, anchorFrames: !scrubbing)) break;
    }
    return allDone;
  }

  void _completePlayback() {
    _ticker?.stop();
    _activeTracks.clear();
    // A continuation started by the hook starts a new run; either way only
    // the resulting status is reported.
    _holdStatus = true;
    try {
      onPlaybackCompleted();
    } finally {
      _holdStatus = false;
    }
    _updateStatus();
  }

  /// Adds [tracks] to the current run, starting a new run when no track is
  /// active.
  void _joinRun(Iterable<Track> tracks) {
    if (_activeTracks.isEmpty) _runTracks.clear();
    _runTracks.addAll(tracks);
  }

  /// Recomputes [status] from the run's tracks and reports a change.
  void _updateStatus() {
    if (_holdStatus) return;
    _statusDirty = false;
    var anyReverse = false;
    var allDismissed = true;
    AnimationStatus? status;
    for (final track in _runTracks) {
      switch (_statusOf(track)) {
        case AnimationStatus.forward:
          status = AnimationStatus.forward;
        case AnimationStatus.reverse:
          anyReverse = true;
        case AnimationStatus.completed:
          allDismissed = false;
        case AnimationStatus.dismissed:
          break;
      }
      if (status != null) break;
    }
    _status = status ??
        (anyReverse
            ? AnimationStatus.reverse
            : allDismissed
                ? AnimationStatus.dismissed
                : AnimationStatus.completed);
    if (_status == _lastReportedStatus) return;
    _lastReportedStatus = _status;
    notifyStatusListeners(_status);
  }

  /// Reports the steps [track] entered since the last call to `onStep`, or
  /// only marks them as seen when [notify] is false.
  void _notifyStep(Track track, _TrackSlot slot, {required bool notify}) {
    final entered = slot.takeEnteredSteps();
    if (entered.isNotEmpty) _statusDirty = true;
    final onStep = _onStep;
    if (!notify || onStep == null) return;
    for (final step in entered) {
      onStep(track, step);
    }
  }
}
