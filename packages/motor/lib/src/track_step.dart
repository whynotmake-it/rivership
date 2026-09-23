import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:motor/src/controllers/track_controller.dart';
import 'package:motor/src/motion.dart';
import 'package:motor/src/track_phase_timeline.dart';

/// A single instruction in a track animation.
@immutable
// ignore: deprecated_member_use
sealed class TrackStep<T extends Object> with EquatableMixin {
  /// Creates a step.
  const TrackStep();

  /// Animates to [value] using a target-based [motion].
  ///
  /// Provide either a single [motion] (applied to every dimension) or
  /// [motionPerDimension] (one motion per normalized dimension), not both. If
  /// neither is given, the track's default motion is used at playback time. An
  /// assertion fires if no motion is available from any source.
  const factory TrackStep.to(
    T value, {
    Motion? motion,
    List<Motion>? motionPerDimension,
  }) = StepTo<T>;

  /// Runs a self-directed free [motion].
  const factory TrackStep.free({
    required FreeMotion motion,
  }) = StepFree<T>;

  /// Holds the current value for [duration].
  const factory TrackStep.hold(Duration duration) = StepHold<T>;

  /// A keyframe that targets [value] at absolute time [at].
  ///
  /// [at] is measured from the start of the track animation (and from the
  /// start of the current cycle when looping), and [value] is reached exactly
  /// at [at]:
  ///
  /// - If the preceding steps finish before [at], the motion is time-scaled
  ///   to fill the gap.
  /// - If the preceding step would still be running at [at], it is cut short
  ///   so that the motion runs for its natural duration and ends at [at]. The
  ///   cut never happens before that step started; if there is not enough
  ///   time, the motion is compressed. A motion without a known duration
  ///   starts right when the preceding step starts.
  ///
  /// [value] arrives late only when this step cannot start before [at], for
  /// example because a preceding sync barrier is released after [at]. [at]
  /// must not be earlier than the total duration of preceding holds
  /// (asserted).
  ///
  /// Provide either a single [motion] (applied to every dimension) or
  /// [motionPerDimension] (one motion per normalized dimension), not both. If
  /// neither is given, the track's default motion is used at playback time. An
  /// assertion fires if no motion is available from any source.
  const factory TrackStep.at(
    Duration at,
    T value, {
    Motion? motion,
    List<Motion>? motionPerDimension,
  }) = StepAt<T>;

  /// A synchronization barrier that waits for sibling tracks.
  ///
  /// When playback reaches this step, the track holds its current value until
  /// every other active track that shares the same [token] (by `==`) also
  /// reaches a matching sync step. The controller then releases them together,
  /// so the tracks continue in lockstep.
  ///
  /// Use this to keep independent tracks aligned at key moments without
  /// hand-tuning each track's durations.
  const factory TrackStep.sync({required Object token}) = StepSync<T>;
}

/// A step that animates toward [value].
@immutable
class StepTo<T extends Object> extends TrackStep<T> {
  /// Creates a target step.
  const StepTo(
    this.value, {
    this.motion,
    this.motionPerDimension,
  }) : assert(
          motion == null || motionPerDimension == null,
          'Provide either motion or motionPerDimension, not both.',
        );

  /// The target value.
  final T value;

  /// The motion used to reach [value] in every dimension, or null to use
  /// [motionPerDimension] or the track default.
  final Motion? motion;

  /// Per-dimension motions used to reach [value].
  ///
  /// Each entry drives one normalized dimension of [value]. Mutually exclusive
  /// with [motion]; if both are null the track default is used.
  final List<Motion>? motionPerDimension;

  @override
  List<Object?> get props => [value, motion, motionPerDimension];
}

/// A step that runs a self-directed motion.
@immutable
class StepFree<T extends Object> extends TrackStep<T> {
  /// Creates a free-motion step.
  const StepFree({
    required this.motion,
  });

  /// The free motion to run.
  final FreeMotion motion;

  @override
  List<Object?> get props => [motion];
}

/// A step that holds the current value.
@immutable
class StepHold<T extends Object> extends TrackStep<T> {
  /// Creates a hold step.
  const StepHold(this.duration);

  /// The duration to hold.
  final Duration duration;

  @override
  List<Object?> get props => [duration];
}

/// A step that starts at an absolute time.
@immutable
class StepAt<T extends Object> extends TrackStep<T> {
  /// Creates an absolute-time target step.
  const StepAt(
    this.at,
    this.value, {
    this.motion,
    this.motionPerDimension,
  }) : assert(
          motion == null || motionPerDimension == null,
          'Provide either motion or motionPerDimension, not both.',
        );

  /// The absolute time from the start of the track animation.
  final Duration at;

  /// The target value.
  final T value;

  /// The motion used to reach [value] in every dimension, or null to use
  /// [motionPerDimension] or the track default.
  final Motion? motion;

  /// Per-dimension motions used to reach [value].
  ///
  /// Each entry drives one normalized dimension of [value]. Mutually exclusive
  /// with [motion]; if both are null the track default is used.
  final List<Motion>? motionPerDimension;

  @override
  List<Object?> get props => [at, value, motion, motionPerDimension];
}

/// A synchronization barrier that keeps sibling tracks aligned.
///
/// When a track reaches a [StepSync] during live playback, it holds its
/// current value until every other active track with the same [token] (by
/// `==`) also reaches a matching sync step. The [TrackController] then
/// releases them simultaneously, at the moment the last one arrived, so they
/// continue in unison independent of the frame rate.
///
/// Tracks stopped or redirected before reaching their barrier are removed from
/// the barrier's participant set. The remaining tracks keep waiting for each
/// other.
///
/// Add one via [TrackStep.sync] to coordinate otherwise-independent tracks, for
/// example to make a slower and a faster track meet before the next move.
/// [TrackPhaseTimeline] inserts these automatically at phase boundaries.
///
/// During seek operations, barriers that have not been released yet are
/// treated as zero-duration holds and passed through freely. Barriers that
/// were already released keep their recorded release time, so seeking back
/// shows the timeline as it played.
@immutable
class StepSync<T extends Object> extends TrackStep<T> {
  /// Creates a sync step with a [token] for grouped release.
  const StepSync({required this.token});

  /// The token used to group sync steps across tracks.
  ///
  /// All tracks waiting on a sync step with the same token (by `==`) are
  /// released together once every participating track has reached its barrier.
  final Object token;

  @override
  List<Object?> get props => [token];
}
