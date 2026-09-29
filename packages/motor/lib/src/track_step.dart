import 'package:flutter/foundation.dart';
import 'package:motor/src/controllers/track_controller.dart';
import 'package:motor/src/motion.dart';
import 'package:motor/src/settling_simulation.dart';
import 'package:motor/src/track_phase_timeline.dart';

/// What the step after a [TrackStep.to] or [TrackStep.free] waits for before
/// it starts.
///
/// ```dart
/// .to(1, motion: m)                   // until: .settled
/// .to(1, motion: m, until: .duration) // the next step takes over sooner
/// ```
///
/// Either way the motion plays out: the timeline never cuts it short, unless
/// a [TrackStep.at] follows. The controller call's `MotionFuture.ended`
/// completes at the last step's duration either way.
enum WaitUntil {
  /// Once the step has settled: at rest and exactly on its target. The next
  /// step starts from rest. This is the default, as in 1.x and in Motion,
  /// anime.js and Compose.
  settled,

  /// Once the step has ended: its motion's duration ([Motion.duration], a
  /// spring's perceptual duration) has passed. The next step takes over the
  /// current value and velocity while a spring is still settling, as
  /// SwiftUI's `PhaseAnimator` moves between phases. A motion without a
  /// duration still waits to settle.
  duration,
}

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
  /// The next step starts once the move has settled
  /// ([SettlingSimulation.settlesAt]), from rest, as in 1.x and in Motion,
  /// anime.js and Compose.
  ///
  /// Pass `until: .duration` ([WaitUntil.duration]) to start the next step
  /// once this one has ended instead, after its motion's [Motion.duration]
  /// (a spring's perceptual duration): it takes over the current value and
  /// velocity while a spring is still settling. That mirrors SwiftUI's
  /// `PhaseAnimator`, which moves to the next phase at the spring's duration
  /// and keeps its velocity. A motion without a duration always waits to
  /// settle.
  ///
  /// Provide either a single [motion] (applied to every dimension) or
  /// [motionPerDimension] (one motion per normalized dimension), not both. If
  /// neither is given, the track's default motion is used at playback time. An
  /// assertion fires if no motion is available from any source.
  const factory TrackStep.to(
    T value, {
    Motion? motion,
    List<Motion>? motionPerDimension,
    WaitUntil until,
  }) = StepTo<T>;

  /// Runs a self-directed free [motion]. The next step starts once it has
  /// come to rest.
  ///
  /// Pass `until: .duration` ([WaitUntil.duration]) to start the next step
  /// once the motion's [FreeMotion.duration] has passed instead, if it has
  /// one, taking over its value and velocity, as with [TrackStep.to].
  const factory TrackStep.free({
    required FreeMotion motion,
    WaitUntil until,
  }) = StepFree<T>;

  /// Waits for [duration] before the next step.
  ///
  /// It holds the current value. A spring before it with `until: .duration`
  /// keeps settling meanwhile.
  const factory TrackStep.hold(Duration duration) = StepHold<T>;

  /// A keyframe that targets [value] at absolute time [at].
  ///
  /// [at] is measured from the start of the track animation (and from the
  /// start of the current cycle when looping), and [value] is reached exactly
  /// at [at]. The preceding step always plays at its own speed; this step's
  /// motion adapts to the time left:
  ///
  /// - If this step can start at least the motion's natural length before
  ///   [at], it starts then and slows down to fill the gap. The natural
  ///   length is the motion's [Motion.duration], or, if it has none, when
  ///   its move from where the preceding step leaves off settles. A spring
  ///   is cut at its duration so that it lands.
  /// - Otherwise the preceding step is cut short so that the motion runs its
  ///   natural length and arrives at [at]. This is the only case where a
  ///   step cuts a motion short. The cut never happens before that step
  ///   started; if there is not enough time, the motion is compressed, and
  ///   with no time at all [value] is reached instantly. A motion that never
  ///   settles stretches whenever this step can start before [at], and
  ///   otherwise starts when the preceding step starts.
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
  /// so the tracks continue in lockstep. While a track waits, a spring before
  /// it with `until: .duration` keeps settling, and the step after the
  /// barrier starts from where it is at the release.
  ///
  /// {@template motor.TrackStep.sync.arrival}
  /// A track arrives once the step before the barrier has settled, or, with
  /// `until: .duration`, once it has ended, after its motion's
  /// [Motion.duration], while a spring keeps settling as it waits.
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
    this.until = WaitUntil.settled,
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

  /// When the next step starts: once this one has settled
  /// ([WaitUntil.settled], the default), or once it has ended, after its
  /// motion's [Motion.duration] ([WaitUntil.duration]).
  final WaitUntil until;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StepTo<T> &&
          other.runtimeType == runtimeType &&
          other.value == value &&
          other.motion == motion &&
          listEquals(other.motionPerDimension, motionPerDimension) &&
          other.until == until;

  @override
  int get hashCode => Object.hash(
        runtimeType,
        value,
        motion,
        _hashList(motionPerDimension),
        until,
      );

  @override
  String toString() => '${objectRuntimeType(this, 'StepTo')}($value, '
      '${_describeMotion(motion, motionPerDimension)}'
      '${until == WaitUntil.duration ? ', until: duration' : ''})';
}

/// A step that runs a self-directed motion.
@immutable
class StepFree<T extends Object> extends TrackStep<T> {
  /// Creates a free-motion step.
  const StepFree({
    required this.motion,
    this.until = WaitUntil.settled,
  });

  /// The free motion to run.
  final FreeMotion motion;

  /// When the next step starts: once this one has come to rest
  /// ([WaitUntil.settled], the default), or once it has ended, after the
  /// motion's [FreeMotion.duration] ([WaitUntil.duration]).
  final WaitUntil until;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StepFree<T> &&
          other.runtimeType == runtimeType &&
          other.motion == motion &&
          other.until == until;

  @override
  int get hashCode => Object.hash(runtimeType, motion, until);

  @override
  String toString() => '${objectRuntimeType(this, 'StepFree')}($motion'
      '${until == WaitUntil.duration ? ', until: duration' : ''})';
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
/// By default the step before the barrier has settled, so a track waits at
/// rest and the step after the barrier starts from rest. If that step has
/// `until: .duration`, its spring keeps settling while the track waits, and
/// the step after the barrier takes over from where it is at the release.
/// This holds for phase boundaries in a [TrackPhaseTimeline] too.
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
