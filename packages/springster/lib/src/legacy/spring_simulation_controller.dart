import 'package:flutter/widgets.dart';
import 'package:springster/src/controllers/single_motion_controller.dart';
import 'package:springster/src/legacy/spring_simulation_controller_base.dart';
import 'package:springster/src/motion.dart';

/// A controller that manages a spring simulation.
///
/// This controller can be used to drive spring animations with a target value,
/// while maintaining velocity between target changes.
///
/// The controller extends [ValueNotifier] to notify listeners of value changes,
/// and provides access to the current velocity of the simulation.
@Deprecated('Use SingleMotionController and its derived classes instead')
class SpringSimulationController extends SingleMotionControllerBounded
    implements SpringSimulationControllerBase<double> {
  /// Creates a [SpringSimulationController] with the given parameters.
  ///
  /// The [spring] parameter defines the characteristics of the spring animation
  /// and the [vsync] parameter is required to drive the animation.
  ///
  /// The [lowerBound] and [upperBound] parameters are optional and can be used
  /// to constrain the animation value.
  @Deprecated('Use SingleMotionControllerBounded instead')
  SpringSimulationController({
    required SpringDescription spring,
    required super.vsync,
    super.lowerBound = 0,
    super.upperBound = 1,
    super.behavior = AnimationBehavior.normal,
    super.initialValue = 0,
  }) : super(motion: SpringMotion(spring));

  /// Creates an unbounded [SpringSimulationController].
  ///
  /// This controller will not have a lower or upper bound, and will use the
  /// [AnimationBehavior.preserve] behavior.
  @Deprecated('Use SingleMotionController instead')
  SpringSimulationController.unbounded({
    required SpringDescription spring,
    required super.vsync,
    super.behavior = AnimationBehavior.preserve,
    super.initialValue = 0,
  }) : super(
          motion: SpringMotion(spring),
          lowerBound: double.negativeInfinity,
          upperBound: double.infinity,
        );

  @override
  SpringDescription get spring => (super.motion as SpringMotion).spring;

  @override
  set spring(SpringDescription value) {
    super.motion = SpringMotion(value);
  }

  @override
  bool get isBounded =>
      super.lowerBound != double.negativeInfinity &&
      super.upperBound != double.infinity;

  @override
  Tolerance get tolerance => motion.tolerance;

  @override
  TickerFuture forward({double? from, double? withVelocity}) {
    if (!SpringSimulationControllerBase.assertBounded(this, forward: true)) {
      return TickerFuture.complete();
    }
    return super.forward(from: from, withVelocity: withVelocity);
  }

  @override
  TickerFuture reverse({double? from, double? withVelocity}) {
    if (!SpringSimulationControllerBase.assertBounded(this, forward: false)) {
      return TickerFuture.complete();
    }
    return super.reverse(from: from, withVelocity: withVelocity);
  }
}
