import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

double _seconds(Duration duration) => duration.inMicroseconds / 1e6;

/// The time from which [simulation] stays done, on a 1e-5 s grid.
double _doneForGood(Simulation simulation, double until) {
  const step = 1e-5;
  var last = -step;
  for (var t = 0.0; t < until; t += step) {
    if (!simulation.isDone(t)) last = t;
  }
  return last + step;
}

void main() {
  group('Motion.settlingDuration', () {
    test('curves and NoMotion return their duration', () {
      const duration = Duration(milliseconds: 300);
      expect(const Motion.linear(duration).settlingDuration(), duration);
      expect(const Motion.curved(duration).settlingDuration(), duration);
      expect(const NoMotion(duration).settlingDuration(), duration);
    });

    test('springs end when they are done for good', () {
      final random = math.Random(3);
      final springs = <Motion>[
        const CupertinoMotion(),
        const CupertinoMotion.bouncy(),
        const CupertinoMotion.snappy(),
        const CupertinoMotion.interactive(),
        const MaterialSpringMotion.expressiveSpatialDefault(),
        for (var i = 0; i < 12; i++)
          () {
            final zeta = 0.1 + random.nextDouble() * 2;
            final stiffness = 50 + random.nextDouble() * 1000;
            return SpringMotion(
              SpringDescription(
                mass: 1,
                stiffness: stiffness,
                damping: 2 * zeta * math.sqrt(stiffness),
              ),
            );
          }(),
      ];
      for (final motion in springs) {
        for (final (end, velocity) in [(1.0, 0.0), (300.0, -2000.0)]) {
          final settle = motion.settlingDuration(end: end, velocity: velocity)!;
          final simulation = motion.createSimulation(
            end: end,
            velocity: velocity,
          );
          expect(
            _seconds(settle),
            closeTo(_doneForGood(simulation, _seconds(settle) + 1), 2e-5),
            reason: '$motion to $end at $velocity',
          );
          expect(simulation.isDone(_seconds(settle)), isTrue);
        }
      }
    });

    test('a spring whose isDone flickers ends after its last swing', () {
      const motion = CupertinoMotion.bouncy();
      final simulation = motion.createSimulation(start: 2.4964, end: 0);
      final settle = _seconds(motion.settlingDuration(start: 2.4964, end: 0)!);

      expect(simulation.isDone(1.03), isTrue);
      expect(settle, greaterThan(1.2));
      expect(_doneForGood(simulation, 2), closeTo(settle, 2e-5));
    });

    test('a spring at rest on its target is done at once', () {
      expect(
        const CupertinoMotion.bouncy().settlingDuration(start: 1),
        Duration.zero,
      );
    });

    test('wrappers ask their parent', () {
      const spring = CupertinoMotion.bouncy();
      const duration = Duration(milliseconds: 400);
      expect(spring.scaleTo(duration).settlingDuration(), duration);

      final trimmed = spring.trimmed(fromStart: 0.2, fromEnd: 0.2);
      final parent = spring.settlingDuration(start: -0.12, end: 1.12)!;
      expect(
        _seconds(trimmed.settlingDuration()!),
        closeTo(_seconds(parent) * 0.6 - spring.tolerance.time, 1e-5),
      );
    });
  });
}
