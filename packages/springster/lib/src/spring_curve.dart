import 'package:flutter/animation.dart';
import 'package:flutter/physics.dart';

/// A Curve that is represented by a spring.
///
/// {@template spring_curve}
///
/// This can be used as an easing curve for widgets that do not support
/// spring animations.
///
/// You can also apply a initial velocity to the spring.
///
/// ```dart
///  AnimatedContainer(
///   duration: const Duration(milliseconds: 500),
///   curve: SpringCurve(spring: FluidSpring.bouncy),
///   height: size,
///   width: size,
///   color: Colors.blue,
/// ),
/// ```
/// {@endtemplate}
class SpringCurve extends Curve {
  /// Creates a [SpringCurve] out of [spring].
  ///
  /// {@macro spring_curve}
  SpringCurve({required this.spring, double velocity = 0})
      : _simulation = SpringSimulation(spring, 0, 1, velocity);

  /// The spring the curve is based on.
  final SpringDescription spring;

  final SpringSimulation _simulation;

  /// The simulation used for the spring.
  SpringSimulation get simulation => _simulation;

  @override
  double transform(double t) {
    return _simulation.x(t);
  }
}

/// Converts a [SpringDescription] to a [SpringCurve].
extension CurveConversion on SpringDescription {
  /// Converts a [SpringDescription] to a [SpringCurve].
  SpringCurve get toCurve => SpringCurve(spring: this);
}
