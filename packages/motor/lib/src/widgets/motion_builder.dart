import 'package:flutter/widgets.dart';
import 'package:motor/src/motion_converter.dart';
import 'package:motor/src/widgets/base_motion_builder.dart';

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
/// * [SingleMotionBuilder] for a motion builder that animates a single value.
class MotionBuilder<T extends Object> extends BaseMotionBuilder<T> {
  /// Creates a [MotionBuilder] with a single [motion].
  const MotionBuilder({
    required super.value,
    required super.motion,
    required super.converter,
    required this.builder,
    super.active = true,
    super.onAnimationStatusChanged,
    super.from,
    super.child,
    super.key,
  });

  /// Creates a [MotionBuilder] with a separate [motion] for each dimension.
  const MotionBuilder.motionPerDimension({
    required super.value,
    required super.motionPerDimension,
    required super.converter,
    required this.builder,
    super.active = true,
    super.onAnimationStatusChanged,
    super.from,
    super.child,
    super.key,
  }) : super.motionPerDimension();

  /// {@template motor.MotionBuilder.builder}
  /// Called to build the child widget.
  ///
  /// The [builder] function is passed the interpolated [value] from the
  /// animation.
  /// {@endtemplate}
  final ValueWidgetBuilder<T> builder;

  @override
  BaseMotionBuilderState<T> createState() => _MotionBuilderState<T>();
}

class _MotionBuilderState<T extends Object> extends BaseMotionBuilderState<T> {
  @override
  MotionBuilder<T> get widget => super.widget as MotionBuilder<T>;

  @override
  Widget buildWithController(BuildContext context, Widget? child) {
    return widget.builder(context, controller.value, child);
  }
}

/// A [MotionBuilder] that animates a single value.
///
/// {@macro motor.MotionBuilder}
class SingleMotionBuilder extends MotionBuilder<double> {
  /// Creates a [SingleMotionBuilder].
  const SingleMotionBuilder({
    required super.value,
    required super.motion,
    required super.builder,
    super.active = true,
    super.onAnimationStatusChanged,
    super.from,
    super.child,
    super.key,
  }) : super(converter: const SingleMotionConverter());
}
