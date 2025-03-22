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
    _controllers = [
      for (final value in normalized)
        AnimationController.unbounded(
          value: value,
          vsync: vsync,
          animationBehavior: behavior,
        ),
    ];

    // Listen to the first controller by default
    _setListeningTo(0, initial: true);
  }

  /// Converts the value of type T to a List<double> for internal processing.
  final MotionConverter<T> converter;

  /// The internal list of animation controllers, one for each dimension.
  late final List<AnimationController> _controllers;

  /// The motion style controlling the animation characteristics.
  late List<Motion> _motionPerDimension;

  /// The index of the controller we're currently listening to for status
  /// changes.
  int _listeningTo = 0;

  /// The target values for each dimension when animating.
  List<double>? _target;

  /// The current value of this animation.
  @override
  T get value =>
      converter.denormalize(_controllers.map((e) => e.value).toList());

  /// Sets the current value of the animation.
  set value(T newValue) {
    final normalized = converter.normalize(newValue);
    for (final (i, c) in _controllers.indexed) {
      c.value = normalized[i];
    }
  }

  /// The current status of this [Animation].
  ///
  /// Spring simulations don't really have a concept of directionality,
  /// especially in higher dimensions.
  /// Thus, this will never return [AnimationStatus.reverse].
  @override
  AnimationStatus get status => _controllers[_listeningTo].status;

  /// Whether this animation is currently animating in either the forward or
  /// reverse direction.
  @override
  bool get isAnimating => _controllers.any((e) => e.isAnimating);

  /// The current velocity of the simulation in units per second for each
  /// dimension.
  List<double> get velocities => _controllers.map((e) => e.velocity).toList();

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
  }

  /// {@template MotionController.motionStyle}
  /// The current motion style
  ///
  /// When set, this will create a new simulation with the current velocity if
  /// an animation is in progress.
  /// {@endtemplate}
  UnmodifiableListView<Motion> get motionPerDimension =>
      UnmodifiableListView(_motionPerDimension);

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
  AnimationBehavior get animationBehavior =>
      _controllers.first.animationBehavior;

  /// Sets the controller to listen to for status changes.
  void _setListeningTo(int index, {bool initial = false}) {
    if (index == _listeningTo && !initial) return;

    if (!initial) {
      // Remove listeners from the previous controller
      _controllers[_listeningTo]
        ..removeListener(notifyListeners)
        ..removeStatusListener(notifyStatusListeners);
    }

    _listeningTo = index;

    _controllers[_listeningTo]
      ..addListener(notifyListeners)
      ..addStatusListener(notifyStatusListeners);
  }

  /// Recreates the [Ticker] with the new [TickerProvider].
  void resync(TickerProvider ticker) {
    for (final c in _controllers) {
      c.resync(ticker);
    }
  }

  /// Animates towards [target], while ensuring that any current velocity is
  /// maintained.

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

    final fromValue = from ?? converter.normalize(value);
    final velocities = velocity ?? this.velocities;

    final changed = [
      for (var i = 0; i < _controllers.length; i++)
        motionPerDimension[i].tolerance.distance <
                (target[i] - fromValue[i]).abs() ||
            velocities[i] > motionPerDimension[i].tolerance.velocity,
    ];

    final listeningTo = switch (changed.indexOf(true)) {
      -1 => 0,
      final v => v,
    };

    _setListeningTo(listeningTo);

    // Stop all animations and set the value to the from value if it hasn't
    // changed
    for (final (i, c) in _controllers.indexed) {
      if (!changed[i] && c.value != fromValue[i]) {
        c.value = fromValue[i];
      }
      c.stop();
    }

    TickerFuture animate(int i) {
      final simulation = motionPerDimension[i].createSimulation(
        start: fromValue[i],
        end: target[i],
        velocity: velocities[i],
      );

      return _controllers[i].animateWith(simulation);
    }

    for (var i = 0; i < _controllers.length; i++) {
      if (i == listeningTo || !changed[i]) {
        continue;
      }

      animate(i);
    }

    return animate(listeningTo);
  }

  /// Redirect a motion when the [motionPerDimension] changes.
  void _redirectSimulation() {
    if (!_controllers.any((e) => e.isAnimating)) return;

    if (_target case final target?) {
      animateTo(converter.denormalize(target));
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
    if (canceled || motionPerDimension.every((e) => !e.needsSettle)) {
      for (final c in _controllers) {
        c.stop(canceled: canceled);
      }
      return TickerFuture.complete();
    } else {
      return animateTo(value);
    }
  }

  /// Frees any resources used by this object.
  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
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
    for (final (i, c) in _controllers.indexed) {
      c.value = normalized[i].clamp(_lowerBound[i], _upperBound[i]);
    }
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
