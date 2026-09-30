// ignore_for_file: unawaited_futures

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:motor/motor.dart';

import '../util.dart';

void main() {
  group('BoundedSingleMotionController', () {
    setUp(TestWidgetsFlutterBinding.ensureInitialized);

    late BoundedSingleMotionController controller;

    const spring = CupertinoMotion.smooth();

    tearDown(() {
      controller.dispose();
    });

    testWidgets(
        'the bounded factory passes on debugLabel and clamps set and '
        'animated values within bounds', (tester) async {
      controller = SingleMotionController.bounded(
        motion: spring,
        vsync: tester,
        debugLabel: 'progress',
      ) as BoundedSingleMotionController;

      expect(controller.internalInnerController.debugLabel, 'progress');

      expect(controller.value, equals(0.0));
      controller.value = 2.0;
      expect(controller.value, equals(1.0));

      controller.value = -1.0;
      expect(controller.value, equals(0.0));

      controller.animateTo(2);
      await tester.pumpAndSettle();
      expect(controller.value, moreOrLessEquals(1, epsilon: error));

      controller.animateTo(-1);
      await tester.pumpAndSettle();
      expect(controller.value, moreOrLessEquals(0, epsilon: error));
    });

    for (final (name, initialValue, bound, low, high) in [
      ('forward', 0.0, 1.0, 0.0, 0.4),
      ('reverse', 1.0, 0.0, 0.6, 1.0),
    ]) {
      TickerFuture start() =>
          name == 'forward' ? controller.forward() : controller.reverse();

      testWidgets('$name animates to its default bound', (tester) async {
        controller = BoundedSingleMotionController(
          motion: spring,
          vsync: tester,
          initialValue: initialValue,
        );
        final future = start();

        await tester.pump();

        expect(future, isA<TickerFuture>());
        expect(controller.value, equals(initialValue));

        await tester.pump(const Duration(milliseconds: 100));

        expect(controller.value, greaterThan(low));
        expect(controller.value, lessThan(high));

        await tester.pumpAndSettle();
        expect(controller.value, moreOrLessEquals(bound, epsilon: error));
      });

      testWidgets('$name will overshoot', (tester) async {
        final values = <double>[];
        controller = BoundedSingleMotionController(
          motion: const CupertinoMotion.bouncy(),
          vsync: tester,
          initialValue: initialValue,
        );

        controller.addListener(() {
          values.add(controller.value);
        });
        start();

        await tester.pumpAndSettle();

        expect(
          values,
          contains(bound == 1 ? greaterThan(1.0) : lessThan(0.0)),
        );
        expect(
          controller.value,
          closeTo(bound, controller.motion.tolerance.distance),
        );
      });
    }

    testWidgets('forward with curve is equivalent to AnimationController',
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
        motion: const CurvedMotion(duration),
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

      // Neither controller emits a value synchronously when the animation
      // starts; the first notification comes from the first tick.
      expect(motionValues, isEmpty);
      expect(animationValues, isEmpty);

      await tester.pumpAndSettle();

      // MotionController drives a Ticker exactly like AnimationController and
      // emits the identical value sequence - no extra (synchronous) value at
      // the start and no duplicated frames. This locks the emission behavior
      // so a regression that adds or drops a frame is caught.
      expect(motionValues, equals(animationValues));
    });
  });
}
