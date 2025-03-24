import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'package:springster/src/controllers/motion_controller.dart';
import 'package:springster/src/legacy/spring_simulation_controller_base.dart';
import 'package:springster/src/motion.dart';
import 'package:springster/src/motion_converter.dart';

/// A simple 2d record type.
typedef Double2D = (double x, double y);

/// A controller that manages a 2D spring simulation.
///
/// This class has been deprecated in favor of [MotionController] and
/// [BoundedMotionController], which support different types of [Motion]s
/// beyond springs, different value types via [MotionConverter]s, and
/// are more efficient and performant. It also uses a [MotionController]
/// internally.
@Deprecated('Use MotionController and its derived classes instead')
class SpringSimulationController2D extends BoundedMotionController<Double2D>
    implements SpringSimulationControllerBase<Double2D> {
  /// Creates a [SpringSimulationController2D] with the given parameters.
  ///
  /// The [spring] parameter defines the characteristics of the spring
  /// animation.
  /// The [vsync] parameter is required to drive the animation.
  /// The [lowerBound] and [upperBound] parameters are optional and can be used
  /// to constrain the animation value.
  @Deprecated('Use BoundedMotionController and its derived classes instead')
  SpringSimulationController2D({
    required SpringDescription spring,
    required super.vsync,
    super.lowerBound = const (0, 0),
    super.upperBound = const (1, 1),
    super.initialValue = const (0, 0),
    super.behavior = AnimationBehavior.normal,
  }) : super(
          motion: SpringMotion(spring),
          converter: const Double2DMotionConverter(),
        );

  /// Creates an unbounded [SpringSimulationController2D].
  ///
  /// This controller will not have a lower or upper bound, and will use the
  /// [AnimationBehavior.preserve] behavior.
  @Deprecated('Use MotionController and its derived classes instead')
  SpringSimulationController2D.unbounded({
    required SpringDescription spring,
    required TickerProvider vsync,
    Double2D initialValue = const (0, 0),
    AnimationBehavior behavior = AnimationBehavior.preserve,
  }) : this(
          spring: spring,
          vsync: vsync,
          lowerBound: (double.negativeInfinity, double.negativeInfinity),
          upperBound: (double.infinity, double.infinity),
          initialValue: initialValue,
          behavior: behavior,
        );

  @override
  bool get isBounded =>
      lowerBound.x != double.negativeInfinity &&
      lowerBound.y != double.negativeInfinity &&
      upperBound.x != double.infinity &&
      upperBound.y != double.infinity;

  @override
  SpringDescription get spring => (motion as SpringMotion).spring;

  @override
  set spring(SpringDescription newSpring) {
    motion = SpringMotion(newSpring);
  }

  @override
  Tolerance get tolerance => motion.tolerance;

  @override
  TickerFuture forward({Double2D? from, Double2D? withVelocity}) {
    if (!SpringSimulationControllerBase.assertBounded(this, forward: true)) {
      return TickerFuture.complete();
    }
    return super.forward(from: from, withVelocity: withVelocity);
  }

  @override
  TickerFuture reverse({Double2D? from, Double2D? withVelocity}) {
    if (!SpringSimulationControllerBase.assertBounded(this, forward: false)) {
      return TickerFuture.complete();
    }
    return super.reverse(from: from, withVelocity: withVelocity);
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

@internal
class Double2DMotionConverter implements MotionConverter<Double2D> {
  const Double2DMotionConverter();
  @override
  Double2D denormalize(List<double> values) => (values[0], values[1]);

  @override
  List<double> normalize(Double2D value) => [value.x, value.y];
}
