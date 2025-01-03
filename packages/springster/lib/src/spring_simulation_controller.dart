import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// A controller that manages a spring simulation.
///
/// This controller can be used to drive spring animations with a target value,
/// while maintaining velocity between target changes.
///
/// The controller extends [ValueNotifier] to notify listeners of value changes,
/// and provides access to the current velocity of the simulation.
class SpringSimulationController extends Animation<double>
    with
        AnimationLocalListenersMixin,
        AnimationLocalStatusListenersMixin,
        AnimationEagerListenerMixin {
  /// Creates a [SpringSimulationController] with the given parameters.
  ///
  /// The [spring] parameter defines the characteristics of the spring animation.
  /// The [vsync] parameter is required to drive the animation.
  /// The [lowerBound] and [upperBound] parameters are optional and can be used
  /// to constrain the animation value.
  SpringSimulationController({
    required SpringDescription spring,
    required TickerProvider vsync,
    this.lowerBound = double.negativeInfinity,
    this.upperBound = double.infinity,
    double? initialValue,
  })  : _spring = spring,
        _controller = AnimationController(
          value: initialValue,
          vsync: vsync,
          lowerBound: lowerBound,
          upperBound: upperBound,
        ) {
    _controller.addListener(_onAnimationUpdate);
  }

  @override
  double get value => _controller.value;

  set value(double value) {
    _controller.value = 0;
  }

  @override
  AnimationStatus get status => _controller.status;

  final AnimationController _controller;

  SpringDescription _spring;

  double _absoluteVelocity = 0;

  double _target = 0;

  double _lastValue = 0;

  DateTime? _lastUpdate;

  /// The lower bound of the animation value.
  final double lowerBound;

  /// The upper bound of the animation value.
  final double upperBound;

  /// The current velocity of the animation.
  double get velocity => _absoluteVelocity;

  /// The spring description that defines the animation characteristics.
  SpringDescription get spring => _spring;

  /// Updates the spring description.
  ///
  /// This will create a new simulation with the current velocity if an
  /// animation is in progress.
  set spring(SpringDescription newSpring) {
    if (_spring == newSpring) return;
    _spring = newSpring;
    _redirectSimulation();
  }

  /// Updates the target value and creates a new simulation with the current
  /// velocity.
  TickerFuture animateTo(
    double target, {
    double? from,
    double? withVelocity,
  }) {
    _target = target.clamp(lowerBound, upperBound);

    final fromValue = from ?? value;

    if (_target == fromValue) return TickerFuture.complete();

    final absoluteVelocity = withVelocity ?? _absoluteVelocity;

    final simulation = SpringSimulation(
      _spring,
      fromValue,
      _target,
      absoluteVelocity,
    );

    return _controller.animateWith(simulation);
  }

  void _onAnimationUpdate() {
    notifyListeners();
    if (_lastUpdate != null) {
      final now = DateTime.now();
      final timeDelta = now.difference(_lastUpdate!).inMilliseconds * 1000;
      final valueDelta = _lastValue - value;
      _absoluteVelocity = valueDelta / timeDelta;
    }
    _lastUpdate = DateTime.now();
    _lastValue = value;
  }

  void _redirectSimulation() {
    if (!_controller.isAnimating) return;

    final simulation = SpringSimulation(
      _spring,
      value,
      _target,
      _absoluteVelocity,
    );
    _controller.animateWith(simulation);
  }

  /// Stops the animation.
  void stop() {
    _controller.stop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
