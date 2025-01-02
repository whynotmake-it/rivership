import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:springster/src/simple_spring.dart';

/// Continuously animates [value] using a Spring simulation using a given
/// [SpringDescription].
///
/// If [simulate] is false, the animation will be immediately set to the target
/// value.
///
/// See also:
///   * [SimpleSpring]
T useSpringAnimation<T>({
  required T value,
  SpringDescription spring = SimpleSpring.smooth,
  bool simulate = true,
}) {
  final ticker = useSingleTickerProvider();
  final animation = use(
    _UseSpringAnimation<T>(
      tickerProvider: ticker,
      value: value,
      spring: spring,
      simulate: simulate,
    ),
  );

  return useAnimation(animation);
}

/// Continuously animates a 2D value using a Spring simulation using a given
/// [SpringDescription].
///
/// If [simulate] is false, the animation will be immediately set to the target
/// value.
///
/// See also:
///   * [useSpringAnimation]
(T x, T y) use2DSpringAnimation<T>({
  required (T x, T y) value,
  SpringDescription spring = SimpleSpring.smooth,
  bool simulate = true,
}) {
  final x =
      useSpringAnimation(value: value.$1, spring: spring, simulate: simulate);
  final y =
      useSpringAnimation(value: value.$2, spring: spring, simulate: simulate);

  return (x, y);
}

class _UseSpringAnimation<T> extends Hook<Animation<T>> {
  const _UseSpringAnimation({
    required this.value,
    required this.tickerProvider,
    required this.spring,
    this.onDone,
    this.simulate = true,
    super.keys,
  });

  /// The target value for the transition.
  ///
  /// Whenever this value changes, the widget smoothly animates from
  /// the previous value to the new one.
  final T value;

  /// The spring behavior of the transition.
  ///
  /// Modify this for bounciness and duration.
  final SpringDescription spring;

  /// Called approximately when the spring animation ends.
  final VoidCallback? onDone;

  /// The [TickerProvider] for the animation.
  final TickerProvider tickerProvider;

  /// Whether to simulate the spring animation.
  ///
  /// If false, the animation will be immediately set to the target value.
  final bool simulate;

  @override
  _SpringAnimationState<T> createState() => _SpringAnimationState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);

    properties
      ..add(DiagnosticsProperty<T>('value', value))
      ..add(DiagnosticsProperty<SpringDescription>('spring', spring));
  }
}

class _SpringAnimationState<T>
    extends HookState<Animation<T>, _UseSpringAnimation<T>> {
  late AnimationController _controller;

  late Animation<T> _animation;

  DateTime? _lastUpdate;

  double _absoluteVelocity = 0;

  @override
  void initHook() {
    super.initHook();

    _initController();
    _animation = AlwaysStoppedAnimation(hook.value);
  }

  void _initController() {
    _controller = AnimationController.unbounded(vsync: hook.tickerProvider);
  }

  @override
  void didUpdateHook(covariant _UseSpringAnimation<T> oldHook) {
    final oldValue = oldHook.value;

    final newValue = hook.value;

    final spring = hook.spring;

    if (oldValue != newValue || oldHook.spring != spring) {
      _absoluteVelocity = _calculateAbsoluteVelocity(
        oldTarget: oldValue,
        newTarget: newValue,
        lastUpdate: _lastUpdate,
      );
      if (hook.simulate) {
        final tween = Tween<T>(begin: _animation.value, end: newValue);
        _animation = _controller.drive(tween);

        final relativeVelocity = _calculateRelativeVelocity(
          target: newValue,
          currentValue: _animation.value,
          absoluteVelocity: _absoluteVelocity,
        );

        print('relativeVelocity: $relativeVelocity');
        final simulation = SpringSimulation(spring, 0, 1, relativeVelocity);
        _controller.animateWith(simulation).then((value) {
          hook.onDone?.call();
        });
      } else {
        _animation = AlwaysStoppedAnimation(newValue);
        _controller.stop();
      }
    }

    super.didUpdateHook(oldHook);
  }

  double _calculateAbsoluteVelocity({
    required T oldTarget,
    required T newTarget,
    required DateTime? lastUpdate,
  }) {
    if (oldTarget is num && newTarget is num && lastUpdate != null) {
      final absolute = newTarget - oldTarget;

      final now = DateTime.now();
      final time = now.difference(lastUpdate).inMilliseconds;
      _lastUpdate = now;

      return absolute.toDouble() / time;
    }

    _lastUpdate = DateTime.now();
    return 0;
  }

  double _calculateRelativeVelocity({
    required T target,
    required T currentValue,
    required double absoluteVelocity,
  }) {
    if (target is num && currentValue is num) {
      final direction = target < currentValue ? 1 : -1;
      return absoluteVelocity * direction;
    }

    return 0;
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
