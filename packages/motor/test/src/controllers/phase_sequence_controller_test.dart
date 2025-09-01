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
  group('PhaseSequenceController', () {
    setUp(TestWidgetsFlutterBinding.ensureInitialized);

    late PhaseSequenceController<String, Offset> controller;
    const motion = CupertinoMotion.smooth();
    const converter = OffsetMotionConverter();

    tearDown(() {
      controller.dispose();
    });

    group('MotionController API compatibility', () {
      testWidgets('creates with initial value', (tester) async {
        controller = PhaseSequenceController<String, Offset>(
          motion: motion,
          vsync: tester,
          converter: converter,
          initialValue: Offset.zero,
        );
        expect(controller.value, equals(Offset.zero));
        expect(controller.velocity, equals(Offset.zero));
      });

      testWidgets('updates motion style', (tester) async {
        controller = PhaseSequenceController<String, Offset>(
          motion: motion,
          vsync: tester,
          converter: converter,
          initialValue: Offset.zero,
        );
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
        controller = PhaseSequenceController<String, Offset>(
          motion: motion,
          vsync: mockTickerProvider,
          converter: converter,
          initialValue: Offset.zero,
        );

        verify(() => mockTickerProvider.createTicker(any())).called(1);
      });

      group('.animateTo', () {
        testWidgets('animates to target value', (tester) async {
          controller = PhaseSequenceController<String, Offset>(
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
          controller = PhaseSequenceController<String, Offset>(
            motion: motion,
            vsync: tester,
            converter: converter,
            initialValue: Offset.zero,
          )..animateTo(
              const Offset(0.5, 0.5),
              withVelocity: const Offset(2, 2),
            );
          await tester.pump();

          final initialVelocity = controller.velocity;
          expect(initialVelocity.dx, moreOrLessEquals(2, epsilon: error));
          expect(initialVelocity.dy, moreOrLessEquals(2, epsilon: error));
          await tester.pumpAndSettle();
        });

        testWidgets('completes immediately if target is within tolerance',
            (tester) async {
          controller = PhaseSequenceController<String, Offset>(
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
          controller = PhaseSequenceController<String, Offset>(
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
          controller = PhaseSequenceController<String, Offset>(
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

        testWidgets('stops any active sequence when animateTo is called',
            (tester) async {
          final sequence = PhaseSequence.map(
            const {
              'a': Offset.zero,
              'b': Offset(1, 1),
              'c': Offset(2, 2),
            },
            motion: motion,
          );

          controller = PhaseSequenceController<String, Offset>(
            motion: motion,
            vsync: tester,
            converter: converter,
            initialValue: Offset.zero,
          );

          // Start a sequence
          unawaited(controller.playSequence(sequence));
          await tester.pump();
          expect(controller.isPlayingSequence, isTrue);

          // Call animateTo - should stop the sequence
          unawaited(controller.animateTo(const Offset(3, 3)));
          await tester.pump();
          expect(controller.isPlayingSequence, isFalse);
          expect(controller.activeSequence, isNull);

          await tester.pumpAndSettle();
          expect(controller.value.dx, moreOrLessEquals(3, epsilon: error));
          expect(controller.value.dy, moreOrLessEquals(3, epsilon: error));
        });

        testWidgets(
            'animates with from parameter correctly when x are identical',
            (tester) async {
          controller = PhaseSequenceController<String, Offset>(
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

        testWidgets(
            'animates with from parameter correctly when y are identical',
            (tester) async {
          controller = PhaseSequenceController<String, Offset>(
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
        testWidgets('redirects simulation', (tester) async {
          controller = PhaseSequenceController<String, Offset>(
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
        testWidgets('stop settles animation by default', (tester) async {
          controller = PhaseSequenceController<String, Offset>(
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
          controller = PhaseSequenceController<String, Offset>(
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

        testWidgets('stops any active sequence when stop is called',
            (tester) async {
          final sequence = PhaseSequence.map(
            motion: motion,
            const {
              'a': Offset.zero,
              'b': Offset(1, 1),
              'c': Offset(2, 2),
            },
          );

          controller = PhaseSequenceController<String, Offset>(
            motion: motion,
            vsync: tester,
            converter: converter,
            initialValue: Offset.zero,
          );

          // Start a sequence
          unawaited(controller.playSequence(sequence));
          await tester.pump();
          expect(controller.isPlayingSequence, isTrue);

          // Call stop - should stop the sequence
          unawaited(controller.stop());
          expect(controller.isPlayingSequence, isFalse);
          expect(controller.activeSequence, isNull);
        });
      });

      group('.resync', () {
        testWidgets('resyncs the controller', (tester) async {
          final mockTickerProvider = _MockTickerProvider();
          final mockTicker = _MockTicker();

          when(() => mockTickerProvider.createTicker(any())).thenAnswer(
            (_) => mockTicker,
          );

          controller = PhaseSequenceController<String, Offset>(
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
        testWidgets('is .dismissed initially', (tester) async {
          controller = PhaseSequenceController<String, Offset>(
            motion: motion,
            vsync: tester,
            converter: converter,
            initialValue: Offset.zero,
          );
          expect(controller.status, equals(AnimationStatus.dismissed));
        });

        testWidgets('is forward when animating to larger values',
            (tester) async {
          controller = PhaseSequenceController<String, Offset>(
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
          controller = PhaseSequenceController<String, Offset>(
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
          controller = PhaseSequenceController<String, Offset>(
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

      group('.value setter', () {
        testWidgets('sets value directly', (tester) async {
          controller = PhaseSequenceController<String, Offset>(
            motion: motion,
            vsync: tester,
            converter: converter,
            initialValue: Offset.zero,
          );

          expect(controller.value, equals(Offset.zero));
          controller.value = const Offset(1, 1);
          expect(controller.value, equals(const Offset(1, 1)));
        });

        testWidgets('stops any active sequence when value is set',
            (tester) async {
          final sequence = PhaseSequence.map(
            const {
              'a': Offset.zero,
              'b': Offset(1, 1),
              'c': Offset(2, 2),
            },
            motion: motion,
          );

          controller = PhaseSequenceController<String, Offset>(
            motion: motion,
            vsync: tester,
            converter: converter,
            initialValue: Offset.zero,
          );

          // Start a sequence
          unawaited(controller.playSequence(sequence));
          await tester.pump();
          expect(controller.isPlayingSequence, isTrue);

          // Set value - should stop the sequence
          controller.value = const Offset(3, 3);
          expect(controller.isPlayingSequence, isFalse);
          expect(controller.activeSequence, isNull);
          expect(controller.value, equals(const Offset(3, 3)));
        });
      });

      group('.velocity', () {
        testWidgets('returns zero velocity when not animating', (tester) async {
          controller = PhaseSequenceController<String, Offset>(
            motion: motion,
            vsync: tester,
            converter: converter,
            initialValue: Offset.zero,
          );

          expect(controller.velocity, equals(Offset.zero));
        });
      });

      group('.isAnimating', () {
        testWidgets('returns false when not animating', (tester) async {
          controller = PhaseSequenceController<String, Offset>(
            motion: motion,
            vsync: tester,
            converter: converter,
            initialValue: Offset.zero,
          );

          expect(controller.isAnimating, isFalse);
        });

        testWidgets('returns true when animating', (tester) async {
          controller = PhaseSequenceController<String, Offset>(
            motion: motion,
            vsync: tester,
            converter: converter,
            initialValue: Offset.zero,
          );

          unawaited(controller.animateTo(const Offset(1, 1)));
          await tester.pump();
          expect(controller.isAnimating, isTrue);

          await tester.pumpAndSettle();
          expect(controller.isAnimating, isFalse);
        });
      });

      group('constructor variants', () {
        testWidgets('motionPerDimension constructor works', (tester) async {
          controller =
              PhaseSequenceController<String, Offset>.motionPerDimension(
            motionPerDimension: [motion, motion],
            vsync: tester,
            converter: converter,
            initialValue: Offset.zero,
          );

          expect(controller.value, equals(Offset.zero));
          expect(controller.motionPerDimension.length, equals(2));
          expect(controller.motionPerDimension[0], equals(motion));
          expect(controller.motionPerDimension[1], equals(motion));
        });
      });
    });
  });
}
