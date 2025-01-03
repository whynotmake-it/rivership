import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:springster/springster.dart';

/// Builds a widget that continuously animates a value using a Spring simulation
/// with a given [SpringDescription].
///
/// See also:
///   * [useSpringAnimation], which provides the underlying animation hook
///   * [SpringBuilder2D], which animates two values simultaneously
class SpringBuilder extends StatefulWidget {
  /// Creates a widget that animates a single value using spring physics.
  ///
  /// The [builder], [spring], and [value] arguments must not be null.
  const SpringBuilder({
    required this.value,
    required this.spring,
    required this.builder,
    this.simulate = true,
    this.child,
    super.key,
  });

  /// The target value for the transition.
  ///
  /// Whenever this value changes, the widget smoothly animates from
  /// the previous value to the new one.
  final double value;

  /// Called to build the child widget.
  ///
  /// The [builder] function is passed the interpolated value from the spring
  /// animation.
  final ValueWidgetBuilder<double> builder;

  /// The spring behavior of the transition.
  ///
  /// Modify this for bounciness and duration.
  final SpringDescription spring;

  /// Whether to simulate the spring animation.
  ///
  /// If false, the animation will be immediately set to the target value.
  final bool simulate;

  /// The child widget to animate.
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
      initialValue: widget.value,
    );
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
        print('animateTo ${widget.value}');
        controller.animateTo(widget.value);
      } else {
        controller.value = widget.value;
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

/// Builds a widget that continuously animates two values using a Spring
/// simulation with a given [SpringDescription].
///
/// See also:
///   * [use2DSpringAnimation], which provides the underlying animation hook
///   * [SpringBuilder], which animates a single value
class SpringBuilder2D<T> extends HookWidget {
  /// Creates a widget that animates two values using spring physics.
  ///
  /// The [builder], [spring], and [value] arguments must not be null.
  const SpringBuilder2D({
    required this.builder,
    required this.spring,
    required this.value,
    this.simulate = true,
    this.child,
    super.key,
  });

  /// The target (x,y) values for the transition.
  ///
  /// Whenever these values change, the widget smoothly animates from
  /// the previous values to the new ones.
  final (T x, T y) value;

  /// Called to build the child widget.
  ///
  /// The [builder] function is passed the interpolated (x,y) values from the
  /// spring animation.
  final ValueWidgetBuilder<(T x, T y)> builder;

  /// The spring behavior of the transition.
  ///
  /// Modify this for bounciness and duration.
  final SpringDescription spring;

  /// Whether to simulate the spring animation.
  ///
  /// If false, the animation will be immediately set to the target value.
  final bool simulate;

  /// The child widget to animate.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final value = use2DSpringAnimation(
      value: this.value,
      spring: spring,
      simulate: simulate,
    );
    return builder(context, value, child);
  }
}
