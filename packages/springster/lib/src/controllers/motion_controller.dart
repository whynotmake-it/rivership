import 'dart:collection';

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:meta/meta.dart';
import 'package:springster/src/motion.dart';
import 'package:springster/src/motion_converter.dart';

/// A base [MotionController] that can manage a [Motion] of any value that you
/// can pass a [MotionConverter] for.
///
/// See also:
///   * [BoundedMotionController] for a version that adds bounds, as well as
///     `forward` and `reverse` methods to the controller.
class MotionController<T extends Object> extends Animation<T>
    with
        AnimationLocalListenersMixin,
        AnimationLocalStatusListenersMixin,
        AnimationEagerListenerMixin {
  /// Creates a [MotionController] with the given parameters and a single motion
  /// that is used for all dimensions.
  ///
  /// The [motion] parameter defines the characteristics of the motion
  /// and the [vsync] parameter is required to drive the animation.
  MotionController({
    required Motion motion,
    required TickerProvider vsync,
    required MotionConverter<T> converter,
    required T initialValue,
    AnimationBehavior behavior = AnimationBehavior.normal,
  }) : this._(
          motionPerDimension: List.filled(
            converter.normalize(initialValue).length,
            motion,
          ),
          vsync: vsync,
          converter: converter,
          initialValue: initialValue,
          behavior: behavior,
        );

  /// Creates a [MotionController] with the given parameters and a list of
  /// motions for each dimension.
  MotionController.motionPerDimension({
    required List<Motion> motionPerDimension,
    required TickerProvider vsync,
    required MotionConverter<T> converter,
    required T initialValue,
    AnimationBehavior behavior = AnimationBehavior.normal,
  }) : this._(
          motionPerDimension: motionPerDimension,
          vsync: vsync,
          converter: converter,
          initialValue: initialValue,
          behavior: behavior,
        );

  MotionController._({
    required List<Motion> motionPerDimension,
    required TickerProvider vsync,
    required this.converter,
    required T initialValue,
    AnimationBehavior behavior = AnimationBehavior.normal,
  }) : assert(
          converter.normalize(initialValue).isNotEmpty,
          'normalizing all given values must result in a non-empty list',
        ) {
    final normalized = converter.normalize(initialValue);
    _motionPerDimension = motionPerDimension;
    _dimensions = normalized.length;

    // Initialize the values and velocities
    _currentValues = List.of(normalized);

    // Create the ticker
    _ticker = vsync.createTicker(_tick);

    // Initialize status based on its position relative to bounds
    _animationBehavior = behavior;

    // Initialize with a dismissed status by default
    _status = AnimationStatus.dismissed;
  }

  /// Converts the value of type T to a List<double> for internal processing.
  final MotionConverter<T> converter;

  /// Number of dimensions being animated
  late final int _dimensions;

  /// The motion style controlling the animation characteristics.
  late List<Motion> _motionPerDimension;

  /// The current values for each dimension
  late List<double> _currentValues;

  /// The amount of time that has passed between the time the animation started
  /// and the most recent tick of the animation.
  ///
  /// If the controller is not animating, the last elapsed duration is null.
  Duration? get lastElapsedDuration => _lastElapsedDuration;
  Duration? _lastElapsedDuration;

  /// The ticker that drives the animation
  Ticker? _ticker;

  /// The target values for each dimension when animating.
  List<double>? _target;

  /// List of simulations, one for each dimension
  List<Simulation> _simulations = [];

  /// The current status of the animation
  late AnimationStatus _status;

  /// The animation behavior
  late final AnimationBehavior _animationBehavior;

  /// The current value of this animation.
  @override
  T get value => converter.denormalize(_currentValues);

  /// Sets the current value of the animation.
  set value(T newValue) {
    _ticker?.stop();
    _status = AnimationStatus.dismissed;

    final normalized = converter.normalize(newValue);
    _internalSetValue(normalized);
    notifyListeners();
    _checkStatusChanged();
  }

  /// Updates the internal values array
  void _internalSetValue(List<double> newValues) {
    assert(
      newValues.length == _dimensions,
      'New values must have the same number of dimensions as the controller',
    );

    _currentValues = List.of(newValues);
  }

  /// The current status of this [Animation].
  ///
  /// Spring simulations don't really have a concept of directionality,
  /// especially in higher dimensions.
  /// Thus, this will never return [AnimationStatus.reverse].
  @override
  AnimationStatus get status => _status;

  /// Whether this animation is currently animating in either the forward or
  /// reverse direction.
  @override
  bool get isAnimating => switch (_ticker) {
        null => false,
        Ticker(:final isActive) => isActive,
      };

  /// The current velocity of the simulation in units per second for each
  /// dimension.
  List<double> get velocities {
    if (!isAnimating) return List.filled(_dimensions, 0);

    return [
      for (var i = 0; i < _dimensions; i++)
        _simulations[i].dx(_lastElapsedDuration!.toSec()),
    ];
  }

  /// The type-specific velocity representation.
  T get velocity => converter.denormalize(velocities);

  /// The single motion that is used for all dimensions.
  ///
  /// This assumes that all motions in [motionPerDimension] are the same.
  Motion get motion {
    assert(
      motionPerDimension.every((e) => e == motionPerDimension.first),
      'tried to access a single motion in a '
      '${objectRuntimeType(this, 'MotionController')}, but not all motions '
      'per dimension are the same',
    );
    return motionPerDimension.first;
  }

  /// Sets the default motion to use for each dimension.
  set motion(Motion value) {
    _motionPerDimension = List.filled(_motionPerDimension.length, value);
    _redirectSimulation();
  }

  /// {@template MotionController.motionStyle}
  /// The current motion style
  ///
  /// When set, this will create a new simulation with the current velocity if
  /// an animation is in progress.
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
    _redirectSimulation();
  }

  /// The behavior of the animation.
  ///
  /// Defaults to [AnimationBehavior.normal] for bounded, and
  /// [AnimationBehavior.preserve] for unbounded controllers.
  AnimationBehavior get animationBehavior => _animationBehavior;

  /// Recreates the [Ticker] with the new [TickerProvider].
  void resync(TickerProvider vsync) {
    final oldTicker = _ticker!;
    _ticker = vsync.createTicker(_tick);
    _ticker!.absorbTicker(oldTicker);
  }

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
  }) =>
      _animateToInternal(
        target: converter.normalize(target),
        from: from != null ? converter.normalize(from) : null,
        velocity:
            withVelocity != null ? converter.normalize(withVelocity) : null,
      );

  TickerFuture _animateToInternal({
    required List<double> target,
    List<double>? from,
    List<double>? velocity,
  }) {
    _target = target;

    final fromValue = from ?? List.of(_currentValues);
    final velocityValue = velocity ?? velocities;

    // Stop any existing animations
    _stopTicker(canceled: true);

    _simulations = [
      for (var i = 0; i < _dimensions; i++)
        _motionPerDimension[i].createSimulation(
          start: fromValue[i],
          end: target[i],
          velocity: velocityValue[i],
        ),
    ];

    _internalSetValue(_simulations.map((e) => e.x(0)).toList());
    _lastElapsedDuration = Duration.zero;
    final result = _ticker!.start();
    _status = AnimationStatus.forward;
    _checkStatusChanged();
    return result;
  }

  /// Tick function called by the ticker
  void _tick(Duration elapsed) {
    _lastElapsedDuration = elapsed;

    final elapsedInSeconds =
        elapsed.inMicroseconds.toDouble() / Duration.microsecondsPerSecond;

    assert(elapsedInSeconds >= 0, 'elapsed must be non-negative');

    _currentValues = [
      for (var i = 0; i < _dimensions; i++) _simulations[i].x(elapsedInSeconds),
    ];

    // Check if all simulations are done
    if (_simulations.every((e) => e.isDone(elapsedInSeconds))) {
      _status = AnimationStatus.completed;
      _stopTicker();
    }

    notifyListeners();
    _checkStatusChanged();
  }

  /// Redirect a motion when the [motionPerDimension] changes.
  void _redirectSimulation() {
    if (!isAnimating) return;

    if (_target case final target?) {
      animateTo(converter.denormalize(target));
    }
  }

  AnimationStatus _lastReportedStatus = AnimationStatus.dismissed;
  void _checkStatusChanged() {
    if (_status != _lastReportedStatus) {
      _lastReportedStatus = _status;
      notifyStatusListeners(_status);
    }
  }

  /// Stops the current simulation, and depending on the value of [canceled],
  /// either settles the simulation at the current value, or interrupts the
  /// simulation immediately
  ///
  /// Unlike [AnimationController.stop], [canceled] defaults to false.
  /// If you set it to true, the simulation will be stopped immediately.
  /// Otherwise, the simulation will redirect to settle at the current value, if
  /// [Motion.needsSettle] is true for any [motionPerDimension].
  TickerFuture stop({bool canceled = false}) {
    if (canceled || _motionPerDimension.every((e) => !e.needsSettle)) {
      _stopTicker(canceled: canceled);
      return TickerFuture.complete();
    } else {
      return animateTo(value);
    }
  }

  void _stopTicker({bool canceled = false}) {
    _lastElapsedDuration = null;
    if (isAnimating) {
      _ticker?.stop(canceled: canceled);
    }
  }

  /// Frees any resources used by this object.
  @override
  void dispose() {
    _ticker?.dispose();
    _ticker = null;
    super.dispose();
  }
}

/// A [MotionController] that is bounded.
///
/// {@template springster.MotionController.boundedExplainer}
/// This adds a [lowerBound] and [upperBound] to the controller, and will
/// automatically clamp the [value] to be within the bounds when setting
/// (although) it can still overshoot as part of the [motion]s that are used.
///
/// This also adds [forward] and [reverse] methods that will animate towards
/// the [lowerBound] and [upperBound] respectively.
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
  })  : _lowerBound = converter.normalize(lowerBound),
        _upperBound = converter.normalize(upperBound),
        super.motionPerDimension();

  /// The lower bounds for each dimension.
  final List<double> _lowerBound;

  /// The upper bounds for each dimension.
  final List<double> _upperBound;

  /// The lower bound of the animation value.
  /// The lower bound of the animation value.
  ///
  /// {@template springster.spring_simulation.bounds_overshoot_warning}
  /// **Note:** since springs can, and often will, overshoot, [value] is not
  /// guaranteed to be within [lowerBound] and [upperBound]. Make sure to clamp
  /// [value] upon consumption if necessary.
  /// {@endtemplate}
  T get lowerBound => converter.denormalize(_lowerBound);

  /// The upper bound of the animation value.
  ///
  /// {@macro springster.spring_simulation.bounds_overshoot_warning}
  T get upperBound => converter.denormalize(_upperBound);

  /// Sets the current value of the animation.
  ///
  /// This will clamp the value to be within the bounds.
  @override
  set value(T newValue) {
    final normalized = converter.normalize(newValue);
    final clamped = [
      for (final (i, v) in normalized.indexed)
        v.clamp(_lowerBound[i], _upperBound[i]),
    ];
    _internalSetValue(clamped);
    notifyListeners();
  }

  /// Animates towards [upperBound].
  TickerFuture forward({
    T? from,
    T? withVelocity,
  }) {
    return animateTo(upperBound, from: from, withVelocity: withVelocity);
  }

  /// Animates towards [lowerBound].
  ///
  /// **Note**: [status] will still return [AnimationStatus.forward] when
  /// this is called. See [status] for more information.
  TickerFuture reverse({
    T? from,
    T? withVelocity,
  }) {
    return animateTo(lowerBound, from: from, withVelocity: withVelocity);
  }

  @override
  TickerFuture animateTo(T target, {T? from, T? withVelocity}) {
    final normalizedTarget = converter.normalize(target);
    final clamped = [
      for (final (i, v) in normalizedTarget.indexed)
        v.clamp(_lowerBound[i], _upperBound[i]),
    ];
    return _animateToInternal(
      target: clamped,
      from: from != null ? converter.normalize(from) : null,
      velocity: withVelocity != null ? converter.normalize(withVelocity) : null,
    );
  }
}

@internal
bool motionsEqual(Iterable<Motion>? a, Iterable<Motion>? b) {
  if (a == null && b == null) return true;
  if (a == null || b == null) return false;

  return a.length == b.length &&
      [for (final (i, m) in a.indexed) m == b.elementAt(i)].every((e) => e);
}

extension on Duration {
  double toSec() => inMicroseconds.toDouble() / Duration.microsecondsPerSecond;
}
