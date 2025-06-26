// ignore_for_file: unawaited_futures

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:motor.dart';

import '../util.dart';

void main() {
  group('SingleMotionController', () {
    setUp(TestWidgetsFlutterBinding.ensureInitialized);

    late SingleMotionController controller;

    const spring = CupertinoMotion.smooth;

    tearDown(() {
      controller.dispose();
    });

    testWidgets('creates unbounded', (tester) async {
      controller = SingleMotionController(
        motion: spring,
        vsync: tester,
      );
      expect(controller.value, equals(0.0));
    });

    group('.animateTo', () {
      testWidgets('animates to target value', (tester) async {
        controller = SingleMotionController(
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
        controller = SingleMotionController(
          motion: spring,
          vsync: tester,
        )..animateTo(0.5, withVelocity: 2);
        await tester.pump();

        final initialVelocity = controller.velocity;
        expect(initialVelocity, moreOrLessEquals(2, epsilon: error));
        await tester.pumpAndSettle();
      });

      testWidgets('completes immediately if target is within tolerance',
          (tester) async {
        controller = SingleMotionController(
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
        controller = SingleMotionController(
          motion: spring,
          vsync: tester,
        )..animateTo(1);
        await tester.pump();
        expect(controller.value, equals(0));

        await tester.pump(const Duration(milliseconds: 100));
        expect(controller.isAnimating, isTrue);
        expect(controller.value, greaterThan(0));

        controller.stop();
        expect(controller.isAnimating, isTrue);
        final valueAfterStop = controller.value;

        await tester.pumpAndSettle();
        expect(
          controller.value,
          closeTo(
            valueAfterStop,
            spring.tolerance.distance,
          ),
        );
      });

      testWidgets('updates spring redirects simulation', (tester) async {
        controller = SingleMotionController(
          motion: spring,
          vsync: tester,
        )..animateTo(1);
        await tester.pump();

        final newSpring =
            CupertinoMotion(duration: const Duration(milliseconds: 100));
        controller.motion = newSpring;

        expect(controller.motion, equals(newSpring));
        expect(controller.isAnimating, isTrue);
        await tester.pumpAndSettle();
      });

      testWidgets('maintains velocity between animations', (tester) async {
        controller = SingleMotionController(
          motion: spring,
          vsync: tester,
        )..animateTo(1);
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

  group('BoundedSingleMotionController', () {
    setUp(TestWidgetsFlutterBinding.ensureInitialized);

    late BoundedSingleMotionController controller;

    const spring = CupertinoMotion.smooth;

    tearDown(() {
      controller.dispose();
    });

    testWidgets('creates with default bounds', (tester) async {
      controller = BoundedSingleMotionController(
        motion: spring,
        vsync: tester,
      );

      expect(controller.lowerBound, equals(0.0));
      expect(controller.upperBound, equals(1.0));
      expect(controller.value, equals(0.0));
      expect(controller.velocity, equals(0.0));
    });

    testWidgets('updates spring description', (tester) async {
      controller = BoundedSingleMotionController(
        motion: spring,
        vsync: tester,
      );
      final newSpring = CupertinoMotion.smooth.copyWithBounce(bounce: 0.1);
      controller.motion = newSpring;
      expect(controller.motion, equals(newSpring));
    });

    testWidgets('clamps value within bounds', (tester) async {
      controller = BoundedSingleMotionController(
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
        controller = BoundedSingleMotionController(
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
        controller = BoundedSingleMotionController(
          motion: CupertinoMotion.bouncy,
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

        controller = BoundedSingleMotionController(
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
    });

    group('.reverse', () {


      testWidgets('animates to lower bound', (tester) async {
        controller = BoundedSingleMotionController(
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
        controller = BoundedSingleMotionController(
          motion: CupertinoMotion.bouncy,
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
      testWidgets('clamps target within bounds', (tester) async {
        controller = BoundedSingleMotionController(
          motion: spring,
          vsync: tester,
        )..animateTo(2);

        await tester.pumpAndSettle();
        expect(controller.value, moreOrLessEquals(1, epsilon: error));

        controller.animateTo(-1);
        await tester.pumpAndSettle();
        expect(controller.value, moreOrLessEquals(0, epsilon: error));
      });
    });
  });
}
