import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:rivership/src/design/simple_spring.dart';

/// Continuously animates [value] using a Spring simulation using a given
/// [SpringDescription].
///
/// See also:
///   * [SimpleSpring]
T useSpringAnimation<T>({
  required T value,
  SpringDescription spring = SimpleSpring.smooth,
}) {
  final ticker = useSingleTickerProvider();
  final animation = use(
    _UseSpringAnimation<T>(
      tickerProvider: ticker,
      value: value,
      spring: spring,
    ),
  );

  return useAnimation(animation);
}

class _UseSpringAnimation<T> extends Hook<Animation<T>> {
  const _UseSpringAnimation({
    required this.value,
    required this.tickerProvider,
    required this.spring,
    this.upperBound,
    this.lowerBound,
    this.onDone,
    super.keys,
  }) : assert(
          (upperBound != null && lowerBound != null) ||
              (upperBound == null && lowerBound == null),
          'upperBound and lowerBound have to be set for a bound animation. '
          'For an unbound animation both have to be null',
        );

  /// The target value for the transition.
  ///
  /// Whenever this value changes, the widget smoothly animates from
  /// the previous value to the new one.
  final T value;

  /// The spring behavior of the transition.
  ///
  /// Modify this for bounciness and duration.
  final SpringDescription spring;

  /// The value at which this animation is deemed to be completed.
  ///
  /// Can be used to clamp the spring to a maximal value.
  final double? upperBound;

  /// The value at which this animation is deemed to be dismissed.
  ///
  /// Can be used to clamp the spring to a minimal value.
  final double? lowerBound;

  /// Called approximately when the spring animation ends.
  final VoidCallback? onDone;

  /// The [TickerProvider] for the animation.
  final TickerProvider tickerProvider;

  @override
  _SpringAnimationState<T> createState() => _SpringAnimationState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);

    properties
      ..add(DiagnosticsProperty<T>('value', value))
      ..add(DoubleProperty('upperBound', upperBound, ifNull: 'infinite'))
      ..add(DoubleProperty('lowerBound', lowerBound, ifNull: 'infinite'))
      ..add(DiagnosticsProperty<SpringDescription>('spring', spring));
  }
}

class _SpringAnimationState<T>
    extends HookState<Animation<T>, _UseSpringAnimation<T>> {
  late AnimationController _controller;

  late Animation<T> _animation;

  @override
  void initHook() {
    super.initHook();

    _initController();
    _animation = AlwaysStoppedAnimation(hook.value);
  }

  void _initController() {
    if (hook.upperBound == null && hook.lowerBound == null) {
      _controller = AnimationController.unbounded(vsync: hook.tickerProvider);
    } else {
      _controller = AnimationController(
        vsync: hook.tickerProvider,
        upperBound: hook.upperBound!,
        lowerBound: hook.lowerBound!,
      );
    }
  }

  @override
  void didUpdateHook(covariant _UseSpringAnimation<T> oldHook) {
    final oldValue = oldHook.value;

    final newValue = hook.value;

    final spring = hook.spring;

    if (oldValue != newValue) {
      Tween<T>(begin: _animation.value, end: newValue);
      _animation = _controller.drive(
        Tween<T>(begin: _animation.value, end: newValue),
      );

      final simulation = SpringSimulation(spring, 0, 1, -_controller.velocity);

      _controller.animateWith(simulation).then((value) {
        hook.onDone?.call();
      });
    }

    super.didUpdateHook(oldHook);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Animation<T> build(BuildContext context) {
    return _animation;
  }
}
