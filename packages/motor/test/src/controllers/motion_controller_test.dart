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

    // One ticker keeps the controller usable with a
    // SingleTickerProviderStateMixin.
    testWidgets('creates a single ticker and resync absorbs it',
        (tester) async {
      final mockTickerProvider = _MockTickerProvider();
      final mockTicker = _MockTicker();
      when(() => mockTickerProvider.createTicker(any())).thenAnswer(
        (_) => mockTicker,
      );
      final controller = MotionController<Offset>(
        motion: motion,
        vsync: mockTickerProvider,
        converter: converter,
        initialValue: Offset.zero,
      );
      addTearDown(controller.dispose);

      verify(() => mockTickerProvider.createTicker(any())).called(1);

      controller.resync(mockTickerProvider);
      verify(() => mockTickerProvider.createTicker(any())).called(1);
      verify(() => mockTicker.absorbTicker(mockTicker));
    });

    group('futures, like 1.x', () {
      const linear = Motion.linear(Duration(milliseconds: 100));

      testWidgets('setting value mid-flight completes the future',
          (tester) async {
        final controller =
            SingleMotionController(motion: linear, vsync: tester);
        addTearDown(controller.dispose);
        final future = _FutureOutcome(controller.animateTo(1));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 30));

        controller.value = 0.5;
        await tester.pump();

        expect(future.completed, isTrue);
        expect(future.canceled, isFalse);
      });

      testWidgets('each animateTo gets its own future and cancels the last',
          (tester) async {
        final controller =
            SingleMotionController(motion: linear, vsync: tester);
        addTearDown(controller.dispose);
        final firstFuture = controller.animateTo(1);
        final first = _FutureOutcome(firstFuture);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 30));

        final secondFuture = controller.animateTo(0);
        final second = _FutureOutcome(secondFuture);
        await tester.pumpAndSettle();

        expect(identical(firstFuture, secondFuture), isFalse);
        expect(first.completed, isFalse);
        expect(first.canceled, isTrue);
        expect(second.completed, isTrue);
      });

      testWidgets('a graceful stop that settles cancels the last future',
          (tester) async {
        final controller = SingleMotionController(
          motion: const CupertinoMotion(),
          vsync: tester,
        );
        addTearDown(controller.dispose);
        final first = _FutureOutcome(controller.animateTo(1));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        unawaited(controller.stop());
        await tester.pumpAndSettle();

        expect(first.completed, isFalse);
        expect(first.canceled, isTrue);
      });
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
      for (final (axis, target) in [
        ('x', const Offset(100, 400)),
        ('y', const Offset(400, 100)),
      ]) {
        testWidgets(
            'animates with from parameter correctly when $axis values are '
            'identical', (tester) async {
          double still(Offset value) => axis == 'x' ? value.dx : value.dy;
          double moving(Offset value) => axis == 'x' ? value.dy : value.dx;
          controller = MotionController<Offset>(
            motion: motion,
            vsync: tester,
            converter: converter,
            initialValue: Offset.zero,
          );
          final values = <Offset>[];
          controller.addListener(() {
            values.add(controller.value);
          });

          unawaited(
            controller.animateTo(target, from: const Offset(100, 100)),
          );

          await tester.pump();
          expect(values.isNotEmpty, isTrue);
          expect(values.first, equals(const Offset(100, 100)));

          await tester.pump(const Duration(milliseconds: 100));
          expect(still(controller.value), equals(100));
          expect(moving(controller.value), inExclusiveRange(100, 400));

          await tester.pumpAndSettle();
          expect(still(controller.value), equals(100));
          expect(
            moving(controller.value),
            moreOrLessEquals(400, epsilon: error),
          );

          for (final recordedValue in values) {
            expect(
              still(recordedValue),
              equals(100),
              reason: '$axis changed from 100 during animation',
            );
          }
        });
      }
    });

    group('.motion', () {
      testWidgets('only updates while idle and redirects simulation',
          (tester) async {
        final controller = MotionController<Offset>(
          motion: motion,
          vsync: tester,
          converter: converter,
          initialValue: Offset.zero,
        );
        addTearDown(controller.dispose);

        controller.motion = const CupertinoMotion.bouncy();
        expect(controller.motion, const CupertinoMotion.bouncy());
        expect(controller.isAnimating, isFalse);

        controller.animateTo(const Offset(1, 1));
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

    group('.status', () {
      testWidgets('if converter provides compare, it will be respected',
          (tester) async {
        final controller = SingleMotionController(
          motion: motion,
          vsync: tester,
        );
        addTearDown(controller.dispose);

        unawaited(controller.animateTo(3));
        await tester.pump();
        expect(controller.status, equals(AnimationStatus.forward));
        await tester.pumpAndSettle();
        expect(controller.status, equals(AnimationStatus.completed));

        unawaited(controller.animateTo(1));
        await tester.pump();
        expect(controller.status, equals(AnimationStatus.reverse));
        await tester.pumpAndSettle();
        expect(
          controller.status,
          equals(AnimationStatus.dismissed),
          reason: 'A downward move finishes dismissed',
        );

        unawaited(controller.animateTo(2));
        await tester.pumpAndSettle();
        expect(controller.status, equals(AnimationStatus.completed));

        unawaited(controller.animateTo(0));
        await tester.pump();
        expect(controller.status, equals(AnimationStatus.reverse));
        await tester.pumpAndSettle();
        expect(controller.status, equals(AnimationStatus.dismissed));
      });
    });

    group('converter swap', () {
      testWidgets('keeps an in-flight animation going', (tester) async {
        final controller = MotionController<double>(
          motion: const Motion.linear(Duration(milliseconds: 100)),
          vsync: tester,
          converter: MotionConverter.single,
          initialValue: 0,
        );
        addTearDown(controller.dispose);

        unawaited(controller.animateTo(1));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 30));
        controller.converter = MotionConverter.custom(
          normalize: (value) => [value],
          denormalize: (values) => values[0],
        );
        expect(controller.value, closeTo(0.3, error));
        expect(controller.isAnimating, isTrue);

        await tester.pump(const Duration(milliseconds: 20));
        expect(controller.value, closeTo(0.5, error));
        await tester.pumpAndSettle();
        expect(controller.value, closeTo(1, error));
      });

      testWidgets(
          'in a MotionBuilder with an inline converter, survives a parent '
          'rebuild mid-flight', (tester) async {
        var target = 0.0;
        late StateSetter setState;
        var built = -1.0;
        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, set) {
              setState = set;
              return MotionBuilder<double>(
                value: target,
                motion: const Motion.linear(Duration(milliseconds: 100)),
                converter: MotionConverter.custom(
                  normalize: (value) => [value],
                  denormalize: (values) => values[0],
                ),
                builder: (context, value, child) {
                  built = value;
                  return const SizedBox();
                },
              );
            },
          ),
        );

        setState(() => target = 1);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 30));
        setState(() {});
        await tester.pump();
        await tester.pumpAndSettle();
        expect(built, closeTo(1, error));
      });

      testWidgets('forgets replaced track state', (tester) async {
        final controller = MotionController<Offset>(
          motion: motion,
          vsync: tester,
          converter: converter,
          initialValue: Offset.zero,
        );
        addTearDown(controller.dispose);

        for (var i = 0; i < 100; i++) {
          controller.converter = MotionConverter.custom(
            normalize: (value) => [value.dx, value.dy],
            denormalize: (values) => Offset(values[0], values[1]),
          );
        }

        expect(controller.internalInnerController.debugTrackCount, 1);

        controller.animateTo(const Offset(1, 1)).ignore();
        await tester.pumpAndSettle();

        expect(controller.value.dx, moreOrLessEquals(1, epsilon: error));
        expect(controller.value.dy, moreOrLessEquals(1, epsilon: error));
      });

      testWidgets('reinterprets the current value under the new converter',
          (tester) async {
        final controller = MotionController<Offset>(
          motion: motion,
          vsync: tester,
          converter: converter,
          initialValue: const Offset(2, 3),
        );
        addTearDown(controller.dispose);

        controller.converter = MotionConverter.custom(
          normalize: (value) => [value.dy, value.dx],
          denormalize: (values) => Offset(values[1], values[0]),
        );

        expect(controller.value, const Offset(3, 2));
      });

      testWidgets(
          'reinterprets a mid-animation swap, keeps animating and does not '
          'report completion', (tester) async {
        final controller = MotionController<Offset>(
          motion: const Motion.linear(Duration(milliseconds: 40)),
          vsync: tester,
          converter: converter,
          initialValue: Offset.zero,
        );
        addTearDown(controller.dispose);
        final statuses = <AnimationStatus>[];
        controller
          ..addStatusListener(statuses.add)
          ..animateTo(const Offset(10, 20)).ignore();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 10));
        final valueBeforeSwap = controller.value;

        controller.converter = MotionConverter.custom(
          normalize: (value) => [value.dy, value.dx],
          denormalize: (values) => Offset(values[1], values[0]),
        );

        expect(tester.takeException(), isNull);
        expect(controller.isAnimating, isTrue);
        expect(
          controller.value,
          Offset(valueBeforeSwap.dy, valueBeforeSwap.dx),
        );
        expect(statuses, [AnimationStatus.forward]);
        await tester.pumpAndSettle();
      });
    });

    group('.converter', () {
      testWidgets('throws a TypeError for values the converter rejects',
          (tester) async {
        const converter = EdgeInsetsMotionConverter();

        expect(
          () => MotionController<EdgeInsetsGeometry>(
            motion: const CupertinoMotion.smooth(),
            vsync: tester,
            initialValue: EdgeInsetsDirectional.zero,
            converter: converter,
          ),
          throwsA(isA<TypeError>()),
        );

        final controller = MotionController<EdgeInsetsGeometry>(
          motion: const CupertinoMotion.smooth(),
          vsync: tester,
          initialValue: EdgeInsets.zero,
          converter: converter,
        );
        addTearDown(controller.dispose);

        expect(
          () => controller.value = EdgeInsetsDirectional.zero,
          throwsA(isA<TypeError>()),
        );
        expect(
          () => controller.animateTo(EdgeInsetsDirectional.zero),
          throwsA(isA<TypeError>()),
        );
      });

      testWidgets('can be swapped mid animation', (tester) async {
        const converterA = EdgeInsetsMotionConverter();
        const converterB = EdgeInsetsDirectionalMotionConverter();
        final controller = MotionController<EdgeInsetsGeometry>(
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
          controller.value.horizontal,
          moreOrLessEquals(0, epsilon: error),
        );
        expect(
          controller.value.vertical,
          moreOrLessEquals(0, epsilon: error),
        );
      });
    });
  });

  group('TrackController.forgetTrack', () {
    testWidgets('evicts state and allows lazy reinitialization',
        (tester) async {
      final controller = TrackController(vsync: tester);
      addTearDown(controller.dispose);
      final forgottenTrack = Track<Offset>(
        const OffsetMotionConverter(),
        initial: const Offset(2, 3),
      );
      final retainedTrack = Track<Offset>(
        const OffsetMotionConverter(),
        initial: Offset.zero,
        motion: const CupertinoMotion.smooth(),
      );

      controller
        ..set([forgottenTrack.value(const Offset(4, 5))])
        ..animate([retainedTrack.to(const Offset(1, 1))]);

      expect(controller.debugTrackCount, 2);

      controller.forgetTrack(forgottenTrack);

      expect(controller.debugTrackCount, 1);
      expect(controller.value(forgottenTrack), const Offset(2, 3));
      expect(controller.debugTrackCount, 2);

      await tester.pumpAndSettle();
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

    testWidgets('animateTo(forward: false) reports reverse, as in 1.x',
        (tester) async {
      controller = BoundedMotionController<Offset>(
        motion: motion,
        vsync: tester,
        converter: converter,
        initialValue: const Offset(1, 1),
        lowerBound: Offset.zero,
        upperBound: const Offset(1, 1),
      );
      final statuses = <AnimationStatus>[];
      controller
        ..addStatusListener(statuses.add)
        ..animateTo(const Offset(0.5, 0.5), forward: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.status, AnimationStatus.reverse);

      controller.stop();
      await tester.pumpAndSettle();
      expect(controller.status, AnimationStatus.reverse);

      controller.animateTo(const Offset(2, 2));
      await tester.pump();
      expect(controller.status, AnimationStatus.forward);
      await tester.pumpAndSettle();
      expect(controller.value, const Offset(1, 1));
      expect(statuses.first, AnimationStatus.reverse);
    });

    group('.status', () {
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

      testWidgets(
          'reports the direction of reverse() and forward() for a '
          'non-directional converter, as in 1.x', (tester) async {
        // OffsetMotionConverter has no direction, so the direction comes
        // from which bound the controller animates towards.
        controller = BoundedMotionController<Offset>(
          motion: motion,
          vsync: tester,
          converter: converter,
          initialValue: const Offset(1, 1),
          lowerBound: Offset.zero,
          upperBound: const Offset(1, 1),
        );
        final statuses = <AnimationStatus>[];
        controller.addStatusListener(statuses.add);

        unawaited(controller.reverse());
        await tester.pump();
        expect(controller.status, AnimationStatus.reverse);
        // Without a direction, dismissed means back at the initial value.
        await tester.pumpAndSettle();
        expect(controller.status, AnimationStatus.completed);

        unawaited(controller.forward());
        await tester.pump();
        expect(controller.status, AnimationStatus.forward);
        await tester.pumpAndSettle();
        expect(controller.status, AnimationStatus.dismissed);

        unawaited(controller.reverse());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        unawaited(controller.stop(canceled: true));
        expect(controller.status, AnimationStatus.reverse);

        expect(statuses, [
          AnimationStatus.reverse,
          AnimationStatus.completed,
          AnimationStatus.forward,
          AnimationStatus.dismissed,
          AnimationStatus.reverse,
        ]);
      });

      testWidgets(
          'keeps the direction when stopped and settles a directional '
          'reverse() at dismissed, as in 1.x', (tester) async {
        // Use a converter that orders based on x direction only
        final xDirectionConverter = MotionConverter.customDirectional(
          normalize: (value) => [value.dx, value.dy],
          denormalize: (values) => Offset(values[0], values[1]),
          compare: (a, b) => a.dx.compareTo(b.dx),
        );

        controller = BoundedMotionController<Offset>(
          motion: motion,
          vsync: tester,
          converter: xDirectionConverter,
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

        unawaited(controller.forward());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        unawaited(controller.stop(canceled: true));
        expect(controller.status, equals(AnimationStatus.forward));

        unawaited(controller.reverse());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        unawaited(controller.stop(canceled: true));
        expect(controller.status, equals(AnimationStatus.reverse));

        unawaited(controller.reverse());
        await tester.pump();
        expect(controller.status, equals(AnimationStatus.reverse));
        await tester.pumpAndSettle();
        expect(controller.status, equals(AnimationStatus.dismissed));
      });
    });
  });

  group('MotionController velocity tracking', () {
    setUp(TestWidgetsFlutterBinding.ensureInitialized);

    const motion = CupertinoMotion.smooth();
    const converter = OffsetMotionConverter();

    testWidgets('when disabled, set values leave the velocity at zero',
        (tester) async {
      final controller = MotionController<Offset>(
        motion: motion,
        vsync: tester,
        converter: converter,
        initialValue: Offset.zero,
        velocityTracking: const VelocityTracking.off(),
      );
      addTearDown(controller.dispose);

      expect(controller.velocity, equals(Offset.zero));
      expect(controller.trackedVelocityEstimate, isNull);

      controller.value = const Offset(10, 20);
      expect(controller.velocity, equals(Offset.zero));
      expect(controller.trackedVelocityEstimate, isNull);
    });

    group('with velocity tracking enabled (default)', () {
      testWidgets(
          'tracks velocity from set values and animateTo adopts it, then '
          'resets tracking', (tester) async {
        final controller = MotionController<Offset>(
          motion: motion,
          vsync: tester,
          converter: converter,
          initialValue: Offset.zero,
        );
        addTearDown(controller.dispose);

        // Set values at a constant 16ms cadence (the fake clock advances with
        // pump), moving by (10, 20) each frame. Four samples give the velocity
        // tracker full confidence, so the estimate is exact:
        // 10px / 16ms = 625 px/s on x, 20px / 16ms = 1250 px/s on y.
        const frame = Duration(milliseconds: 16);
        controller.value = Offset.zero;
        await tester.pump(frame);
        controller.value = const Offset(10, 20);
        await tester.pump(frame);
        controller.value = const Offset(20, 40);
        await tester.pump(frame);
        controller.value = const Offset(30, 60);

        final estimate = controller.trackedVelocityEstimate;
        expect(estimate, isNotNull);
        expect(estimate!.perSecond.dx, closeTo(625, error));
        expect(estimate.perSecond.dy, closeTo(1250, error));

        // When not animating, the velocity getter returns the tracked velocity.
        final trackedVelocity = controller.velocity;
        expect(trackedVelocity.dx, closeTo(625, error));
        expect(trackedVelocity.dy, closeTo(1250, error));

        // Without explicit velocity, animateTo adopts the tracked velocity as
        // its initial velocity (read at t=0).
        controller.animateTo(const Offset(100, 200));
        await tester.pump();

        final animationVelocity = controller.velocity;
        expect(
          animationVelocity.dx,
          moreOrLessEquals(trackedVelocity.dx, epsilon: error),
        );
        expect(
          animationVelocity.dy,
          moreOrLessEquals(trackedVelocity.dy, epsilon: error),
        );
        expect(controller.trackedVelocityEstimate, isNull);

        await tester.pumpAndSettle();
      });

      testWidgets(
          'animateTo with explicit velocity ignores tracked velocity and '
          'reads the simulation velocity while animating', (tester) async {
        final controller = MotionController<Offset>(
          motion: motion,
          vsync: tester,
          converter: converter,
          initialValue: Offset.zero,
        );
        addTearDown(controller.dispose);

        controller
          ..value = Offset.zero
          ..value = const Offset(10, 20)
          ..value = const Offset(20, 40)
          ..animateTo(
            const Offset(100, 200),
            withVelocity: const Offset(500, 500),
          );
        await tester.pump();

        expect(controller.isAnimating, isTrue);
        final initialVelocity = controller.velocity;
        expect(initialVelocity.dx, moreOrLessEquals(500.0, epsilon: error));
        expect(initialVelocity.dy, moreOrLessEquals(500.0, epsilon: error));

        await tester.pumpAndSettle();
        expect(controller.isAnimating, isFalse);

        // No tracked samples since animateTo reset the tracker.
        expect(controller.velocity, equals(Offset.zero));
      });

      testWidgets('changing converter recreates velocity tracker',
          (tester) async {
        final controller = MotionController<Offset>(
          motion: motion,
          vsync: tester,
          converter: converter,
          initialValue: Offset.zero,
        );
        addTearDown(controller.dispose);

        controller
          ..value = Offset.zero
          ..value = const Offset(10, 20);

        expect(controller.trackedVelocityEstimate, isNotNull);

        controller.converter = MotionConverter.custom(
          normalize: (value) => [value.dx, value.dy],
          denormalize: (values) => Offset(values[0], values[1]),
        );

        expect(controller.trackedVelocityEstimate, isNull);
      });
    });
  });
}

/// Records whether a [TickerFuture] completed or was canceled.
class _FutureOutcome {
  _FutureOutcome(TickerFuture future) {
    future.then((_) => completed = true);
    future.orCancel.catchError((Object error) {
      canceled = error is TickerCanceled;
    });
  }

  bool completed = false;
  bool canceled = false;
}
