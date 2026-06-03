import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';
import 'package:motor/src/controllers/track_controller.dart'
    show TrackController;
import 'package:motor/src/motion.dart';
import 'package:motor/src/motion_converter.dart';
import 'package:motor/src/step.dart';
import 'package:motor/src/track_timeline.dart' show TrackTimeline;

/// Identity for a single animated property (e.g. a panel's size or a tint).
///
/// A controller tracks values per [Track], keyed by object identity, so
/// declare tracks as top-level or `static final` variables and reuse the same
/// instance. The identity is the object reference itself — editing fields like
/// [origin] during hot reload keeps the same track.
class Track<T extends Object> {
  /// Creates a track with a [converter] and declared [origin].
  ///
  /// If [motion] is provided, it becomes the default motion for steps on this
  /// track that don't specify their own motion.
  Track(
    this.converter, {
    required this.origin,
    this.motion,
  });

  /// Converts track values to and from normalized dimensions.
  final MotionConverter<T> converter;

  /// The default resting value for this track.
  ///
  /// Will be used by any motion controllers that don't have a set initial
  /// value for this track.
  final T origin;

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

  /// Creates a value snapshot for this track.
  ///
  /// {@macro TrackValue}
  TrackValue<T> value(T value) => TrackValue._(this, value);

  /// Creates a velocity snapshot for this track.
  ///
  /// This is sugar for [value] that reads better in `withVelocity:` lists:
  /// the snapshot's [TrackValue.value] is interpreted as a velocity.
  TrackValue<T> velocity(T velocity) => TrackValue._(this, velocity);

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
  @internal
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

/// A value snapshot for a [Track].
///
/// {@template TrackValue}
/// Used as initial-value overrides in [TrackTimeline.from] and
/// [TrackController.set]. The same type is reused for `withVelocity:` lists,
/// where its [value] is interpreted as a velocity.
///
/// {@endtemplate}
class TrackValue<T extends Object> with EquatableMixin {
  /// Creates a value snapshot for [track].
  TrackValue._(this.track, this.value);

  /// The track this snapshot applies to.
  final Track<T> track;

  /// The value for [track] (or, in `withVelocity:` lists, the velocity).
  final T value;

  @override
  List<Object?> get props => [track, value];
}

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
