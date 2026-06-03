import 'package:equatable/equatable.dart';
import 'package:motor/src/motion.dart';
import 'package:motor/src/motion_converter.dart';
import 'package:motor/src/step.dart';

/// Identity token for a logical animated property.
///
/// Declare tracks as top-level or static `final` variables. Identity is the
/// Dart object reference, so changing [zero] during hot reload preserves
/// the same track identity.
class Track<T extends Object> {
  /// Creates a track with a [converter] and declared [zero].
  ///
  /// If [motion] is provided, it becomes the default motion for steps on this
  /// track that don't specify their own motion.
  Track(
    this.converter, {
    required this.zero,
    this.motion,
  });

  /// Converts track values to and from normalized dimensions.
  final MotionConverter<T> converter;

  /// The fallback initial value for this track.
  final T zero;

  /// The default motion for steps on this track.
  ///
  /// When a [Step.to] or [Step.at] omits its motion, this value is used
  /// as the fallback at playback time.
  final Motion? motion;

  /// Creates a single-step animation to [value].
  ///
  /// If [motion] is omitted, the track's [Track.motion] default is used at
  /// playback time.
  TrackAnimation<T> to(
    T value, {
    Motion? motion,
  }) {
    return TrackAnimation._(this, [Step.to(value, motion: motion)]);
  }

  /// Creates a multi-step animation for this track.
  TrackAnimation<T> call(List<Step<T>> steps) => TrackAnimation._(this, steps);

  /// Creates a value snapshot for this track, optionally with [velocity].
  TrackValue<T> value(T value, {T? velocity}) =>
      TrackValue(this, value, velocity: velocity);

  /// Creates a free-motion animation for this track.
  TrackAnimation<T> free(FreeMotion motion) {
    return TrackAnimation._(this, [Step.free(motion: motion)]);
  }

  /// Creates a [TrackAnimation] from a list of steps whose static type may
  /// have been erased to `Step<Object>`.
  ///
  /// [SyncStep] barriers (which carry no value) are re-wrapped as
  /// `SyncStep<T>` so the resulting list has a uniform runtime type.
  /// All other steps must already be `Step<T>` at runtime.
  TrackAnimation<T> animationFromUntypedSteps(List<Step<Object>> steps) {
    final typed = <Step<T>>[
      for (final step in steps)
        if (step case SyncStep(:final token))
          SyncStep<T>(token: token)
        else
          step as Step<T>,
    ];
    return TrackAnimation._(this, typed);
  }
}

/// A value (and optional velocity) snapshot for a [Track].
///
/// Used as initial-value overrides in `TrackTimeline.from` and
/// `TrackController.set`.
class TrackValue<T extends Object> with EquatableMixin {
  /// Creates a value snapshot that starts [track] from [value].
  TrackValue(this.track, this.value, {this.velocity});

  /// The track this snapshot applies to.
  final Track<T> track;

  /// The value for [track].
  final T value;

  /// Optional initial velocity for [track].
  final T? velocity;

  @override
  List<Object?> get props => [track, value, velocity];
}

/// Backwards-compatible alias.
@Deprecated('Use TrackValue instead')
typedef TrackFrom<T extends Object> = TrackValue<T>;

/// An animation instruction for a single [Track].
class TrackAnimation<T extends Object> with EquatableMixin {
  /// Creates an animation for [track] using [steps].
  TrackAnimation._(this.track, this.steps);

  /// The track this animation targets.
  final Track<T> track;

  /// The steps to play for [track].
  final List<Step<T>> steps;

  @override
  List<Object?> get props => [track, ...steps];
}
