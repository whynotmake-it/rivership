// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

void main() {
  group('TrimmedMotion', () {
    group('constructor', () {
      test('creates with valid parameters', () {
        const parent = CupertinoMotion();
        const trimmed = TrimmedMotion(
          parent: parent,
          startTrim: 0.2,
          endTrim: 0.3,
        );

        expect(trimmed.parent, equals(parent));
        expect(trimmed.startTrim, equals(0.2));
        expect(trimmed.endTrim, equals(0.3));
      });

      test('throws when startTrim is negative', () {
        const parent = CupertinoMotion();
        expect(
          () => TrimmedMotion(
            parent: parent,
            startTrim: -0.1,
            endTrim: 0.1,
          ),
          throwsA(isA<AssertionError>()),
        );
      });

      test('throws when endTrim is negative', () {
        const parent = CupertinoMotion();
        expect(
          () => TrimmedMotion(
            parent: parent,
            startTrim: 0.1,
            endTrim: -0.1,
          ),
          throwsA(isA<AssertionError>()),
        );
      });

      test('throws when startTrim + endTrim >= 1.0', () {
        const parent = CupertinoMotion();
        expect(
          () => TrimmedMotion(
            parent: parent,
            startTrim: 0.5,
            endTrim: 0.5,
          ),
          throwsA(isA<AssertionError>()),
        );

        expect(
          () => TrimmedMotion(
            parent: parent,
            startTrim: 0.6,
            endTrim: 0.5,
          ),
          throwsA(isA<AssertionError>()),
        );
      });

      test('allows startTrim + endTrim < 1.0', () {
        const parent = CupertinoMotion();
        expect(
          () => const TrimmedMotion(
            parent: parent,
            startTrim: 0.4,
            endTrim: 0.59,
          ),
          returnsNormally,
        );
      });
    });

    group('properties', () {
      test('forwards needsSettle from parent', () {
        const springMotion = CupertinoMotion();
        const curveMotion = CurvedMotion(duration: Duration(seconds: 1));

        const trimmedSpring = TrimmedMotion(
          parent: springMotion,
          startTrim: 0.1,
          endTrim: 0.1,
        );

        const trimmedCurve = TrimmedMotion(
          parent: curveMotion,
          startTrim: 0.1,
          endTrim: 0.1,
        );

        expect(trimmedSpring.needsSettle, isTrue);
        expect(trimmedCurve.needsSettle, isFalse);
      });

      test('forwards unboundedWillSettle from parent', () {
        const springMotion = CupertinoMotion();
        const curveMotion = CurvedMotion(duration: Duration(seconds: 1));

        const trimmedSpring = TrimmedMotion(
          parent: springMotion,
          startTrim: 0.1,
          endTrim: 0.1,
        );

        const trimmedCurve = TrimmedMotion(
          parent: curveMotion,
          startTrim: 0.1,
          endTrim: 0.1,
        );

        expect(trimmedSpring.unboundedWillSettle, isFalse);
        expect(trimmedCurve.unboundedWillSettle, isTrue);
      });

      test('forwards tolerance from parent', () {
        const customMotion = CurvedMotion(
          duration: Duration(seconds: 1),
        );

        const trimmed = TrimmedMotion(
          parent: customMotion,
          startTrim: 0.1,
          endTrim: 0.1,
        );

        expect(trimmed.tolerance, equals(customMotion.tolerance));
      });
    });

    group('simulation behavior', () {
      test('trims linear curve correctly', () {
        const curve = CurvedMotion(
          duration: Duration(seconds: 1),
          curve: Curves.linear,
        );

        const trimmed = TrimmedMotion(
          parent: curve,
          startTrim: 0.2,
          endTrim: 0.3,
        );

        final simulation = trimmed.createSimulation(start: 0, end: 1);

        // At time 0, should be at start (0)
        expect(simulation.x(0), closeTo(0, 1e-10));

        // Should finish early when trimmed portion is complete
        // With 50% usable portion, should be done at 0.5 seconds
        expect(simulation.isDone(0.5), isTrue);

        // When done, should be at end (1)
        expect(simulation.x(0.5), closeTo(1, 1e-10));
      });

      test('trims ease-in curve correctly', () {
        const curve = CurvedMotion(
          duration: Duration(seconds: 2),
          curve: Curves.easeIn,
        );

        const trimmed = TrimmedMotion(
          parent: curve,
          startTrim: 0.1,
          endTrim: 0.1,
        );

        final simulation = trimmed.createSimulation(start: 0, end: 10);

        // Should start at 0
        expect(simulation.x(0), closeTo(0, 1e-10));

        // Should end at 10 when trimmed portion is complete
        // With 80% usable portion, duration should be 2 * 0.8 = 1.6 seconds
        expect(simulation.isDone(1.6), isTrue);
        expect(simulation.x(1.6), closeTo(10, 1e-10));

        // Should not be done before the trimmed portion is complete
        expect(simulation.isDone(1.5), isFalse);
      });

      test('works with no trimming', () {
        const m = CurvedMotion(
          duration: Duration(milliseconds: 500),
          curve: Curves.bounceOut,
        );

        const trimmed = TrimmedMotion(
          parent: m,
          startTrim: 0,
          endTrim: 0,
        );

        final newCurve = trimmed.toCurve;

        for (var t = 0.0; t <= 1; t += 0.001) {
          expect(newCurve.transform(t), closeTo(m.curve.transform(t), 1e-10));
        }
      });

      test('handles velocity correctly', () {
        const curve = CurvedMotion(
          duration: Duration(seconds: 1),
          curve: Curves.linear,
        );

        const trimmed = TrimmedMotion(
          parent: curve,
          startTrim: 0.25,
          endTrim: 0.25,
        );

        final simulation =
            trimmed.createSimulation(start: 0, end: 1, velocity: 5);

        // Velocity should be zero when simulation is done
        expect(simulation.dx(0.5), equals(0));

        // Velocity should be scaled appropriately during active portion
        final midVelocity = simulation.dx(0.25);
        expect(midVelocity, greaterThan(0));
      });
    });

    group('equality and hashCode', () {
      test('equal when all properties match', () {
        const parent = CupertinoMotion();
        const trimmed1 = TrimmedMotion(
          parent: parent,
          startTrim: 0.2,
          endTrim: 0.3,
        );
        const trimmed2 = TrimmedMotion(
          parent: parent,
          startTrim: 0.2,
          endTrim: 0.3,
        );

        expect(trimmed1, equals(trimmed2));
        expect(trimmed1.hashCode, equals(trimmed2.hashCode));
      });

      test('not equal when parent differs', () {
        const trimmed1 = TrimmedMotion(
          parent: CupertinoMotion(),
          startTrim: 0.2,
          endTrim: 0.3,
        );
        const trimmed2 = TrimmedMotion(
          parent: CupertinoMotion.bouncy(),
          startTrim: 0.2,
          endTrim: 0.3,
        );

        expect(trimmed1, isNot(equals(trimmed2)));
      });

      test('not equal when startTrim differs', () {
        const parent = CupertinoMotion();
        const trimmed1 = TrimmedMotion(
          parent: parent,
          startTrim: 0.2,
          endTrim: 0.3,
        );
        const trimmed2 = TrimmedMotion(
          parent: parent,
          startTrim: 0.1,
          endTrim: 0.3,
        );

        expect(trimmed1, isNot(equals(trimmed2)));
      });

      test('not equal when endTrim differs', () {
        const parent = CupertinoMotion();
        const trimmed1 = TrimmedMotion(
          parent: parent,
          startTrim: 0.2,
          endTrim: 0.3,
        );
        const trimmed2 = TrimmedMotion(
          parent: parent,
          startTrim: 0.2,
          endTrim: 0.2,
        );

        expect(trimmed1, isNot(equals(trimmed2)));
      });

      test('not equal to different type', () {
        const parent = CupertinoMotion();
        const trimmed = TrimmedMotion(
          parent: parent,
          startTrim: 0.2,
          endTrim: 0.3,
        );

        expect(trimmed, isNot(equals(parent)));
        expect(trimmed, isNot(equals('string')));
      });
    });

    group('toString', () {
      test('includes all relevant information', () {
        const parent = CupertinoMotion();
        const trimmed = TrimmedMotion(
          parent: parent,
          startTrim: 0.2,
          endTrim: 0.3,
        );

        final str = trimmed.toString();
        expect(str, contains('TrimmedMotion'));
        expect(str, contains('0.2-0.3'));
      });
    });
  });

  group('MotionTrimming extension', () {
    test('creates TrimmedMotion with default parameters', () {
      const parent = CupertinoMotion();
      final trimmed = parent.trimmed();

      expect(trimmed.parent, equals(parent));
      expect(trimmed.startTrim, equals(0.0));
      expect(trimmed.endTrim, equals(0.0));
    });

    test('creates TrimmedMotion with specified parameters', () {
      const parent = CupertinoMotion();
      final trimmed = parent.trimmed(
        startTrim: 0.1,
        endTrim: 0.2,
      );

      expect(trimmed.parent, equals(parent));
      expect(trimmed.startTrim, equals(0.1));
      expect(trimmed.endTrim, equals(0.2));
    });

    test('works with different motion types', () {
      const spring = CupertinoMotion();
      const curve = CurvedMotion(duration: Duration(seconds: 1));

      final trimmedSpring = spring.trimmed(startTrim: 0.1);
      final trimmedCurve = curve.trimmed(endTrim: 0.2);

      expect(trimmedSpring.parent, equals(spring));
      expect(trimmedCurve.parent, equals(curve));
    });
  });
}
