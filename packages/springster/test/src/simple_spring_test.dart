// ignore_for_file: deprecated_member_use_from_same_package

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:springster/src/simple_spring.dart';

import 'util.dart';

void main() {
  group('SimpleSpring', () {
    setUp(() {});

    group('migration to Flutter SDK', () {
      void verifyMatch({
        required Duration duration,
        required double bounce,
        bool expectDifference = false,
      }) {
        final simple = SimpleSpring(
          bounce: bounce,
          durationSeconds:
              duration.inMicroseconds / Duration.microsecondsPerSecond,
        );
        final flutter = SpringDescription.withDurationAndBounce(
          bounce: bounce,
          duration: duration,
        );

        if (expectDifference) {
          // For negative bounce values, the implementations differ
          expect(flutter.mass, closeTo(simple.mass, 0.0001));
          expect(flutter.stiffness, closeTo(simple.stiffness, 0.1));
          // Damping and bounce will be different for negative values
          expect(flutter.damping, isNot(closeTo(simple.damping, 0.1)));
        } else {
          expect(flutter, equalsSimpleSpring(simple));
        }
      }

      test('parameters match for default', () async {
        const simple = SimpleSpring();
        final flutter = SpringDescription.withDurationAndBounce();

        expect(flutter, equalsSimpleSpring(simple));
      });

      test('parameters match for critically damped', () async {
        verifyMatch(
          duration: const Duration(milliseconds: 500),
          bounce: 0,
        );
      });

      test('parameters match for underdamped values', () async {
        for (final bounce in [0.1, 0.3, 0.5, 0.7, 0.9, 1.0]) {
          verifyMatch(
            duration: const Duration(seconds: 1),
            bounce: bounce,
          );
        }
      });

      test('parameters differ for overdamped values (negative bounce)',
          () async {
        for (final bounce in [-0.1, -0.3, -0.5, -0.7, -0.9]) {
          verifyMatch(
            duration: const Duration(seconds: 1),
            bounce: bounce,
            expectDifference: true,
          );
        }
      });

      test('parameters match across different durations', () async {
        for (final durationMs in [100, 300, 500, 1000, 2000]) {
          for (final bounce in [0.0, 0.2, 0.5, 0.8]) {
            verifyMatch(
              duration: Duration(milliseconds: durationMs),
              bounce: bounce,
            );
          }
        }
      });

      test('negative bounce behavior comparison', () async {
        // Test that shows the mathematical difference for negative bounce
        const bounce = -0.5;
        const duration = Duration(seconds: 1);

        final simple = SimpleSpring(
          bounce: bounce,
          durationSeconds: duration.inSeconds.toDouble(),
        );
        final flutter = SpringDescription.withDurationAndBounce(
          bounce: bounce,
          duration: duration,
        );

        // Both should have same mass and similar stiffness
        expect(flutter.mass, equals(simple.mass));
        expect(flutter.stiffness, closeTo(simple.stiffness, 0.1));

        // But damping will be different due to different formulas
        expect(flutter.damping, greaterThan(simple.damping));

        // SimpleSpring: damping = 4π(1 - bounce) = 4π(1.5) ≈ 18.85
        expect(simple.damping, closeTo(18.85, 0.1));

        // Flutter: uses dampingRatio = 1/(bounce + 1) = 2.0, then damping ≈ 25.1
        expect(flutter.damping, closeTo(25.1, 0.1));
      });
    });
  });
}
