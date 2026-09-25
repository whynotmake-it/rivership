import 'dart:typed_data';

import 'package:flutter/physics.dart';
import 'package:meta/meta.dart';
import 'package:motor/src/motion.dart';

/// A simulation whose finish time is known exactly.
///
/// Otherwise playback asks the motion ([Motion.settlingDuration]), and
/// failing that, has to find a segment's end by sampling `isDone` on a grid
/// and bisecting. `isDone` isn't monotonic: an underdamped spring can report
/// done and then not done again near an oscillation peak, where its velocity
/// check fails. So an end can't be read off `isDone` cheaply or early.
/// Curves, holds, `.at` arrivals, fixed-duration and trimmed wrappers, and
/// `NoMotion` know their end and declare it here, so playback skips the
/// search. That matters when the end is needed ahead of time, for a
/// following `.at` step or the devtools' look-ahead.
@internal
abstract interface class FiniteSimulation {
  /// The time from which `isDone` is true for good, or null if it never is.
  double? get finishSeconds;
}

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

/// When [simulation] is done at or right after [seconds], or null if
/// [seconds] is missing or not finite, or it isn't done by then.
///
/// Guards the ends motions report through [Motion.settlingDuration]. Curves
/// are done just after their duration, so that counts too.
@internal
double? settledAt(Simulation simulation, double? seconds) {
  if (seconds == null || !seconds.isFinite || seconds < 0) return null;
  if (simulation.isDone(seconds)) return seconds;
  final after = justAfter(seconds);
  return simulation.isDone(after) ? after : null;
}

/// Estimates when [simulation] finishes using exponential search followed by
/// binary search, avoiding fixed-step scans through the whole timeline.
///
/// Motions that time-scale or trim another motion whose
/// [Motion.settlingDuration] is null use this. Returns [fallback], or [max]
/// without one, when the simulation isn't done by [max].
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
