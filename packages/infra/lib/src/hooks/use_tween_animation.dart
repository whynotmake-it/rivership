import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:infra/src/design/blend_color_tween.dart';

/// A hook that works like [TweenAnimationBuilder], with sensible defaults.
///
/// You can pass any [tween] (as long as it's `to` value is not null), and this
/// will return a value that smoothly transitions. Using this is equivalent
/// to placing the entire Widget in a [TweenAnimationBuilder] `builder` function
/// with the same parameters.
T useTweenAnimation<T>(
  Tween<T> tween, {
  Duration duration = Durations.short4,
  Curve curve = Easing.standard,
}) {
  final vsync = useSingleTickerProvider();
  return use(
    _TweenAnimationHook(
      tween: tween,
      duration: duration,
      curve: curve,
      vsync: vsync,
      keys: const [],
    ),
  );
}

/// A convenience wrapper around [useTweenAnimation] that uses [value] as the
/// tween's `begin` and `end` values.
///
/// This means, that the first time this hook is called, it will return [value],
/// and any subsequent changes to [value] will be animated.
T useTweenedValue<T>(
  T value, {
  Duration duration = Durations.short4,
  Curve curve = Easing.standard,
}) {
  final tween = switch (value) {
    Color() => BlendColorTween(begin: value, end: value),
    _ => Tween<T>(begin: value, end: value),
  };
  return useTweenAnimation(
    tween as Tween<T>,
    duration: duration,
    curve: curve,
  );
}

class _TweenAnimationHook<T> extends Hook<T> {
  const _TweenAnimationHook({
    required this.tween,
    required this.duration,
    required this.curve,
    required this.vsync,
    required super.keys,
  });

  final Tween<T> tween;
  final Duration duration;
  final Curve curve;
  final TickerProvider vsync;

  @override
  HookState<T, Hook<T>> createState() => _ImplicitTweenHookState<T>();
}

class _ImplicitTweenHookState<T> extends HookState<T, _TweenAnimationHook<T>> {
  Tween<T>? _currentTween;

  /// The animation controller driving this widget's implicit animations.
  @protected
  AnimationController get controller => _controller;
  late final AnimationController _controller = AnimationController(
    duration: hook.duration,
    debugLabel: kDebugMode ? hook.toStringShort() : null,
    vsync: hook.vsync,
  );

  /// The animation driving this widget's implicit animations.
  Animation<double> get animation => _animation;
  late CurvedAnimation _animation = _createCurve();

  @override
  void initHook() {
    _currentTween = hook.tween;
    _currentTween!.begin ??= _currentTween!.end;
    super.initHook();
    controller.addListener(() => setState(() {}));
    _constructTweens();
    if (_currentTween!.begin != _currentTween!.end) {
      controller.forward();
    }
  }

  @override
  void didUpdateHook(_TweenAnimationHook<T> oldHook) {
    super.didUpdateHook(oldHook);
    if (hook.curve != oldHook.curve) {
      _animation.dispose();
      _animation = _createCurve();
    }
    _controller.duration = hook.duration;
    if (_constructTweens()) {
      forEachTween((
        Tween<dynamic>? tween,
        dynamic targetValue,
        TweenConstructor<dynamic> constructor,
      ) {
        _updateTween(tween, targetValue);
        return tween;
      });
      _controller
        ..value = 0.0
        ..forward();
    }
  }

  @override
  T build(BuildContext context) {
    return _currentTween!.evaluate(animation);
  }

  CurvedAnimation _createCurve() {
    return CurvedAnimation(parent: _controller, curve: hook.curve);
  }

  @override
  void dispose() {
    _animation.dispose();
    _controller.dispose();
    super.dispose();
  }

  bool _shouldAnimateTween(Tween<dynamic> tween, dynamic targetValue) {
    return targetValue != (tween.end ?? tween.begin);
  }

  void _updateTween(Tween<dynamic>? tween, dynamic targetValue) {
    if (tween == null) {
      return;
    }
    tween
      ..begin = tween.evaluate(_animation)
      ..end = targetValue;
  }

  bool _constructTweens() {
    var shouldStartAnimation = false;
    forEachTween((
      Tween<dynamic>? tween,
      dynamic targetValue,
      TweenConstructor<dynamic> constructor,
    ) {
      if (targetValue != null) {
        tween ??= constructor(targetValue);
        if (_shouldAnimateTween(tween, targetValue)) {
          shouldStartAnimation = true;
        } else {
          tween.end ??= tween.begin;
        }
      } else {
        tween = null;
      }
      return tween;
    });
    return shouldStartAnimation;
  }

  @protected
  void forEachTween(TweenVisitor<dynamic> visitor) {
    assert(
      hook.tween.end != null,
      'Tween provided to ImplicitTweenHook must have non-null Tween.end value.',
    );
    _currentTween = visitor(_currentTween, hook.tween.end, (dynamic value) {
      // ignore: prefer_asserts_with_message
      assert(false);
      throw StateError(
        '''
Constructor will never be called because null is never provided as current tween.
''',
      );
    }) as Tween<T>?;
  }
}
