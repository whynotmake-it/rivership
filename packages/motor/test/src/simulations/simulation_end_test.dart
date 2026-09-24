import 'dart:typed_data';

import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/src/simulations/simulation_end.dart';

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

  group('settledAt', () {
    test('accepts an end the simulation is done at', () {
      expect(settledAt(_DoneFrom(0.3), 0.3), 0.3);
      expect(settledAt(_DoneFrom(0.2), 0.3), 0.3);
    });

    test('finds the end within the microsecond after the reported one', () {
      // Curves are done just after their duration.
      expect(settledAt(_DoneFrom(justAfter(0.3)), 0.3), justAfter(0.3));
      const between = 0.3000004321;
      expect(settledAt(_DoneFrom(between), 0.3), between);
    });

    test('rejects missing, invalid and early ends', () {
      final simulation = _DoneFrom(0.3);
      expect(settledAt(simulation, null), isNull);
      expect(settledAt(simulation, double.infinity), isNull);
      expect(settledAt(simulation, double.nan), isNull);
      expect(settledAt(simulation, -1), isNull);
      expect(settledAt(simulation, 0.29), isNull);
    });
  });
}

/// Done from [from] on.
class _DoneFrom extends Simulation {
  _DoneFrom(this.from);

  final double from;

  @override
  double x(double time) => 0;

  @override
  double dx(double time) => 0;

  @override
  bool isDone(double time) => time >= from;
}
