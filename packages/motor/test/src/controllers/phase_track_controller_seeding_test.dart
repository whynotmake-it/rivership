// ignore_for_file: cascade_invocations, unawaited_futures

import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

import '../util.dart';

void main() {
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

    TrackPhaseTimeline<String> timelineA() => TrackPhaseTimeline(
          {
            'a1': [scale.to(1)],
            'a2': [scale.to(2)],
          },
          from: [scale.value(10)],
        );

    TrackPhaseTimeline<String> timelineB() => TrackPhaseTimeline(
          {
            'b1': [scale.to(3)],
          },
          from: [scale.value(99)],
        );

    testWidgets('playing a different timeline applies its own from seed',
        (tester) async {
      controller = PhaseTrackController<String>(vsync: tester);

      controller.playPhases(timelineA());
      // The seed is applied synchronously, before the animation ticks.
      expect(controller.value(scale), closeTo(10, error));

      await tester.pump();
      await tester.pumpAndSettle();
      expect(controller.value(scale), closeTo(2, error));

      // A second, different timeline must snap to its own seed before
      // animating (regression: the old once-per-controller flag skipped it).
      controller.playPhases(timelineB());
      expect(controller.value(scale), closeTo(99, error));

      await tester.pump();
      await tester.pumpAndSettle();
      expect(controller.value(scale), closeTo(3, error));
    });

    testWidgets('replaying an equal-value timeline does not re-apply the seed',
        (tester) async {
      controller = PhaseTrackController<String>(vsync: tester);

      controller.playPhases(timelineA());
      await tester.pump();
      await tester.pumpAndSettle();
      expect(controller.value(scale), closeTo(2, error));

      // Fresh but value-equal instance: the documented once-per-timeline
      // semantics mean the seed must NOT snap the track back to 10.
      controller.playPhases(timelineA());
      expect(controller.value(scale), closeTo(2, error));

      await tester.pump();
      await tester.pumpAndSettle();
      expect(controller.value(scale), closeTo(2, error));
    });

    testWidgets(
        'playing a different timeline with same from seed applies the seed',
        (tester) async {
      controller = PhaseTrackController<String>(vsync: tester);

      controller.playPhases(timelineA());
      await tester.pump();
      await tester.pumpAndSettle();

      expect(controller.value(scale), closeTo(2, error));

      // Fresh but value-equal instance: the documented once-per-timeline
      // semantics mean the seed must NOT snap the track back to 10.
      controller.playPhases(timelineA());

      // Same from as timelineA, but different phase.
      final timelineA2 = TrackPhaseTimeline(
        {
          'a2': [scale.to(100)],
        },
        from: [scale.value(10)],
      );

      controller.playPhases(timelineA2);
      expect(controller.value(scale), closeTo(10, error));

      await tester.pump();
      await tester.pumpAndSettle();
      expect(controller.value(scale), closeTo(100, error));
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
            'v1': [pos.to(0, motion: spring)],
          },
          withVelocity: [pos.velocity(200)],
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
            'w1': [pos.to(0, motion: spring)],
          },
          withVelocity: [pos.velocity(-200)],
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
  });
}
