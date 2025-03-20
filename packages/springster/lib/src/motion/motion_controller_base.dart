import 'package:flutter/animation.dart';
import 'package:flutter/scheduler.dart';
import 'package:springster/src/motion/motion_style.dart';

/// A base class for motion controllers that manages animations based on a
/// [Motion]
abstract class MotionControllerBase<T extends Object> extends Animation<T>
    with
        AnimationLocalListenersMixin,
        AnimationLocalStatusListenersMixin,
        AnimationEagerListenerMixin {
  /// Creates a [MotionControllerBase] with the given parameters.
  ///
  /// The [motion] parameter defines the characteristics of the motion
  /// and the [vsync] parameter is required to drive the animation.
  /// The [normalize] and [denormalize] callbacks allow conversion between
  /// type [T] and List<double> for internal animation handling.
  MotionControllerBase({
    required Motion motion,
    required TickerProvider vsync,
    required this.normalize,
    required this.denormalize,
    required T lowerBound,
    required T upperBound,
    required T initialValue,
    AnimationBehavior behavior = AnimationBehavior.normal,
  })  : _motion = motion,
        _lowerBound = normalize(lowerBound),
        _upperBound = normalize(upperBound),
        assert(
          normalize(lowerBound).isNotEmpty &&
              normalize(upperBound).isNotEmpty &&
              normalize(initialValue).isNotEmpty,
          'normalizing all given values must result in a non-empty list',
        ) {
    final normalized = normalize(initialValue);
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
  final List<double> Function(T value) normalize;

  /// Converts the internal List<double> representation back to type T.
  final T Function(List<double> values) denormalize;

  /// The internal list of animation controllers, one for each dimension.
  late final List<AnimationController> _controllers;

  /// The motion style controlling the animation characteristics.
  Motion _motion;

  /// The lower bounds for each dimension.
  final List<double> _lowerBound;

  /// The upper bounds for each dimension.
  final List<double> _upperBound;

  /// The index of the controller we're currently listening to for status
  /// changes.
  int _listeningTo = 0;

  /// The target values for each dimension when animating.
  List<double>? _target;

  /// Whether the controller is bounded, meaning neither [lowerBound] nor
  /// [upperBound] are infinite.
  bool get isBounded =>
      _lowerBound.every((l) => l != double.negativeInfinity) &&
      _upperBound.every((u) => u != double.infinity);

  /// The current value of this animation.
  @override
  T get value => denormalize(_controllers.map((e) => e.value).toList());

  /// Sets the current value of the animation.
  set value(T newValue) {
    final normalized = normalize(newValue);
    for (final (i, c) in _controllers.indexed) {
      c.value = normalized[i].clamp(_lowerBound[i], _upperBound[i]);
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
  List<double> get velocityValues =>
      _controllers.map((e) => e.velocity).toList();

  /// The type-specific velocity representation.
  T get velocity => denormalize(velocityValues);

  /// The lower bound of the animation value.
  ///
  /// {@template springster.spring_simulation.bounds_overshoot_warning}
  /// **Note:** since springs can, and often will, overshoot, [value] is not
  /// guaranteed to be within [lowerBound] and [upperBound]. Make sure to clamp
  /// [value] upon consumption if necessary.
  /// {@endtemplate}
  T get lowerBound => denormalize(_lowerBound);

  /// The upper bound of the animation value.
  ///
  /// {@macro springster.spring_simulation.bounds_overshoot_warning}
  T get upperBound => denormalize(_upperBound);

  /// {@template MotionController.motionStyle}
  /// The current motion style
  ///
  /// When set, this will create a new simulation with the current velocity if
  /// an animation is in progress.
  /// {@endtemplate}
  Motion get motion => _motion;

  /// {@macro MotionController.motionStyle}
  set motion(Motion value) {
    if (_motion == value) return;
    _motion = value;
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

  /// Animates towards [upperBound].
  ///
  /// Only valid if [isBounded] is true, otherwise an [AssertionError] will be
  /// thrown, since unbounded controllers do not have a direction.
  TickerFuture forward({
    T? from,
    T? withVelocity,
  }) {
    return animateTo(upperBound, from: from, withVelocity: withVelocity);
  }

  /// Animates towards [lowerBound].
  ///
  /// Only valid if [isBounded] is true, otherwise an [AssertionError] will be
  /// thrown, since unbounded controllers do not have a direction.
  ///
  /// **Note**: [status] will still return [AnimationStatus.forward] when
  /// this is called. See [status] for more information.
  TickerFuture reverse({
    T? from,
    T? withVelocity,
  }) {
    if (!isBounded && from != null) {
      value = from;
    }
    return animateTo(lowerBound, from: from, withVelocity: withVelocity);
  }

  /// Animates towards [target], while ensuring that any current velocity is
  /// maintained.
  ///
  /// If this controller [isBounded], the [target] will be clamped to be within
  /// [lowerBound] and [upperBound].
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
    final normalizedTarget = normalize(target);
    final clamped = [
      for (final (i, v) in normalizedTarget.indexed)
        v.clamp(_lowerBound[i], _upperBound[i]),
    ];

    _target = clamped;

    final fromValue = from != null ? normalize(from) : normalize(value);
    final velocityValue =
        withVelocity != null ? normalize(withVelocity) : velocityValues;

    final changed = [
      for (var i = 0; i < _controllers.length; i++)
        motion.tolerance.distance < (clamped[i] - fromValue[i]).abs() ||
            velocityValues[i] > motion.tolerance.velocity,
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

    // Start all animations but only return the future from one that changed
    final futures = <TickerFuture>[];

    for (var i = 0; i < _controllers.length; i++) {
      if (changed[i]) {
        final simulation = _motion.createSimulation(
          start: fromValue[i],
          end: clamped[i],
          velocity: velocityValue[i],
        );

        futures.add(_controllers[i].animateWith(simulation));
      }
    }

    if (futures.isEmpty) return TickerFuture.complete();
    return futures.first;
  }

  /// Redirect a motion when the [motion] changes.
  void _redirectSimulation() {
    if (!_controllers.any((e) => e.isAnimating)) return;

    if (_target case final target?) {
      animateTo(denormalize(target));
    }
  }

  /// Stops the current simulation, and depending on the value of [canceled],
  /// either settles the simulation at the current value, or interrupts the
  /// simulation immediately
  ///
  /// Unlike [AnimationController.stop], [canceled] defaults to false.
  /// If you set it to true, the simulation will be stopped immediately.
  /// Otherwise, the simulation will redirect to settle at the current value, if
  /// [Motion.needsSettle] is true for the current [motion].
  TickerFuture stop({bool canceled = false}) {
    if (canceled || !motion.needsSettle) {
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
