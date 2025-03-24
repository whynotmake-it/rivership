import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:springster/springster.dart';

import '../util.dart';

class _MockTickerProvider extends Mock implements TickerProvider {}

class _MockTicker extends Mock implements Ticker {
  @override
  String toString({bool debugIncludeStack = false}) {
    return 'MockTicker';
  }
}

void main() {
  group('MotionController', () {
    setUp(TestWidgetsFlutterBinding.ensureInitialized);

    late MotionController<Offset> controller;
    const spring = Spring();
    const motion = SpringMotion(spring);
    const converter = OffsetMotionConverter();

    tearDown(() {
      controller.dispose();
    });

    testWidgets('creates with initial value', (tester) async {
      controller = MotionController<Offset>(
        motion: motion,
        vsync: tester,
        converter: converter,
        initialValue: Offset.zero,
      );
      expect(controller.value, equals(Offset.zero));
      expect(controller.velocity, equals(Offset.zero));
    });

    testWidgets('updates motion style', (tester) async {
      controller = MotionController<Offset>(
        motion: motion,
        vsync: tester,
        converter: converter,
        initialValue: Offset.zero,
      );
      const newSpring = Spring(durationSeconds: 0.1);
      controller.motion = const SpringMotion(newSpring);
      expect(controller.motion, isA<SpringMotion>());
      expect((controller.motion as SpringMotion).spring, equals(newSpring));
    });

    testWidgets('creates a single ticker', (tester) async {
      final mockTickerProvider = _MockTickerProvider();
      final mockTicker = _MockTicker();
      when(() => mockTickerProvider.createTicker(any())).thenAnswer((_) {
        return mockTicker;
      });
      controller = MotionController<Offset>(
        motion: motion,
        vsync: mockTickerProvider,
        converter: converter,
        initialValue: Offset.zero,
      );

      verify(() => mockTickerProvider.createTicker(any())).called(1);
    });

    group('.animateTo', () {
      testWidgets('animates to target value', (tester) async {
        controller = MotionController<Offset>(
          motion: motion,
          vsync: tester,
          converter: converter,
          initialValue: Offset.zero,
        );
        expect(controller.status, equals(AnimationStatus.dismissed));
        final future = controller.animateTo(const Offset(0.5, 0.5));

        await tester.pump();
        expect(controller.status, equals(AnimationStatus.forward));

        expect(future, isA<TickerFuture>());
        expect(controller.value, equals(Offset.zero));

        await tester.pump(const Duration(milliseconds: 100));
        expect(controller.value.dx, greaterThan(0.0));
        expect(controller.value.dx, lessThan(0.5));
        expect(controller.value.dy, greaterThan(0.0));
        expect(controller.value.dy, lessThan(0.5));

        await tester.pumpAndSettle();

        expect(controller.status, equals(AnimationStatus.completed));

        expect(controller.value.dx, moreOrLessEquals(0.5, epsilon: error));
        expect(controller.value.dy, moreOrLessEquals(0.5, epsilon: error));
      });

      testWidgets('animates with initial velocity', (tester) async {
        controller = MotionController<Offset>(
          motion: motion,
          vsync: tester,
          converter: converter,
          initialValue: Offset.zero,
        )..animateTo(const Offset(0.5, 0.5), withVelocity: const Offset(2, 2));
        await tester.pump();

        final initialVelocity = controller.velocity;
        expect(initialVelocity.dx, moreOrLessEquals(2, epsilon: error));
        expect(initialVelocity.dy, moreOrLessEquals(2, epsilon: error));
        await tester.pumpAndSettle();
      });

      testWidgets('completes immediately if target is within tolerance',
          (tester) async {
        controller = MotionController<Offset>(
          motion: motion,
          vsync: tester,
          converter: converter,
          initialValue: const Offset(0.5, 0.5),
        )..animateTo(
            Offset(
              0.5 + motion.tolerance.distance / 2,
              0.5 + motion.tolerance.distance / 2,
            ),
          );
        final pumps = await tester.pumpAndSettle();

        expect(pumps, 1);
      });

      testWidgets('animates only changed dimension', (tester) async {
        controller = MotionController<Offset>(
          motion: motion,
          vsync: tester,
          converter: converter,
          initialValue: const Offset(0.5, 0.5),
        );
        expect(controller.value, equals(const Offset(0.5, 0.5)));

        // Only animate x
        unawaited(controller.animateTo(const Offset(0.8, 0.5)));
        await tester.pump();
        expect(controller.value.dx, equals(0.5));
        expect(controller.value.dy, equals(0.5));
        await tester.pumpAndSettle();
        expect(controller.value.dx, moreOrLessEquals(0.8, epsilon: error));
        expect(controller.value.dy, moreOrLessEquals(0.5, epsilon: error));

        // Only animate y
        unawaited(controller.animateTo(const Offset(0.8, 0.8)));
        await tester.pump();
        expect(controller.value.dx, moreOrLessEquals(0.8, epsilon: error));
        expect(controller.value.dy, equals(0.5));
        await tester.pumpAndSettle();
        expect(controller.value.dx, moreOrLessEquals(0.8, epsilon: error));
        expect(controller.value.dy, moreOrLessEquals(0.8, epsilon: error));
      });

      testWidgets('maintains velocity between animations', (tester) async {
        controller = MotionController<Offset>(
          motion: motion,
          vsync: tester,
          converter: converter,
          initialValue: Offset.zero,
        )..animateTo(const Offset(1, 1));
        await tester.pump(const Duration(milliseconds: 50));
        final midwayVelocity = controller.velocity;

        unawaited(controller.animateTo(const Offset(0.5, 0.5)));

        await tester.pump();
        expect(
          controller.velocity.dx,
          moreOrLessEquals(midwayVelocity.dx, epsilon: error),
        );
        expect(
          controller.velocity.dy,
          moreOrLessEquals(midwayVelocity.dy, epsilon: error),
        );
        await tester.pumpAndSettle();
      });
    });

    group('.motion', () {
      testWidgets('redirects simulation', (tester) async {
        controller = MotionController<Offset>(
          motion: motion,
          vsync: tester,
          converter: converter,
          initialValue: Offset.zero,
        )..animateTo(const Offset(1, 1));
        await tester.pump();

        const newSpring = Spring(durationSeconds: 0.1);
        controller.motion = const SpringMotion(newSpring);

        expect(controller.motion, isA<SpringMotion>());
        expect((controller.motion as SpringMotion).spring, equals(newSpring));
        expect(controller.isAnimating, isTrue);
        await tester.pumpAndSettle();
      });
    });

    group('.stop', () {
      testWidgets('stop settles animation by default', (tester) async {
        controller = MotionController<Offset>(
          motion: motion,
          vsync: tester,
          converter: converter,
          initialValue: Offset.zero,
        )..animateTo(const Offset(1, 1));
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
          controller.value.dx,
          moreOrLessEquals(valueAfterStop.dx, epsilon: error),
        );
        expect(
          controller.value.dy,
          moreOrLessEquals(valueAfterStop.dy, epsilon: error),
        );
      });

      testWidgets('stops animation if canceled is true', (tester) async {
        controller = MotionController<Offset>(
          motion: motion,
          vsync: tester,
          converter: converter,
          initialValue: Offset.zero,
        )..animateTo(const Offset(1, 1));
        await tester.pump();
        expect(controller.isAnimating, isTrue);

        unawaited(controller.stop(canceled: true));
        expect(controller.isAnimating, isFalse);
        final valueAfterStop = controller.value;

        await tester.pump(const Duration(milliseconds: 100));
        expect(controller.value, equals(valueAfterStop));
      });
    });

    group('.resync', () {
      testWidgets('resyncs the controller', (tester) async {
        final mockTickerProvider = _MockTickerProvider();
        final mockTicker = _MockTicker();

        when(() => mockTickerProvider.createTicker(any())).thenAnswer(
          (_) => mockTicker,
        );

        controller = MotionController<Offset>(
          motion: motion,
          vsync: mockTickerProvider,
          converter: converter,
          initialValue: Offset.zero,
        );

        verify(() => mockTickerProvider.createTicker(any()));

        controller.resync(mockTickerProvider);
        verify(() => mockTickerProvider.createTicker(any()));
        verify(() => mockTicker.absorbTicker(mockTicker));
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
