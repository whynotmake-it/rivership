import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';
import 'package:springster/src/spring_simulation_controller_base.dart';

/// A controller that manages a spring simulation.
///
/// This controller can be used to drive spring animations with a target value,
/// while maintaining velocity between target changes.
///
/// The controller extends [ValueNotifier] to notify listeners of value changes,
/// and provides access to the current velocity of the simulation.
class SpringSimulationController extends SpringSimulationControllerBase<double>
    with
        AnimationLocalListenersMixin,
        AnimationLocalStatusListenersMixin,
        AnimationEagerListenerMixin {
  /// Creates a [SpringSimulationController] with the given parameters.
  ///
  /// The [spring] parameter defines the characteristics of the spring animation
  /// and the [vsync] parameter is required to drive the animation.
  ///
  /// The [lowerBound] and [upperBound] parameters are optional and can be used
  /// to constrain the animation value.
  SpringSimulationController({
    required SpringDescription spring,
    required TickerProvider vsync,
    this.lowerBound = 0,
    this.upperBound = 1,
    AnimationBehavior behavior = AnimationBehavior.normal,
    double initialValue = 0,
  })  : _spring = spring,
        _controller = AnimationController(
          value: initialValue,
          vsync: vsync,
          lowerBound: lowerBound,
          upperBound: upperBound,
          animationBehavior: behavior,
        ) {
    _controller
      ..addListener(notifyListeners)
      ..addStatusListener(notifyStatusListeners);
  }

  /// Creates an unbounded [SpringSimulationController].
  ///
  /// This controller will not have a lower or upper bound, and will use the
  /// [AnimationBehavior.preserve] behavior.
  SpringSimulationController.unbounded({
    required SpringDescription spring,
    required TickerProvider vsync,
    AnimationBehavior behavior = AnimationBehavior.preserve,
    double? initialValue,
  }) : this(
          spring: spring,
          vsync: vsync,
          lowerBound: double.negativeInfinity,
          upperBound: double.infinity,
          behavior: behavior,
          initialValue: initialValue ?? 0,
        );

  @override
  final double lowerBound;

  @override
  final double upperBound;

  @override
  bool get isBounded =>
      lowerBound != double.infinity && upperBound != double.infinity;

  @override
  double get value => _controller.value;

  @override
  set value(double value) {
    _controller.value = value;
  }

  @override
  AnimationStatus get status => _controller.status;

  final AnimationController _controller;

  SpringDescription _spring;

  double? _target;

  @override
  double get velocity => _controller.velocity;

  @override
  SpringDescription get spring => _spring;

  @override
  set spring(SpringDescription newSpring) {
    if (_spring == newSpring) return;
    _spring = newSpring;
    _redirectSimulation();
  }

  @override
  Tolerance get tolerance => Tolerance.defaultTolerance;

  @override
  AnimationBehavior get animationBehavior => _controller.animationBehavior;

  @override
  void resync(TickerProvider ticker) => _controller.resync(ticker);

  @override
  TickerFuture animateTo(
    double target, {
    double? from,
    double? withVelocity,
  }) {
    _target = target.clamp(lowerBound, upperBound);

    final fromValue = from ?? value;
    final velocity = withVelocity ?? this.velocity;

    final simulation = SpringSimulation(
      _spring,
      fromValue,
      _target!,
      velocity,
      tolerance: tolerance,
    );

    if ((_target! - fromValue).abs() < simulation.tolerance.distance) {
      _controller.stop();
      return TickerFuture.complete();
    }

    return _controller.animateWith(simulation);
  }

  void _redirectSimulation() {
    if (!_controller.isAnimating || _target == null) return;

    final simulation = SpringSimulation(
      _spring,
      value,
      _target!,
      velocity,
      tolerance: tolerance,
    );
    _controller.animateWith(simulation);
  }

  @override
  void stop() {
    _controller.stop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
