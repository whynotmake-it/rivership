import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:motor/motor.dart';

// ignore: implementation_imports
import 'package:motor/src/controllers/motion_controller.dart';

part 'use_motion_utils.dart';

/// A hook that animates a value using a dynamic motion.
///
/// {@macro rivership.MotionHook}
T useMotion<T extends Object>({
  required T value,
  required Motion motion,
  required MotionConverter<T> converter,
  bool active = true,
  T? from,
  ValueChanged<AnimationStatus>? onAnimationStatusChanged,
}) {
  final vsync = useSingleTickerProvider();
  return use(
    MotionHook(
      vsync: vsync,
      value: value,
      motion: motion,
      converter: converter,
      active: active,
      from: from,
      onAnimationStatusChanged: onAnimationStatusChanged,
    ),
  );
}

/// A hook that animates a value using a separate motion for each dimension.
///
/// {@macro rivership.MotionHook}
T useMotionPerDimension<T extends Object>({
  required T value,
  required List<Motion> motionPerDimension,
  required MotionConverter<T> converter,
  bool active = true,
  T? from,
  ValueChanged<AnimationStatus>? onAnimationStatusChanged,
}) {
  final vsync = useSingleTickerProvider();
  return use(
    MotionHook.motionPerDimension(
      vsync: vsync,
      value: value,
      motionPerDimension: motionPerDimension,
      converter: converter,
      active: active,
      from: from,
      onAnimationStatusChanged: onAnimationStatusChanged,
    ),
  );
}

/// {@template rivership.MotionHook}
/// A hook that animates a value using a dynamic motion.
///
/// Let's say for example you want to animate [Alignment]:
///
/// ```dart
/// Widget build(BuildContext context) {
///   final alignment = useMotion(
///     value: Alignment.center,
///     motion: SpringMotion(Spring()),
///     converter: const AlignmentMotionConverter(),
///   );
///
///   return Align(
///     alignment: alignment,
///     child: const FlutterLogo(),
///   );
/// }
/// ```
/// {@endtemplate}
///
/// See also:
/// * [useSingleMotion] for a hook that animates a single value.
class MotionHook<T extends Object> extends Hook<T> {
  /// Creates a [MotionHook] with a single [motion].
  const MotionHook({
    required this.vsync,
    required this.value,
    required this.motion,
    required this.converter,
    this.active = true,
    this.onAnimationStatusChanged,
    this.from,
  }) : motionPerDimension = null;

  /// Creates a [MotionHook] with a separate [motion] for each dimension.
  const MotionHook.motionPerDimension({
    required this.vsync,
    required this.value,
    required this.motionPerDimension,
    required this.converter,
    this.active = true,
    this.onAnimationStatusChanged,
    this.from,
  }) : motion = null;

  /// {@template motor.MotionHook.vsync}
  /// The [TickerProvider] to use for the animation.
  /// {@endtemplate}
  final TickerProvider vsync;

  /// {@template motor.MotionHook.value}
  /// The target value for the transition.
  ///
  /// Whenever this value changes, the hook smoothly animates from
  /// the previous value to the new one.
  /// {@endtemplate}
  final T value;

  /// {@template motor.MotionHook.from}
  /// The starting value for the initial animation.
  ///
  /// If this value is null, the hook will start out at [value].
  ///
  /// This is only considered for the first animation, any subsequent changes
  /// during the lifecycle of this hook will be ignored.
  /// {@endtemplate}
  final T? from;

  /// {@template motor.MotionHook.motion}
  /// The motion to use for the animation.
  /// {@endtemplate}
  final Motion? motion;

  /// {@template motor.MotionHook.motionPerDimension}
  /// The motion to use for each dimension of the animation.
  /// {@endtemplate}
  final List<Motion>? motionPerDimension;

  /// {@template motor.MotionHook.converter}
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
  /// If false, the [value] will be immediately set to the target value.
  /// {@endtemplate}
  final bool active;

  /// {@template motor.on_animation_status_changed}
  /// Called when the animation status changes.
  /// {@endtemplate}
  final ValueChanged<AnimationStatus>? onAnimationStatusChanged;

  @override
  HookState<T, MotionHook<T>> createState() => _MotionHookState<T>();
}

class _MotionHookState<T extends Object> extends HookState<T, MotionHook<T>> {
  late MotionController<T> controller;

  @override
  void initHook() {
    controller = switch (hook.motion) {
      final motion? => MotionController(
          motion: motion,
          vsync: hook.vsync,
          initialValue: hook.from ?? hook.value,
          converter: hook.converter,
        ),
      null => MotionController.motionPerDimension(
          motionPerDimension: hook.motionPerDimension!,
          vsync: hook.vsync,
          initialValue: hook.from ?? hook.value,
          converter: hook.converter,
        ),
    };

    controller.addListener(() {
      setState(() {});
    });

    if (hook.onAnimationStatusChanged != null) {
      controller.addStatusListener(hook.onAnimationStatusChanged!);
    }
    if (hook.active && hook.from != null) {
      controller.animateTo(hook.value);
    }
  }

  @override
  void didUpdateHook(MotionHook<T> oldHook) {
    if (hook.motion != oldHook.motion ||
        // ignore: invalid_use_of_internal_member
        !motionsEqual(
          hook.motionPerDimension,
          oldHook.motionPerDimension,
        )) {
      switch (hook.motion) {
        case final motion?:
          controller.motion = motion;
        case null:
          controller.motionPerDimension = hook.motionPerDimension!;
      }
    }
    if (!hook.active) {
      controller
        ..stop()
        ..value = hook.value;
    }

    if (hook.value != oldHook.value) {
      if (hook.active) {
        controller.animateTo(hook.value);
      } else {
        controller.value = hook.value;
      }
    }

    if (hook.onAnimationStatusChanged != oldHook.onAnimationStatusChanged) {
      if (oldHook.onAnimationStatusChanged != null) {
        controller.removeStatusListener(oldHook.onAnimationStatusChanged!);
      }
      if (hook.onAnimationStatusChanged != null) {
        controller.addStatusListener(hook.onAnimationStatusChanged!);
      }
    }
  }

  @override
  T build(BuildContext context) => controller.value;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
