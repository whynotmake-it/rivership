import 'dart:math' as math;
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
/// a trimmed motion's end falls between two microseconds, and a sampled or
/// computed time is rounded up to the next one.
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

/// How far ahead motor looks for when a simulation settles, in seconds.
@internal
const settleSearchSeconds = 120.0;

/// When [simulation] is first done, or null if it isn't within
/// [settleSearchSeconds].
///
/// It samples `isDone` on the grid playback uses (1/60 s steps up to a
/// minute, then doubling) and bisects the first grid step that is done, to
/// the precision of a double. The default [Motion.settlingDuration] and
/// [FreeMotion.settlingDuration] use this.
@internal
double? searchSettlingSeconds(Simulation simulation) {
  if (simulation.isDone(0)) return 0;
  const step = 1 / 60;
  var low = 0.0;
  var high = step;
  while (!simulation.isDone(high)) {
    if (high >= settleSearchSeconds) return null;
    low = high;
    high = high < 60 ? high + step : math.min(high * 2, settleSearchSeconds);
  }
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

/// [seconds] as a [Duration], rounded up to whole microseconds, or null.
@internal
Duration? settlingDurationOf(double? seconds) => seconds == null
    ? null
    : Duration(microseconds: (seconds * Duration.microsecondsPerSecond).ceil());
