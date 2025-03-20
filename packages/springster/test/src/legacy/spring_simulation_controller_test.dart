// ignore_for_file: unawaited_futures, deprecated_member_use_from_same_package

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:springster/springster.dart';

import '../util.dart';

void main() {
  group('SpringSimulationController', () {
    setUp(TestWidgetsFlutterBinding.ensureInitialized);

    late SpringSimulationController controller;

    const spring = Spring();

    tearDown(() {
      controller.dispose();
    });

    testWidgets('creates with default bounds', (tester) async {
      controller = SpringSimulationController(
        spring: spring,
        vsync: tester,
      );
      expect(controller.lowerBound, equals(0.0));
      expect(controller.upperBound, equals(1.0));
      expect(controller.value, equals(0.0));
      expect(controller.velocity, equals(0.0));
    });

    testWidgets('creates unbounded', (tester) async {
      controller = SpringSimulationController.unbounded(
        spring: spring,
        vsync: tester,
      );
      expect(controller.lowerBound, equals(double.negativeInfinity));
      expect(controller.upperBound, equals(double.infinity));
      expect(controller.isBounded, isFalse);
    });

    testWidgets('updates spring description', (tester) async {
      controller = SpringSimulationController(
        spring: spring,
        vsync: tester,
      );
      const newSpring = Spring(durationSeconds: 0.1);
      controller.spring = newSpring;
      expect(controller.spring, equals(newSpring));
    });

    testWidgets('clamps value within bounds', (tester) async {
      controller = SpringSimulationController(
        spring: spring,
        vsync: tester,
      );
      expect(controller.value, equals(0.0));
      controller.value = 2.0;
      expect(controller.value, equals(1.0));

      controller.value = -1.0;
      expect(controller.value, equals(0.0));
    });

    group('.forward', () {
      testWidgets('animates to upper bound', (tester) async {
        controller = SpringSimulationController(
          spring: spring,
          vsync: tester,
        );
        final future = controller.forward();

        await tester.pump();

        expect(future, isA<TickerFuture>());
        expect(controller.value, equals(0.0));

        await tester.pump(const Duration(milliseconds: 100));

        expect(controller.value, greaterThan(0.0));
        expect(controller.value, lessThan(0.4));

        await tester.pumpAndSettle();
        expect(controller.value, moreOrLessEquals(1, epsilon: error));
      });
      testWidgets('will overshoot', (tester) async {
        var overshot = false;
        controller = SpringSimulationController(
          spring: Spring.bouncy,
          vsync: tester,
        );

        controller
          ..addListener(() {
            if (controller.value > 1.0) {
              overshot = true;
            }
          })
          ..forward();

        await tester.pumpAndSettle();

        expect(overshot, isTrue);
        expect(controller.value, closeTo(1.0, 0.01));
      });

      testWidgets('throws if called on unbounded controller', (tester) async {
        controller = SpringSimulationController.unbounded(
          spring: spring,
          vsync: tester,
        );
        expect(() => controller.forward(), throwsAssertionError);
      });
    });

    group('.reverse', () {
      testWidgets('throws if called on unbounded controller', (tester) async {
        controller = SpringSimulationController.unbounded(
          spring: spring,
          vsync: tester,
        );
        expect(() => controller.reverse(), throwsAssertionError);
      });

      testWidgets('animates to lower bound', (tester) async {
        controller = SpringSimulationController(
          spring: spring,
          vsync: tester,
          initialValue: 1,
        );
        final future = controller.reverse();

        await tester.pump();

        expect(future, isA<TickerFuture>());
        expect(controller.value, equals(1.0));

        await tester.pump(const Duration(milliseconds: 100));

        expect(controller.value, lessThan(1.0));
        expect(controller.value, greaterThan(0.6));

        await tester.pumpAndSettle();
        expect(controller.value, moreOrLessEquals(0, epsilon: error));
      });

      testWidgets('will overshoot', (tester) async {
        var overshot = false;
        controller = SpringSimulationController(
          spring: Spring.bouncy,
          vsync: tester,
          initialValue: 1,
        );

        controller
          ..addListener(() {
            if (controller.value < 0.0) {
              overshot = true;
            }
          })
          ..reverse();

        await tester.pumpAndSettle();

        expect(overshot, isTrue);
        expect(controller.value, closeTo(0.0, 0.01));
      });
    });

    group('.animateTo', () {
      testWidgets('animates to target value', (tester) async {
        controller = SpringSimulationController(
          spring: spring,
          vsync: tester,
        );
        final future = controller.animateTo(0.5);

        await tester.pump();
        expect(future, isA<TickerFuture>());
        expect(controller.value, equals(0.0));

        await tester.pump(const Duration(milliseconds: 100));
        expect(controller.value, greaterThan(0.0));
        expect(controller.value, lessThan(0.5));

        await tester.pumpAndSettle();
        expect(controller.value, moreOrLessEquals(0.5, epsilon: error));
      });

      testWidgets('animates with initial velocity', (tester) async {
        controller = SpringSimulationController(
          spring: spring,
          vsync: tester,
        )..animateTo(0.5, withVelocity: 2);
        await tester.pump();

        final initialVelocity = controller.velocity;
        expect(initialVelocity, moreOrLessEquals(2, epsilon: error));
        await tester.pumpAndSettle();
      });

      testWidgets('clamps target within bounds', (tester) async {
        controller = SpringSimulationController(
          spring: spring,
          vsync: tester,
        )..animateTo(2);

        await tester.pumpAndSettle();
        expect(controller.value, moreOrLessEquals(1, epsilon: error));

        controller.animateTo(-1);
        await tester.pumpAndSettle();
        expect(controller.value, moreOrLessEquals(0, epsilon: error));
      });

      testWidgets('completes immediately if target is within tolerance',
          (tester) async {
        controller = SpringSimulationController(
          spring: spring,
          vsync: tester,
          initialValue: 0.5,
        );

        controller.animateTo(0.5 + controller.tolerance.distance / 2);
        final pumps = await tester.pumpAndSettle();

        expect(pumps, 1);
      });
    });

    group('stop and control', () {
      testWidgets('does not stop animation immediately if canceled is false',
          (tester) async {
        controller = SpringSimulationController(
          spring: spring,
          vsync: tester,
        )..forward();
        await tester.pump();
        expect(controller.isAnimating, isTrue);

        controller.stop();
        expect(controller.isAnimating, isTrue);
        final valueAfterStop = controller.value;

        await tester.pump(const Duration(milliseconds: 100));
        expect(controller.value, equals(valueAfterStop));
      });

      testWidgets('updates spring redirects simulation', (tester) async {
        controller = SpringSimulationController(
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
        controller = SpringSimulationController(
          spring: spring,
          vsync: tester,
        )..forward();
        await tester.pump(const Duration(milliseconds: 50));
        final midwayVelocity = controller.velocity;

        controller.animateTo(0.5);
        await tester.pump();
        expect(
          controller.velocity,
          moreOrLessEquals(midwayVelocity, epsilon: error),
        );
        await tester.pumpAndSettle();
      });
    });
  });
}
