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
@internal
double justAfter(double seconds) {
  final bits = ByteData(8)..setFloat64(0, seconds);
  return (bits..setInt64(0, bits.getInt64(0) + 1)).getFloat64(0);
}
