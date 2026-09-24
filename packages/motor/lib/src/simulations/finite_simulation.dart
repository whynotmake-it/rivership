import 'dart:typed_data';

import 'package:meta/meta.dart';

/// A simulation whose finish time is known exactly.
///
/// Otherwise playback has to find a segment's end by sampling `isDone` on a
/// grid and bisecting. `isDone` isn't monotonic: an underdamped spring can
/// report done and then not done again near an oscillation peak, where its
/// velocity check fails. So an end can't be read off `isDone` cheaply or
/// early. Curves, holds, `.at` arrivals, fixed-duration wrappers and
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
