import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:motor/src/simulations/finite_simulation.dart';

void main() {
  // Runs on the VM and, with `--platform chrome`, compiled to JavaScript,
  // where 64-bit ByteData accessors are unsupported.
  group('justAfter', () {
    test('is the next double, with nothing in between', () {
      const times = <double>[0, 1e-300, 0.0167, 0.3, 1, 2.5, 60, 86400];
      for (final seconds in times) {
        final after = justAfter(seconds);
        expect(after, greaterThan(seconds));
        final middle = seconds + (after - seconds) / 2;
        expect(middle == seconds || middle == after, isTrue);
      }
    });

    test('carries into the high word', () {
      final bits = ByteData(8)
        ..setUint32(0, 0x3FF00000)
        ..setUint32(4, 0xFFFFFFFF);
      final after = ByteData(8)..setFloat64(0, justAfter(bits.getFloat64(0)));
      expect(after.getUint32(0), 0x3FF00001);
      expect(after.getUint32(4), 0);
    });
  });
}
