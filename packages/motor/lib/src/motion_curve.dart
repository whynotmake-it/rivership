import 'package:flutter/animation.dart';
import 'package:motor/motor.dart';

/// A Curve that is represented by a [Motion].
///
/// {@template motion_curve}
///
/// This can be used as an easing curve for widgets that do not support
/// physics-based animations.
///
/// **Note**: This should only be used if you really need to use Flutter's
/// built-in widgets. In most cases you will want to use a [MotionController],
/// [MotionBuilder], etc., since they offer all the benefits of physics-based
/// animations.
///
/// You can also apply an initial velocity to the motion.
///
/// ```dart
///  AnimatedContainer(
///   duration: const Duration(milliseconds: 500),
///   curve: MotionCurve(spring: CupertinoMotion.bouncy, velocity: .3),
///   height: size,
///   width: size,
///   color: Colors.blue,
/// ),
/// ```
/// {@endtemplate}
class MotionCurve extends Curve {
  /// Creates a [Curve] that represents [motion], assuming a starting [velocity]
  ///
  /// {@macro motion_curve}
  MotionCurve({
    required this.motion,
    double velocity = 0,
  }) : _simulation = motion.createSimulation(velocity: velocity);

  /// The spring the curve is based on.
  final Motion motion;

  final Simulation _simulation;

  /// The simulation used for the spring.
  Simulation get simulation => _simulation;

  @override
  double transform(double t) {
    return _simulation.x(t);
  }
}

/// Converts a [Motion] to a [MotionCurve].
extension CurveConversion on Motion {
  /// Converts a [Motion] to a [MotionCurve].
  MotionCurve get toCurve => MotionCurve(motion: this);

  /// Converts a [Motion] to a [MotionCurve] with an initial velocity.
  MotionCurve toCurveWithVelocity(double velocity) {
    return MotionCurve(motion: this, velocity: velocity);
  }
}
