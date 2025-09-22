// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

import 'util.dart';

void main() {
  group('NoMotion', () {
    test('creates a simulation that holds the target value', () {
      const motion = Motion.none(Duration(seconds: 1));
      final simulation = motion.createSimulation(start: 0, end: 100);

      // Should hold the target value immediately
      expect(simulation.x(0), equals(0));
      expect(simulation.x(0.5), equals(0));
      expect(simulation.x(1), equals(0));
      expect(simulation.x(2), equals(0));

      expect(simulation.isDone(1), isFalse);
      expect(simulation.isDone(1.000001), isTrue);
      expect(simulation.isDone(2), isTrue);
    });
  });

  group('TrimmedMotion - Basic Tests', () {
    group('Linear Motion Trimming', () {
      test('no trimming = original behavior', () {
        const parent = LinearMotion(Duration(seconds: 1));
        const trimmed = TrimmedMotion(parent: parent, fromStart: 0, fromEnd: 0);

        final parentSim = parent.createSimulation(start: 0, end: 100);
        final trimmedSim = trimmed.createSimulation(start: 0, end: 100);

        // Should behave identically at several time points
        for (double t = 0; t <= 1.0; t += 0.2) {
          expect(trimmedSim.x(t), closeTo(parentSim.x(t), error));
        }
      });

      test('symmetric trimming (0.2, 0.2)', () {
        const parent = LinearMotion(Duration(seconds: 1));
        const trimmed = TrimmedMotion(
          parent: parent,
          fromStart: 0.2,
          fromEnd: 0.2,
        );

        final simulation = trimmed.createSimulation();

        // Should start at 0
        expect(simulation.x(0), closeTo(0, error));

        // Should end at 1
        expect(simulation.x(.6), closeTo(1, error));

        // Middle should be 50 (linear interpolation)
        expect(simulation.x(0.3), closeTo(.5, error));

        // Should be done at t=1
        expect(simulation.isDone(.6), isTrue);
      });
    });

    group('Extension Methods', () {
      test('trimmed() extension works', () {
        const parent = LinearMotion(Duration(seconds: 1));
        final trimmed = parent.trimmed(fromStart: 0.1, fromEnd: 0.2);

        expect(trimmed, isA<TrimmedMotion>());
        expect(trimmed.parent, equals(parent));
        expect(trimmed.fromStart, equals(0.1));
        expect(trimmed.fromEnd, equals(0.2));
      });

      test('subExtent() extension works', () {
        const parent = LinearMotion(Duration(seconds: 1));
        final trimmed = parent.segment(length: 0.5, start: 0.2);

        expect(trimmed.fromStart, equals(0.2));
        expect(trimmed.fromEnd, closeTo(0.3, error)); // 1.0 - (0.2 + 0.5)
      });
    });

    test('velocity calculation works', () {
      const parent = LinearMotion(Duration(seconds: 1));
      const trimmed =
          TrimmedMotion(parent: parent, fromStart: 0.2, fromEnd: 0.2);

      final simulation = trimmed.createSimulation(start: 0, end: 100);

      // Linear motion should have constant velocity when active
      final velocity = simulation.dx(0.5);
      expect(velocity, greaterThan(0));

      // For linear motion, velocity should be positive and finite
      expect(velocity, greaterThan(0));
      expect(velocity.isFinite, isTrue);
    });
  });
}
