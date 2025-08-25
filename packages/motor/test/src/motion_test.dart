// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

import 'util.dart';

void main() {
  group('CupertinoMotion', () {
    test('generate constant SpringDescriptions', () async {
      expect(const CupertinoMotion().description, equalsSpring(standard));
      expect(const CupertinoMotion.bouncy().description, equalsSpring(bouncy));
      expect(const CupertinoMotion.snappy().description, equalsSpring(snappy));
      expect(const CupertinoMotion.smooth().description, equalsSpring(smooth));
      expect(
        const CupertinoMotion.interactive().description,
        equalsSpring(interactive),
      );
    });
  });

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
        expect(trimmed.scaleVelocity, isTrue);
      });

      test('creates with scaleVelocity disabled', () {
        const parent = CupertinoMotion();
        const trimmed = TrimmedMotion(
          parent: parent,
          startTrim: 0.1,
          endTrim: 0.1,
          scaleVelocity: false,
        );

        expect(trimmed.scaleVelocity, isFalse);
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
        const customTolerance = Tolerance(velocity: 0.01, distance: 0.02);

        final customMotion = _TestMotion(tolerance: customTolerance);
        final trimmed = TrimmedMotion(
          parent: customMotion,
          startTrim: 0.1,
          endTrim: 0.1,
        );

        expect(trimmed.tolerance, equals(customTolerance));
      });
    });

    group('createSimulation', () {
      test('extends simulation range correctly with no velocity scaling', () {
        final parent = _TestMotion();
        TrimmedMotion(
          parent: parent,
          startTrim: 0.2,
          endTrim: 0.3,
          scaleVelocity: false,
        ).createSimulation(start: 0, end: 1, velocity: 10);

        // With 20% start trim and 30% end trim, usable portion is 50%
        // So range needs to be extended from 1 to 2
        // Extended start = 0 - (2 * 0.2) = -0.4
        // Extended end = -0.4 + 2 = 1.6
        expect(parent.lastStart, closeTo(-0.4, 1e-10));
        expect(parent.lastEnd, closeTo(1.6, 1e-10));
        expect(parent.lastVelocity, equals(10)); // No scaling
      });

      test('extends simulation range correctly with velocity scaling', () {
        final parent = _TestMotion();
        TrimmedMotion(
          parent: parent,
          startTrim: 0.2,
          endTrim: 0.3,
          scaleVelocity: true,
        ).createSimulation(start: 0, end: 1, velocity: 10);

        // Same range calculation as above
        expect(parent.lastStart, closeTo(-0.4, 1e-10));
        expect(parent.lastEnd, closeTo(1.6, 1e-10));
        expect(parent.lastVelocity, equals(20)); // Scaled by 1/0.5 = 2
      });

      test('works with different start and end values', () {
        final parent = _TestMotion();
        TrimmedMotion(
          parent: parent,
          startTrim: 0.25,
          endTrim: 0.25,
        ).createSimulation(start: 2, end: 6, velocity: 5);

        // Desired range = 6 - 2 = 4
        // Usable portion = 1 - 0.25 - 0.25 = 0.5
        // Extended range = 4 / 0.5 = 8
        // Extended start = 2 - (8 * 0.25) = 0
        // Extended end = 0 + 8 = 8
        expect(parent.lastStart, closeTo(0, 1e-10));
        expect(parent.lastEnd, closeTo(8, 1e-10));
        expect(parent.lastVelocity, equals(10)); // 5 / 0.5 = 10
      });

      test('works with no trimming', () {
        final parent = _TestMotion();
        TrimmedMotion(
          parent: parent,
          startTrim: 0,
          endTrim: 0,
        ).createSimulation(start: 1, end: 3, velocity: 7);

        // No trimming, so values should pass through unchanged
        expect(parent.lastStart, equals(1));
        expect(parent.lastEnd, equals(3));
        expect(parent.lastVelocity, equals(7));
      });
    });

    group('equality and hashCode', () {
      test('equal when all properties match', () {
        const parent = CupertinoMotion();
        const trimmed1 = TrimmedMotion(
          parent: parent,
          startTrim: 0.2,
          endTrim: 0.3,
          scaleVelocity: false,
        );
        const trimmed2 = TrimmedMotion(
          parent: parent,
          startTrim: 0.2,
          endTrim: 0.3,
          scaleVelocity: false,
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

      test('not equal when scaleVelocity differs', () {
        const parent = CupertinoMotion();
        const trimmed1 = TrimmedMotion(
          parent: parent,
          startTrim: 0.2,
          endTrim: 0.3,
          scaleVelocity: true,
        );
        const trimmed2 = TrimmedMotion(
          parent: parent,
          startTrim: 0.2,
          endTrim: 0.3,
          scaleVelocity: false,
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
          scaleVelocity: false,
        );

        final str = trimmed.toString();
        expect(str, contains('TrimmedMotion'));
        expect(str, contains('0.2-0.3'));
        expect(str, contains('scaleVelocity: false'));
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
      expect(trimmed.scaleVelocity, isTrue);
    });

    test('creates TrimmedMotion with specified parameters', () {
      const parent = CupertinoMotion();
      final trimmed = parent.trimmed(
        startTrim: 0.1,
        endTrim: 0.2,
        scaleVelocity: false,
      );

      expect(trimmed.parent, equals(parent));
      expect(trimmed.startTrim, equals(0.1));
      expect(trimmed.endTrim, equals(0.2));
      expect(trimmed.scaleVelocity, isFalse);
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

/// A smooth spring with no bounce.
///
/// This uses the [default values for iOS](https://developer.apple.com/documentation/swiftui/animation/default).
final standard = SpringDescription.withDurationAndBounce(
  duration: const Duration(milliseconds: 550),
);

/// A spring with a predefined duration and higher amount of bounce.
final bouncy = SpringDescription.withDurationAndBounce(bounce: 0.3);

/// A snappy spring with a damping fraction of 0.85.
final snappy = SpringDescription.withDurationAndBounce(bounce: 0.15);

/// A smooth spring with a predefined duration and no bounce.
final smooth = SpringDescription.withDurationAndBounce();

/// A spring animation with a lower response value,
/// intended for driving interactive animations.
final interactive = SpringDescription.withDurationAndBounce(
  bounce: 0.14,
  duration: const Duration(milliseconds: 150),
);

/// Test motion that records the last parameters passed to createSimulation
// ignore: must_be_immutable
class _TestMotion extends Motion {
  _TestMotion({super.tolerance});

  double? lastStart;
  double? lastEnd;
  double? lastVelocity;

  @override
  bool get needsSettle => false;

  @override
  bool get unboundedWillSettle => true;

  @override
  Simulation createSimulation({
    double start = 0,
    double end = 1,
    double velocity = 0,
  }) {
    lastStart = start;
    lastEnd = end;
    lastVelocity = velocity;

    return _TestSimulation(start, end, velocity, tolerance);
  }

  @override
  bool operator ==(Object other) =>
      other is _TestMotion && tolerance == other.tolerance;

  @override
  int get hashCode => tolerance.hashCode;
}

/// Test simulation that does basic linear interpolation
class _TestSimulation extends Simulation {
  _TestSimulation(this.start, this.end, this.velocity, Tolerance tolerance)
      : super(tolerance: tolerance);

  final double start;
  final double end;
  final double velocity;

  @override
  double x(double time) => start + (end - start) * time;

  @override
  double dx(double time) => velocity;

  @override
  bool isDone(double time) => time >= 1.0;
}
