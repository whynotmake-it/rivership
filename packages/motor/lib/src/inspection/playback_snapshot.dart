import 'package:flutter/animation.dart';
import 'package:meta/meta.dart';
import 'package:motor/src/controllers/track_controller.dart';
import 'package:motor/src/loop_mode.dart';
import 'package:motor/src/track.dart';
import 'package:motor/src/track_step.dart';

/// A point-in-time view of everything a [TrackController] is playing.
@immutable
class PlaybackSnapshot {
  /// Creates an immutable playback snapshot.
  PlaybackSnapshot({
    required this.revision,
    required this.tickerElapsed,
    required this.status,
    required List<TrackPlayback> tracks,
  }) : tracks = List.unmodifiable(tracks);

  /// Monotonic counter that changes whenever the controller's plan changes.
  final int revision;

  /// The controller ticker's elapsed time, or `null` while it is stopped.
  final Duration? tickerElapsed;

  /// The controller's current animation status.
  final AnimationStatus status;

  /// Playback details for every slot that still retains a playback plan.
  final List<TrackPlayback> tracks;
}

/// One track's live, read-only playback state.
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
    required this.cycle,
    required this.isWaitingForSync,
    required this.syncToken,
    required this.startOffset,
    required this.playhead,
    required this.cycleStart,
    required List<Duration?> stepStarts,
    required List<Duration?> stepDurations,
  })  : steps = List.unmodifiable(steps),
        stepStarts = List.unmodifiable(stepStarts),
        stepDurations = List.unmodifiable(stepDurations);

  /// The identity of the track represented by this snapshot.
  final Track<Object> track;

  /// The actual running plan, including a synthetic loop-return step when
  /// [hasSyntheticReturnStep] is true.
  final List<TrackStep<Object>> steps;

  /// Whether the final entry in [steps] was synthesized for [LoopMode.loop].
  final bool hasSyntheticReturnStep;

  /// The loop mode used by this track's running plan.
  final LoopMode loop;

  /// The active step index, or `-1` when playback has completed.
  final int currentStepIndex;

  /// The current direction: `1` while forward and `-1` while reversing.
  final int direction;

  /// The number of loop boundaries crossed by this playback.
  final int cycle;

  /// Whether this track is currently held at a synchronization barrier.
  final bool isWaitingForSync;

  /// The active synchronization token, or `null` when not waiting.
  final Object? syncToken;

  /// The track's start position on the controller ticker axis.
  final Duration startOffset;

  /// The latest elapsed position on this track's slot-local axis.
  final Duration playhead;

  /// The slot-local origin of the current loop or ping-pong leg.
  ///
  /// Subtract this from [playhead] to render time within the current leg.
  final Duration cycleStart;

  /// Actual starts for forward steps on the slot-local axis.
  ///
  /// An entry remains `null` until that step is reached in the current cycle.
  /// For a synchronization step, the following entry is the recorded barrier
  /// release moment.
  final List<Duration?> stepStarts;

  /// Actual durations occupied by forward steps, or `null` until recorded.
  final List<Duration?> stepDurations;
}

/// Read-only playback inspection for [TrackController].
extension TrackControllerInspection on TrackController {
  /// Builds a snapshot of the controller's current playback state.
  ///
  /// This copies only the small plan and timing lists, so inspectors may call
  /// it from a controller listener on every tick.
  PlaybackSnapshot inspectPlayback() => internalInspectPlayback();

  /// Monotonic counter that changes whenever the playing plan changes.
  int get playbackRevision => internalPlaybackRevision;
}
