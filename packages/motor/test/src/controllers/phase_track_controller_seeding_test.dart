// ignore_for_file: cascade_invocations, unawaited_futures

import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

import '../util.dart';

void main() {
  test('phase animations cannot set their own from or withVelocity', () {
    final scale = Track<double>(MotionConverter.single, initial: 0);

    expect(
      () => TrackPhaseTimeline({
        'a': [
          scale([const TrackStep.to(1)], from: 0.5),
        ],
      }),
      throwsAssertionError,
    );
    expect(
      () => TrackPhaseTimeline({
        'a': [
          scale([const TrackStep.to(1)], withVelocity: 2),
        ],
      }),
      throwsAssertionError,
    );
  });

  group('PhaseTrackController from/withVelocity seeding', () {
    const linear100 = Motion.linear(Duration(milliseconds: 100));

    late PhaseTrackController<String> controller;
    final scale = Track<double>(
      MotionConverter.single,
      initial: 0,
      motion: linear100,
    );

    tearDown(() {
      controller.dispose();
    });

    testWidgets("every play applies the timeline's initial values",
        (tester) async {
      controller = PhaseTrackController<String>(vsync: tester);
      TrackPhaseTimeline<String> timelineA() => TrackPhaseTimeline(
            {
              'a1': [
                scale([const TrackStep.to(1)]),
              ],
              'a2': [
                scale([const TrackStep.to(2)]),
              ],
            },
            initialValues: [scale.value(10)],
          );

      controller.playPhases(timelineA());
      // The seed is applied synchronously, before the animation ticks.
      expect(controller.value(scale), closeTo(10, error));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(controller.value(scale), closeTo(2, error));

      // Every play applies them, also for an equal timeline.
      controller.playPhases(timelineA());
      expect(controller.value(scale), closeTo(10, error));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(controller.value(scale), closeTo(2, error));

      // Moving between phases doesn't apply them.
      controller.goToPhase('a1');
      expect(controller.value(scale), closeTo(2, error));
      await tester.pumpAndSettle();
      expect(controller.value(scale), closeTo(1, error));

      // Same from as timelineA, but different phases.
      controller.playPhases(
        TrackPhaseTimeline(
          {
            'a2': [
              scale([const TrackStep.to(100)]),
            ],
          },
          initialValues: [scale.value(10)],
        ),
      );
      expect(controller.value(scale), closeTo(10, error));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(controller.value(scale), closeTo(100, error));

      // A different timeline must snap to its own seed before animating
      // (regression: the old once-per-controller flag skipped it).
      controller.playPhases(
        TrackPhaseTimeline(
          {
            'b1': [
              scale([const TrackStep.to(3)]),
            ],
          },
          initialValues: [scale.value(99)],
        ),
      );
      expect(controller.value(scale), closeTo(99, error));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(controller.value(scale), closeTo(3, error));
    });

    testWidgets(
        'velocity-only seed keeps the value, applies the velocity, and '
        're-applies for a different timeline', (tester) async {
      controller = PhaseTrackController<String>(vsync: tester);
      final pos = Track<double>(MotionConverter.single, initial: 0);
      const spring = CupertinoMotion.smooth();

      controller.playPhases(
        TrackPhaseTimeline<String>(
          {
            'v1': [
              pos([const TrackStep.to(0, motion: spring)]),
            ],
          },
          initialValues: [pos.velocity(200)],
        ),
      );
      // Velocity-only seeds must not move the value.
      expect(controller.value(pos), closeTo(0, error));

      await tester.pump();
      var maxSeen = controller.value(pos);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        if (controller.value(pos) > maxSeen) maxSeen = controller.value(pos);
      }
      expect(
        maxSeen,
        greaterThan(0.5),
        reason: 'the seeded velocity should carry the track past its target '
            'before the spring pulls it back',
      );

      await tester.pumpAndSettle();
      expect(controller.value(pos), closeTo(0, 0.05));

      // A second, different timeline's velocity seed applies as well.
      controller.playPhases(
        TrackPhaseTimeline<String>(
          {
            'w1': [
              pos([const TrackStep.to(0, motion: spring)]),
            ],
          },
          initialValues: [pos.velocity(-200)],
        ),
      );
      expect(controller.value(pos), closeTo(0, 0.05));

      await tester.pump();
      var minSeen = controller.value(pos);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        if (controller.value(pos) < minSeen) minSeen = controller.value(pos);
      }
      expect(
        minSeen,
        lessThan(-0.5),
        reason: 'a new timeline must apply its own velocity seed',
      );

      await tester.pumpAndSettle();
    });

    testWidgets('a second identical throw keeps its velocity', (tester) async {
      controller = PhaseTrackController<String>(vsync: tester);
      final offset = Track<double>(MotionConverter.single, initial: 0);
      const spring = CupertinoMotion.smooth();
      TrackPhaseTimeline<String> fling() => TrackPhaseTimeline(
            {
              'back': [
                offset([const TrackStep.to(0, motion: spring)]),
              ],
            },
            initialValues: [offset.velocity(200)],
          );

      for (var throwIndex = 0; throwIndex < 2; throwIndex++) {
        controller.playPhases(fling());
        await tester.pump();
        var highest = controller.value(offset);
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          if (controller.value(offset) > highest) {
            highest = controller.value(offset);
          }
        }
        expect(highest, greaterThan(0.5), reason: 'throw $throwIndex');
        await tester.pumpAndSettle();
      }
    });

    testWidgets('setTimeline makes the next goToPhase apply them',
        (tester) async {
      controller = PhaseTrackController<String>(vsync: tester);
      TrackPhaseTimeline<String> timeline() => TrackPhaseTimeline(
            {
              'a': [
                scale([const TrackStep.to(1)]),
              ],
              'b': [
                scale([const TrackStep.to(2)]),
              ],
            },
            initialValues: [scale.value(10)],
          );

      for (var round = 0; round < 2; round++) {
        controller
          ..setTimeline(timeline())
          ..goToPhase('a');
        expect(controller.value(scale), closeTo(10, error));
        await tester.pumpAndSettle();
        controller.goToPhase('b');
        expect(controller.value(scale), closeTo(1, error));
        await tester.pumpAndSettle();
      }
    });
  });
}
