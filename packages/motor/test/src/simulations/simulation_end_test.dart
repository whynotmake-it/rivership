import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/src/simulations/simulation_end.dart';

void main() {
  test('settledAt checks a reported end against isDone', () {
    const between = 0.3000004321;
    for (final (doneFrom, reported, expected) in <(double, double?, double?)>[
      // Done at the reported end.
      (0.3, 0.3, 0.3),
      (0.2, 0.3, 0.3),
      // Done within the microsecond after it: curves are done just after
      // their duration.
      (justAfter(0.3), 0.3, justAfter(0.3)),
      (between, 0.3, between),
      // Missing, invalid and early ends.
      (0.3, null, null),
      (0.3, double.infinity, null),
      (0.3, double.nan, null),
      (0.3, -1, null),
      (0.3, 0.29, null),
    ]) {
      expect(
        settledAt(_DoneFrom(doneFrom), reported),
        expected,
        reason: '$reported for a simulation done from $doneFrom',
      );
    }
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
