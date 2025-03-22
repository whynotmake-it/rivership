import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:springster/springster.dart';

import '../util.dart';

void main() {
  group('MotionController', () {
    setUp(TestWidgetsFlutterBinding.ensureInitialized);

    late MotionController<Double2D> controller;
    const spring = Spring();
    const motion = SpringMotion(spring);
    final converter = MotionConverter<Double2D>(
      normalize: (value) => [value.x, value.y],
      denormalize: (values) => (values[0], values[1]),
    );

    tearDown(() {
      controller.dispose();
    });

    testWidgets('creates with initial value', (tester) async {
      controller = MotionController<Double2D>(
        motion: motion,
        vsync: tester,
        converter: converter,
        initialValue: const (0.0, 0.0),
      );
      expect(controller.value, equals(const (0.0, 0.0)));
      expect(controller.velocity, equals(const (0.0, 0.0)));
    });

    testWidgets('updates motion style', (tester) async {
      controller = MotionController<Double2D>(
        motion: motion,
        vsync: tester,
        converter: converter,
        initialValue: const (0.0, 0.0),
      );
      const newSpring = Spring(durationSeconds: 0.1);
      controller.motion = const SpringMotion(newSpring);
      expect(controller.motion, isA<SpringMotion>());
      expect((controller.motion as SpringMotion).spring, equals(newSpring));
    });

    group('.animateTo', () {
      testWidgets('animates to target value', (tester) async {
        controller = MotionController<Double2D>(
          motion: motion,
          vsync: tester,
          converter: converter,
          initialValue: const (0.0, 0.0),
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
        controller = MotionController<Double2D>(
          motion: motion,
          vsync: tester,
          converter: converter,
          initialValue: const (0.0, 0.0),
        )..animateTo(const (0.5, 0.5), withVelocity: const (2, 2));
        await tester.pump();

        final initialVelocity = controller.velocity;
        expect(initialVelocity.$1, moreOrLessEquals(2, epsilon: error));
        expect(initialVelocity.$2, moreOrLessEquals(2, epsilon: error));
        await tester.pumpAndSettle();
      });

      testWidgets('completes immediately if target is within tolerance',
          (tester) async {
        controller = MotionController<Double2D>(
          motion: motion,
          vsync: tester,
          converter: converter,
          initialValue: const (0.5, 0.5),
        )..animateTo(
            (
              0.5 + motion.tolerance.distance / 2,
              0.5 + motion.tolerance.distance / 2,
            ),
          );
        final pumps = await tester.pumpAndSettle();

        expect(pumps, 1);
      });

      testWidgets('animates only changed dimension', (tester) async {
        controller = MotionController<Double2D>(
          motion: motion,
          vsync: tester,
          converter: converter,
          initialValue: const (0.5, 0.5),
        );
        expect(controller.value, equals(const (0.5, 0.5)));

        // Only animate x
        unawaited(controller.animateTo(const (0.8, 0.5)));
        await tester.pump();
        expect(controller.value.$1, equals(0.5));
        expect(controller.value.$2, equals(0.5));
        await tester.pumpAndSettle();
        expect(controller.value.$1, moreOrLessEquals(0.8, epsilon: error));
        expect(controller.value.$2, moreOrLessEquals(0.5, epsilon: error));

        // Only animate y
        unawaited(controller.animateTo(const (0.8, 0.8)));
        await tester.pump();
        expect(controller.value.$1, moreOrLessEquals(0.8, epsilon: error));
        expect(controller.value.$2, equals(0.5));
        await tester.pumpAndSettle();
        expect(controller.value.$1, moreOrLessEquals(0.8, epsilon: error));
        expect(controller.value.$2, moreOrLessEquals(0.8, epsilon: error));
      });
    });

    group('stop and control', () {
      testWidgets('stop settles animation by default', (tester) async {
        controller = MotionController<Double2D>(
          motion: motion,
          vsync: tester,
          converter: converter,
          initialValue: const (0.0, 0.0),
        )..animateTo(const (1.0, 1.0));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 40));
        expect(controller.isAnimating, isTrue);

        unawaited(controller.stop());

        final valueAfterStop = controller.value;
        expect(controller.isAnimating, isTrue);

        final pumps = await tester.pumpAndSettle();
        expect(controller.isAnimating, isFalse);
        expect(pumps, greaterThan(1));
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
        controller = MotionController<Double2D>(
          motion: motion,
          vsync: tester,
          converter: converter,
          initialValue: const (0.0, 0.0),
        )..animateTo(const (1.0, 1.0));
        await tester.pump();
        expect(controller.isAnimating, isTrue);

        unawaited(controller.stop(canceled: true));
        expect(controller.isAnimating, isFalse);
        final valueAfterStop = controller.value;

        await tester.pump(const Duration(milliseconds: 100));
        expect(controller.value, equals(valueAfterStop));
      });

      testWidgets('updates motion redirects simulation', (tester) async {
        controller = MotionController<Double2D>(
          motion: motion,
          vsync: tester,
          converter: converter,
          initialValue: const (0.0, 0.0),
        )..animateTo(const (1.0, 1.0));
        await tester.pump();

        const newSpring = Spring(durationSeconds: 0.1);
        controller.motion = const SpringMotion(newSpring);

        expect(controller.motion, isA<SpringMotion>());
        expect((controller.motion as SpringMotion).spring, equals(newSpring));
        expect(controller.isAnimating, isTrue);
        await tester.pumpAndSettle();
      });

      testWidgets('maintains velocity between animations', (tester) async {
        controller = MotionController<Double2D>(
          motion: motion,
          vsync: tester,
          converter: converter,
          initialValue: const (0.0, 0.0),
        )..animateTo(const (1.0, 1.0));
        await tester.pump(const Duration(milliseconds: 50));
        final midwayVelocity = controller.velocity;

        unawaited(controller.animateTo(const (0.5, 0.5)));

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

  group('BoundedMotionController', () {
    setUp(TestWidgetsFlutterBinding.ensureInitialized);

    late BoundedMotionController<Offset> controller;
    const spring = Spring();
    const motion = SpringMotion(spring);
    const converter = OffsetMotionConverter();

    tearDown(() {
      controller.dispose();
    });

    testWidgets('creates with default bounds', (tester) async {
      controller = BoundedMotionController<Offset>(
        motion: motion,
        vsync: tester,
        converter: converter,
        initialValue: Offset.zero,
        lowerBound: Offset.zero,
        upperBound: const Offset(1, 1),
      );
      expect(controller.lowerBound, equals(Offset.zero));
      expect(controller.upperBound, equals(const Offset(1, 1)));
      expect(controller.value, equals(Offset.zero));
      expect(controller.velocity, equals(Offset.zero));
    });

    testWidgets('clamps value within bounds', (tester) async {
      controller = BoundedMotionController<Offset>(
        motion: motion,
        vsync: tester,
        converter: converter,
        initialValue: Offset.zero,
        lowerBound: Offset.zero,
        upperBound: const Offset(1, 1),
      );
      expect(controller.value, equals(Offset.zero));
      controller.value = const Offset(2, 2);
      expect(controller.value, equals(const Offset(1, 1)));

      controller.value = const Offset(-1, -1);
      expect(controller.value, equals(Offset.zero));
    });

    group('.forward', () {
      testWidgets('animates to upper bound', (tester) async {
        controller = BoundedMotionController<Offset>(
          motion: motion,
          vsync: tester,
          converter: converter,
          initialValue: Offset.zero,
          lowerBound: Offset.zero,
          upperBound: const Offset(1, 1),
        );
        final future = controller.forward();

        await tester.pump();
        expect(future, isA<TickerFuture>());
        expect(controller.value, equals(Offset.zero));

        await tester.pump(const Duration(milliseconds: 100));
        expect(controller.value.dx, greaterThan(0.0));
        expect(controller.value.dx, lessThan(0.4));
        expect(controller.value.dy, greaterThan(0.0));
        expect(controller.value.dy, lessThan(0.4));

        await tester.pumpAndSettle();
        expect(controller.value.dx, moreOrLessEquals(1, epsilon: error));
        expect(controller.value.dy, moreOrLessEquals(1, epsilon: error));
      });

      testWidgets('will overshoot', (tester) async {
        var overshot = false;
        controller = BoundedMotionController<Offset>(
          motion: const SpringMotion(Spring.bouncy),
          vsync: tester,
          converter: converter,
          initialValue: Offset.zero,
          lowerBound: Offset.zero,
          upperBound: const Offset(1, 1),
        );

        controller
          ..addListener(() {
            if (controller.value.dx > 1.0 || controller.value.dy > 1.0) {
              overshot = true;
            }
          })
          ..forward();

        await tester.pumpAndSettle();

        expect(overshot, isTrue);
        expect(controller.value.dx, closeTo(1, motion.tolerance.distance));
        expect(controller.value.dy, closeTo(1, motion.tolerance.distance));
      });
    });

    group('.reverse', () {
      testWidgets('animates to lower bound', (tester) async {
        controller = BoundedMotionController<Offset>(
          motion: motion,
          vsync: tester,
          converter: converter,
          initialValue: const Offset(1, 1),
          lowerBound: Offset.zero,
          upperBound: const Offset(1, 1),
        );
        final future = controller.reverse();

        await tester.pump();
        expect(future, isA<TickerFuture>());
        expect(controller.value, equals(const Offset(1, 1)));

        await tester.pump(const Duration(milliseconds: 100));
        expect(controller.value.dx, lessThan(1.0));
        expect(controller.value.dx, greaterThan(0.6));
        expect(controller.value.dy, lessThan(1.0));
        expect(controller.value.dy, greaterThan(0.6));

        await tester.pumpAndSettle();
        expect(controller.value.dx, moreOrLessEquals(0, epsilon: error));
        expect(controller.value.dy, moreOrLessEquals(0, epsilon: error));
      });

      testWidgets('will overshoot', (tester) async {
        var overshot = false;
        controller = BoundedMotionController<Offset>(
          motion: const SpringMotion(Spring.bouncy),
          vsync: tester,
          converter: converter,
          initialValue: const Offset(1, 1),
          lowerBound: Offset.zero,
          upperBound: const Offset(1, 1),
        );

        controller
          ..addListener(() {
            if (controller.value.dx < 0.0 || controller.value.dy < 0.0) {
              overshot = true;
            }
          })
          ..reverse();

        await tester.pumpAndSettle();

        expect(overshot, isTrue);
        expect(controller.value.dx, closeTo(0, motion.tolerance.distance));
        expect(controller.value.dy, closeTo(0, motion.tolerance.distance));
      });
    });
  });
}
