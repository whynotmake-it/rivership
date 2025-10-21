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

  group('FrictionMotion', () {
    test('creates simulation with correct initial conditions', () {
      const motion = Motion.friction(endVelocity: 0);
      final simulation = motion.createSimulation(
        start: 0,
        end: 100,
        velocity: 50,
      );

      expect(simulation.x(0), closeTo(0, error));
      expect(simulation.dx(0), closeTo(50, error));
    });

    test('decelerates over time', () {
      const motion = Motion.friction(endVelocity: 0);
      final simulation = motion.createSimulation(
        start: 0,
        end: 100,
        velocity: 50,
      );

      // Velocity should decrease over time
      expect(simulation.dx(0.1), lessThan(simulation.dx(0)));
      expect(simulation.dx(1), lessThan(simulation.dx(0.1)));
    });

    test('takes very long time to truly settle (quirk)', () {
      const motion = Motion.friction(endVelocity: 0);
      final simulation = motion.createSimulation(
        start: 0,
        end: 100,
        velocity: 50,
      );

      // Not done quickly
      expect(simulation.isDone(1), isFalse);
      expect(simulation.isDone(10), isFalse);
      expect(simulation.isDone(100), isFalse);

      // Takes a very long time due to asymptotic deceleration
      expect(simulation.isDone(500), isFalse);
    });

    test('approach to target is asymptotic', () {
      const motion = Motion.friction(endVelocity: 0);
      final simulation = motion.createSimulation(
        start: 0,
        end: 100,
        velocity: 50,
      );

      // Covers most distance quickly, then slows down
      final positionAt1 = simulation.x(1);
      expect(positionAt1, greaterThan(30));
      expect(positionAt1, lessThan(50));

      // Eventually reaches exactly 100 due to the simulation physics
      expect(simulation.x(100), equals(100.0));
    });

    test('requires velocity to point toward target', () {
      const motion = Motion.friction();

      // Valid: positive velocity toward positive target
      expect(
        () => motion.createSimulation(start: 0, end: 100, velocity: 50),
        returnsNormally,
      );

      // Valid: negative velocity toward negative target
      expect(
        () => motion.createSimulation(start: 100, end: 0, velocity: -50),
        returnsNormally,
      );

      // Invalid: direction mismatch throws assertion
      expect(
        () => motion.createSimulation(start: 0, end: 100, velocity: -50),
        throwsA(isA<AssertionError>()),
      );
    });

    test('needsSettle is true', () {
      expect(Motion.friction().needsSettle, isTrue);
    });

    test('unboundedWillSettle is false', () {
      expect(Motion.friction().unboundedWillSettle, isFalse);
    });
  });

  group('ScaledFrictionMotion', () {
    test('scales final velocity proportionally', () {
      const motion = Motion.scaledFriction(velocityFactor: 0.5);
      final simulation = motion.createSimulation(
        start: 0,
        end: 100,
        velocity: 100,
      );

      // Initial velocity unchanged
      expect(simulation.dx(0), closeTo(100, error));

      expect(simulation.dx(0.1), lessThan(100));
      expect(simulation.isDone(2), isTrue);
      expect(simulation.dx(2), closeTo(0, error));
    });

    test('velocityFactor 0.0 behaves like standard friction', () {
      const scaledMotion = Motion.scaledFriction(velocityFactor: 0.0);
      const standardMotion = Motion.friction(endVelocity: 0);

      final scaledSim = scaledMotion.createSimulation(
        start: 0,
        end: 100,
        velocity: 50,
      );
      final standardSim = standardMotion.createSimulation(
        start: 0,
        end: 100,
        velocity: 50,
      );

      // Should behave identically
      expect(scaledSim.x(1), closeTo(standardSim.x(1), error));
      expect(scaledSim.dx(1), closeTo(standardSim.dx(1), error));
    });

    test('validates velocityFactor is in valid range', () {
      expect(
        () => ScaledFrictionMotion(velocityFactor: -0.1),
        throwsA(isA<AssertionError>()),
      );

      expect(
        () => ScaledFrictionMotion(velocityFactor: 1.1),
        throwsA(isA<AssertionError>()),
      );

      expect(
        () => ScaledFrictionMotion(velocityFactor: 0.5),
        returnsNormally,
      );
    });
  });

  group('FrictionMotion - Edge Cases', () {
    test('zero velocity with distance causes assertion', () {
      const motion = Motion.friction();

      expect(
        () => motion.createSimulation(start: 0, end: 100, velocity: 0),
        throwsA(isA<AssertionError>()),
      );
    });

    test('zero distance with non-zero velocity causes assertion', () {
      const motion = Motion.friction();

      expect(
        () => motion.createSimulation(start: 50, end: 50, velocity: 10),
        throwsA(isA<AssertionError>()),
      );
    });

    test('handles small velocity values', () {
      const motion = Motion.friction();
      final simulation = motion.createSimulation(
        start: 0,
        end: 100,
        velocity: 0.1,
      );

      expect(simulation.x(0), closeTo(0, error));
      expect(simulation.dx(0), closeTo(0.1, error));
      expect(simulation.x(1), greaterThan(0));
    });

    test('works with negative velocity toward lower target', () {
      const motion = Motion.scaledFriction(velocityFactor: 0.3);
      final simulation = motion.createSimulation(
        start: 100,
        end: 0,
        velocity: -60,
      );

      expect(simulation.dx(0), closeTo(-60, error));

      // Decelerates toward 0 (not -18)
      // ScaledFrictionMotion scales the deceleration curve, not the end velocity
      expect(simulation.dx(0.1), lessThan(0));
      expect(simulation.dx(0.1), greaterThan(-60));

      // Eventually reaches 0
      expect(simulation.dx(100), closeTo(0, 1));
    });
  });
}
