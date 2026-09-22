import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor/src/widgets/base_motion_builder.dart';

/// Builds a [Widget] when given a concrete value and velocity of a [Motion].
///
/// If the `child` parameter provided to the [ValueListenableBuilder] is not
/// null, the same `child` widget is passed back to this [ValueWidgetBuilder]
/// and should typically be incorporated in the returned widget tree.
typedef VelocityMotionWidgetBuilder<T> = Widget Function(
  BuildContext context,
  T value,
  T velocity,
  Widget? child,
);

/// A widget that animates a value using a dynamic motion.
///
/// Let's say for example you want to animate [Alignment]:
///
/// ```dart
/// Widget build(BuildContext context) {
///   return MotionBuilder(
///     value: Alignment.center,
///     motion: SpringMotion(Spring()),
///     converter: const AlignmentMotionConverter(),
///     builder: (context, value, child) => Align(
///       alignment: value,
///       child: child,
///     ),
///     child: const FlutterLogo(),
///   );
/// }
/// ```
///
/// See also:
/// * [MotionBuilder] for simpler variant of this widget for when you don't need
///  the velocity of the motion.
/// * [SingleVelocityMotionBuilder] for a motion builder that animates a single
/// value.
class VelocityMotionBuilder<T extends Object> extends BaseMotionBuilder<T> {
  /// Creates a [VelocityMotionBuilder] with a single [motion].
  const VelocityMotionBuilder({
    required super.value,
    required super.motion,
    required super.converter,
    required this.builder,
    super.velocityTracking,
    super.active = true,
    super.onAnimationStatusChanged,
    super.from,
    super.child,
    super.key,
  });

  /// Creates a [VelocityMotionBuilder] with a separate [motion] for each
  /// dimension.
  const VelocityMotionBuilder.motionPerDimension({
    required super.value,
    required super.motionPerDimension,
    required super.converter,
    required this.builder,
    super.velocityTracking,
    super.active = true,
    super.onAnimationStatusChanged,
    super.from,
    super.child,
    super.key,
  }) : super.motionPerDimension();

  /// {@template motor.VelocityMotionBuilder.builder}
  /// Called to build the child widget.
  ///
  /// The [builder] function is passed the interpolated [value] and the current
  /// velocity from the animation.
  /// {@endtemplate}
  final VelocityMotionWidgetBuilder<T> builder;

  @override
  BaseMotionBuilderState<T> createState() => _VelocityMotionBuilderState<T>();
}

class _VelocityMotionBuilderState<T extends Object>
    extends BaseMotionBuilderState<T> {
  @override
  VelocityMotionBuilder<T> get widget =>
      super.widget as VelocityMotionBuilder<T>;

  @override
  Widget buildWithController(BuildContext context, Widget? child) {
    return widget.builder(
      context,
      controller.value,
      controller.velocity,
      child,
    );
  }
}

/// A [VelocityMotionBuilder] that animates a single value.
///
/// {@macro motor.MotionBuilder}
class SingleVelocityMotionBuilder extends VelocityMotionBuilder<double> {
  /// Creates a [SingleVelocityMotionBuilder].
  const SingleVelocityMotionBuilder({
    required super.value,
    required super.motion,
    required super.builder,
    super.velocityTracking,
    super.active = true,
    super.onAnimationStatusChanged,
    super.from,
    super.child,
    super.key,
  }) : super(converter: const SingleMotionConverter());
}
