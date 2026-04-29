import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart';
import 'package:motor/src/motion.dart';

/// A single instruction in a track animation.
@immutable
sealed class Step<T extends Object> with EquatableMixin {
  /// Creates a step.
  const Step();

  /// Animates to [value] using a target-based [motion].
  ///
  /// If [motion] is omitted, the track's default motion is used at playback
  /// time. An assertion fires if no motion is available from either source.
  const factory Step.to(
    T value, {
    Motion? motion,
  }) = StepTo<T>;

  /// Runs a self-directed free [motion].
  const factory Step.free({
    required FreeMotion motion,
  }) = StepFree<T>;

  /// Holds the current value for [duration].
  const factory Step.hold(Duration duration) = StepHold<T>;

  /// Starts an animation that reaches [value] at absolute time [at].
  ///
  /// If [motion] is omitted, the track's default motion is used at playback
  /// time. An assertion fires if no motion is available from either source.
  const factory Step.at(
    Duration at,
    T value, {
    Motion? motion,
  }) = StepAt<T>;

  /// A synchronization barrier.
  ///
  /// When playback reaches this step, the track pauses until all other active
  /// tracks that share the same [token] (by `==`) also reach their sync step.
  /// The [TrackController] then releases them together.
  const factory Step.sync({required Object token}) = SyncStep<T>;
}

/// A step that animates toward [value].
@immutable
class StepTo<T extends Object> extends Step<T> {
  /// Creates a target step.
  const StepTo(
    this.value, {
    this.motion,
  });

  /// The target value.
  final T value;

  /// The motion used to reach [value], or null to use the track default.
  final Motion? motion;

  @override
  List<Object?> get props => [value, motion];
}

/// A step that runs a self-directed motion.
@immutable
class StepFree<T extends Object> extends Step<T> {
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
class StepHold<T extends Object> extends Step<T> {
  /// Creates a hold step.
  const StepHold(this.duration);

  /// The duration to hold.
  final Duration duration;

  @override
  List<Object?> get props => [duration];
}

/// A step that starts at an absolute time.
@immutable
class StepAt<T extends Object> extends Step<T> {
  /// Creates an absolute-time target step.
  const StepAt(
    this.at,
    this.value, {
    this.motion,
  });

  /// The absolute time from the start of the track animation.
  final Duration at;

  /// The target value.
  final T value;

  /// The motion used to reach [value], or null to use the track default.
  final Motion? motion;

  @override
  List<Object?> get props => [at, value, motion];
}

/// A synchronization point inserted at phase boundaries.
///
/// When a track reaches a [SyncStep] during live playback, it enters a
/// `waitForSync` state and holds its current value until all other active
/// tracks with the same [token] also reach their sync step. The
/// [TrackController] then releases them simultaneously so the next phase
/// begins in unison.
///
/// During seek operations, sync steps are treated as zero-duration holds
/// and passed through freely.
///
/// This class is an internal implementation detail of [TrackPhaseTimeline]
/// and is not part of the public API.
@internal
@immutable
class SyncStep<T extends Object> extends Step<T> {
  /// Creates a sync step with a [token] for grouped release.
  const SyncStep({required this.token});

  /// The token used to group sync steps across tracks.
  ///
  /// All tracks waiting on a sync step with the same token (by `==`) are
  /// released together once every participating track has reached its barrier.
  final Object token;

  @override
  List<Object?> get props => [token];
}
