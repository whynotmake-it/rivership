// ignore_for_file: unawaited_futures

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:springster/springster.dart';

import 'util.dart';

void main() {
  group('SpringSimulationController2D', () {
    setUp(TestWidgetsFlutterBinding.ensureInitialized);

    late SpringSimulationController2D controller;

    const spring = Spring();

    tearDown(() {
      controller.dispose();
    });

    testWidgets('creates with default bounds', (tester) async {
      controller = SpringSimulationController2D(
        spring: spring,
        vsync: tester,
      );
      expect(controller.lowerBound, equals(const (0.0, 0.0)));
      expect(controller.upperBound, equals(const (1.0, 1.0)));
      expect(controller.value, equals(const (0.0, 0.0)));
      expect(controller.velocity, equals(const (0.0, 0.0)));
    });

    testWidgets('creates unbounded', (tester) async {
      controller = SpringSimulationController2D.unbounded(
        spring: spring,
        vsync: tester,
      );
      expect(
        controller.lowerBound,
        equals(const (double.negativeInfinity, double.negativeInfinity)),
      );
      expect(
        controller.upperBound,
        equals(const (double.infinity, double.infinity)),
      );
      expect(controller.isBounded, isFalse);
    });

    testWidgets('updates spring description', (tester) async {
      controller = SpringSimulationController2D(
        spring: spring,
        vsync: tester,
      );
      const newSpring = Spring(durationSeconds: 0.1);
      controller.spring = newSpring;
      expect(controller.spring, equals(newSpring));
    });

    testWidgets('clamps value within bounds', (tester) async {
      controller = SpringSimulationController2D(
        spring: spring,
        vsync: tester,
      );
      expect(controller.value, equals(const (0.0, 0.0)));
      controller.value = const (2.0, 2.0);
      expect(controller.value, equals(const (1.0, 1.0)));

      controller.value = const (-1.0, -1.0);
      expect(controller.value, equals(const (0.0, 0.0)));
    });

    group('.forward', () {
      testWidgets('animates to upper bound', (tester) async {
        controller = SpringSimulationController2D(
          spring: spring,
          vsync: tester,
        );
        final future = controller.forward();

        await tester.pump();

        expect(future, isA<TickerFuture>());
        expect(controller.value, equals(const (0.0, 0.0)));

        await tester.pump(const Duration(milliseconds: 100));

        expect(controller.value.$1, greaterThan(0.0));
        expect(controller.value.$1, lessThan(0.4));
        expect(controller.value.$2, greaterThan(0.0));
        expect(controller.value.$2, lessThan(0.4));

        await tester.pumpAndSettle();
        expect(controller.value.$1, moreOrLessEquals(1, epsilon: error));
        expect(controller.value.$2, moreOrLessEquals(1, epsilon: error));
      });

      testWidgets('will overshoot', (tester) async {
        var overshot = false;
        controller = SpringSimulationController2D(
          spring: Spring.bouncy,
          vsync: tester,
        );

        controller
          ..addListener(() {
            if (controller.value.$1 > 1.0 || controller.value.$2 > 1.0) {
              overshot = true;
            }
          })
          ..forward();

        await tester.pumpAndSettle();

        expect(overshot, isTrue);
        expect(controller.value.$1, closeTo(1.0, 0.01));
        expect(controller.value.$2, closeTo(1.0, 0.01));
      });

      testWidgets('throws if called on unbounded controller', (tester) async {
        controller = SpringSimulationController2D.unbounded(
          spring: spring,
          vsync: tester,
        );
        expect(() => controller.forward(), throwsAssertionError);
      });
    });

    group('.reverse', () {
      testWidgets('throws if called on unbounded controller', (tester) async {
        controller = SpringSimulationController2D.unbounded(
          spring: spring,
          vsync: tester,
        );
        expect(() => controller.reverse(), throwsAssertionError);
      });

      testWidgets('animates to lower bound', (tester) async {
        controller = SpringSimulationController2D(
          spring: spring,
          vsync: tester,
          initialValue: const (1, 1),
        );
        final future = controller.reverse();

        await tester.pump();

        expect(future, isA<TickerFuture>());
        expect(controller.value, equals(const (1.0, 1.0)));

        await tester.pump(const Duration(milliseconds: 100));

        expect(controller.value.$1, lessThan(1.0));
        expect(controller.value.$1, greaterThan(0.6));
        expect(controller.value.$2, lessThan(1.0));
        expect(controller.value.$2, greaterThan(0.6));

        await tester.pumpAndSettle();
        expect(controller.value.$1, moreOrLessEquals(0, epsilon: error));
        expect(controller.value.$2, moreOrLessEquals(0, epsilon: error));
      });

      testWidgets('will overshoot', (tester) async {
        var overshot = false;
        controller = SpringSimulationController2D(
          spring: Spring.bouncy,
          vsync: tester,
          initialValue: const (1, 1),
        );

        controller
          ..addListener(() {
            if (controller.value.$1 < 0.0 || controller.value.$2 < 0.0) {
              overshot = true;
            }
          })
          ..reverse();

        await tester.pumpAndSettle();

        expect(overshot, isTrue);
        expect(controller.value.$1, closeTo(0.0, 0.01));
        expect(controller.value.$2, closeTo(0.0, 0.01));
      });
    });

    group('.animateTo', () {
      testWidgets('animates to target value', (tester) async {
        controller = SpringSimulationController2D(
          spring: spring,
          vsync: tester,
        );
        final future = controller.animateTo(const (0.5, 0.5));

        await tester.pump();
        expect(future, isA<TickerFuture>());
        expect(controller.value, equals(const (0.0, 0.0)));

        await tester.pump(const Duration(milliseconds: 100));
        expect(controller.value.$1, greaterThan(0.0));
        expect(controller.value.$1, lessThan(0.5));
        expect(controller.value.$2, greaterThan(0.0));
        expect(controller.value.$2, lessThan(0.5));

        await tester.pumpAndSettle();
        expect(controller.value.$1, moreOrLessEquals(0.5, epsilon: error));
        expect(controller.value.$2, moreOrLessEquals(0.5, epsilon: error));
      });

      testWidgets('animates with initial velocity', (tester) async {
        controller = SpringSimulationController2D(
          spring: spring,
          vsync: tester,
        )..animateTo(const (0.5, 0.5), withVelocity: const (2, 2));
        await tester.pump();

        final initialVelocity = controller.velocity;
        expect(initialVelocity.$1, moreOrLessEquals(2, epsilon: error));
        expect(initialVelocity.$2, moreOrLessEquals(2, epsilon: error));
        await tester.pumpAndSettle();
      });

      testWidgets('clamps target within bounds', (tester) async {
        controller = SpringSimulationController2D(
          spring: spring,
          vsync: tester,
        )..animateTo(const (2, 2));

        await tester.pumpAndSettle();
        expect(controller.value.$1, moreOrLessEquals(1, epsilon: error));
        expect(controller.value.$2, moreOrLessEquals(1, epsilon: error));

        controller.animateTo(const (-1, -1));
        await tester.pumpAndSettle();
        expect(controller.value.$1, moreOrLessEquals(0, epsilon: error));
        expect(controller.value.$2, moreOrLessEquals(0, epsilon: error));
      });

      testWidgets('completes immediately if target is within tolerance',
          (tester) async {
        controller = SpringSimulationController2D(
          spring: spring,
          vsync: tester,
          initialValue: const (0.5, 0.5),
        );

        controller.animateTo(
          (
            0.5 + controller.tolerance.distance / 2,
            0.5 + controller.tolerance.distance / 2,
          ),
        );
        final pumps = await tester.pumpAndSettle();

        expect(pumps, 1);
      });

      testWidgets('animates only changed dimension', (tester) async {
        controller = SpringSimulationController2D(
          spring: spring,
          vsync: tester,
          initialValue: const (0.5, 0.5),
        );
        expect(controller.value, equals(const (0.5, 0.5)));

        // Only animate x
        controller.animateTo(const (0.8, 0.5));
        await tester.pump();
        expect(controller.value.$1, equals(0.5));
        expect(controller.value.$2, equals(0.5));
        await tester.pumpAndSettle();
        expect(controller.value.$1, moreOrLessEquals(0.8, epsilon: error));
        expect(controller.value.$2, moreOrLessEquals(0.5, epsilon: error));

        // Only animate y
        controller.animateTo(const (0.8, 0.8));
        await tester.pump();
        expect(controller.value.$1, moreOrLessEquals(0.8, epsilon: error));
        expect(controller.value.$2, equals(0.5));
        await tester.pumpAndSettle();
        expect(controller.value.$1, moreOrLessEquals(0.8, epsilon: error));
        expect(controller.value.$2, moreOrLessEquals(0.8, epsilon: error));
      });

      // regression: https://github.com/whynotmake-it/rivership/issues/76
      testWidgets(
          'animates with from parameter correctly when x values are identical',
          (tester) async {
        controller = SpringSimulationController2D.unbounded(
          spring: spring,
          vsync: tester,
        );

        // Track actual values during animation to debug
        final values = <Double2D>[];
        controller
          ..addListener(() {
            values.add(controller.value);
          })

          // Use the exact values from the bug report
          ..animateTo(
            const (100, 400), // Same x as from value
            from: const (100, 100),
          );

        await tester.pump();

        // Check first value after animation starts
        expect(values.isNotEmpty, isTrue);
        expect(values.first.x, equals(100));
        expect(values.first.y, equals(100));

        // Check intermediate values
        await tester.pump(const Duration(milliseconds: 100));
        expect(controller.value.x, equals(100));
        expect(controller.value.y, inExclusiveRange(100, 400));

        await tester.pumpAndSettle();
        expect(controller.value.x, equals(100));
        expect(controller.value.y, moreOrLessEquals(400, epsilon: error));

        // Check all recorded values to ensure x stayed at 100
        for (final recordedValue in values) {
          expect(
            recordedValue.x,
            equals(100),
            reason: 'x changed from 100 during animation',
          );
        }
      });

      // regression: https://github.com/whynotmake-it/rivership/issues/76
      testWidgets(
          'animates with from parameter correctly when y values are identical',
          (tester) async {
        controller = SpringSimulationController2D.unbounded(
          spring: spring,
          vsync: tester,
        );

        // Track actual values during animation to debug
        final values = <Double2D>[];
        controller
          ..addListener(() {
            values.add(controller.value);
          })

          // Use the exact values from the bug report
          ..animateTo(
            const (400, 100), // Same x as from value
            from: const (100, 100),
          );

        await tester.pump();

        // Check first value after animation starts
        expect(values.isNotEmpty, isTrue);
        expect(values.first.x, equals(100));
        expect(values.first.y, equals(100));

        // Check intermediate values
        await tester.pump(const Duration(milliseconds: 100));
        expect(controller.value.x, inExclusiveRange(100, 400));
        expect(controller.value.y, equals(100));

        await tester.pumpAndSettle();
        expect(controller.value.x, moreOrLessEquals(400, epsilon: error));
        expect(controller.value.y, equals(100));

        // Check all recorded values to ensure y stayed at 100
        for (final recordedValue in values) {
          expect(
            recordedValue.y,
            equals(100),
            reason: 'x changed from 100 during animation',
          );
        }
      });
    });

    group('stop and control', () {
      testWidgets('stop settles animation by default', (tester) async {
        controller = SpringSimulationController2D(
          spring: spring,
          vsync: tester,
        )..forward();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 40));
        expect(controller.isAnimating, isTrue);

        controller.stop();
        final valueAfterStop = controller.value;
        expect(controller.isAnimating, isTrue);

        final pumps = await tester.pumpAndSettle();
        expect(controller.isAnimating, isFalse);
        expect(pumps, 10);
        expect(
          controller.value.x,
          moreOrLessEquals(valueAfterStop.x, epsilon: error),
        );
        expect(
          controller.value.y,
          moreOrLessEquals(valueAfterStop.y, epsilon: error),
        );
      });

      testWidgets('stops animation if canceled is true', (tester) async {
        controller = SpringSimulationController2D(
          spring: spring,
          vsync: tester,
        )..forward();
        await tester.pump();
        expect(controller.isAnimating, isTrue);

        controller.stop(canceled: true);
        expect(controller.isAnimating, isFalse);
        final valueAfterStop = controller.value;

        await tester.pump(const Duration(milliseconds: 100));
        expect(controller.value, equals(valueAfterStop));
      });

      testWidgets('updates spring redirects simulation', (tester) async {
        controller = SpringSimulationController2D(
          spring: spring,
          vsync: tester,
        )..forward();
        await tester.pump();

        const newSpring = Spring(durationSeconds: 0.1);
        controller.spring = newSpring;

        expect(controller.spring, equals(newSpring));
        expect(controller.isAnimating, isTrue);
        await tester.pumpAndSettle();
      });

      testWidgets('maintains velocity between animations', (tester) async {
        controller = SpringSimulationController2D(
          spring: spring,
          vsync: tester,
        )..forward();
        await tester.pump(const Duration(milliseconds: 50));
        final midwayVelocity = controller.velocity;

        controller.animateTo(const (0.5, 0.5));
        await tester.pump();
        expect(
          controller.velocity.$1,
          moreOrLessEquals(midwayVelocity.$1, epsilon: error),
        );
        expect(
          controller.velocity.$2,
          moreOrLessEquals(midwayVelocity.$2, epsilon: error),
        );
        await tester.pumpAndSettle();
      });
    });
  });

  group('Value2DGetters', () {
    test('provides x and y getters', () {
      const value = (1.0, 2.0);
      expect(value.x, equals(1.0));
      expect(value.y, equals(2.0));
    });

    test('converts to Offset', () {
      const value = (1.0, 2.0);
      expect(value.toOffset(), equals(const Offset(1, 2)));
    });
  });
}
