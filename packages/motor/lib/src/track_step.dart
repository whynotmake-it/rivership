import 'package:flutter/foundation.dart';
import 'package:motor/src/controllers/track_controller.dart';
import 'package:motor/src/motion.dart';
import 'package:motor/src/track_phase_timeline.dart';

/// A single instruction in a track animation.
///
/// Steps compare by value. Their motions compare by movement, so steps with
/// motions of different classes that move the same are equal.
@immutable
sealed class TrackStep<T extends Object> {
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
  /// at [at]. The preceding step always plays at its own speed; this step's
  /// motion adapts to the time left:
  ///
  /// - If the preceding step ends at least the motion's natural duration
  ///   before [at], the motion starts when that step ends and slows down to
  ///   fill the gap.
  /// - Otherwise the preceding step is cut short so that the motion runs for
  ///   its natural duration and ends at [at]. The cut never happens before
  ///   that step started; if there is not enough time, the motion is
  ///   compressed, and with no time at all [value] is reached instantly. A
  ///   motion without a known duration stretches whenever the preceding step
  ///   ends before [at], and otherwise starts when that step starts.
  ///
  /// Only the step immediately before is ever cut, and it can be another
  /// [TrackStep.at]: the later keyframe wins. [value] arrives late only when
  /// this step cannot start before [at], for example because a preceding sync
  /// barrier is released after [at], or because [at] had already passed when
  /// the preceding step started (that step is then skipped). [at] must not be
  /// earlier than the total duration of preceding holds (asserted).
  ///
  /// ```dart
  /// track([
  ///   // Takes 200 ms, leaving time before the keyframe.
  ///   .to(1, motion: .linear(const Duration(milliseconds: 200))),
  ///   // Its 300 ms curve starts at 200 ms and slows down to land at 1 s.
  ///   .at(
  ///     const Duration(seconds: 1),
  ///     0,
  ///     motion: .curved(const Duration(milliseconds: 300), Curves.easeOut),
  ///   ),
  /// ]);
  /// ```
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
  /// so the tracks continue in lockstep. Each track waits at rest, so the
  /// step after the barrier starts from rest, without the velocity the step
  /// before it ended with.
  ///
  /// {@template motor.TrackStep.sync.arrival}
  /// A track arrives once the step before the barrier has finished. For a
  /// spring, that means fully settled, with distance and velocity under its
  /// tolerance, which often takes 2–3× its nominal duration. To sync on the
  /// visual arrival, give that step a fixed duration (`motion.scaleTo(d)`),
  /// use a curve, or place the arrival with [TrackStep.at].
  /// {@endtemplate}
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
  /// with [motion]; if both are null the track default is used. Steps compare
  /// by this list, so don't modify it after passing it in.
  final List<Motion>? motionPerDimension;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StepTo<T> &&
          other.runtimeType == runtimeType &&
          other.value == value &&
          other.motion == motion &&
          listEquals(other.motionPerDimension, motionPerDimension);

  @override
  int get hashCode => Object.hash(
        runtimeType,
        value,
        motion,
        _hashList(motionPerDimension),
      );

  @override
  String toString() => '${objectRuntimeType(this, 'StepTo')}($value, '
      '${_describeMotion(motion, motionPerDimension)})';
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
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StepFree<T> &&
          other.runtimeType == runtimeType &&
          other.motion == motion;

  @override
  int get hashCode => Object.hash(runtimeType, motion);

  @override
  String toString() => '${objectRuntimeType(this, 'StepFree')}($motion)';
}

/// A step that holds the current value.
@immutable
class StepHold<T extends Object> extends TrackStep<T> {
  /// Creates a hold step.
  const StepHold(this.duration);

  /// The duration to hold.
  final Duration duration;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StepHold<T> &&
          other.runtimeType == runtimeType &&
          other.duration == duration;

  @override
  int get hashCode => Object.hash(runtimeType, duration);

  @override
  String toString() => '${objectRuntimeType(this, 'StepHold')}($duration)';
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
  /// with [motion]; if both are null the track default is used. Steps compare
  /// by this list, so don't modify it after passing it in.
  final List<Motion>? motionPerDimension;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StepAt<T> &&
          other.runtimeType == runtimeType &&
          other.at == at &&
          other.value == value &&
          other.motion == motion &&
          listEquals(other.motionPerDimension, motionPerDimension);

  @override
  int get hashCode => Object.hash(
        runtimeType,
        at,
        value,
        motion,
        _hashList(motionPerDimension),
      );

  @override
  String toString() => '${objectRuntimeType(this, 'StepAt')}($at, $value, '
      '${_describeMotion(motion, motionPerDimension)})';
}

/// A synchronization barrier that keeps sibling tracks aligned.
///
/// When a track reaches a [StepSync] during live playback, it holds its
/// current value until every other active track with the same [token] (by
/// `==`) also reaches a matching sync step. The [TrackController] then
/// releases them simultaneously, at the moment the last one arrived, so they
/// continue in unison independent of the frame rate. In a looping plan the
/// barrier holds every cycle: a track that comes around again waits for the
/// others to reach the barrier of that same cycle.
///
/// A track waits at rest, so the step after the barrier starts from rest,
/// without the velocity the step before it ended with. This holds for phase
/// boundaries in a [TrackPhaseTimeline] too.
///
/// {@macro motor.TrackStep.sync.arrival}
///
/// Tracks stopped or redirected before reaching their barrier are removed from
/// the barrier's participant set. The remaining tracks keep waiting for each
/// other.
///
/// Add one via [TrackStep.sync] to coordinate otherwise-independent tracks, for
/// example to make a slower and a faster track meet before the next move.
/// [TrackPhaseTimeline] inserts these automatically at phase boundaries.
///
/// Scrubbing with [TrackController.scrubTo] resolves barriers the same way,
/// so it shows what playback would show at that time.
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
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StepSync<T> &&
          other.runtimeType == runtimeType &&
          other.token == token;

  @override
  int get hashCode => Object.hash(runtimeType, token);

  @override
  String toString() => '${objectRuntimeType(this, 'StepSync')}($token)';
}

int? _hashList(List<Object?>? list) =>
    list == null ? null : Object.hashAll(list);

String _describeMotion(Motion? motion, List<Motion>? motionPerDimension) =>
    switch ((motion, motionPerDimension)) {
      (final motion?, _) => 'motion: $motion',
      (_, final perDimension?) => 'motionPerDimension: $perDimension',
      _ => 'track motion',
    };
