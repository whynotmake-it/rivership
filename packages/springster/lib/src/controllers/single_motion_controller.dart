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

  /// Creates a [BoundedSingleMotionController].
  factory SingleMotionController.bounded({
    required Spring motion,
    required TickerProvider vsync,
    double initialValue,
    double lowerBound,
    double upperBound,
    AnimationBehavior behavior,
  }) = BoundedSingleMotionController;
}

/// A [SingleMotionController] that is bounded.
///
/// {@macro springster.MotionController.boundedExplainer}
class BoundedSingleMotionController extends BoundedMotionController<double>
    implements SingleMotionController {
  /// Creates a [BoundedSingleMotionController].
  BoundedSingleMotionController({
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
