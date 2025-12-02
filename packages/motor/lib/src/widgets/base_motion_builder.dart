import 'package:flutter/widgets.dart';
import 'package:motor/src/controllers/motion_controller.dart';
import 'package:motor/src/motion.dart';
import 'package:motor/src/motion_converter.dart';

/// Base class for motion builders that provides shared functionality.
abstract class BaseMotionBuilder<T extends Object> extends StatefulWidget {
  /// Creates a [BaseMotionBuilder] with a single [motion].
  const BaseMotionBuilder({
    required this.value,
    required Motion this.motion,
    required this.converter,
    this.active = true,
    this.onAnimationStatusChanged,
    this.from,
    this.child,
    super.key,
  }) : motionPerDimension = null;

  /// Creates a [BaseMotionBuilder] with a separate [motion] for each dimension.
  const BaseMotionBuilder.motionPerDimension({
    required this.value,
    required List<Motion> this.motionPerDimension,
    required this.converter,
    this.active = true,
    this.onAnimationStatusChanged,
    this.from,
    this.child,
    super.key,
  }) : motion = null;

  /// {@template motor.MotionBuilder.value}
  /// The target value for the transition.
  ///
  /// Whenever this value changes, the widget smoothly animates from
  /// the previous value to the new one.
  /// {@endtemplate}
  final T value;

  /// {@template motor.MotionBuilder.from}
  /// The starting value for the initial animation.
  ///
  /// If this value is null, the widget will start out at [value].
  ///
  /// This is only considered for the first animation, any subsequent changes
  /// during the lifecycle of this widget will be ignored.
  /// {@endtemplate}
  final T? from;

  /// {@template motor.MotionBuilder.motion}
  /// The motion to use for the animation.
  /// {@endtemplate}
  final Motion? motion;

  /// {@template motor.MotionBuilder.motionPerDimension}
  /// The motion to use for each dimension of the animation.
  /// {@endtemplate}
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
  /// builder.
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
  BaseMotionBuilderState<T> createState();
}

/// Base state class that provides shared motion builder functionality.
abstract class BaseMotionBuilderState<T extends Object>
    extends State<BaseMotionBuilder<T>> with TickerProviderStateMixin {
  /// The motion controller that manages the animation.
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
  void didUpdateWidget(covariant BaseMotionBuilder<T> oldWidget) {
    if (widget.converter != oldWidget.converter) {
      controller.converter = widget.converter;
    }

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

  /// Builds the widget using the controller's current value and velocity.
  ///
  /// Subclasses should override this method to provide their specific
  /// builder implementation.
  Widget buildWithController(BuildContext context, Widget? child);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: buildWithController,
      child: widget.child,
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
