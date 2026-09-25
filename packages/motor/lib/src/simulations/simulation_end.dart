import 'dart:typed_data';

import 'package:flutter/physics.dart';
import 'package:meta/meta.dart';
import 'package:motor/src/motion.dart';

/// The smallest double greater than [seconds], which must be finite and not
/// negative: when a simulation whose `isDone` is `time > seconds` is done.
///
/// Increments the bits in two 32-bit halves, since JavaScript builds don't
/// support 64-bit `ByteData` accessors.
@internal
double justAfter(double seconds) {
  final bits = ByteData(8)..setFloat64(0, seconds);
  final low = bits.getUint32(4);
  if (low == 0xFFFFFFFF) {
    bits
      ..setUint32(4, 0)
      ..setUint32(0, bits.getUint32(0) + 1);
  } else {
    bits.setUint32(4, low + 1);
  }
  return bits.getFloat64(0);
}

/// When [simulation] is done at [seconds] or within the microsecond after
/// it, or null if [seconds] is missing, not finite or negative, or it isn't
/// done by then.
///
/// Guards the ends motions report through [Motion.settlingDuration], which
/// has microsecond resolution: curves are done just after their duration,
/// and a trimmed motion's end falls between two microseconds.
///
/// `isDone` isn't monotonic: an underdamped spring can report done and then
/// not done again near an oscillation peak, where its velocity check fails.
/// So an end can't be read off `isDone` cheaply or early, only checked.
@internal
double? settledAt(Simulation simulation, double? seconds) {
  if (seconds == null || !seconds.isFinite || seconds < 0) return null;
  if (simulation.isDone(seconds)) return seconds;
  final after = justAfter(seconds);
  if (simulation.isDone(after)) return after;
  var high = seconds + 1e-6;
  if (!simulation.isDone(high)) return null;
  var low = after;
  while (true) {
    final mid = (low + high) / 2;
    if (mid <= low || mid >= high) return high;
    if (simulation.isDone(mid)) {
      high = mid;
    } else {
      low = mid;
    }
  }
}

/// Estimates when [simulation] finishes using exponential search followed by
/// binary search, avoiding fixed-step scans through the whole timeline.
///
/// Wrappers that time-scale or trim a source whose end isn't known use
/// this: a [FreeMotion], or a motion whose [Motion.settlingDuration] is null
/// or fails [settledAt]. Returns [fallback], or [max] without one, when the
/// simulation isn't done by [max].
@internal
double estimateSimulationDuration(
  Simulation simulation, {
  Duration? fallback,
  Duration max = const Duration(seconds: 60),
}) {
  if (simulation.isDone(0)) return 0;

  final fallbackSeconds = fallback?.toSeconds();
  var lower = 0.0;
  var upper = fallbackSeconds == null || fallbackSeconds <= 0
      ? 1 / 60
      : fallbackSeconds;
  final maxSeconds = max.toSeconds();

  while (upper < maxSeconds && !simulation.isDone(upper)) {
    lower = upper;
    upper *= 2;
  }

  if (!simulation.isDone(upper)) {
    return fallbackSeconds ?? maxSeconds;
  }

  for (var i = 0; i < 24; i++) {
    final mid = (lower + upper) / 2;
    if (simulation.isDone(mid)) {
      upper = mid;
    } else {
      lower = mid;
    }
  }

  return upper;
}

extension on Duration {
  double toSeconds() => inMicroseconds / Duration.microsecondsPerSecond;
}
