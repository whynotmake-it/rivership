import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor/src/controllers/motion_controller.dart';

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
class VelocityMotionBuilder<T extends Object> extends StatefulWidget {
  /// Creates a [VelocityMotionBuilder] with a single [motion].
  const VelocityMotionBuilder({
    required this.value,
    required Motion this.motion,
    required this.converter,
    required this.builder,
    this.active = true,
    this.onAnimationStatusChanged,
    this.from,
    this.child,
    super.key,
  }) : motionPerDimension = null;

  /// Creates a [VelocityMotionBuilder] with a separate [motion] for each
  /// dimension.
  const VelocityMotionBuilder.motionPerDimension({
    required this.value,
    required List<Motion> this.motionPerDimension,
    required this.converter,
    required this.builder,
    this.active = true,
    this.onAnimationStatusChanged,
    this.from,
    this.child,
    super.key,
  }) : motion = null;

  /// {@macro motor.MotionBuilder.value}
  final T value;

  /// {@macro motor.MotionBuilder.from}
  final T? from;

  /// {@template motor.VelocityMotionBuilder.builder}
  /// Called to build the child widget.
  ///
  /// The [builder] function is passed the interpolated [value] and the current
  /// velocity from the animation.
  /// {@endtemplate}
  final VelocityMotionWidgetBuilder<T> builder;

  /// {@macro motor.MotionBuilder.motion}
  final Motion? motion;

  /// {@macro motor.MotionBuilder.motionPerDimension}
  final List<Motion>? motionPerDimension;

  /// {@template motor.MotionBuilder.converter}
  /// The converter to use to convert [T] into its normalized form of values.
  ///
  /// See also:
  ///
  /// * [MotionConverter]
  /// * [SingleMotionConverter]
  /// * [OffsetMotionConverter]
  /// * ...
  /// {@endtemplate}
  final MotionConverter<T> converter;

  /// {@template motor.simulate}
  /// Whether the motion is active.
  ///
  /// If false, the [value] will be immediately set to the target value in
  /// [builder].
  /// {@endtemplate}
  final bool active;

  /// {@template motor.on_animation_status_changed}
  /// Called when the animation status changes.
  /// {@endtemplate}
  final ValueChanged<AnimationStatus>? onAnimationStatusChanged;

  /// {@template motor.child}
  /// The child widget to animate.
  /// {@endtemplate}
  final Widget? child;

  @override
  State<VelocityMotionBuilder<T>> createState() => _MotionBuilderState<T>();
}

class _MotionBuilderState<T extends Object>
    extends State<VelocityMotionBuilder<T>> with TickerProviderStateMixin {
  late MotionController<T> controller;

  @override
  void initState() {
    super.initState();
    controller = switch (widget.motion) {
      final motion? => MotionController(
          motion: motion,
          vsync: this,
          initialValue: widget.from ?? widget.value,
          converter: widget.converter,
        ),
      null => MotionController.motionPerDimension(
          motionPerDimension: widget.motionPerDimension!,
          vsync: this,
          initialValue: widget.from ?? widget.value,
          converter: widget.converter,
        ),
    };

    if (widget.onAnimationStatusChanged != null) {
      controller.addStatusListener(widget.onAnimationStatusChanged!);
    }
    if (widget.active && widget.from != null) {
      controller.animateTo(widget.value);
    }
  }

  @override
  void didUpdateWidget(covariant VelocityMotionBuilder<T> oldWidget) {
    if (widget.motion != oldWidget.motion ||
        !motionsEqual(
          widget.motionPerDimension,
          oldWidget.motionPerDimension,
        )) {
      switch (widget.motion) {
        case final motion?:
          controller.motion = motion;
        case null:
          controller.motionPerDimension = widget.motionPerDimension!;
      }
    }
    if (!widget.active) {
      controller
        ..stop()
        ..value = widget.value;
    }

    if (widget.value != oldWidget.value) {
      if (widget.active) {
        controller.animateTo(widget.value);
      } else {
        controller.value = widget.value;
      }
    }

    if (widget.onAnimationStatusChanged != oldWidget.onAnimationStatusChanged) {
      if (oldWidget.onAnimationStatusChanged != null) {
        controller.removeStatusListener(oldWidget.onAnimationStatusChanged!);
      }
      if (widget.onAnimationStatusChanged != null) {
        controller.addStatusListener(widget.onAnimationStatusChanged!);
      }
    }

    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        return widget.builder(
          context,
          controller.value,
          controller.velocity,
          child,
        );
      },
      child: widget.child,
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
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
    super.active = true,
    super.onAnimationStatusChanged,
    super.from,
    super.child,
    super.key,
  }) : super(converter: const SingleMotionConverter());
}
