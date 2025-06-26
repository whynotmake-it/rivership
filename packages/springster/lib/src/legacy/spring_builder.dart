import 'package:flutter/widgets.dart';
import 'package:springster/springster.dart';

/// {@template springster.spring_builder}
/// Builds a widget that continuously animates a value using a Spring simulation
/// with a given [SpringDescription].
/// {@endtemplate}
///
/// This widget has been deprecated in favor of [SingleMotionBuilder], which
/// supports different types of [Motion]s, not just springs.
@Deprecated('Use SingleMotionBuilder instead')
class SpringBuilder extends StatelessWidget {
  /// {@template springster.spring_builder.constructor}
  /// Creates a widget that animates a single value using spring physics.
  ///
  /// The [builder], [spring], and [value] arguments must not be null.
  /// {@endtemplate}
  @Deprecated('Use SingleMotionBuilder instead')
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
  Widget build(BuildContext context) {
    return SingleMotionBuilder(
      value: value,
      motion: SpringMotion(spring),
      builder: builder,
      active: simulate,
      from: from,
      onAnimationStatusChanged: onAnimationStatusChanged,
      child: child,
    );
  }
}

/// {@template springster.spring_builder_2d}
/// Builds a widget that continuously animates two values using a Spring
/// simulation with a given [SpringDescription].
/// {@endtemplate}
///
/// This widget has been deprecated in favor of [MotionBuilder], which can
/// handle your desired types such as [Offset], [Size], [Rect], etc. using
/// a [MotionConverter], and supports different types of [Motion]s.
@Deprecated('Use MotionBuilder with a sensible converter instead')
class SpringBuilder2D extends StatelessWidget {
  /// {@template springster.spring_builder_2d.constructor}
  /// Creates a widget that animates two values using spring physics.
  ///
  /// The [builder], [spring], and [value] arguments must not be null.
  /// {@endtemplate}
  @Deprecated('Use MotionBuilder with a sensible converter instead')
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
  Widget build(BuildContext context) {
    return MotionBuilder(
      value: value,
      motion: SpringMotion(spring),
      from: from,
      active: simulate,
      onAnimationStatusChanged: onAnimationStatusChanged,
      converter: MotionConverter<Double2D>(
        normalize: (value) => [value.x, value.y],
        denormalize: (values) => (values[0], values[1]),
      ),
      builder: builder,
      child: child,
    );
  }
}
