import 'package:flutter/foundation.dart' show listEquals, objectRuntimeType;
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
/// instance. The identity is the object reference itself, so editing fields
/// like [initial] during hot reload keeps the same track.
base class Track<T extends Object> {
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
  /// concrete target (`TrackStep.to`/`TrackStep.at`) of the animation being
  /// played.
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
  })  : assert(
          debugCheckDimensions(converter, motionPerDimension!.length),
          'motionPerDimension must match the converter dimensions',
        ),
        motion = null;

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
  /// used as the fallback at playback time. Mutually exclusive with
  /// [motionPerDimension].
  final Motion? motion;

  /// The per-dimension default motions for steps on this track.
  ///
  /// When a step omits its motion, these are used as the fallback at playback
  /// time. Mutually exclusive with [motion].
  final List<Motion>? motionPerDimension;

  /// Creates an animation that plays [steps] on this track, for example
  /// `track([TrackStep.to(1)])`.
  ///
  /// {@template Track.fromVelocity}
  /// [from] starts the animation from a different value (jumping to it first)
  /// and keeps the current velocity, and [withVelocity] seeds the starting
  /// velocity instead, without moving the value.
  /// {@endtemplate}
  ///
  /// {@macro TrackAnimation.delay}
  TrackAnimation<T> call(
    List<TrackStep<T>> steps, {
    T? from,
    T? withVelocity,
    Duration delay = Duration.zero,
  }) =>
      TrackAnimation._(
        this,
        steps,
        from: from,
        withVelocity: withVelocity,
        delay: delay,
      );

  /// Creates a value snapshot for this track, optionally with a [velocity].
  ///
  /// {@macro TrackValue}
  TrackValue<T> value(T value, {T? velocity}) =>
      TrackValue._(this, value, velocity: velocity);

  /// Creates a snapshot that sets only this track's [velocity] and keeps its
  /// current value.
  ///
  /// {@macro TrackValue}
  TrackValue<T> velocity(T velocity) =>
      TrackValue._(this, null, velocity: velocity);

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
        if (step case PhaseBoundary(:final token))
          PhaseBoundary<T>(token: token)
        else if (step case StepSync(:final token))
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
/// Used to jump tracks to a value with [TrackController.set] and as
/// per-track initial values of a `TrackPhaseTimeline`. A snapshot can also
/// carry the [velocity] the track has at that value; without one, the
/// controller estimates it from the values it was set to. A snapshot made
/// with [Track.velocity] has no [value]: it sets the velocity and keeps the
/// track where it is.
///
/// Snapshots compare by value.
/// {@endtemplate}
@immutable
final class TrackValue<T extends Object> {
  /// Creates a value snapshot for [track].
  const TrackValue._(this.track, this.value, {this.velocity});

  /// The track this snapshot applies to.
  final Track<T> track;

  /// The value for [track], or null when this snapshot only sets the
  /// [velocity] (see [Track.velocity]).
  final T? value;

  /// The velocity [track] has at [value], in units per second, or null to
  /// leave it to the controller: it estimates the velocity from the values
  /// the track was set to, unless its velocity tracking is off.
  final T? velocity;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrackValue<T> &&
          other.runtimeType == runtimeType &&
          other.track == track &&
          other.value == value &&
          other.velocity == velocity;

  @override
  int get hashCode => Object.hash(runtimeType, track, value, velocity);

  @override
  String toString() => '${objectRuntimeType(this, 'TrackValue')}($track, $value'
      '${velocity == null ? '' : ', velocity: $velocity'})';
}

/// An animation instruction for a single [Track].
///
/// Besides the [steps] to play, an animation can carry a per-track [from]
/// override (jump to this value before animating) and an initial
/// [withVelocity]. `loop` is not part of an animation: the timeline or the
/// playback call owns it.
///
/// Animations compare by value, including their steps.
@immutable
final class TrackAnimation<T extends Object> {
  /// Creates an animation for [track] using [steps].
  TrackAnimation._(
    this.track,
    List<TrackStep<T>> steps, {
    this.from,
    this.withVelocity,
    this.delay = Duration.zero,
  })  : assert(!delay.isNegative, 'delay must not be negative'),
        steps = List.unmodifiable(steps);

  /// The track this animation targets.
  final Track<T> track;

  /// The steps to play for [track].
  final List<TrackStep<T>> steps;

  /// Optional value to jump to before animating.
  final T? from;

  /// Optional starting velocity for the animation.
  final T? withVelocity;

  /// {@template TrackAnimation.delay}
  /// [delay] starts the animation that long after it is played: its `.at`
  /// times count from then, and it applies once, not per loop cycle. While
  /// waiting, a track that is moving keeps its motion (a redirect without
  /// `from` or `withVelocity` hands the running motion over), and one at rest
  /// stays put.
  /// {@endtemplate}
  final Duration delay;

  /// Rebuilds target-based steps with [motion] while preserving value types.
  @internal
  TrackAnimation<T> withMotionOverride(Motion motion) => TrackAnimation._(
        track,
        [
          for (final step in steps)
            switch (step) {
              StepTo<T>(:final value, :final until) => TrackStep.to(
                  value,
                  motion: motion,
                  until: until,
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
        delay: delay,
      );

  /// Resolves the value this animation should start from when the controller
  /// has no existing value for [track].
  ///
  /// Resolution order: [from] -> [Track.initial] -> a zero-filled value whose
  /// dimensionality matches this animation's first concrete target
  /// (`TrackStep.to`/`TrackStep.at`). Throws if none of these can supply a value.
  @internal
  T resolveStartValue() {
    if (from case final value?) return value;
    if (track.initial case final value?) return value;
    if (_firstTargetDimensions case final dimensions?) {
      return track.converter.denormalize(List<double>.filled(dimensions, 0));
    }
    throw StateError(
      'Track has no initial value, no `from`, and the animation has no '
      'concrete target (TrackStep.to/TrackStep.at) to infer a starting value from. '
      'Provide Track.initial or a from: value.',
    );
  }

  /// The end value of this animation: its last `TrackStep.to`/`TrackStep.at`
  /// value, or null when no step carries a value.
  @internal
  TrackValue<T>? get endValue {
    for (final step in steps.reversed) {
      if (step case StepTo<T>(:final value) || StepAt<T>(:final value)) {
        return track.value(value);
      }
    }
    return null;
  }

  /// The dimension count of this animation's first concrete target, or null
  /// when no step carries a value.
  int? get _firstTargetDimensions {
    for (final step in steps) {
      if (step case StepTo<T>(:final value) || StepAt<T>(:final value)) {
        return track.converter.normalize(value).length;
      }
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrackAnimation<T> &&
          other.runtimeType == runtimeType &&
          other.track == track &&
          listEquals(other.steps, steps) &&
          other.from == from &&
          other.withVelocity == withVelocity &&
          other.delay == delay;

  @override
  int get hashCode => Object.hash(
        runtimeType,
        track,
        Object.hashAll(steps),
        from,
        withVelocity,
        delay,
      );

  @override
  String toString() =>
      '${objectRuntimeType(this, 'TrackAnimation')}($track, $steps, '
      'from: $from, withVelocity: $withVelocity, delay: $delay)';
}
