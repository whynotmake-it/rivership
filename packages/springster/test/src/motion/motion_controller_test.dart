// ignore_for_file: unawaited_futures

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:springster/src/motion/motion_controller.dart';
import 'package:springster/src/motion/motion_style.dart';
import 'package:springster/src/spring.dart' as old;

import '../util.dart';

void main() {
  group('MotionController', () {
    setUp(TestWidgetsFlutterBinding.ensureInitialized);

    late MotionController controller;

    const spring = Spring(old.Spring());

    tearDown(() {
      controller.dispose();
    });

    testWidgets('creates with default bounds', (tester) async {
      controller = MotionController(
        motion: spring,
        vsync: tester,
      );
      expect(controller.lowerBound, equals(0.0));
      expect(controller.upperBound, equals(1.0));
      expect(controller.value, equals(0.0));
      expect(controller.velocity, equals(0.0));
    });

    testWidgets('creates unbounded', (tester) async {
      controller = MotionController.unbounded(
        motion: spring,
        vsync: tester,
      );
      expect(controller.lowerBound, equals(double.negativeInfinity));
      expect(controller.upperBound, equals(double.infinity));
      expect(controller.isBounded, isFalse);
    });

    testWidgets('updates spring description', (tester) async {
      controller = MotionController(
        motion: spring,
        vsync: tester,
      );
      const newSpring = Spring(old.Spring(durationSeconds: 0.1));
      controller.motion = newSpring;
      expect(controller.motion, equals(newSpring));
    });

    testWidgets('clamps value within bounds', (tester) async {
      controller = MotionController(
        motion: spring,
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
        controller = MotionController(
          motion: spring,
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
        final values = <double>[];
        controller = MotionController(
          motion: const Spring(old.Spring.bouncy),
          vsync: tester,
        );

        controller
          ..addListener(() {
            values.add(controller.value);
          })
          ..forward();

        await tester.pumpAndSettle();

        expect(values, contains(greaterThan(1.0)));
        expect(
          controller.value,
          closeTo(
            1.0,
            controller.motion.tolerance.distance,
          ),
        );
      });

      testWidgets('with curve is equivalent to AnimationController',
          (tester) async {
        final animationValues = <double>[];
        final motionValues = <double>[];

        const duration = Duration(seconds: 1);
        final animationController = AnimationController(
          duration: const Duration(seconds: 1),
          vsync: tester,
        );
        addTearDown(animationController.dispose);

        controller = MotionController(
          motion: const DurationAndCurve(duration: duration),
          vsync: tester,
        );

        animationController.addListener(() {
          animationValues.add(animationController.value);
        });
        controller.addListener(() {
          motionValues.add(controller.value);
        });

        animationController.forward();
        controller.forward();

        await tester.pumpAndSettle();

        expect(animationValues, equals(motionValues));
      });

      testWidgets('behaves like AnimationController on unbounded controller',
          (tester) async {
        final values = <double>[];
        const duration = Duration(seconds: 1);
        final animationValues = <double>[];
        final animationController = AnimationController.unbounded(
          duration: duration,
          vsync: tester,
        );
        addTearDown(animationController.dispose);

        controller = MotionController.unbounded(
          motion: const DurationAndCurve(duration: duration),
          vsync: tester,
        );

        controller
          ..addListener(() {
            values.add(controller.value);
          })
          ..forward();

        animationController
          ..addListener(() {
            animationValues.add(animationController.value);
          })
          ..forward();

        await tester.pumpAndSettle();

        expect(values, equals(animationValues));
      });
    });

    group('.reverse', () {
      testWidgets('behaves like AnimationController on unbounded controller',
          (tester) async {
        final values = <double>[];
        const duration = Duration(seconds: 1);
        final animationValues = <double>[];
        final animationController = AnimationController.unbounded(
          duration: duration,
          vsync: tester,
        );
        addTearDown(animationController.dispose);

        controller = MotionController.unbounded(
          motion: const DurationAndCurve(duration: duration),
          vsync: tester,
        );

        controller
          ..addListener(() {
            values.add(controller.value);
          })
          ..reverse(from: 1);

        animationController
          ..addListener(() {
            animationValues.add(animationController.value);
          })
          ..reverse(from: 1);

        await tester.pumpAndSettle();

        expect(values, equals(animationValues));
      });

      testWidgets('animates to lower bound', (tester) async {
        controller = MotionController(
          motion: spring,
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
        final values = <double>[];
        controller = MotionController(
          motion: const Spring(old.Spring.bouncy),
          vsync: tester,
          initialValue: 1,
        );

        controller
          ..addListener(() {
            values.add(controller.value);
          })
          ..reverse();

        await tester.pumpAndSettle();
        expect(values, contains(lessThan(0.0)));
        expect(
          controller.value,
          closeTo(
            0.0,
            controller.motion.tolerance.distance,
          ),
        );
      });
    });

    group('.animateTo', () {
      testWidgets('animates to target value', (tester) async {
        controller = MotionController(
          motion: spring,
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
        controller = MotionController(
          motion: spring,
          vsync: tester,
        )..animateTo(0.5, withVelocity: 2);
        await tester.pump();

        final initialVelocity = controller.velocity;
        expect(initialVelocity, moreOrLessEquals(2, epsilon: error));
        await tester.pumpAndSettle();
      });

      testWidgets('clamps target within bounds', (tester) async {
        controller = MotionController(
          motion: spring,
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
        controller = MotionController(
          motion: spring,
          vsync: tester,
          initialValue: 0.5,
        );

        controller.animateTo(0.5 + controller.motion.tolerance.distance / 2);
        final pumps = await tester.pumpAndSettle();

        expect(pumps, 1);
      });
    });

    group('stop and control', () {
      testWidgets('stops animation', (tester) async {
        controller = MotionController(
          motion: spring,
          vsync: tester,
        )..forward();
        await tester.pump();
        expect(controller.isAnimating, isTrue);

        controller.stop();
        expect(controller.isAnimating, isFalse);
        final valueAfterStop = controller.value;

        await tester.pump(const Duration(milliseconds: 100));
        expect(controller.value, equals(valueAfterStop));
      });

      testWidgets('updates spring redirects simulation', (tester) async {
        controller = MotionController(
          motion: spring,
          vsync: tester,
        )..forward();
        await tester.pump();

        const newSpring = Spring(old.Spring(durationSeconds: 0.1));
        controller.motion = newSpring;

        expect(controller.motion, equals(newSpring));
        expect(controller.isAnimating, isTrue);
        await tester.pumpAndSettle();
      });

      testWidgets('maintains velocity between animations', (tester) async {
        controller = MotionController(
          motion: spring,
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
