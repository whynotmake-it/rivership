import 'package:flutter/widgets.dart';
import 'package:springster/src/spring_simulation_controller.dart';

typedef Value2D = (double x, double y);

/// A controller that manages a 2D spring simulation.
///
/// This controller can be used to drive spring animations with a target value
/// in two dimensions, while maintaining velocity between target changes.
///
/// The controller extends [ValueNotifier] to notify listeners of value changes,
/// and provides access to the current velocity of the simulation.
class SpringSimulationController2D extends Animation<Value2D>
    with
        AnimationLocalListenersMixin,
        AnimationLocalStatusListenersMixin,
        AnimationEagerListenerMixin {
  /// Creates a [SpringSimulationController2D] with the given parameters.
  ///
  /// The [spring] parameter defines the characteristics of the spring
  /// animation.
  /// The [vsync] parameter is required to drive the animation.
  /// The [lowerBound] and [upperBound] parameters are optional and can be used
  /// to constrain the animation value.
  SpringSimulationController2D({
    required SpringDescription spring,
    required TickerProvider vsync,
    Value2D lowerBound = const (
      double.negativeInfinity,
      double.negativeInfinity,
    ),
    Value2D upperBound = const (double.infinity, double.infinity),
    Value2D initialValue = const (0, 0),
  })  : _spring = spring,
        _lowerBound = lowerBound,
        _upperBound = upperBound,
        _xController = SpringSimulationController(
          spring: spring,
          vsync: vsync,
          lowerBound: lowerBound.x,
          upperBound: upperBound.x,
          initialValue: initialValue.x,
        ),
        _yController = SpringSimulationController(
          spring: spring,
          vsync: vsync,
          lowerBound: lowerBound.y,
          upperBound: upperBound.y,
          initialValue: initialValue.y,
        ) {
    _xController.addListener(_onControllerUpdate);
    _yController.addListener(_onControllerUpdate);
  }

  @override
  Value2D get value => (
        _xController.value,
        _yController.value,
      );

  set value(Value2D newValue) {
    _xController.value = newValue.x;
    _yController.value = newValue.y;
  }

  @override
  AnimationStatus get status => _xController.status;

  final SpringSimulationController _xController;
  final SpringSimulationController _yController;
  SpringDescription _spring;
  final Value2D _lowerBound;
  final Value2D _upperBound;

  /// The current velocity of the animation.
  Value2D get velocity => (
        _xController.velocity,
        _yController.velocity,
      );

  /// The spring description that defines the animation characteristics.
  SpringDescription get spring => _spring;

  /// Updates the spring description.
  ///
  /// This will create a new simulation with the current velocity if an animation
  /// is in progress.
  set spring(SpringDescription newSpring) {
    if (_spring == newSpring) return;
    _spring = newSpring;
    _xController.spring = newSpring;
    _yController.spring = newSpring;
  }

  /// Updates the target value and creates a new simulation with the current
  /// velocity.
  TickerFuture animateTo(
    Value2D target, {
    Value2D? from,
    Value2D? withVelocity,
  }) {
    final clamped = (
      target.x.clamp(_lowerBound.x, _upperBound.x),
      target.y.clamp(_lowerBound.y, _upperBound.y),
    );

    final xFuture = _xController.animateTo(
      clamped.x,
      from: from?.x,
      withVelocity: withVelocity?.x,
    );
    _yController.animateTo(
      clamped.y,
      from: from?.y,
      withVelocity: withVelocity?.y,
    );

    return xFuture;
  }

  void _onControllerUpdate() {
    notifyListeners();
  }

  /// Stops the animation.
  void stop() {
    _xController.stop();
    _yController.stop();
  }

  @override
  void dispose() {
    _xController.dispose();
    _yController.dispose();
    super.dispose();
  }
}

/// Extension methods for [Value2D].
extension Value2DGetters on Value2D {
  /// The x value of the 2D value.
  double get x => this.$1;

  /// The y value of the 2D value.
  double get y => this.$2;
}
