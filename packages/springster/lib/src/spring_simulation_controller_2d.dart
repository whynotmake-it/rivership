import 'package:flutter/widgets.dart';
import 'package:springster/src/spring_simulation_controller.dart';
import 'package:springster/src/spring_simulation_controller_base.dart';

/// A simple 2d record type.
typedef Double2D = (double x, double y);

/// A controller that manages a 2D spring simulation.
///
/// This controller can be used to drive spring animations with a target value
/// in two dimensions, while maintaining velocity between target changes.
///
/// The controller extends [ValueNotifier] to notify listeners of value changes,
/// and provides access to the current velocity of the simulation.
class SpringSimulationController2D extends Animation<Double2D>
    with
        AnimationLocalListenersMixin,
        AnimationLocalStatusListenersMixin,
        AnimationEagerListenerMixin
    implements SpringSimulationControllerBase<Double2D> {
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
    Double2D lowerBound = const (
      double.negativeInfinity,
      double.negativeInfinity,
    ),
    Double2D upperBound = const (double.infinity, double.infinity),
    Double2D initialValue = const (0, 0),
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
        );

  @override
  Double2D get value => (
        _xController.value,
        _yController.value,
      );

  set value(Double2D newValue) {
    _xController.value = newValue.x;
    _yController.value = newValue.y;
  }

  @override
  AnimationStatus get status =>
      (_listeningToY ?? false) ? _yController.status : _xController.status;

  final SpringSimulationController _xController;
  final SpringSimulationController _yController;
  SpringDescription _spring;
  final Double2D _lowerBound;
  final Double2D _upperBound;

  @override
  Double2D get lowerBound => _lowerBound;

  @override
  Double2D get upperBound => _upperBound;

  @override
  Double2D get velocity => (
        _xController.velocity,
        _yController.velocity,
      );

  @override
  SpringDescription get spring => _spring;

  @override
  set spring(SpringDescription newSpring) {
    if (_spring == newSpring) return;
    _spring = newSpring;
    _xController.spring = newSpring;
    _yController.spring = newSpring;
  }

  @override
  Tolerance get tolerance => _xController.tolerance;

  @override
  void resync(TickerProvider ticker) {
    _xController.resync(ticker);
    _yController.resync(ticker);
  }

  bool? _listeningToY;
  void _setListeningToY(bool value) {
    if (value == _listeningToY) return;
    _listeningToY = value;
    if (value) {
      _xController
        ..removeListener(notifyListeners)
        ..removeStatusListener(notifyStatusListeners);
      _yController
        ..addListener(notifyListeners)
        ..addStatusListener(notifyStatusListeners);
    } else {
      _yController
        ..removeListener(notifyListeners)
        ..removeStatusListener(notifyStatusListeners);
      _xController
        ..addListener(notifyListeners)
        ..addStatusListener(notifyStatusListeners);
    }
  }

  @override
  TickerFuture animateTo(
    Double2D target, {
    Double2D? from,
    Double2D? withVelocity,
  }) {
    final clamped = (
      target.x.clamp(_lowerBound.x, _upperBound.x),
      target.y.clamp(_lowerBound.y, _upperBound.y),
    );

    final fromValue = from ?? value;

    final xChanged =
        _xController.tolerance.distance < (clamped.x - fromValue.x).abs();

    final yChanged =
        _yController.tolerance.distance < (clamped.y - fromValue.y).abs();

    TickerFuture y() => _yController.animateTo(
          clamped.y,
          from: fromValue.y,
          withVelocity: withVelocity?.y,
        );

    // Start both animations but only return the future from one, since the
    // x controller is the base for everything.
    TickerFuture x() => _xController.animateTo(
          clamped.x,
          from: fromValue.x,
          withVelocity: withVelocity?.x,
        );

    if (xChanged) {
      _setListeningToY(false);
      y();
      return x();
    }

    if (yChanged) {
      _setListeningToY(true);
      return y();
    }

    return TickerFuture.complete();
  }

  @override
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

/// Extension methods for [Double2D].
extension Value2DGetters on Double2D {
  /// The x value of the 2D value.
  double get x => this.$1;

  /// The y value of the 2D value.
  double get y => this.$2;

  /// Converts the 2D value to an [Offset].
  Offset toOffset() => Offset(x, y);
}
