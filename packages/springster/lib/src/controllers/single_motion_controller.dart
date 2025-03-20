import 'package:flutter/widgets.dart';
import 'package:springster/src/controllers/motion_controller.dart';
import 'package:springster/src/motion.dart';
import 'package:springster/src/motion_converter.dart';

/// A controller that manages a single-dimensional motion.
///
/// It works directly with [double] values.
class SingleMotionController extends MotionController<double> {
  /// Creates a [SingleMotionController] with the given parameters.
  SingleMotionController({
    required super.motion,
    required super.vsync,
    super.initialValue = 0,
    super.behavior = AnimationBehavior.normal,
  }) : super(
          converter: const SingleMotionConverter(),
        );

  /// Creates a [SingleMotionControllerBounded].
  factory SingleMotionController.bounded({
    required SpringMotion motion,
    required TickerProvider vsync,
    double initialValue,
    double lowerBound,
    double upperBound,
    AnimationBehavior behavior,
  }) = SingleMotionControllerBounded;
}

/// A [SingleMotionController] that is bounded.
///
/// {@macro springster.MotionController.boundedExplainer}
class SingleMotionControllerBounded extends BoundedMotionController<double>
    implements SingleMotionController {
  /// Creates a [SingleMotionControllerBounded].
  SingleMotionControllerBounded({
    required super.motion,
    required super.vsync,
    super.initialValue = 0,
    super.lowerBound = 0,
    super.upperBound = 1,
    super.behavior,
  }) : super(
          converter: const SingleMotionConverter(),
        );
}
