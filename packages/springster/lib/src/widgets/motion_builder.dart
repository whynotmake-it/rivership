import 'package:flutter/widgets.dart';
import 'package:springster/src/controllers/motion_controller.dart';
import 'package:springster/src/motion.dart';
import 'package:springster/src/motion_converter.dart';

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
class MotionBuilder<T extends Object> extends StatefulWidget {
  /// Creates a [MotionBuilder].
  const MotionBuilder({
    required this.value,
    required this.motion,
    required this.converter,
    required this.builder,
    this.active = true,
    this.onAnimationStatusChanged,
    this.from,
    this.child,
    super.key,
  });

  /// {@template springster.MotionBuilder.value}
  /// The target value for the transition.
  ///
  /// Whenever this value changes, the widget smoothly animates from
  /// the previous value to the new one.
  /// {@endtemplate}
  final T value;

  /// {@template springster.MotionBuilder.from}
  /// The starting value for the initial animation.
  ///
  /// If this value is null, the widget will start out at [value].
  ///
  /// This is only considered for the first animation, any subsequent changes
  /// during the lifecycle of this widget will be ignored.
  /// {@endtemplate}
  final T? from;

  /// {@template springster.MotionBuilder.builder}
  /// Called to build the child widget.
  ///
  /// The [builder] function is passed the interpolated [value] from the spring
  /// animation.
  /// {@endtemplate}
  final ValueWidgetBuilder<T> builder;

  /// {@template springster.MotionBuilder.motion}
  /// The motion to use for the animation.
  /// {@endtemplate}
  final Motion motion;

  /// {@template springster.MotionBuilder.converter}
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

  /// {@template springster.simulate}
  /// Whether the motion is active.
  ///
  /// If false, the [value] will be immediately set to the target value in
  /// [builder].
  /// {@endtemplate}
  final bool active;

  /// {@template springster.on_animation_status_changed}
  /// Called when the animation status changes.
  /// {@endtemplate}
  final ValueChanged<AnimationStatus>? onAnimationStatusChanged;

  /// {@template springster.child}
  /// The child widget to animate.
  /// {@endtemplate}
  final Widget? child;

  @override
  State<MotionBuilder<T>> createState() => _MotionBuilderState<T>();
}

class _MotionBuilderState<T extends Object> extends State<MotionBuilder<T>>
    with TickerProviderStateMixin {
  late MotionController<T> controller;

  @override
  void initState() {
    super.initState();
    controller = MotionController<T>(
      motion: widget.motion,
      vsync: this,
      initialValue: widget.from ?? widget.value,
      converter: widget.converter,
    );
    if (widget.onAnimationStatusChanged != null) {
      controller.addStatusListener(widget.onAnimationStatusChanged!);
    }
    if (widget.active && widget.from != null) {
      controller.animateTo(widget.value);
    }
  }

  @override
  void didUpdateWidget(covariant MotionBuilder<T> oldWidget) {
    if (widget.motion != oldWidget.motion) {
      controller.motion = widget.motion;
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
        return widget.builder(context, controller.value, child);
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

/// A [MotionBuilder] that animates a single value.
///
/// {@macro springster.MotionBuilder}
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
  }) : super(
          converter: const SingleMotionConverter(),
        );
}
