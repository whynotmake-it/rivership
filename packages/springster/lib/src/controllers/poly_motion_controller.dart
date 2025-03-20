import 'package:flutter/widgets.dart';
import 'package:springster/src/controllers/motion_controller.dart';
import 'package:springster/src/motion_converter.dart';

/// A controller that manages a multi-dimensional motion.
///
/// It works directly with [List<double>] values, managing multiple animation
/// dimensions simultaneously.
class PolyMotionController extends MotionController<List<double>> {
  /// Creates a [PolyMotionController] with the given parameters.
  PolyMotionController({
    required super.motion,
    required super.vsync,
    super.initialValue = const [0, 0],
    super.behavior = AnimationBehavior.normal,
  }) : super(
          converter: MotionConverter(
            denormalize: (values) => values,
            normalize: (value) => value,
          ),
        );
}

/// A [PolyMotionController] that is bounded.
///
/// {@macro springster.MotionController.boundedExplainer}
///
/// The [lowerBound], [upperBound], and [initialValue] parameters must have
/// the same length.
class PolyMotionControllerBounded extends BoundedMotionController<List<double>>
    implements PolyMotionController {
  /// Creates a [PolyMotionControllerBounded].
  PolyMotionControllerBounded({
    required super.motion,
    required super.vsync,
    required super.initialValue,
    required super.lowerBound,
    required super.upperBound,
    super.behavior,
  })  : assert(
          initialValue.length == lowerBound.length,
          'initialValue must have the same length as lowerBound and upperBound',
        ),
        assert(
          lowerBound.length == upperBound.length,
          'lowerBound and upperBound must have the same length',
        ),
        super(
          converter: MotionConverter(
            denormalize: (values) => values,
            normalize: (value) => value,
          ),
        );
}
