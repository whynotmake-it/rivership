import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';
import 'package:motor/src/controllers/track_controller.dart'
    show TrackController;
import 'package:motor/src/motion.dart';
import 'package:motor/src/motion_converter.dart';
import 'package:motor/src/track_step.dart';

/// Identity for a single animated property (e.g. a panel's size or a tint).
///
/// A controller tracks values per [Track], keyed by object identity, so
/// declare tracks as top-level or `static final` variables and reuse the same
/// instance. The identity is the object reference itself — editing fields like
/// [initial] during hot reload keeps the same track.
class Track<T extends Object> {
  /// Creates a track with a [converter] and optional [initial] value.
  ///
  /// If [motion] is provided, it becomes the default motion for steps on this
  /// track that don't specify their own motion.
  ///
  /// {@template Track.initial}
  /// [initial] is the resting value of this track before anything plays. It is
  /// optional: when a controller first needs a value for this track and no
  /// `from` override, prior value, or [initial] is available, the track falls
  /// back to a zero-filled value whose dimensionality matches the first
  /// concrete target (`TrackStep.to`/`TrackStep.at`) of the animation being played.
  /// {@endtemplate}
  Track(
    this.converter, {
    this.initial,
    this.motion,
    this.debugLabel,
  }) : motionPerDimension = null;

  /// Creates a track whose default motion differs per normalized dimension.
  ///
  /// [motionPerDimension] becomes the per-dimension default for steps on this
  /// track that don't specify their own motion.
  ///
  /// {@macro Track.initial}
  Track.motionPerDimension(
    this.converter, {
    required this.motionPerDimension,
    this.initial,
    this.debugLabel,
  }) : motion = null;

  /// A human-readable name shown by optional inspection tools.
  final String? debugLabel;

  /// Converts track values to and from normalized dimensions.
  final MotionConverter<T> converter;

  /// The default resting value for this track, if any.
  ///
  /// {@macro Track.initial}
  final T? initial;

  /// The default motion for steps on this track.
  ///
  /// When a [TrackStep.to] or [TrackStep.at] omits its motion, this value is
  /// used
  /// as the fallback at playback time. Mutually exclusive with
  /// [motionPerDimension].
  final Motion? motion;

  /// The per-dimension default motions for steps on this track.
  ///
  /// When a step omits its motion, these are used as the fallback at playback
  /// time. Mutually exclusive with [motion].
  final List<Motion>? motionPerDimension;

  /// Creates a single-step animation to [value].
  ///
  /// Provide either a single [motion] or [motionPerDimension] (not both). If
  /// neither is given, the track's [Track.motion] / [Track.motionPerDimension]
  /// default is used at playback time.
  ///
  /// {@template Track.fromVelocity}
  /// [from] starts the animation from a different value (jumping to it first),
  /// and [withVelocity] seeds the starting velocity without moving the value.
  /// {@endtemplate}
  TrackAnimation<T> to(
    T value, {
    Motion? motion,
    List<Motion>? motionPerDimension,
    T? from,
    T? withVelocity,
  }) {
    return TrackAnimation._(
      this,
      [
        TrackStep.to(
          value,
          motion: motion,
          motionPerDimension: motionPerDimension,
        ),
      ],
      from: from,
      withVelocity: withVelocity,
    );
  }

  /// Creates a multi-step animation for this track.
  ///
  /// {@macro Track.fromVelocity}
  TrackAnimation<T> call(
    List<TrackStep<T>> steps, {
    T? from,
    T? withVelocity,
  }) =>
      TrackAnimation._(this, steps, from: from, withVelocity: withVelocity);

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
  ///
  /// {@macro Track.fromVelocity}
  TrackAnimation<T> free(
    FreeMotion motion, {
    T? from,
    T? withVelocity,
  }) {
    return TrackAnimation._(
      this,
      [TrackStep.free(motion: motion)],
      from: from,
      withVelocity: withVelocity,
    );
  }

  /// Creates a [TrackAnimation] from a list of steps whose static type may
  /// have been erased to `TrackStep<Object>`.
  ///
  /// [StepSync] barriers (which carry no value) are re-wrapped as
  /// `StepSync<T>` so the resulting list has a uniform runtime type.
  /// All other steps must already be `TrackStep<T>` at runtime.
  @internal
  TrackAnimation<T> animationFromUntypedSteps(
    List<TrackStep<Object>> steps, {
    T? from,
    T? withVelocity,
  }) {
    final typed = <TrackStep<T>>[
      for (final step in steps)
        if (step case StepSync(:final token))
          StepSync<T>(token: token)
        else
          step as TrackStep<T>,
    ];
    return TrackAnimation._(
      this,
      typed,
      from: from,
      withVelocity: withVelocity,
    );
  }
}

/// A value snapshot for a [Track].
///
/// {@template TrackValue}
/// Used as initial-value overrides in [TrackController.set] and as per-track
/// initial velocities. The same type is reused for `withVelocity:` lists,
/// where its [value] is interpreted as a velocity.
///
/// {@endtemplate}
// ignore: deprecated_member_use
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
///
/// Besides the [steps] to play, an animation can carry a per-track [from]
/// override (jump to this value before animating) and an initial
/// [withVelocity]. `loop` is intentionally not part of an animation — it is a
/// per-clip concern owned by the timeline or the playback call site.
// ignore: deprecated_member_use
class TrackAnimation<T extends Object> with EquatableMixin {
  /// Creates an animation for [track] using [steps].
  TrackAnimation._(
    this.track,
    this.steps, {
    this.from,
    this.withVelocity,
  });

  /// The track this animation targets.
  final Track<T> track;

  /// The steps to play for [track].
  final List<TrackStep<T>> steps;

  /// Optional value to jump to before animating.
  final T? from;

  /// Optional starting velocity for the animation.
  final T? withVelocity;

  /// Rebuilds target-based steps with [motion] while preserving value types.
  @internal
  TrackAnimation<T> withMotionOverride(Motion motion) => TrackAnimation._(
        track,
        [
          for (final step in steps)
            switch (step) {
              StepTo<T>(:final value) => TrackStep.to(
                  value,
                  motion: motion,
                ),
              StepAt<T>(:final at, :final value) => TrackStep.at(
                  at,
                  value,
                  motion: motion,
                ),
              _ => step,
            },
        ],
        from: from,
        withVelocity: withVelocity,
      );

  /// Resolves the value this animation should start from when the controller
  /// has no existing value for [track].
  ///
  /// Resolution order: [from] -> [Track.initial] -> a zero-filled value whose
  /// dimensionality matches this animation's first concrete target
  /// (`TrackStep.to`/`TrackStep.at`). Throws if none of these can supply a value.
  T resolveStartValue() {
    if (from case final value?) return value;
    if (track.initial case final value?) return value;
    if (_firstTargetDimensions case final dimensions?) {
      return track.converter.denormalize(List<double>.filled(dimensions, 0));
    }
    assert(
      false,
      'Track has no initial value, no `from`, and the animation has no '
      'concrete target (TrackStep.to/TrackStep.at) to infer a starting value from. '
      'Provide Track.initial or a from: value.',
    );
    throw StateError(
      'Cannot resolve a starting value for a track with no initial value, '
      'no `from`, and no concrete target.',
    );
  }

  /// The dimension count of this animation's first concrete target, or null
  /// when no step carries a value.
  int? get _firstTargetDimensions {
    for (final step in steps) {
      if (step is StepTo<T>) {
        return track.converter.normalize(step.value).length;
      }
      if (step is StepAt<T>) {
        return track.converter.normalize(step.value).length;
      }
    }
    return null;
  }

  @override
  List<Object?> get props => [track, ...steps, from, withVelocity];
}
