import 'package:flutter/widgets.dart';
import 'package:springster/src/motion/motion_controller_base.dart';
import 'package:springster/src/motion/motion_style.dart';

/// A controller that manages a multi-dimensional motion.
///
/// It works directly with [List<double>] values, managing multiple animation
/// dimensions simultaneously.
class MotionController extends MotionControllerBase<double> {
  /// Creates a [MotionController] with the given parameters.
  MotionController({
    required super.motion,
    required super.vsync,
    super.lowerBound = 0,
    super.upperBound = 1,
    super.initialValue = 0,
    super.behavior = AnimationBehavior.normal,
  }) : super(
          normalize: (value) => [value],
          denormalize: (values) => values.first,
        );

  /// Creates an unbounded [MotionController].
  ///
  /// This controller will not have a lower or upper bound, and will use the
  /// [AnimationBehavior.preserve] behavior.
  MotionController.unbounded({
    required Motion motion,
    required TickerProvider vsync,
    double initialValue = 0,
    AnimationBehavior behavior = AnimationBehavior.preserve,
  }) : this(
          motion: motion,
          vsync: vsync,
          lowerBound: double.negativeInfinity,
          upperBound: double.infinity,
          behavior: behavior,
          initialValue: initialValue,
        );
}
