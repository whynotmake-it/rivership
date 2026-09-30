import 'package:flutter/animation.dart';
import 'package:meta/meta.dart';
import 'package:motor/src/controllers/motion_controller.dart';
import 'package:motor/src/controllers/track_controller.dart';
import 'package:motor/src/inspection/controller_registry.dart';
import 'package:motor/src/loop_mode.dart';
import 'package:motor/src/motion.dart';
import 'package:motor/src/track.dart';
import 'package:motor/src/track_step.dart';

/// A point-in-time view of everything a [TrackController] is playing.
@experimental
@immutable
class PlaybackSnapshot {
  /// Creates an immutable playback snapshot.
  PlaybackSnapshot({
    required this.status,
    required List<TrackPlayback> tracks,
    List<PlaybackPlan> plans = const [],
    this.position = Duration.zero,
  })  : plans = List.unmodifiable(plans),
        tracks = List.unmodifiable(tracks);

  /// Where the controller is on its playback timeline, in the time that
  /// `scrubTo` takes. It only advances while the controller ticks.
  final Duration position;

  /// The controller's current animation status.
  final AnimationStatus status;

  /// Playback details for every slot that still retains a playback plan.
  final List<TrackPlayback> tracks;

  /// The most recent plans submitted with `play` or `animate`, oldest first.
  ///
  /// Recorded only while an inspection observer is attached, up to 16.
  final List<PlaybackPlan> plans;
}

/// A plan submitted to a [TrackController] with `play` or `animate`.
@experimental
@immutable
class PlaybackPlan {
  /// Creates a record of a submitted plan.
  PlaybackPlan({
    required this.start,
    required List<TrackAnimation> animations,
    required this.loop,
    required List<TrackValue> startValues,
  })  : animations = List.unmodifiable(animations),
        startValues = List.unmodifiable(startValues);

  /// When the plan started, on the controller's playback clock.
  final Duration start;

  /// The animations as they were submitted.
  final List<TrackAnimation> animations;

  /// The loop mode the animations were played with.
  final LoopMode loop;

  /// Each animated track's value when the plan started.
  ///
  /// Setting these with `TrackController.set` and submitting [animations]
  /// again replays the plan.
  final List<TrackValue> startValues;
}

/// One track's live, read-only playback state.
@experimental
@immutable
class TrackPlayback {
  /// Creates an immutable track playback snapshot.
  TrackPlayback({
    required this.track,
    required List<TrackStep<Object>> steps,
    required this.hasSyntheticReturnStep,
    required this.loop,
    required this.currentStepIndex,
    required this.direction,
    required this.isWaitingForSync,
    required this.startOffset,
    required this.playhead,
    required List<Duration?> stepDurations,
    required List<Duration?> estimatedStepDurations,
    List<PlaybackSegment> segments = const [],
    this.loopPeriod,
    this.loopRepeatStart,
  })  : steps = List.unmodifiable(steps),
        segments = List.unmodifiable(segments),
        stepDurations = List.unmodifiable(stepDurations),
        estimatedStepDurations = List.unmodifiable(estimatedStepDurations);

  /// The identity of the track represented by this snapshot.
  final Track<Object> track;

  /// The actual running plan, including a synthetic loop-return step when
  /// [hasSyntheticReturnStep] is true.
  final List<TrackStep<Object>> steps;

  /// Whether the final entry in [steps] was synthesized for [LoopMode.loop].
  final bool hasSyntheticReturnStep;

  /// The loop mode used by this track's running plan.
  final LoopMode loop;

  /// The active step index, or `-1` once playback has settled.
  final int currentStepIndex;

  /// The current direction: `1` while forward and `-1` while reversing.
  final int direction;

  /// Whether this track is currently held at a synchronization barrier.
  final bool isWaitingForSync;

  /// When the track's current plan started on the controller's playback
  /// clock, the same timeline used by `TrackController.scrubTo`.
  final Duration startOffset;

  /// The latest elapsed position on this track's slot-local axis.
  final Duration playhead;

  /// How long each forward step occupied the timeline, from its start until
  /// the next step started, or `null` until recorded.
  ///
  /// By default the next step waits until a step has settled, so this can be
  /// longer than the step's motion duration.
  final List<Duration?> stepDurations;

  /// Stable duration estimates computed when this playback plan was created.
  ///
  /// While an inspection observer is attached, controllers resolve each new
  /// plan ahead of playback, releasing sync barriers the way playback would,
  /// so estimates match the actual durations unless the plan is interrupted.
  /// Only tracks started together are waited for at barriers. Entries stay
  /// `null` for simulations that do not settle within a day.
  final List<Duration?> estimatedStepDurations;

  /// The resolved segments of this plan, oldest first, on the slot-local
  /// axis. Resolution can run ahead of [playhead].
  final List<PlaybackSegment> segments;

  /// Once a looping plan repeats exactly, the length of one repetition.
  ///
  /// Segments starting at [loopRepeatStart] or later then repeat forever with
  /// this period and are not resolved again.
  final Duration? loopPeriod;

  /// Where the repeating part of a looping plan starts, when [loopPeriod] is
  /// set.
  final Duration? loopRepeatStart;
}

/// One resolved step of a [TrackPlayback].
@experimental
@immutable
class PlaybackSegment {
  /// Creates a resolved segment.
  const PlaybackSegment({
    required this.stepIndex,
    required this.direction,
    required this.cycle,
    required this.start,
    required this.end,
  });

  /// The index into [TrackPlayback.steps] this segment plays.
  final int stepIndex;

  /// `1` while playing forward, `-1` on a pingPong reverse pass.
  final int direction;

  /// The loop cycle this segment belongs to.
  final int cycle;

  /// When the segment starts, on the slot-local axis.
  final Duration start;

  /// When the segment is over on the timeline: when the next segment starts,
  /// or for the last one when it settles. `null` while that isn't known
  /// yet.
  final Duration? end;
}

/// Read-only playback inspection for [TrackController].
@experimental
extension TrackControllerInspection on TrackController {
  /// Builds a snapshot of the controller's current playback state.
  ///
  /// This copies only the small plan and timing lists, so inspectors may call
  /// it from a controller listener on every tick.
  PlaybackSnapshot inspectPlayback() => internalInspectPlayback();

  /// The controller-local playback rate used by inspection tooling.
  ///
  /// A value of `0.25` runs this controller at quarter speed without changing
  /// Flutter's global time dilation or affecting unrelated animations.
  double get playbackSpeed => internalPlaybackSpeed;

  /// Changes the controller-local playback rate.
  set playbackSpeed(double value) => internalPlaybackSpeed = value;

  /// Chooses motions that replace the authored ones in future playback.
  ///
  /// Called with each track when a plan starts. A returned motion replaces
  /// the motion of that track's target steps (`TrackStep.to` and
  /// `TrackStep.at`); null keeps the authored motions. Plans already playing
  /// are not affected.
  Motion? Function(Track<Object> track)? get motionOverride =>
      internalMotionOverride;

  set motionOverride(Motion? Function(Track<Object> track)? value) =>
      internalMotionOverride = value;

  /// Whether the controller's ticker is muted, such as by a
  /// `TickerMode(enabled: false)` above the widget that provides its vsync.
  ///
  /// A muted controller keeps its playback state but does not advance until
  /// its ticker is unmuted.
  bool get isMuted => internalIsMuted;

  /// Whether inspection tools show this controller.
  ///
  /// Reads the controller's own setting, else the nearest
  /// `MotorInspectionScope` of the builder that created it, else true.
  /// Setting null goes back to the scope. Only kept while a tool is
  /// attached.
  bool get inspectable => MotorInspectionRegistry.inspectableOf(this);

  set inspectable(bool? value) =>
      MotorInspectionRegistry.setInspectable(this, value);

  /// The group inspection tools show this controller in, if any.
  ///
  /// Resolved like [inspectable].
  String? get inspectionGroup => MotorInspectionRegistry.groupOf(this);

  set inspectionGroup(String? value) =>
      MotorInspectionRegistry.setGroup(this, value);

  /// What created this controller, when motor's builder widgets created it:
  /// the builder's `Element`. Recorded only in debug builds while an
  /// inspection observer is attached.
  Object? get debugCreator => MotorInspectionRegistry.creatorOf(this);
}

/// Inspection settings for [MotionController], forwarded to the track
/// controller inside it.
@experimental
extension MotionControllerInspection<T extends Object> on MotionController<T> {
  /// See [TrackControllerInspection.inspectable].
  bool get inspectable => internalInnerController.inspectable;

  set inspectable(bool? value) => internalInnerController.inspectable = value;

  /// See [TrackControllerInspection.inspectionGroup].
  String? get inspectionGroup => internalInnerController.inspectionGroup;

  set inspectionGroup(String? value) =>
      internalInnerController.inspectionGroup = value;
}
