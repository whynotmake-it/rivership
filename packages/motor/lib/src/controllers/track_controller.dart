import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart'
    show
        ErrorDescription,
        FlutterError,
        FlutterErrorDetails,
        VoidCallback,
        describeIdentity;
import 'package:flutter/scheduler.dart';
import 'package:meta/meta.dart';
import 'package:motor/src/controllers/frame_anchored_sync_token.dart';
import 'package:motor/src/controllers/phase_track_controller.dart';
import 'package:motor/src/inspection/controller_registry.dart';
import 'package:motor/src/inspection/playback_snapshot.dart';
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
///
/// Like [AnimationController], value listeners hear only about value
/// changes. [stop], [pause] and [resume] change no value, so they don't
/// notify them, except when a stop releases a sync barrier, which moves the
/// tracks waiting there. A render object can stop its controller during
/// layout. Status listeners are notified whenever [status] changes.
class TrackController extends Animation<TrackValueReader>
    with
        AnimationLocalListenersMixin,
        AnimationLocalStatusListenersMixin,
        AnimationEagerListenerMixin {
  /// Creates a track controller.
  ///
  /// [initialValues] sets the value a track takes the first time this
  /// controller sees it, in place of [Track.initial], and the velocity it
  /// starts with: the first animation continues with it unless that
  /// animation has its own `withVelocity`. An entry from [Track.velocity]
  /// sets only the velocity. They are consulted only
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
    MotorInspectionRegistry.registerController(this);
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

  /// Upper bound on barrier rounds released in a row within one frame
  /// without time passing, so zero-length loops cannot spin forever. Rounds
  /// that take time don't count, so a jump far ahead always catches up.
  static const _maxBarrierPasses = 100;
  Motion? Function(Track<Object> track)? _motionOverride;
  final List<PlaybackPlan> _plans = [];
  var _hasInspectionData = false;

  /// How many submitted plans are kept for inspection tooling.
  static const _maxRecordedPlans = 16;
  final _clock = PlaybackClock();

  Ticker? _ticker;

  /// The futures returned by [play], [animate] and [stop] that are still
  /// pending.
  // Linked: O(1) removal, resolved in creation order.
  final LinkedHashSet<_TrackFuture> _futures = LinkedHashSet();

  /// The `onStep` of the call that started each track's plan.
  final Map<Track, void Function(Track track, int stepIndex)> _onSteps = {};
  AnimationStatus _status = AnimationStatus.dismissed;
  AnimationStatus _lastReportedStatus = AnimationStatus.dismissed;

  /// Whether any track is currently animating.
  @override
  bool get isAnimating => _ticker?.isActive ?? false;

  /// Whether any track is playing, which unlike [isAnimating] it also is
  /// while paused.
  @internal
  bool get hasActiveTracks => _activeTracks.isNotEmpty;

  /// Returns a reader for the current track values.
  ///
  /// Reading a track this controller has never seen returns its entry in the
  /// constructor's `initialValues` or [Track.initial], and registers the
  /// track with the controller. Reading a track with neither throws.
  @override
  late final TrackValueReader value = TrackValueReader(_read);

  /// The status of the tracks moved since this controller was last idle.
  ///
  /// While any of them moves, this is [AnimationStatus.reverse] if all
  /// moving tracks head down, otherwise [AnimationStatus.forward]. Once none
  /// moves, it is [AnimationStatus.dismissed] if all of them are dismissed,
  /// otherwise [AnimationStatus.completed]. See [animationOf] for the status
  /// of a single track; a stopped track counts as moving in its last
  /// direction.
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
  /// - Once its plan has settled, or it jumped with [set]:
  ///   [AnimationStatus.dismissed] if its last move went down, otherwise
  ///   [AnimationStatus.completed]. For converters without a direction,
  ///   dismissed means exactly back at the track's initial value.
  /// - After [stop], the direction it was moving in, also while a graceful
  ///   stop settles: a stop interrupts the move rather than completing it.
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

  /// Returns [track]'s current normalized values, as a copy.
  @internal
  List<double> internalNormalizedValues(Track track) =>
      List.of(_slot(track).normalizedValues);

  /// Returns [track]'s current normalized velocities, as a copy.
  @internal
  List<double> internalNormalizedVelocities(Track track) {
    _applyPendingVelocity(track);
    return List.of(_slot(track).normalizedVelocities);
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
  /// - If it has a [TrackValue.velocity], that velocity is set along with the
  ///   position. A snapshot from [Track.velocity] sets only the velocity and
  ///   keeps the track's current value.
  /// - Otherwise, the position is recorded in a [MotionVelocityTracker] to
  ///   estimate velocity from the history of samples (unless
  ///   [velocityTracking] is off).
  ///
  /// Subsequent [play] or [animate] calls inherit the velocity.
  ///
  /// Like a [stop] with `canceled: true`, this cancels the futures of the
  /// calls that played these tracks and detaches them: they no longer play,
  /// and barriers other tracks wait at no longer wait for them.
  void set(List<TrackValue> values) => internalSet(values);

  /// [set] for controllers that jump on their own behalf, without being
  /// treated as a call to [set].
  @internal
  void internalSet(List<TrackValue> values) {
    if (_futures.isNotEmpty) {
      _cancelFutures([for (final value in values) value.track]);
    }
    _sampledAt = null;
    if (_activeTracks.isEmpty) _runTracks.clear();
    var detached = false;
    for (final trackValue in values) {
      _runTracks.add(trackValue.track);
      _setTrackValue(trackValue);
      detached |= _activeTracks.remove(trackValue.track);
    }
    if (detached) {
      _pruneTokenParticipants([for (final value in values) value.track]);
      _releaseArrivedBarriers(_clock.now);
      if (_activeTracks.isEmpty) _ticker?.stop(canceled: true);
    }
    notifyListeners();
    _updateStatus();
  }

  // When the values of the current [set] call were sampled; values set
  // together share one instant.
  DateTime? _sampledAt;

  void _setTrackValue<T extends Object>(TrackValue<T> trackValue) {
    final slot = _slot(trackValue.track, initialOverride: trackValue.value);
    _archive(slot);
    final value = trackValue.value;
    final velocity = trackValue.velocity;
    if (value != null && velocity == null) {
      slot.setValue(value);
      final tracker = _trackerFor(trackValue.track);
      if (tracker == null) return;
      // Sourced from [clock] so tests drive it with the fake clock.
      final sampledAt = _sampledAt ??= clock.now();
      tracker.addPositionAt(sampledAt, value);
      slot.velocityFromTracker = true;
      return;
    }
    // A snapshot without a value comes from [Track.velocity], which always
    // has a velocity; it keeps the track where it is.
    slot
      ..velocityFromTracker = false
      ..setNormalized(
        value == null
            ? List<double>.of(slot.normalizedValues)
            : slot.converter.normalize(value),
        slot.converter.normalize(velocity!),
      );
  }

  /// Sets [track]'s velocity to the estimate from its tracked samples, as of
  /// now, so it decays once the value holds still. Unless [consume], later
  /// reads estimate it again.
  void _applyPendingVelocity(Track track, {bool consume = false}) {
    final slot = _slots[track];
    final tracker = _velocityTrackers[track];
    if (slot == null || tracker == null || !slot.velocityFromTracker) return;
    if (consume) slot.velocityFromTracker = false;
    final velocity = tracker.getNormalizedVelocity();
    if (velocity != null) slot.setVelocity(velocity);
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
  /// Returns a [MotionFuture] for this call's tracks. It completes when they
  /// have all settled, and [MotionFuture.ended] when they have all ended.
  /// Restarting one of them, or `stop(canceled: true)`, cancels it. A
  /// graceful [stop] completes it once the tracks rest. A looping animation
  /// never completes, so don't await it.
  ///
  /// A track whose animation is a single [TrackStep.to] that its motion
  /// finishes at once from where the track is, such as a spring at rest on
  /// its target, doesn't play: it doesn't tick or change [status], and
  /// counts as settled right away.
  /// {@endtemplate}
  ///
  /// {@template TrackController.onStep}
  /// [onStep] is called once for every step each track enters, in order,
  /// including steps shorter than a frame. It is not called while scrubbing,
  /// or for the internal step that returns a [LoopMode.loop] to its start.
  /// It belongs to the plans this call starts: a later call that restarts a
  /// track replaces it for that track only, and tracks the later call
  /// doesn't name keep reporting to it. An error it throws is reported to
  /// [FlutterError.reportError], and playback goes on.
  /// {@endtemplate}
  MotionFuture play(
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
  MotionFuture animate(
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

  MotionFuture _startAnimations({
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
    if (timelineTracks.isEmpty) return MotionFuture.complete();

    _cancelFutures(timelineTracks);

    for (final track in timelineTracks) {
      if (onStep == null) {
        _onSteps.remove(track);
      } else {
        _onSteps[track] = onStep;
      }
    }

    final resting = <Track, List<double>>{};
    if (!loop.isLooping) {
      for (final animation in animations) {
        if (_restingValues(animation) case final values?) {
          resting[animation.track] = values;
        }
      }
    }
    final moving = resting.isEmpty
        ? animations
        : [
            for (final animation in animations)
              if (!resting.containsKey(animation.track)) animation,
          ];
    final movingTracks = resting.isEmpty
        ? timelineTracks
        : {for (final animation in moving) animation.track};

    _mergeTokenParticipants(animations, timelineTracks);

    if (resting.isNotEmpty) {
      _rest(resting);
      if (moving.isEmpty) {
        if (_activeTracks.isEmpty) _ticker?.stop(canceled: true);
        return MotionFuture.complete();
      }
    }

    // Previously-running tracks stay active; the named tracks (re)start.
    _joinRun(movingTracks);
    _activeTracks.addAll(movingTracks);

    final startOffset = _clock.now;
    for (final animation in moving) {
      _playAnimation(
        _applyMotionOverride(animation),
        loop: loop,
        startOffset: startOffset,
      );
    }

    final inspecting = MotorInspectionRegistry.isInspecting;
    if (inspecting) _recordPlan(moving, loop: loop, start: startOffset);
    final future = _futureFor(movingTracks);
    _startTicker();
    if (inspecting) _tryEstimateDurations(movingTracks);
    _updateStatus();
    return future;
  }

  /// The values [animation]'s track rests at without playing, or null when
  /// it plays.
  ///
  /// An animation rests when it is a single [TrackStep.to] whose motion,
  /// started from the track's value and velocity, is done right away
  /// ([Simulation.isDone] at 0) without moving. A spring at its target
  /// without velocity is done; one with velocity still overshoots, and a
  /// curve from its target to itself has nowhere to go. Like an
  /// [AnimationController] that is never started, such an animation doesn't
  /// tick, notify, report a status or call `onStep`, and its future completes
  /// right away.
  List<double>? _restingValues<T extends Object>(TrackAnimation<T> animation) {
    final resolved = _applyMotionOverride(animation) as TrackAnimation<T>;
    if (resolved.steps
        case [
          StepTo<T>(:final value, :final motion, :final motionPerDimension),
        ]) {
      final track = animation.track;
      _applyPendingVelocity(track, consume: true);
      final slot = _slot(track, forAnimation: animation);
      final converter = track.converter;
      final start = switch (animation.from) {
        final from? => converter.normalize(from),
        null => List.of(slot.normalizedValues),
      };
      final velocity = switch (animation.withVelocity) {
        final velocity? => converter.normalize(velocity),
        null => slot.normalizedVelocities,
      };
      final end = converter.normalize(value);
      if (start.length != end.length || velocity.length != end.length) {
        return null;
      }
      final motions = motionPerDimension ??
          (motion == null ? null : List.filled(end.length, motion)) ??
          track.motionPerDimension ??
          (track.motion == null
              ? null
              : List.filled(end.length, track.motion!));
      if (motions == null || motions.length != end.length) return null;
      for (var i = 0; i < end.length; i++) {
        final simulation = motions[i].createSimulation(
          start: start[i],
          end: end[i],
          velocity: velocity[i],
        );
        if (!simulation.isDone(0) || simulation.x(0) != start[i]) return null;
      }
      return start;
    }
    return null;
  }

  static bool _sameValues(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Puts the [resting] tracks at their values without playing, replacing
  /// whatever they played.
  void _rest(Map<Track, List<double>> resting) {
    var moved = false;
    for (final MapEntry(key: track, value: values) in resting.entries) {
      final slot = _slots[track]!;
      _archive(slot);
      moved |= !_sameValues(values, slot.normalizedValues);
      slot
        ..rest(values)
        ..velocityFromTracker = false;
      _activeTracks.remove(track);
    }
    if (moved) notifyListeners();
    _updateStatus();
  }

  /// Estimates step durations for inspection tooling. Resolving ahead may
  /// reach steps that playback never does, so a failure there is reported
  /// without failing the call that started playback.
  void _tryEstimateDurations(Set<Track> tracks) {
    try {
      _estimateDurations(tracks);
    } catch (error, stack) {
      _report(
        error,
        stack,
        'while estimating step durations for inspection tooling',
      );
    }
  }

  /// Records per-step duration estimates for inspection tooling by resolving
  /// forks of the new plans ahead of time, with barriers released as they
  /// would be during playback. Tracks outside [tracks] are not waited for.
  void _estimateDurations(Set<Track> tracks) {
    final forks = <Track, _TrackSlot>{
      for (final track in tracks)
        if (_slots[track]?.fork() case final fork?) track: fork,
    };
    final horizon = _clock.now + const Duration(days: 1);
    final passes = {
      for (final MapEntry(:key, :value) in _syncPasses.entries)
        key: Map.of(value),
    };
    for (var pass = 0; pass < _maxBarrierPasses; pass++) {
      for (final fork in forks.values) {
        fork.tick(horizon);
      }
      if (_releaseArrivedBarriers(horizon, slots: forks, passes: passes) ==
          null) {
        break;
      }
    }
    for (final MapEntry(key: track, value: fork) in forks.entries) {
      _slots[track]!._stepPlayback!.estimatedSegmentSeconds =
          fork._stepPlayback!.forwardSegmentSeconds;
    }
  }

  /// Evaluates retained track plans at [t] without starting the ticker.
  ///
  /// [t] is a position on the controller's timeline, which starts at zero and
  /// only advances while the controller is ticking. Each track is evaluated
  /// relative to the moment it was started on that timeline, so tracks started
  /// at different times stay aligned. Playback continues from [t] afterwards.
  /// Settled plans are retained, so scrubbing works after playback has
  /// settled.
  ///
  /// Scrubbing resolves plans exactly like playback does, including sync
  /// barriers, so it shows what playback would show at [t]. Times already
  /// played are shown as they played. Looping plans that cannot repeat
  /// exactly, such as loops with sync steps, keep only their two most recent
  /// cycles; earlier times show the start of the earliest cycle kept.
  /// `package:motor/inspection.dart` describes what is kept while inspection
  /// tooling is attached.
  ///
  /// Call [pause] before repeated interactive scrubs, then [resume] to
  /// continue from the selected position without rewinding.
  void scrubTo(Duration t) {
    _dropInspectionDataIfDetached();
    _clock.seek(t);
    for (final entry in _slots.entries) {
      if (!entry.value.hasPlayback && !entry.value.hasArchive) continue;
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
  /// not a completed or canceled animation outcome. Like [stop], it doesn't
  /// notify value listeners. Use [scrubTo] to inspect a position and [resume]
  /// to continue from it. Starting any playback with [play] or [animate] also
  /// resumes the paused tracks from where they stopped.
  void pause() {
    final ticker = _ticker;
    if (ticker == null || !ticker.isActive) return;
    ticker.stop();
  }

  /// Resumes paused playback from each track's current local playhead.
  ///
  /// Calling this while the ticker is already active, or when no track has
  /// anything left to play, is a no-op. Scrubbing a settled plan back with
  /// [scrubTo] makes it resumable again.
  void resume() {
    if (isAnimating) return;
    if (!_activeTracks.any((track) => _slots[track]?.isAnimating ?? false)) {
      return;
    }
    _startTicker();
    _updateStatus();
  }

  /// Keeps [slot]'s current plan for scrubbing back while inspection tooling
  /// is attached.
  void _archive(_TrackSlot slot) {
    _dropInspectionDataIfDetached();
    if (MotorInspectionRegistry.isInspecting) {
      slot.archive(_clock.now);
      _hasInspectionData = true;
    }
  }

  /// Forgets archived plans and plan history once no tool is attached.
  void _dropInspectionDataIfDetached() {
    if (!_hasInspectionData || MotorInspectionRegistry.isInspecting) return;
    _hasInspectionData = false;
    _plans.clear();
    for (final slot in _slots.values) {
      slot.clearArchive();
    }
  }

  void _recordPlan(
    List<TrackAnimation> animations, {
    required LoopMode loop,
    required Duration start,
  }) {
    _hasInspectionData = true;
    _plans.add(
      PlaybackPlan(
        start: start,
        animations: animations,
        loop: loop,
        startValues: [
          for (final animation in animations) _currentValueOf(animation.track),
        ],
      ),
    );
    if (_plans.length > _maxRecordedPlans) _plans.removeAt(0);
  }

  TrackValue<T> _currentValueOf<T extends Object>(Track<T> track) =>
      track.value(_slots[track]!.value as T);

  TrackAnimation _applyMotionOverride(TrackAnimation animation) {
    final override = _motionOverride?.call(animation.track);
    if (override == null) return animation;
    return animation.withMotionOverride(override);
  }

  /// Stops the given [tracks], or all tracks when [tracks] is null.
  ///
  /// Unless [canceled] is true, each targeted track whose running step moves
  /// with a motion that needs to settle ([Motion.needsSettle]) settles at its
  /// current value with that motion instead of freezing: a spring keeps its
  /// momentum and eases to rest. While a free motion, hold or barrier runs,
  /// the track's default motion decides. Other tracks stop immediately, as
  /// does every targeted track when [canceled] is true. Either way, stopped
  /// tracks keep the direction they were moving in as their status.
  ///
  /// While paused, a settling track waits for [resume] like the others, and
  /// the future settles then.
  ///
  /// Returns a [MotionFuture] that settles when the settling tracks come to
  /// rest, or an already settled one when none settles.
  ///
  /// The futures of earlier calls for the stopped tracks are canceled when
  /// [canceled] is true, like [AnimationController.stop]. Otherwise they are
  /// completed: [MotionFuture.ended] right away, and the future itself once
  /// all of its tracks have come to rest, which for a spring that settles is
  /// later.
  ///
  /// A stop doesn't notify value listeners (see [TrackController]).
  MotionFuture stop({
    List<Track>? tracks,
    bool canceled = false,
  }) {
    return canceled ? _hardStop(tracks) : _gracefulStop(tracks);
  }

  MotionFuture _hardStop(List<Track>? tracks) {
    _cancelFutures(tracks);
    if (tracks == null) {
      for (final slot in _slots.values) {
        _archive(slot);
        slot.stop();
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
        if (slot != null) _archive(slot);
        slot?.stop();
        _activeTracks.remove(track);
        slot?.velocityFromTracker = false;
      }
      _pruneTokenParticipants(tracks);
    }
    final released = _releaseArrivedBarriers(_clock.now);
    if (_activeTracks.isEmpty) {
      _ticker?.stop(canceled: true);
    }
    // Releasing a barrier is the only way a stop moves a track.
    if (released != null) notifyListeners();
    _updateStatus();
    return MotionFuture.complete();
  }

  MotionFuture _gracefulStop(List<Track>? tracks) {
    final targets = tracks ?? _slots.keys.toList();
    for (final future in _futures) {
      if (future.repeats && future.tracks.every(targets.contains)) {
        future.repeats = false;
      }
    }
    final settling = <Track>{};
    for (final track in targets) {
      final slot = _slots[track];
      if (slot == null) continue;
      _archive(slot);
      if (slot.settle(startOffset: _clock.now)) {
        // Keep the track active so the ticker drives it to rest.
        _activeTracks.add(track);
        settling.add(track);
      } else {
        slot
          ..stop()
          ..velocityFromTracker = false;
        _activeTracks.remove(track);
      }
    }

    _pruneTokenParticipants(targets);
    final released = _releaseArrivedBarriers(_clock.now);
    _completeFinishedFutures();
    // Releasing a barrier is the only way a stop moves a track.
    if (released != null) notifyListeners();
    if (_activeTracks.isEmpty) {
      _ticker?.stop();
      _updateStatus();
      return MotionFuture.complete();
    }

    // Settling tracks keep running; the ticker settles them via the normal
    // _tick completion path. It is not restarted: while paused they wait for
    // [resume], like the other tracks.
    final future = settling.isEmpty
        ? MotionFuture.complete()
        : (_futureFor(settling)..end());
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
    _slots[track]?.stop();
    _slots.remove(track);
    _onSteps.remove(track);
    _animations.remove(track);
    _activeTracks.remove(track);
    _runTracks.remove(track);
    _velocityTrackers.remove(track);
    _pruneTokenParticipants([track]);
  }

  /// Replaces [old] with [replacement] at [value] and [velocity], keeping
  /// its status, e.g. for a converter swap with the same dimensions.
  ///
  /// A plan [old] is playing keeps playing on [replacement], which reads its
  /// normalized values the same way.
  @internal
  void replaceTrack<T extends Object>(
    Track old,
    Track<T> replacement, {
    required List<double> values,
    required List<double> velocities,
  }) {
    final oldSlot = _slots[old];
    final inRun = _runTracks.contains(old);
    if (oldSlot != null && oldSlot.isAnimating) {
      _slots
        ..remove(old)
        ..[replacement] = (oldSlot..replaceConverter(replacement.converter));
      _runTracks.remove(old);
      _velocityTrackers.remove(old);
      if (_onSteps.remove(old) case final onStep?) {
        _onSteps[replacement] = onStep;
      }
      if (_activeTracks.remove(old)) _activeTracks.add(replacement);
      for (final future in _futures) {
        if (future.tracks.remove(old)) future.tracks.add(replacement);
      }
      for (final participants in _tokenParticipants.values) {
        if (participants.remove(old)) participants.add(replacement);
      }
      for (final counts in _syncPasses.values) {
        if (counts.remove(old) case final passes?) counts[replacement] = passes;
      }
    } else {
      forgetTrack(old);
      final slot = _slots[replacement] ?? _newSlot(replacement, values);
      if (oldSlot != null) slot.adoptStatus(oldSlot);
      slot.setNormalized(values, velocities);
    }
    if (inRun) _runTracks.add(replacement);
    notifyListeners();
  }

  /// Whether [track] is moving down, or was when it was stopped.
  @internal
  bool internalMovingDown(Track track) => _slots[track]?.movingDown ?? false;

  /// Treats [track]'s running animation as the settle of a graceful stop, for
  /// controllers that settle with their own animation: the track keeps
  /// [movingDown] as its direction for status.
  @internal
  void internalKeepStopDirection(Track track, {required bool movingDown}) {
    _slots[track]?.keepStopDirection(down: movingDown);
    _updateStatus();
  }

  /// Stops the ticker and completes every pending future or, if [canceled],
  /// cancels them; the tracks keep their plans.
  ///
  /// `MotionController` uses this to complete an interrupted animation's
  /// future when its value is set, and to restart the ticker for each call,
  /// as in 1.x.
  @internal
  void stopTicker({required bool canceled}) {
    final ticker = _ticker;
    if (ticker != null && ticker.isActive) ticker.stop(canceled: canceled);
    final futures = List.of(_futures);
    _futures.clear();
    for (final future in futures) {
      canceled ? future.cancel() : future.complete();
    }
  }

  /// Marks [future], returned by [play] or [animate], as spanning a looping
  /// sequence of runs: it never ends or settles on its own, and runs started
  /// with [internalContinueRepeating] don't cancel it.
  @internal
  void internalRepeat(MotionFuture future) {
    if (future is _TrackFuture && future._completed == null) {
      future.repeats = true;
    }
  }

  /// Starts the next run of a looping sequence from [onPlaybackSettled],
  /// keeping the futures marked with [internalRepeat].
  @internal
  void internalContinueRepeating(List<TrackAnimation> animations) {
    _continuingRepeat = true;
    try {
      animate(animations);
    } finally {
      _continuingRepeat = false;
    }
  }

  /// Sets [values] between the runs of a looping sequence from
  /// [onPlaybackSettled], keeping the futures marked with [internalRepeat].
  @internal
  void internalJumpRepeating(List<TrackValue> values) {
    _continuingRepeat = true;
    try {
      internalSet(values);
    } finally {
      _continuingRepeat = false;
    }
  }

  var _continuingRepeat = false;

  /// Plays [animations], which settle a graceful stop of controllers that
  /// settle with their own animation. Pending futures are not canceled: their
  /// [MotionFuture.ended] completes now and they complete once the tracks
  /// have settled.
  @internal
  MotionFuture internalSettle(List<TrackAnimation> animations) {
    for (final future in _futures) {
      future
        ..repeats = false
        ..end();
    }
    _keepingFutures = true;
    try {
      return animate(animations);
    } finally {
      _keepingFutures = false;
    }
  }

  var _keepingFutures = false;

  /// Recreates the ticker using [vsync].
  void resync(TickerProvider vsync) {
    final oldTicker = _ticker!;
    _ticker = vsync.createTicker(_tick);
    _ticker!.absorbTicker(oldTicker);
  }

  @override
  void dispose() {
    MotorInspectionRegistry.unregisterController(this);
    // Like AnimationController, pending futures are canceled, not completed.
    _cancelFutures(null);
    _ticker?.stop(canceled: true);
    _ticker?.dispose();
    _ticker = null;
    super.dispose();
  }

  /// Builds a read-only snapshot for `package:motor/inspection.dart`.
  @internal
  PlaybackSnapshot internalInspectPlayback() {
    _dropInspectionDataIfDetached();
    final tracks = <TrackPlayback>[];
    for (final entry in _slots.entries) {
      final playback = entry.value.shownPlayback;
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
          isWaitingForSync: playback.isWaitingForSync,
          startOffset: entry.value.shownStartOffset,
          playhead: _durationFromSeconds(playback.lastElapsedSeconds)!,
          stepDurations: [
            for (final seconds in playback.forwardSegmentSeconds)
              _durationFromSeconds(seconds),
          ],
          estimatedStepDurations: [
            for (final seconds in playback.estimatedSegmentSeconds)
              _durationFromSeconds(seconds),
          ],
          segments: [
            for (final segment in playback.segmentsView)
              PlaybackSegment(
                stepIndex: segment.stepIndex,
                direction: segment.direction,
                cycle: segment.cycle,
                start: _durationFromSeconds(segment.start)!,
                end: _durationFromSeconds(segment.end),
              ),
          ],
          loopPeriod: _durationFromSeconds(playback.loopPeriodSeconds),
          loopRepeatStart: playback.loopPeriodSeconds == null
              ? null
              : _durationFromSeconds(playback.loopRepeatStartSeconds),
        ),
      );
    }
    return PlaybackSnapshot(
      plans: _plans,
      status: status,
      tracks: tracks,
      position: _clock.now,
    );
  }

  /// Exposes the inspection playback speed to tooling.
  @internal
  double get internalPlaybackSpeed => _clock.rate;

  /// Exposes whether the ticker is muted to tooling.
  @internal
  bool get internalIsMuted => _ticker?.muted ?? false;

  /// Changes the logical playback rate without affecting other controllers.
  @internal
  set internalPlaybackSpeed(double value) {
    assert(value > 0, 'playbackSpeed must be greater than zero.');
    if (value <= 0 || value == _clock.rate) return;
    _clock.rate = value;
    notifyListeners();
  }

  /// Exposes the motion override callback to tooling.
  @internal
  Motion? Function(Track<Object> track)? get internalMotionOverride =>
      _motionOverride;

  @internal
  set internalMotionOverride(Motion? Function(Track<Object> track)? value) {
    _motionOverride = value;
  }

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
    _applyPendingVelocity(animation.track, consume: true);
    final slot = _slot(animation.track, forAnimation: animation);
    _archive(slot);
    if (animation.from case final from?) {
      slot.jumpKeepingVelocity(from);
    }
    slot.play(
      animation.steps,
      loop: loop,
      startOffset: startOffset,
      velocity: animation.withVelocity == null
          ? null
          : animation.track.converter.normalize(animation.withVelocity!),
      delay: animation.delay,
      handOver: animation.from == null && animation.withVelocity == null,
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
    final slot = _newSlot(track, track.converter.normalize(initialValue));
    for (final entry in _initialValues.reversed) {
      if (entry
          case TrackValue<T>(
            track: final entryTrack,
            velocity: final T velocity,
          ) when identical(entryTrack, track)) {
        slot.setVelocity(track.converter.normalize(velocity));
        break;
      }
    }
    return slot;
  }

  _TrackSlot _newSlot(Track track, List<double> initialValues) {
    final slot = _TrackSlot(
      converter: track.converter,
      initialValues: initialValues,
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
      if (override
          case TrackValue<T>(
            track: final overrideTrack,
            value: final T value,
          ) when identical(overrideTrack, track)) {
        return value;
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
    if (_tokenParticipants.isEmpty) return;
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
  /// latest arrival. Returns the latest time a barrier was released at, or
  /// null if none was.
  ///
  /// A track's arrivals at a token are counted in rounds: its next arrival is
  /// round `passes + 1`, where `passes` counts how often it was released at
  /// that token. A round releases once every other animating participant has
  /// arrived at the same round or already passed it, so in a loop a fast
  /// track cannot lap a slow one. Barriers with a [FrameAnchoredSyncToken]
  /// release at [now] when [anchorFrames] is true.
  ///
  /// [slots] and [passes] default to the controller's own; estimation passes
  /// forks and a copy of the pass counts to resolve ahead of playback.
  Duration? _releaseArrivedBarriers(
    Duration now, {
    Map<Track, _TrackSlot>? slots,
    Map<Object, Map<Track, int>>? passes,
    bool anchorFrames = true,
  }) {
    if (_tokenParticipants.isEmpty) return null;
    final lookup = slots ?? _slots;
    final passCounts = passes ?? _syncPasses;
    Duration? released;
    for (final MapEntry(key: token, value: participants)
        in _tokenParticipants.entries.toList()) {
      final counts = passCounts[token] ??= {};
      int? round;
      for (final track in participants) {
        if (lookup[track]?.pendingSyncToken != token) continue;
        final arrival = (counts[track] ?? 0) + 1;
        if (round == null || arrival < round) round = arrival;
      }
      if (round == null) continue;

      Duration? releaseAt;
      var allArrived = true;
      for (final track in participants) {
        final slot = lookup[track];
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
      if (anchorFrames && slots == null && token is FrameAnchoredSyncToken) {
        releaseAt = now;
      }

      for (final track in participants) {
        final slot = lookup[track];
        if (slot == null || slot.pendingSyncToken != token) continue;
        if ((counts[track] ?? 0) + 1 != round) continue;
        slot.releaseSync(releaseAt);
        counts[track] = round;
      }
      if (released == null || releaseAt > released) released = releaseAt;
      if (slots == null) onSyncReleased(token);
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
    final future = _TrackFuture(tracks, this);
    _futures.add(future);
    return future;
  }

  /// Cancels the pending futures of calls that played any of [tracks], or
  /// all of them when [tracks] is null.
  void _cancelFutures(Iterable<Track>? tracks) {
    if (_futures.isEmpty || _keepingFutures) return;
    final canceled = [
      for (final future in _futures)
        if ((tracks == null || tracks.any(future.tracks.contains)) &&
            !(future.repeats && _continuingRepeat))
          future,
    ];
    for (final future in canceled) {
      _futures.remove(future);
      future.cancel();
    }
  }

  /// Ends the pending futures whose tracks have all ended, and completes
  /// those whose tracks have all settled.
  void _completeFinishedFutures() {
    if (_futures.isEmpty) return;
    List<_TrackFuture>? settled;
    for (final future in _futures) {
      if (future.repeats) continue;
      if (!future.tracks.any((track) => _slots[track]?.isAnimating ?? false)) {
        (settled ??= []).add(future);
      } else if (future.awaitsEnd && _haveEnded(future.tracks)) {
        future.end();
      }
    }
    if (settled == null) return;
    for (final future in settled) {
      _futures.remove(future);
      future.complete();
    }
  }

  bool _haveEnded(Set<Track> tracks) {
    for (final track in tracks) {
      if (!(_slots[track]?.hasEnded ?? true)) return false;
    }
    return true;
  }

  /// Called when a group of tracks is released past a sync barrier.
  ///
  /// Subclasses (e.g. [PhaseTrackController]) override this to detect phase
  /// transitions. The [token] is the [StepSync.token] that was released.
  @protected
  @visibleForOverriding
  void onSyncReleased(Object token) {}

  /// Called after every active track settles at the end of a non-looping
  /// playback run.
  ///
  /// A subclass may synchronously start a continuation here. Status listeners
  /// then only see the continuation's status, not the run boundary.
  @protected
  @visibleForOverriding
  void onPlaybackSettled() {}

  void _tick(Duration elapsed) {
    try {
      final now = _clock.tick(elapsed);
      final allDone = _advanceTracks(now);
      // Before a continuation started on completion restarts these tracks.
      _completeFinishedFutures();
      if (allDone) {
        _completePlayback();
      } else if (_statusDirty) {
        _updateStatus();
      }
    } catch (error, stack) {
      // An error escaping the ticker would leave it active without frames.
      // Stop it instead, so that the next call starts it again.
      _report(error, stack, 'while advancing playback');
      _ticker?.stop(canceled: true);
      _cancelFutures(null);
    }
    notifyListeners();
  }

  static void _report(Object error, StackTrace stack, String context) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'motor',
        context: ErrorDescription(context),
      ),
    );
  }

  /// Advances every active track to [now] and returns whether all are done.
  ///
  /// Barriers released on the way are released at their exact time, and the
  /// released tracks advance again, so one large frame gap resolves the same
  /// way as many small ones.
  bool _advanceTracks(Duration now, {bool scrubbing = false}) {
    _dropInspectionDataIfDetached();
    var allDone = true;
    Duration? lastRelease;
    var stalled = 0;
    while (true) {
      allDone = true;
      // Snapshot the active set: onStep callbacks may start or stop tracks.
      final tracks = _tickTracks
        ..clear()
        ..addAll(_activeTracks);
      for (final track in tracks) {
        final slot = _slots[track];
        if (slot == null) continue;
        final wasAnimating = slot.isAnimating;
        if (slot.tick(now, scrubbing: scrubbing)) {
          if (wasAnimating) _statusDirty = true;
        } else {
          allDone = false;
        }
        _notifyStep(track, slot, notify: !scrubbing);
      }
      final release = _releaseArrivedBarriers(now, anchorFrames: !scrubbing);
      if (release == null) break;
      if (lastRelease != null && release <= lastRelease) {
        if (++stalled >= _maxBarrierPasses) break;
      } else {
        stalled = 0;
      }
      lastRelease = release;
    }
    // An onStep callback may have started playback after its track was
    // ticked.
    if (allDone) {
      allDone =
          !_activeTracks.any((track) => _slots[track]?.isAnimating ?? false);
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
      onPlaybackSettled();
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
    final onStep = _onSteps[track];
    if (!notify || onStep == null) return;
    for (final step in entered) {
      try {
        onStep(track, step);
      } catch (error, stack) {
        _report(error, stack, 'while calling onStep');
      }
    }
  }
}
