// ignore_for_file: deprecated_member_use_from_same_package, unawaited_futures

import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:motor/motor.dart';

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

    const motion = CupertinoMotion.smooth();
    const converter = OffsetMotionConverter();

    testWidgets('creates with initial value', (tester) async {
      final controller = MotionController<Offset>(
        motion: motion,
        vsync: tester,
        converter: converter,
        initialValue: Offset.zero,
      );
      addTearDown(controller.dispose);
      expect(controller.value, equals(Offset.zero));
      expect(controller.velocity, equals(Offset.zero));
    });

    testWidgets('updates motion style', (tester) async {
      final controller = MotionController<Offset>(
        motion: motion,
        vsync: tester,
        converter: converter,
        initialValue: Offset.zero,
      );
      addTearDown(controller.dispose);
      final newSpring = SpringDescription.withDurationAndBounce(
        duration: const Duration(milliseconds: 100),
      );
      controller.motion = SpringMotion(newSpring);
      expect(controller.motion, isA<SpringMotion>());
      expect(
        (controller.motion as SpringMotion).description,
        equals(newSpring),
      );
    });

    testWidgets('creates a single ticker', (tester) async {
      final mockTickerProvider = _MockTickerProvider();
      final mockTicker = _MockTicker();
      when(() => mockTickerProvider.createTicker(any())).thenAnswer((_) {
        return mockTicker;
      });
      final controller = MotionController<Offset>(
        motion: motion,
        vsync: mockTickerProvider,
        converter: converter,
        initialValue: Offset.zero,
      );
      addTearDown(controller.dispose);

      verify(() => mockTickerProvider.createTicker(any())).called(1);
    });

    group('.animateTo', () {
      late MotionController<Offset> controller;
      tearDown(() {
        controller.dispose();
      });

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

      // regression: https://github.com/whynotmake-it/rivership/issues/76
      testWidgets(
          'animates with from parameter correctly when x values are identical',
          (tester) async {
        controller = MotionController<Offset>(
          motion: motion,
          vsync: tester,
          converter: converter,
          initialValue: Offset.zero,
        );

        // Track actual values during animation to debug
        final values = <Offset>[];
        controller.addListener(() {
          values.add(controller.value);
        });

        // Use the exact values from the bug report
        unawaited(
          controller.animateTo(
            const Offset(100, 400), // Same x as from value
            from: const Offset(100, 100),
          ),
        );

        await tester.pump();

        // Check first value after animation starts
        expect(values.isNotEmpty, isTrue);
        expect(values.first.dx, equals(100));
        expect(values.first.dy, equals(100));

        // Check intermediate values
        await tester.pump(const Duration(milliseconds: 100));
        expect(controller.value.dx, equals(100));
        expect(controller.value.dy, inExclusiveRange(100, 400));

        await tester.pumpAndSettle();
        expect(controller.value.dx, equals(100));
        expect(controller.value.dy, moreOrLessEquals(400, epsilon: error));

        // Check all recorded values to ensure x stayed at 100
        for (final recordedValue in values) {
          expect(
            recordedValue.dx,
            equals(100),
            reason: 'x changed from 100 during animation',
          );
        }
      });

      // regression: https://github.com/whynotmake-it/rivership/issues/76
      testWidgets(
          'animates with from parameter correctly when y values are identical',
          (tester) async {
        controller = MotionController<Offset>(
          motion: motion,
          vsync: tester,
          converter: converter,
          initialValue: Offset.zero,
        );

        // Track actual values during animation to debug
        final values = <Offset>[];
        controller.addListener(() {
          values.add(controller.value);
        });

        // Use the exact values from the bug report
        unawaited(
          controller.animateTo(
            const Offset(400, 100), // Same y as from value
            from: const Offset(100, 100),
          ),
        );

        await tester.pump();

        // Check first value after animation starts
        expect(values.isNotEmpty, isTrue);
        expect(values.first.dx, equals(100));
        expect(values.first.dy, equals(100));

        // Check intermediate values
        await tester.pump(const Duration(milliseconds: 100));
        expect(controller.value.dx, inExclusiveRange(100, 400));
        expect(controller.value.dy, equals(100));

        await tester.pumpAndSettle();
        expect(controller.value.dx, moreOrLessEquals(400, epsilon: error));
        expect(controller.value.dy, equals(100));

        // Check all recorded values to ensure y stayed at 100
        for (final recordedValue in values) {
          expect(
            recordedValue.dy,
            equals(100),
            reason: 'y changed from 100 during animation',
          );
        }
      });
    });

    group('.motion', () {
      late MotionController<Offset> controller;
      tearDown(() {
        controller.dispose();
      });

      testWidgets('redirects simulation', (tester) async {
        controller = MotionController<Offset>(
          motion: motion,
          vsync: tester,
          converter: converter,
          initialValue: Offset.zero,
        )..animateTo(const Offset(1, 1));
        await tester.pump();

        final newSpring = SpringDescription.withDurationAndBounce(
          duration: const Duration(milliseconds: 100),
        );

        controller.motion = SpringMotion(newSpring);

        expect(controller.motion, isA<SpringMotion>());
        expect(
          (controller.motion as SpringMotion).description,
          equals(newSpring),
        );
        expect(controller.isAnimating, isTrue);
        await tester.pumpAndSettle();
      });
    });

    group('.stop', () {
      late MotionController<Offset> controller;
      tearDown(() {
        controller.dispose();
      });

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
      late MotionController<Offset> controller;
      tearDown(() {
        controller.dispose();
      });

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

    group('.status', () {
      late MotionController<Offset> controller;
      tearDown(() {
        controller.dispose();
      });

      testWidgets('is .dismissed initially', (tester) async {
        controller = MotionController<Offset>(
          motion: motion,
          vsync: tester,
          converter: converter,
          initialValue: Offset.zero,
        );
        expect(controller.status, equals(AnimationStatus.dismissed));
      });

      testWidgets('is forward when animating to larger values', (tester) async {
        controller = MotionController(
          motion: motion,
          vsync: tester,
          converter: converter,
          initialValue: Offset.zero,
        );

        unawaited(controller.animateTo(const Offset(1, 1)));
        await tester.pump();
        expect(controller.status, equals(AnimationStatus.forward));
        await tester.pumpAndSettle();
        expect(controller.status, equals(AnimationStatus.completed));
      });

      testWidgets('is forward when animating to smaller values',
          (tester) async {
        controller = MotionController<Offset>(
          motion: motion,
          vsync: tester,
          converter: converter,
          initialValue: const Offset(1, 1),
        );

        unawaited(controller.animateTo(Offset.zero));
        await tester.pump();
        expect(controller.status, equals(AnimationStatus.forward));
        await tester.pumpAndSettle();
        expect(controller.status, equals(AnimationStatus.completed));
      });

      testWidgets('is dismissed when back at initial value', (tester) async {
        controller = MotionController<Offset>(
          motion: motion,
          vsync: tester,
          converter: converter,
          initialValue: Offset.zero,
        );

        unawaited(controller.animateTo(const Offset(1, 1)));
        await tester.pump();
        expect(controller.status, equals(AnimationStatus.forward));
        await tester.pumpAndSettle();
        expect(controller.status, equals(AnimationStatus.completed));

        unawaited(controller.animateTo(Offset.zero));
        await tester.pump();
        expect(controller.status, equals(AnimationStatus.forward));
        await tester.pumpAndSettle();
        expect(controller.status, equals(AnimationStatus.dismissed));
      });
    });

    group('.converter', () {
      late MotionController<EdgeInsetsGeometry> controller;
      tearDown(() {
        controller.dispose();
      });

      testWidgets('will throw in constructor if value type does not match',
          (tester) async {
        const converter = EdgeInsetsMotionConverter();

        void initializeController() {
          controller = MotionController<EdgeInsetsGeometry>(
            motion: const CupertinoMotion.smooth(),
            vsync: tester,
            initialValue: EdgeInsetsDirectional.zero,
            converter: converter,
          );
        }

        expect(initializeController, throwsA(isA<TypeError>()));

        controller = MotionController<EdgeInsetsGeometry>(
          motion: const CupertinoMotion.smooth(),
          vsync: tester,
          initialValue: EdgeInsets.zero,
          converter: converter,
        );
      });

      testWidgets('will throw in setter if value type does not match',
          (tester) async {
        const converter = EdgeInsetsMotionConverter();
        controller = MotionController<EdgeInsetsGeometry>(
          motion: const CupertinoMotion.smooth(),
          vsync: tester,
          initialValue: EdgeInsets.zero,
          converter: converter,
        );

        void setValue() {
          controller.value = EdgeInsetsDirectional.zero;
        }

        expect(setValue, throwsA(isA<TypeError>()));
      });

      testWidgets('will throw in animateTo if value type does not match',
          (tester) async {
        const converter = EdgeInsetsMotionConverter();
        controller = MotionController<EdgeInsetsGeometry>(
          motion: const CupertinoMotion.smooth(),
          vsync: tester,
          initialValue: EdgeInsets.zero,
          converter: converter,
        );

        void animate() {
          controller.animateTo(EdgeInsetsDirectional.zero);
        }

        expect(animate, throwsA(isA<TypeError>()));
      });

      testWidgets('can be swapped mid animation', (tester) async {
        const converterA = EdgeInsetsMotionConverter();
        const converterB = EdgeInsetsDirectionalMotionConverter();
        controller = MotionController<EdgeInsetsGeometry>(
          motion: const CupertinoMotion.smooth(),
          vsync: tester,
          initialValue: EdgeInsets.zero,
          converter: converterA,
        );

        addTearDown(controller.dispose);

        controller.animateTo(const EdgeInsets.all(100)).ignore();

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(controller.value.horizontal, greaterThan(0));

        controller.converter = converterB;
        controller.animateTo(EdgeInsetsDirectional.zero).ignore();

        await tester.pump();

        await tester.pumpAndSettle();

        expect(controller.value, isA<EdgeInsetsDirectional>());
        expect(
            controller.value.horizontal, moreOrLessEquals(0, epsilon: error));
        expect(controller.value.vertical, moreOrLessEquals(0, epsilon: error));
      });
    });
  });

  group('BoundedMotionController', () {
    setUp(TestWidgetsFlutterBinding.ensureInitialized);

    late BoundedMotionController<Offset> controller;
    const motion = CupertinoMotion.smooth();
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
          motion: const CupertinoMotion.bouncy(),
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
          motion: const CupertinoMotion.bouncy(),
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

    group('.status', () {
      testWidgets('is .dismissed initially', (tester) async {
        controller = BoundedMotionController<Offset>(
          motion: motion,
          vsync: tester,
          converter: converter,
          initialValue: Offset.zero,
          lowerBound: Offset.zero,
          upperBound: const Offset(1, 1),
        );
        expect(controller.status, equals(AnimationStatus.dismissed));
      });

      testWidgets('is forward when animating forward', (tester) async {
        controller = BoundedMotionController<Offset>(
          motion: motion,
          vsync: tester,
          converter: converter,
          initialValue: Offset.zero,
          lowerBound: Offset.zero,
          upperBound: const Offset(1, 1),
        );

        unawaited(controller.forward());
        await tester.pump();
        expect(controller.status, equals(AnimationStatus.forward));
        await tester.pumpAndSettle();
        expect(controller.status, equals(AnimationStatus.completed));
      });

      testWidgets('is reverse when animating to smaller values',
          (tester) async {
        controller = BoundedMotionController<Offset>(
          motion: motion,
          vsync: tester,
          converter: converter,
          initialValue: const Offset(1, 1),
          lowerBound: Offset.zero,
          upperBound: const Offset(1, 1),
        );

        unawaited(controller.reverse());
        await tester.pump();
        expect(controller.status, equals(AnimationStatus.reverse));
        await tester.pumpAndSettle();
        expect(controller.status, equals(AnimationStatus.dismissed));
      });

      testWidgets('returns last direction when stopped', (tester) async {
        controller = BoundedMotionController<Offset>(
          motion: motion,
          vsync: tester,
          converter: converter,
          initialValue: Offset.zero,
          lowerBound: Offset.zero,
          upperBound: const Offset(1, 1),
        );

        unawaited(controller.forward());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(controller.status, equals(AnimationStatus.forward));
        unawaited(controller.stop());
        await tester.pumpAndSettle();

        expect(controller.status, equals(AnimationStatus.forward));

        unawaited(controller.reverse());
        await tester.pump();
        await tester.pump();
        expect(controller.status, equals(AnimationStatus.reverse));
        unawaited(controller.stop());
        await tester.pumpAndSettle();
        expect(controller.status, equals(AnimationStatus.reverse));

        unawaited(controller.reverse());
        await tester.pumpAndSettle();
        expect(controller.status, equals(AnimationStatus.dismissed));
      });
    });
  });
}
