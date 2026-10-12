import 'dart:math' as math;

// ignore_for_file: cascade_invocations, unawaited_futures

import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

import '../util.dart';

void main() {
  group('TrackController', () {
    late TrackController controller;
    final opacity = Track<double>(MotionConverter.single, initial: 0.0);
    final scale = Track<double>(MotionConverter.single, initial: 1.0);

    tearDown(() {
      controller.dispose();
    });

    testWidgets('resolves initial values from tracks and overrides',
        (tester) async {
      controller = TrackController(vsync: tester);
      expect(controller, isA<Animation<TrackValueReader>>());
      expect(controller.value(opacity), equals(0));
      expect(controller.value(scale), equals(1));
      controller.dispose();

      controller = TrackController(
        vsync: tester,
        initialValues: [opacity.value(0.5)],
      );
      expect(controller.value(opacity), equals(0.5));
      expect(controller.value(scale), equals(1));
    });

    testWidgets('plays multiple tracks and reports timeline-scoped status',
        (tester) async {
      controller = TrackController(vsync: tester);
      final statuses = <AnimationStatus>[];
      controller.addStatusListener(statuses.add);
      controller.play(
        TrackTimeline([
          opacity.to(
            1,
            motion: const Motion.linear(Duration(milliseconds: 100)),
          ),
          scale.to(
            2,
            motion: const Motion.linear(Duration(milliseconds: 100)),
          ),
        ]),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(controller.value(opacity), greaterThan(0));
      expect(controller.value(opacity), lessThan(1));
      expect(controller.value(scale), greaterThan(1));
      expect(controller.value(scale), lessThan(2));

      await tester.pumpAndSettle();

      expect(controller.value(opacity), closeTo(1, error));
      expect(controller.value(scale), closeTo(2, error));
      expect(controller.isAnimating, isFalse);
      expect(controller.status, AnimationStatus.completed);
      expect(
        statuses,
        containsAllInOrder([
          AnimationStatus.forward,
          AnimationStatus.completed,
        ]),
      );
    });

    testWidgets('reports every step entered, even within one frame',
        (tester) async {
      controller = TrackController(vsync: tester);
      final steps = <int>[];
      final tracks = <Track>{};
      const short = Motion.linear(Duration(milliseconds: 10));

      controller.play(
        TrackTimeline(
          [
            opacity([
              const TrackStep.to(1, motion: short),
              const TrackStep.to(0, motion: short),
              const TrackStep.hold(Duration(milliseconds: 10)),
            ]),
          ],
          loop: LoopMode.seamless,
        ),
        onStep: (track, stepIndex) {
          tracks.add(track);
          steps.add(stepIndex);
        },
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 35));
      expect(steps, [0, 1, 2, 0]);
      expect(tracks, {opacity});

      steps.clear();
      await tester.pump(const Duration(milliseconds: 30));
      expect(steps, [1, 2, 0]);

      controller.pause();
      steps.clear();
      controller.scrubTo(Duration.zero);
      controller.resume();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 5));
      expect(steps, isEmpty);
      controller.stop(canceled: true);
    });

    testWidgets('does not report the internal return step of a loop',
        (tester) async {
      controller = TrackController(vsync: tester);
      final steps = <int>[];
      const short = Motion.linear(Duration(milliseconds: 10));

      controller.play(
        TrackTimeline(
          [
            opacity([
              const TrackStep.to(1, motion: short),
              const TrackStep.to(0.5, motion: short),
            ]),
          ],
          loop: LoopMode.loop,
        ),
        onStep: (track, stepIndex) => steps.add(stepIndex),
      );

      await tester.pump();
      // Each cycle takes 30ms: two steps, then the return to the start.
      await tester.pump(const Duration(milliseconds: 55));
      expect(steps, [0, 1, 0, 1]);
      controller.stop(canceled: true);
    });

    group('looping', () {
      const linear100 = Motion.linear(Duration(milliseconds: 100));
      const oneStep = [TrackStep<double>.to(1, motion: linear100)];
      const twoSteps = [
        TrackStep<double>.to(0.5, motion: linear100),
        TrackStep<double>.to(1.0, motion: linear100),
      ];

      // Values at elapsed milliseconds. A loop animates back to the start
      // after the last step, pingPong reverses through the steps, seamless
      // jumps back to the start.
      for (final (name, loop, steps, expected) in [
        (
          'loop animates back to the start',
          LoopMode.loop,
          oneStep,
          [(50, 0.5), (100, 1.0), (150, 0.5), (200, 0.0), (250, 0.5)],
        ),
        (
          'loop cycles through all steps, then animates back',
          LoopMode.loop,
          twoSteps,
          [(50, 0.25), (150, 0.75), (200, 1.0), (250, 0.5), (350, 0.25)],
        ),
        (
          'pingPong oscillates between start and end',
          LoopMode.pingPong,
          oneStep,
          [(50, 0.5), (100, 1.0), (150, 0.5), (200, 0.0), (300, 1.0)],
        ),
        (
          'pingPong reverses through the steps at the boundaries',
          LoopMode.pingPong,
          twoSteps,
          [(50, 0.25), (150, 0.75), (250, 0.75), (350, 0.25), (450, 0.25)],
        ),
        (
          'seamless jumps back to the start after the last step',
          LoopMode.seamless,
          oneStep,
          [(50, 0.5), (99, 0.99), (120, 0.2), (150, 0.5)],
        ),
      ]) {
        testWidgets('LoopMode.$name', (tester) async {
          controller = TrackController(vsync: tester);
          controller.play(TrackTimeline([opacity(steps)], loop: loop));
          await tester.pump();

          var elapsed = 0;
          for (final (milliseconds, value) in expected) {
            await tester.pump(Duration(milliseconds: milliseconds - elapsed));
            elapsed = milliseconds;
            expect(
              controller.value(opacity),
              closeTo(value, error),
              reason: 'at $milliseconds ms',
            );
          }
          expect(controller.isAnimating, isTrue);
          controller.stop(canceled: true);
        });
      }

      testWidgets(
          'a loop stays in range after a large elapsed gap and over many '
          'cycles', (tester) async {
        controller = TrackController(vsync: tester);
        controller.play(
          TrackTimeline(
            [opacity.to(1, motion: linear100)],
            loop: LoopMode.loop,
          ),
        );
        await tester.pump();

        // Navigating away for 10 seconds, then 100 cycles of 100 ms.
        for (final gaps in [
          [const Duration(seconds: 10)],
          List.filled(100, const Duration(milliseconds: 100)),
        ]) {
          for (final gap in gaps) {
            await tester.pump(gap);
          }
          expect(controller.isAnimating, isTrue);
          final v = controller.value(opacity);
          expect(v, greaterThanOrEqualTo(-error));
          expect(v, lessThanOrEqualTo(1 + error));
        }

        controller.stop(canceled: true);
        await tester.pump();
        expect(controller.isAnimating, isFalse);
      });
    });

    testWidgets('starting other tracks leaves running tracks alone',
        (tester) async {
      controller = TrackController(vsync: tester);
      final rotation = Track<double>(MotionConverter.single, initial: 0.0);
      const motion = Motion.linear(Duration(milliseconds: 200));
      const linear100 = Motion.linear(Duration(milliseconds: 100));

      controller.animate(
        [rotation.to(1, motion: linear100)],
        loop: LoopMode.loop,
      );
      controller.animate([opacity.to(1, motion: motion)]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final opacityMidway = controller.value(opacity);
      expect(opacityMidway, greaterThan(0));
      expect(opacityMidway, lessThan(1));

      controller.play(TrackTimeline([scale.to(2, motion: motion)]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Opacity kept progressing toward its target rather than freezing.
      expect(controller.value(opacity), greaterThan(opacityMidway));
      expect(controller.value(scale), greaterThan(1));

      await tester.pump(const Duration(milliseconds: 150));
      expect(controller.value(opacity), closeTo(1, error));
      expect(controller.value(scale), closeTo(2, error));
      // The looping rotation keeps going.
      expect(controller.isAnimating, isTrue);

      controller.stop(canceled: true);
      await tester.pump();
      expect(controller.isAnimating, isFalse);
    });

    testWidgets(
        'sequential animate calls after a settle start without a stale delay',
        (tester) async {
      controller = TrackController(vsync: tester);
      const motion = Motion.linear(Duration(milliseconds: 100));

      // Run a track to completion so the ticker stops with a large elapsed.
      controller.animate([opacity.to(1, motion: motion)]);
      await tester.pump();
      await tester.pumpAndSettle();
      expect(controller.isAnimating, isFalse);
      expect(controller.value(opacity), closeTo(1, error));

      // Two animate calls in the same frame: the first restarts the stopped
      // ticker, the second must not inherit a stale elapsed start offset.
      controller.animate([opacity.to(0, motion: motion)]);
      controller.animate([scale.to(2, motion: motion)]);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Both tracks are progressing at the halfway mark, not frozen waiting
      // for the ticker to catch up to a stale offset.
      expect(controller.value(opacity), lessThan(1));
      expect(controller.value(opacity), greaterThan(0));
      expect(controller.value(scale), greaterThan(1));
      expect(controller.value(scale), lessThan(2));

      await tester.pumpAndSettle();
      expect(controller.value(opacity), closeTo(0, error));
      expect(controller.value(scale), closeTo(2, error));
    });

    testWidgets('a retarget starts from the current value and velocity',
        (tester) async {
      controller = TrackController(
        vsync: tester,
        initialValues: [opacity.value(0.5)],
      );
      const linear = Motion.linear(Duration(milliseconds: 100));
      controller.play(TrackTimeline([opacity.to(0.8, motion: linear)]));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(controller.value(opacity), closeTo(0.8, error));

      controller.animate([opacity.to(1.0, motion: linear)]);
      expect(controller.value(opacity), closeTo(0.8, error));

      final position = Track<double>(MotionConverter.single, initial: 0);
      const spring = Motion.smoothSpring();
      controller.animate([position.to(100, motion: spring)]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final valueBefore = controller.value(position);
      final velocityBefore = controller.velocity(position);
      expect(velocityBefore, greaterThan(0));

      // Without an explicit velocity, the slot carries the current one into
      // the new simulation rather than resetting to zero.
      controller.play(TrackTimeline([position.to(200, motion: spring)]));
      expect(controller.value(position), closeTo(valueBefore, error));
      expect(controller.velocity(position), closeTo(velocityBefore, error));

      // Zero-duration frame: the new simulation's initial velocity equals the
      // velocity at the moment of redirect.
      await tester.pump();
      expect(
        controller.velocity(position),
        moreOrLessEquals(velocityBefore, epsilon: 1),
      );
      controller.stop(canceled: true);
    });

    testWidgets('settles interrupted tap playground reset at zero rotation',
        (tester) async {
      controller = TrackController(vsync: tester);
      final rotation = Track<double>(MotionConverter.single, initial: 0.0);
      const motion = Motion.smoothSpring(duration: Duration(milliseconds: 420));

      controller.play(
        TrackTimeline([
          rotation.to(math.pi / 10, motion: motion),
        ]),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      controller.play(
        TrackTimeline([
          rotation.to(0.0, motion: motion),
        ]),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(controller.isAnimating, isFalse);
      expect(controller.value(rotation), closeTo(0.0, error));
    });

    for (final (dragged, target) in [
      (const Offset(100, 50), const Offset(100, 50)),
      (const Offset(30, 15), const Offset(50, 25)),
      (const Offset(80, 40), const Offset(100, 50)),
    ]) {
      testWidgets('animate after set to $dragged settles at $target',
          (tester) async {
        controller = TrackController(
          vsync: tester,
          velocityTracking: const VelocityTracking.off(),
        );
        final offset =
            Track<Offset>(MotionConverter.offset, initial: Offset.zero);

        controller.set([offset.value(dragged)]);
        expect(controller.value(offset), equals(dragged));

        controller.animate([
          offset.to(target, motion: const Motion.interactiveSpring()),
        ]);
        await tester.pumpAndSettle();

        expect(controller.value(offset).dx, closeTo(target.dx, error));
        expect(controller.value(offset).dy, closeTo(target.dy, error));
      });
    }

    testWidgets('animate throws when given two animations for one track',
        (tester) async {
      controller = TrackController(vsync: tester);
      const motion = Motion.linear(Duration(milliseconds: 100));

      expect(
        () => controller.animate([
          opacity.to(1, motion: motion),
          opacity.to(0, motion: motion),
        ]),
        throwsA(isA<AssertionError>()),
      );
    });

    testWidgets('custom converters read the reused buffer without a copy',
        (tester) async {
      final received = <List<double>>[];
      final offset = Track<Offset>(
        MotionConverter<Offset>.custom(
          normalize: (value) => [value.dx, value.dy],
          denormalize: (values) {
            received.add(values);
            return Offset(values[0], values[1]);
          },
        ),
        initial: Offset.zero,
      );
      controller = TrackController(vsync: tester);
      controller.animate([
        offset.to(
          const Offset(100, 100),
          motion: const Motion.linear(Duration(milliseconds: 100)),
        ),
      ]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      final earlier = controller.value(offset);
      final earlierList = received.last;
      await tester.pump(const Duration(milliseconds: 40));
      final later = controller.value(offset);

      expect(later, isNot(earlier));
      expect(identical(received.last, earlierList), isTrue);
      controller.stop(canceled: true);
    });
  });

  group('initial value resolution', () {
    late TrackController controller;

    tearDown(() => controller.dispose());

    testWidgets(
        'falls back to zero from the converter or the first target when '
        'initial is omitted', (tester) async {
      controller = TrackController(vsync: tester);
      final offset = Track<Offset>(MotionConverter.offset);
      final custom = Track<Offset>(
        MotionConverter.custom(
          normalize: (value) => [value.dx, value.dy],
          denormalize: (values) => Offset(values[0], values[1]),
        ),
      );

      controller.animate([
        offset.to(
          const Offset(10, 20),
          motion: const Motion.linear(Duration(milliseconds: 100)),
        ),
        custom.to(
          const Offset(4, 8),
          motion: const Motion.linear(Duration(milliseconds: 100)),
        ),
      ]);

      await tester.pump();
      expect(controller.value(offset), Offset.zero);
      expect(controller.value(custom), Offset.zero);

      await tester.pumpAndSettle();
      expect(controller.value(offset).dx, closeTo(10, error));
      expect(controller.value(offset).dy, closeTo(20, error));
    });

    testWidgets('throws when there is no value to read or infer from',
        (tester) async {
      controller = TrackController(vsync: tester);
      final track = Track<double>(MotionConverter.single);

      expect(() => controller.value(track), throwsStateError);
      expect(
        () => controller.animate([
          track([const TrackStep.hold(Duration(milliseconds: 100))]),
        ]),
        throwsStateError,
      );
    });
  });
}
