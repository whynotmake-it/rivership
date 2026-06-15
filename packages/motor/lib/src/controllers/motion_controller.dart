import 'package:flutter/animation.dart';
import 'package:flutter/scheduler.dart';
import 'package:meta/meta.dart';
import 'package:motor/src/controllers/single_motion_controller.dart';
import 'package:motor/src/controllers/track_controller.dart';
import 'package:motor/src/loop_mode.dart';
import 'package:motor/src/motion.dart';
import 'package:motor/src/motion_converter.dart';
import 'package:motor/src/motion_velocity_tracker.dart';
import 'package:motor/src/step.dart';
import 'package:motor/src/track.dart';
import 'package:motor/src/track_timeline.dart';

/// A base [MotionController] that can manage a [Motion] of any value that you
/// can pass a [MotionConverter] for.
///
/// In a lot of ways, this class works like [AnimationController], but a few key
/// differences have been made to make it generalize easier for different types
/// of motion.
///
/// 1. [status] behavior depends on the [MotionConverter]:
///   - If the converter is directional (e.g. [SingleMotionConverter]), [status]
///     will report [AnimationStatus.forward] or [AnimationStatus.reverse]
///     appropriately.
///   - For non-directional converters (common for multi-dimensional types),
///     [status] will always be [AnimationStatus.forward] while animating.
///   - When stopped, it generally returns [AnimationStatus.completed] unless
///     at the initial value (or lower bound), where it returns
///     [AnimationStatus.dismissed].
/// 2. [stop] will not stop the animation right away, unless `canceled` is true.
///   Instead, it will wait until the simulation is done, and then settle at
///   the current value. This allows for a more graceful stop, for example, a
///   bouncy spring will perform its overshoot.
///
/// Internally this is a thin wrapper over a single-[Track] [TrackController],
/// so the single-value and multi-track stacks share one engine.
///
/// See also:
///   * [BoundedMotionController] for a version that adds bounds, as well as
///     `forward` and `reverse` methods to the controller.
///   * [SingleMotionController] and [BoundedSingleMotionController] for a one-
///     dimensional version of this class. These are most closely related to
///     [AnimationController]s.
class MotionController<T extends Object> extends Animation<T>
    with
        AnimationLocalListenersMixin,
        AnimationLocalStatusListenersMixin,
        AnimationEagerListenerMixin {
  /// Creates a motion controller with a single motion for all dimensions.
  ///
  /// Velocity tracking is enabled by default to track velocity when manually
  /// setting [value]. Use [VelocityTracking.off] to disable.
  MotionController({
    required Motion motion,
    required TickerProvider vsync,
    required MotionConverter<T> converter,
    required T initialValue,
    AnimationBehavior behavior = AnimationBehavior.normal,
    VelocityTracking velocityTracking = const VelocityTracking.on(),
  }) : this._(
          motionPerDimension:
              List.filled(converter.normalize(initialValue).length, motion),
          vsync: vsync,
          converter: converter,
          initialValue: initialValue,
          behavior: behavior,
          velocityTracking: velocityTracking,
        );

  /// Creates a motion controller with individual motions per dimension.
  MotionController.motionPerDimension({
    required List<Motion> motionPerDimension,
    required TickerProvider vsync,
    required MotionConverter<T> converter,
    required T initialValue,
    AnimationBehavior behavior = AnimationBehavior.normal,
    VelocityTracking velocityTracking = const VelocityTracking.on(),
  }) : this._(
          motionPerDimension: motionPerDimension,
          vsync: vsync,
          converter: converter,
          initialValue: initialValue,
          behavior: behavior,
          velocityTracking: velocityTracking,
        );

  MotionController._({
    required List<Motion> motionPerDimension,
    required TickerProvider vsync,
    required MotionConverter<T> converter,
    required T initialValue,
    required AnimationBehavior behavior,
    required VelocityTracking velocityTracking,
  })  : assert(
          converter.normalize(initialValue).isNotEmpty,
          'normalizing all given values must result in a non-empty list',
        ),
        assert(
          motionPerDimension.length ==
              converter.normalize(initialValue).length,
          'the number of motions must match the number of dimensions',
        ),
        _converter = converter,
        _initialValue = initialValue,
        _motionPerDimension = List.of(motionPerDimension),
        _animationBehavior = behavior {
    _inner = TrackController(vsync: vsync, velocityTracking: velocityTracking);
    _track = Track<T>(converter, origin: initialValue);
    _inner
      ..addListener(notifyListeners)
      ..addStatusListener(_handleInnerStatus);
  }

  late final TrackController _inner;
  MotionConverter<T> _converter;
  late Track<T> _track;
  final T _initialValue;
  List<Motion> _motionPerDimension;
  final AnimationBehavior _animationBehavior;

  /// The most recent animation target, used to evaluate the resting [status].
  T? _lastTarget;

  AnimationStatus _status = AnimationStatus.dismissed;
  AnimationStatus _lastReportedStatus = AnimationStatus.dismissed;

  /// Converts the value of type T to a `List<double>` for internal processing.
  MotionConverter<T> get converter => _converter;

  /// Swaps the [converter] used by this controller.
  ///
  /// The current normalized values are reinterpreted under the new converter,
  /// so the new converter must have the same number of dimensions.
  set converter(MotionConverter<T> value) {
    if (value == _converter) return;

    final normalized = _converter.normalize(this.value);
    final velocityNormalized = _converter.normalize(velocity);
    final reinterpreted = value.denormalize(normalized);
    assert(
      value.normalize(reinterpreted).length == normalized.length,
      'new converter must have the same number of dimensions as the '
      'previous converter',
    );
    final reinterpretedVelocity = value.denormalize(velocityNormalized);

    if (_inner.isAnimating) _inner.stop(tracks: [_track], canceled: true);
    _converter = value;
    _track = Track<T>(value, origin: reinterpreted);
    _inner
      ..set(
        [_track.value(reinterpreted)],
        withVelocity: [_track.velocity(reinterpretedVelocity)],
      )
      ..resetVelocityTracking();
    notifyListeners();
  }

  /// The current value of this animation.
  @override
  T get value => _inner.value(_track);

  /// Sets the current value of the animation.
  ///
  /// When velocity tracking is enabled (the default), this tracks the value
  /// for velocity estimation. The tracked velocity is used when [animateTo]
  /// is called without explicit velocity, and is available via [velocity].
  set value(T newValue) {
    if (_inner.isAnimating) _inner.stop(canceled: true);
    _inner.set([_track.value(newValue)]);
    _status = _getStatusWhenDone();
    _checkStatusChanged();
  }

  /// The current status of this [Animation].
  ///
  /// This reports [AnimationStatus.forward] or [AnimationStatus.reverse] based
  /// on the directionality defined by the [converter].
  ///
  /// If the [converter] is not a [DirectionalMotionConverter], this will always
  /// report [AnimationStatus.forward] while animating.
  @override
  AnimationStatus get status => _status;

  /// Whether this animation is currently animating in either the forward or
  /// reverse direction.
  @override
  bool get isAnimating => _inner.isAnimating;

  /// The current velocity of the simulation in units per second for each
  /// dimension.
  List<double> get velocities => _converter.normalize(velocity);

  /// The type-specific velocity representation.
  ///
  /// When animating, this returns the velocity from the active simulation.
  /// When not animating, this returns the tracked velocity from user input
  /// if a velocity tracker is available, otherwise the zero value for type T.
  T get velocity => _inner.velocity(_track);

  /// The single motion that is used for all dimensions.
  ///
  /// This assumes that all motions in [motionPerDimension] are the same.
  Motion get motion {
    assert(
      _motionPerDimension.every((e) => e == _motionPerDimension.first),
      'tried to access a single motion in a MotionController, but not all '
      'motions per dimension are the same',
    );
    return _motionPerDimension.first;
  }

  /// Sets the default motion to use for each dimension.
  set motion(Motion value) =>
      motionPerDimension = List.filled(_motionPerDimension.length, value);

  /// {@template MotionController.motionStyle}
  /// The current motion style.
  ///
  /// When set, this will redirect any in-progress animation with the current
  /// velocity.
  /// {@endtemplate}
  List<Motion> get motionPerDimension => List.unmodifiable(_motionPerDimension);

  /// {@macro MotionController.motionStyle}
  set motionPerDimension(Iterable<Motion> value) {
    assert(
      value.length == _motionPerDimension.length,
      'the number of motions must match the number of dimensions',
    );
    if (motionsEqual(_motionPerDimension, value)) return;

    _motionPerDimension = value.toList();
    _redirect();
  }

  /// The behavior of the animation.
  AnimationBehavior get animationBehavior => _animationBehavior;

  /// Returns the tracked velocity estimate from user input.
  ///
  /// Returns `null` if no velocity tracker is available or no samples have
  /// been recorded.
  MotionVelocityEstimate<T>? get trackedVelocityEstimate =>
      _inner.trackedVelocityEstimate(_track);

  /// The amount of time that has passed between the time the animation started
  /// and the most recent tick of the animation, or null if not animating.
  Duration? get lastElapsedDuration => _inner.lastElapsedDuration;

  /// Recreates the [Ticker] with the new [TickerProvider].
  void resync(TickerProvider vsync) => _inner.resync(vsync);

  /// Animates towards [target], while ensuring that any current velocity is
  /// maintained.
  ///
  /// If [from] is provided, the animation will start from there instead of from
  /// the current [value].
  ///
  /// If [withVelocity] is provided, the animation will start with that velocity
  /// instead of [velocity].
  TickerFuture animateTo(
    T target, {
    T? from,
    T? withVelocity,
  }) {
    _lastTarget = target;
    _status = converter.motionIsForward(from: from ?? value, to: target)
        ? AnimationStatus.forward
        : AnimationStatus.reverse;
    final future = _inner.animate(
      [_track.to(target, motionPerDimension: _motionPerDimension)],
      from: from != null ? [_track.value(from)] : const [],
      withVelocity:
          withVelocity != null ? [_track.velocity(withVelocity)] : const [],
    );
    _inner.resetVelocityTracking();
    _checkStatusChanged();
    return future;
  }

  /// Plays [steps] from the current value.
  ///
  /// Non-looping playback completes when all chained simulations finish.
  /// Looping playback runs until [stop], [animateTo], or [value] interrupts it.
  TickerFuture play(
    List<Step<T>> steps, {
    LoopMode? loop,
    void Function(int stepIndex)? onStep,
  }) {
    if (steps.isEmpty) return TickerFuture.complete();

    _lastTarget = null;
    final future = _inner.play(
      TrackTimeline([_track(steps)], loop: loop ?? LoopMode.none),
      onStep: onStep == null ? null : (track, index) => onStep(index),
    );
    _inner.resetVelocityTracking();
    _status = AnimationStatus.forward;
    _checkStatusChanged();
    return future;
  }

  /// Stops the current simulation, and depending on the value of [canceled],
  /// either settles the simulation at the current value, or interrupts the
  /// simulation immediately.
  ///
  /// Unlike [AnimationController.stop], [canceled] defaults to false.
  /// If you set it to true, the simulation will be stopped immediately.
  /// Otherwise, the simulation will redirect to settle at the current value, if
  /// [Motion.needsSettle] is true for any [motionPerDimension].
  TickerFuture stop({bool canceled = false}) {
    if (canceled || _motionPerDimension.every((e) => !e.needsSettle)) {
      _inner.stop(canceled: true);
      return TickerFuture.complete();
    }
    return animateTo(value);
  }

  /// Redirects an in-progress animation to [_lastTarget] using the current
  /// motions and velocity. No-op when not animating.
  void _redirect() {
    if (!_inner.isAnimating) return;
    if (_lastTarget case final target?) {
      animateTo(target);
    }
  }

  /// Evaluates the current status when we're at the end of the animation.
  AnimationStatus _getStatusWhenDone() => switch (_lastTarget) {
        final v? when v == _initialValue => AnimationStatus.dismissed,
        _ => AnimationStatus.completed,
      };

  void _handleInnerStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _status = _getStatusWhenDone();
      _checkStatusChanged();
    }
  }

  void _checkStatusChanged() {
    if (_status != _lastReportedStatus) {
      _lastReportedStatus = _status;
      notifyStatusListeners(_status);
    }
  }

  /// Frees any resources used by this object.
  @override
  void dispose() {
    _inner
      ..removeListener(notifyListeners)
      ..removeStatusListener(_handleInnerStatus)
      ..dispose();
    super.dispose();
  }
}

/// A [MotionController] that is bounded.
///
/// See [MotionController] for more information.
///
/// {@template motor.MotionController.boundedExplainer}
/// This adds a [lowerBound] and [upperBound] to the controller, and will
/// automatically clamp the [value] to be within the bounds when setting
/// (although) it can still overshoot as part of the [motion]s that are used.
///
/// This also adds [forward] and [reverse] methods that will animate towards
/// the [lowerBound] and [upperBound] respectively.
///
/// Furthermore, [status] behaves differently for bounded controllers:
///   - It will return [AnimationStatus.reverse] when animating towards the
///     [lowerBound], and [AnimationStatus.forward] when animating towards the
///     [upperBound].
///   - [status] will return [AnimationStatus.dismissed] if the controller is
///     stopped and at its lower bound.
///   - [status] will return the last reported direction if the controller is
///     stopped and not at its lower or upper bound.
/// {@endtemplate}
class BoundedMotionController<T extends Object> extends MotionController<T> {
  /// Creates a [BoundedMotionController].
  BoundedMotionController({
    required super.motion,
    required super.vsync,
    required super.converter,
    required super.initialValue,
    required T lowerBound,
    required T upperBound,
    super.behavior,
    super.velocityTracking,
  })  : _lowerBound = converter.normalize(lowerBound),
        _upperBound = converter.normalize(upperBound);

  /// Creates a [BoundedMotionController] with the given parameters and a list
  /// of motions for each dimension.
  BoundedMotionController.motionPerDimension({
    required super.motionPerDimension,
    required super.vsync,
    required super.converter,
    required super.initialValue,
    required T lowerBound,
    required T upperBound,
    super.behavior,
    super.velocityTracking,
  })  : _lowerBound = converter.normalize(lowerBound),
        _upperBound = converter.normalize(upperBound),
        super.motionPerDimension();

  final List<double> _lowerBound;
  final List<double> _upperBound;

  bool _forward = true;

  /// The lower bound of the animation value.
  ///
  /// {@template motor.spring_simulation.bounds_overshoot_warning}
  /// **Note:** since springs can, and often will, overshoot, [value] is not
  /// guaranteed to be within [lowerBound] and [upperBound]. Make sure to clamp
  /// [value] upon consumption if necessary.
  /// {@endtemplate}
  T get lowerBound => converter.denormalize(_lowerBound);

  /// The upper bound of the animation value.
  ///
  /// {@macro motor.spring_simulation.bounds_overshoot_warning}
  T get upperBound => converter.denormalize(_upperBound);

  /// Sets the current value of the animation.
  ///
  /// The value is clamped to be within bounds. When velocity tracking is
  /// enabled (the default), this also tracks the value for velocity estimation.
  @override
  set value(T newValue) => super.value = _clamp(newValue);

  T _clamp(T value) {
    final normalized = converter.normalize(value);
    return converter.denormalize([
      for (final (i, v) in normalized.indexed)
        v.clamp(_lowerBound[i], _upperBound[i]),
    ]);
  }

  @override
  AnimationStatus _getStatusWhenDone() => switch (_lastTarget) {
        final v? when v == lowerBound => AnimationStatus.dismissed,
        final v? when v == upperBound => AnimationStatus.completed,
        _ when !_forward => AnimationStatus.reverse,
        _ => AnimationStatus.forward,
      };

  @override
  TickerFuture animateTo(
    T target, {
    T? from,
    T? withVelocity,
  }) {
    final clamped = _clamp(target);
    _forward = converter.motionIsForward(from: from ?? value, to: clamped);
    return super.animateTo(clamped, from: from, withVelocity: withVelocity);
  }

  /// Animates towards [upperBound].
  TickerFuture forward({
    T? from,
    T? withVelocity,
  }) =>
      animateTo(upperBound, from: from, withVelocity: withVelocity);

  /// Animates towards [lowerBound].
  ///
  /// **Note**: [status] might still return [AnimationStatus.forward] when
  /// this is called, depending on the directionality of [converter].
  /// See [status] for more information.
  TickerFuture reverse({
    T? from,
    T? withVelocity,
  }) =>
      animateTo(lowerBound, from: from, withVelocity: withVelocity);

  @override
  TickerFuture stop({bool canceled = false}) {
    if (canceled || motionPerDimension.every((e) => !e.needsSettle)) {
      return super.stop(canceled: true);
    }
    // Settle at the clamped current value, keeping the last direction.
    final target = _clamp(value);
    _lastTarget = target;
    _status = _getStatusWhenDone();
    _checkStatusChanged();
    return _inner.animate([
      _track.to(target, motionPerDimension: motionPerDimension),
    ]);
  }
}

/// Compares two iterables of [Motion]s for equality.
@internal
bool motionsEqual(Iterable<Motion>? a, Iterable<Motion>? b) {
  if (a == null && b == null) return true;
  if (a == null || b == null) return false;

  return a.length == b.length &&
      [for (final (i, m) in a.indexed) m == b.elementAt(i)].every((e) => e);
}

extension<T> on MotionConverter<T> {
  bool motionIsForward({required T from, required T to}) {
    if (this case final DirectionalMotionConverter<T> directional) {
      return switch (directional.compare(from, to)) {
        > 0 => false,
        _ => true,
      };
    }

    // Always consider motion forward for non-directional converters.
    return true;
  }
}
