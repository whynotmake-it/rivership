import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/physics.dart';
import 'package:meta/meta.dart';
import 'package:motor/src/settling_simulation.dart';

final _bits = ByteData(8);

/// The smallest double greater than [seconds], which must be finite and not
/// negative: when a simulation whose `isDone` is `time > seconds` is done.
///
/// Increments the bits in two 32-bit halves, since JavaScript builds don't
/// support 64-bit `ByteData` accessors.
@internal
double justAfter(double seconds) {
  final bits = _bits..setFloat64(0, seconds);
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
/// Guards the ends simulations report through [SettlingSimulation.settlesAt],
/// which has microsecond resolution: curves are done just after their duration,
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
  final high = seconds + 1e-6;
  if (!simulation.isDone(high)) return null;
  return bisectDone(simulation, after, high);
}

/// How far ahead motor looks for when a simulation settles, in seconds.
@internal
const settleSearchSeconds = 120.0;

/// The step of the grid motor samples `isDone` on, in seconds, up to
/// [settleScanLimit] seconds. Past that the steps double.
@internal
const settleScanStep = 1 / 60;

/// Where the grid of [settleScanStep] starts doubling, in seconds.
@internal
const settleScanLimit = 60.0;

/// The grid point after [seconds]: [settleScanStep] further up to
/// [settleScanLimit], then twice as far, but never past
/// [settleSearchSeconds].
@internal
double nextSettleScan(double seconds) => seconds < settleScanLimit
    ? seconds + settleScanStep
    : math.min(seconds * 2, settleSearchSeconds);

/// When [simulation] is first done, or null if it isn't within
/// [settleSearchSeconds].
///
/// It samples `isDone` on the grid playback uses ([nextSettleScan]) and
/// bisects the first grid step that is done ([bisectDone]). Simulations
/// without [SettlingSimulation] settle where this finds.
@internal
double? searchSettlingSeconds(Simulation simulation) {
  if (simulation.isDone(0)) return 0;
  var low = 0.0;
  var high = settleScanStep;
  while (!simulation.isDone(high)) {
    if (high >= settleSearchSeconds) return null;
    low = high;
    high = nextSettleScan(high);
  }
  return bisectDone(simulation, low, high);
}

/// Where [simulation] turns done between [low] and [high], to the precision
/// of a double: the smallest time found done, given that it is done at
/// [high].
@internal
double bisectDone(Simulation simulation, double low, double high) {
  var notDone = low;
  var done = high;
  while (true) {
    final mid = (notDone + done) / 2;
    if (mid <= notDone || mid >= done) return done;
    if (simulation.isDone(mid)) {
      done = mid;
    } else {
      notDone = mid;
    }
  }
}

/// When [simulation] settles, in seconds, or null if it never does.
///
/// [SimulationSettling.simulateSettleTime] reads it, at the precision of a
/// double: a [SettlingSimulation]'s time is only checked, and searched for if
/// the simulation isn't done by then. Other simulations are searched.
@internal
double? settleSecondsOf(Simulation simulation) {
  if (simulation is! SettlingSimulation) {
    return searchSettlingSeconds(simulation);
  }
  final reported = simulation.settlesAt;
  if (reported == null) return null;
  return settledAt(simulation, reported.inMicroseconds / 1e6) ??
      searchSettlingSeconds(simulation);
}

/// [seconds] as a [Duration], rounded up to whole microseconds, or null.
@internal
Duration? settlingDurationOf(double? seconds) => seconds == null
    ? null
    : Duration(microseconds: (seconds * Duration.microsecondsPerSecond).ceil());
