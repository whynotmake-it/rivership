import 'package:flutter/widgets.dart';
import 'package:springster/springster.dart';

/// {@template springster.spring_builder}
/// Builds a widget that continuously animates a value using a Spring simulation
/// with a given [SpringDescription].
/// {@endtemplate}
///
/// See also:
///   * [SpringBuilder2D], which animates two values simultaneously
class SpringBuilder extends StatefulWidget {
  /// {@template springster.spring_builder.constructor}
  /// Creates a widget that animates a single value using spring physics.
  ///
  /// The [builder], [spring], and [value] arguments must not be null.
  /// {@endtemplate}
  const SpringBuilder({
    required this.value,
    required this.spring,
    required this.builder,
    this.from,
    this.simulate = true,
    this.child,
    this.onAnimationStatusChanged,
    super.key,
  });

  /// {@template springster.target_value}
  /// The target value for the transition.
  ///
  /// Whenever this value changes, the widget smoothly animates from
  /// the previous value to the new one.
  /// {@endtemplate}
  final double value;

  /// {@template springster.from_value}
  /// The starting value for the initial animation.
  ///
  /// If this value is null, the widget will start out at [value].
  ///
  /// This is only considered for the first animation, any subsequent changes
  /// during the lifecycle of this widget will be ignored.
  /// {@endtemplate}
  final double? from;

  /// {@template springster.builder}
  /// Called to build the child widget.
  ///
  /// The [builder] function is passed the interpolated value from the spring
  /// animation.
  /// {@endtemplate}
  final ValueWidgetBuilder<double> builder;

  /// {@template springster.spring}
  /// The spring behavior of the transition.
  ///
  /// Modify this for bounciness and duration.
  /// {@endtemplate}
  final SpringDescription spring;

  /// {@template springster.simulate}
  /// Whether to simulate the spring animation.
  ///
  /// If false, the animation will be immediately set to the target value.
  /// {@endtemplate}
  final bool simulate;

  /// {@template springster.on_animation_status_changed}
  /// Called when the animation status changes.
  /// {@endtemplate}
  final ValueChanged<AnimationStatus>? onAnimationStatusChanged;

  /// {@template springster.child}
  /// The child widget to animate.
  /// {@endtemplate}
  final Widget? child;

  @override
  State<SpringBuilder> createState() => _SpringBuilderState();
}

class _SpringBuilderState extends State<SpringBuilder>
    with SingleTickerProviderStateMixin {
  late SpringSimulationController controller;

  @override
  void initState() {
    super.initState();
    controller = SpringSimulationController(
      spring: widget.spring,
      vsync: this,
      initialValue: widget.from ?? widget.value,
    );
    if (widget.onAnimationStatusChanged != null) {
      controller.addStatusListener(widget.onAnimationStatusChanged!);
    }
    if (widget.simulate && widget.from != null) {
      controller.animateTo(widget.value);
    }
  }

  @override
  void didUpdateWidget(covariant SpringBuilder oldWidget) {
    if (widget.spring != oldWidget.spring) {
      controller.spring = widget.spring;
    }
    if (!widget.simulate) {
      controller
        ..stop()
        ..value = widget.value;
    }

    if (widget.value != oldWidget.value) {
      if (widget.simulate) {
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

/// {@template springster.spring_builder_2d}
/// Builds a widget that continuously animates two values using a Spring
/// simulation with a given [SpringDescription].
/// {@endtemplate}
///
/// See also:
///   * [SpringBuilder], which animates a single value
class SpringBuilder2D extends StatefulWidget {
  /// {@template springster.spring_builder_2d.constructor}
  /// Creates a widget that animates two values using spring physics.
  ///
  /// The [builder], [spring], and [value] arguments must not be null.
  /// {@endtemplate}
  const SpringBuilder2D({
    required this.value,
    required this.spring,
    required this.builder,
    this.from,
    this.simulate = true,
    this.child,
    this.onAnimationStatusChanged,
    super.key,
  });

  /// {@macro springster.target_value}
  final Double2D value;

  /// {@macro springster.from_value}
  final Double2D? from;

  /// {@macro springster.builder}
  final ValueWidgetBuilder<Double2D> builder;

  /// {@macro springster.spring}
  final SpringDescription spring;

  /// {@macro springster.simulate}
  final bool simulate;

  /// {@macro springster.on_animation_status_changed}
  final ValueChanged<AnimationStatus>? onAnimationStatusChanged;

  /// {@macro springster.child}
  final Widget? child;

  @override
  State<SpringBuilder2D> createState() => _SpringBuilder2DState();
}

class _SpringBuilder2DState extends State<SpringBuilder2D>
    with TickerProviderStateMixin {
  late SpringSimulationController2D controller;

  @override
  void initState() {
    super.initState();
    controller = SpringSimulationController2D(
      spring: widget.spring,
      vsync: this,
      initialValue: widget.from ?? widget.value,
    );
    if (widget.onAnimationStatusChanged != null) {
      controller.addStatusListener(widget.onAnimationStatusChanged!);
    }
    if (widget.simulate && widget.from != null) {
      controller.animateTo(widget.value);
    }
  }

  @override
  void didUpdateWidget(covariant SpringBuilder2D oldWidget) {
    if (widget.spring != oldWidget.spring) {
      controller.spring = widget.spring;
    }
    if (!widget.simulate) {
      controller
        ..stop()
        ..value = widget.value;
    }

    if (widget.value != oldWidget.value) {
      if (widget.simulate) {
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
