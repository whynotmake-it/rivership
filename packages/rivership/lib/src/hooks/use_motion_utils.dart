part of 'use_motion.dart';

/// A hook that animates a single value.
///
/// {@macro rivership.MotionHook}
double useSingleMotion({
  required double value,
  required Motion motion,
  bool active = true,
  double? from,
  ValueChanged<AnimationStatus>? onAnimationStatusChanged,
}) {
  return useMotion(
    value: value,
    motion: motion,
    active: active,
    converter: const SingleMotionConverter(),
    from: from,
    onAnimationStatusChanged: onAnimationStatusChanged,
  );
}

/// A hook that animates an [Offset] value using a [Motion].
///
/// {@macro motor.MotionHook}
Offset useOffsetMotion({
  required Offset value,
  required Motion motion,
  bool active = true,
}) {
  return useMotion(
    value: value,
    motion: motion,
    active: active,
    converter: const OffsetMotionConverter(),
  );
}

/// A hook that animates a [Size] value using a [Motion].
///
/// {@macro motor.MotionHook}
Size useSizeMotion({
  required Size value,
  required Motion motion,
  bool active = true,
}) {
  return useMotion(
    value: value,
    motion: motion,
    active: active,
    converter: const SizeMotionConverter(),
  );
}

/// A hook that animates a [Rect] value using a [Motion].
///
/// {@macro motor.MotionHook}
Rect useRectMotion({
  required Rect value,
  required Motion motion,
  bool active = true,
}) {
  return useMotion(
    value: value,
    motion: motion,
    active: active,
    converter: const RectMotionConverter(),
  );
}

/// A hook that animates an [Alignment] value using a [Motion].
///
/// {@macro motor.MotionHook}
Alignment useAlignmentMotion({
  required Alignment value,
  required Motion motion,
  bool active = true,
}) {
  return useMotion(
    value: value,
    motion: motion,
    active: active,
    converter: const AlignmentMotionConverter(),
  );
}
