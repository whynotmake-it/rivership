import 'dart:typed_data';

import 'package:meta/meta.dart';

/// A simulation whose finish time is known up front, so playback does not
/// have to search for it.
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
