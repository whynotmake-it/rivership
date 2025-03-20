import 'package:flutter/widgets.dart';
import 'package:springster/src/motion/motion_controller_base.dart';
import 'package:springster/src/motion/motion_style.dart';

/// A controller that manages a multi-dimensional motion.
///
/// It works directly with [List<double>] values, managing multiple animation
/// dimensions simultaneously.
class PolyMotionController extends MotionControllerBase<List<double>> {
  /// Creates a [PolyMotionController] with the given parameters.
  ///
  /// The [lowerBound], [upperBound], and [initialValue] parameters must have
  /// the same length.
  PolyMotionController({
    required super.motion,
    required super.vsync,
    super.lowerBound = const [0, 0],
    super.upperBound = const [1, 1],
    super.initialValue = const [0, 0],
    super.behavior = AnimationBehavior.normal,
  })  : assert(
          lowerBound.length == upperBound.length,
          'lowerBound and upperBound must have the same length',
        ),
        assert(
          initialValue.length == lowerBound.length,
          'initialValue must have the same length as lowerBound and upperBound',
        ),
        super(
          normalize: (value) => value, // Identity function for List<double>
          denormalize: (values) => values, // Identity function for List<double>
        );

  /// Creates an unbounded [PolyMotionController].
  ///
  /// This controller will not have a lower or upper bound, and will use the
  /// [AnimationBehavior.preserve] behavior by default.
  PolyMotionController.unbounded({
    required Motion motion,
    required TickerProvider vsync,
    required List<double> initialValue,
    AnimationBehavior behavior = AnimationBehavior.preserve,
  }) : this(
          motion: motion,
          vsync: vsync,
          lowerBound: List.filled(initialValue.length, double.negativeInfinity),
          upperBound: List.filled(initialValue.length, double.infinity),
          initialValue: initialValue,
          behavior: behavior,
        );

  /// The dimensionality of the motion.
  int get dimensionality => lowerBound.length;
}
