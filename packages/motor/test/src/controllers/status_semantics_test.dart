// ignore_for_file: cascade_invocations, unawaited_futures

import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

void main() {
  const linear40 = Motion.linear(Duration(milliseconds: 40));

  testWidgets('canceled TrackController stop is silent', (tester) async {
    final controller = TrackController(vsync: tester);
    addTearDown(controller.dispose);
    final track = Track<double>(
      MotionConverter.single,
      initial: 0,
      motion: linear40,
    );
    final statuses = <AnimationStatus>[];

    controller.animate([track.to(1)]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    controller.addStatusListener(statuses.add);

    controller.stop(canceled: true);

    expect(statuses, isEmpty);
    expect(controller.isAnimating, isFalse);
  });

  testWidgets('converter swap does not report completion', (tester) async {
    final controller = MotionController<Offset>(
      motion: linear40,
      vsync: tester,
      converter: MotionConverter.offset,
      initialValue: Offset.zero,
    );
    addTearDown(controller.dispose);
    final statuses = <AnimationStatus>[];
    controller.addStatusListener(statuses.add);

    controller.animateTo(const Offset(10, 20));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    controller.converter = MotionConverter.custom(
      normalize: (value) => [value.dy, value.dx],
      denormalize: (values) => Offset(values[1], values[0]),
    );

    expect(statuses, [AnimationStatus.forward]);
    expect(controller.isAnimating, isFalse);
  });

  group('PhaseTrackController status', () {
    final track = Track<double>(MotionConverter.single, initial: 0);
    late PhaseTrackController<String> controller;

    tearDown(() => controller.dispose());

    testWidgets('loop stays forward across multiple cycles', (tester) async {
      controller = PhaseTrackController<String>(vsync: tester);
      final statuses = <AnimationStatus>[];
      final transitions = <PhaseTransition<String>>[];
      controller.addStatusListener(statuses.add);

      controller.playPhases(
        TrackPhaseTimeline(
          {
            'a': [track.to(1, motion: linear40)],
            'b': [track.to(2, motion: linear40)],
          },
          phaseLoop: LoopMode.loop,
        ),
        onTransition: transitions.add,
      );
      await tester.pump();
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 41));
      }

      expect(statuses, [AnimationStatus.forward]);
      expect(
        transitions,
        const [
          PhaseTransitioning<String>(from: 'a', to: 'b'),
          PhaseTransitioning<String>(from: 'b', to: 'a'),
          PhaseTransitioning<String>(from: 'a', to: 'b'),
          PhaseTransitioning<String>(from: 'b', to: 'a'),
          PhaseTransitioning<String>(from: 'a', to: 'b'),
          PhaseTransitioning<String>(from: 'b', to: 'a'),
        ],
      );
      controller.stop(canceled: true);
    });

    testWidgets('pingPong stays forward across multiple cycles',
        (tester) async {
      controller = PhaseTrackController<String>(vsync: tester);
      final statuses = <AnimationStatus>[];
      final transitions = <PhaseTransition<String>>[];
      controller.addStatusListener(statuses.add);

      controller.playPhases(
        TrackPhaseTimeline(
          {
            'a': [track.to(1, motion: linear40)],
            'b': [track.to(2, motion: linear40)],
            'c': [track.to(3, motion: linear40)],
          },
          phaseLoop: LoopMode.pingPong,
        ),
        onTransition: transitions.add,
      );
      await tester.pump();
      for (var i = 0; i < 9; i++) {
        await tester.pump(const Duration(milliseconds: 41));
      }

      expect(statuses, [AnimationStatus.forward]);
      expect(
        transitions,
        const [
          PhaseTransitioning<String>(from: 'a', to: 'b'),
          PhaseTransitioning<String>(from: 'b', to: 'c'),
          PhaseTransitioning<String>(from: 'c', to: 'b'),
          PhaseTransitioning<String>(from: 'b', to: 'a'),
          PhaseTransitioning<String>(from: 'a', to: 'b'),
          PhaseTransitioning<String>(from: 'b', to: 'c'),
          PhaseTransitioning<String>(from: 'c', to: 'b'),
          PhaseTransitioning<String>(from: 'b', to: 'a'),
          PhaseTransitioning<String>(from: 'a', to: 'b'),
        ],
      );
      controller.stop(canceled: true);
    });

    testWidgets('non-looping playback reports one completion', (tester) async {
      controller = PhaseTrackController<String>(vsync: tester);
      final statuses = <AnimationStatus>[];
      final transitions = <PhaseTransition<String>>[];
      controller.addStatusListener(statuses.add);

      controller.playPhases(
        TrackPhaseTimeline({
          'a': [track.to(1, motion: linear40)],
          'b': [track.to(2, motion: linear40)],
        }),
        onTransition: transitions.add,
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(
        statuses,
        [AnimationStatus.forward, AnimationStatus.completed],
      );
      expect(
        transitions,
        const [
          PhaseTransitioning<String>(from: 'a', to: 'b'),
          PhaseSettled<String>('b'),
        ],
      );
    });
  });

  testWidgets('graceful stop reports completion after settling',
      (tester) async {
    final track = Track<double>(
      MotionConverter.single,
      initial: 0,
      motion: const CupertinoMotion.smooth(),
    );
    final controller = TrackController(vsync: tester);
    addTearDown(controller.dispose);
    final statuses = <AnimationStatus>[];

    controller.animate([track.to(1)]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    controller.addStatusListener(statuses.add);

    controller.stop();
    await tester.pumpAndSettle();

    expect(statuses, [AnimationStatus.completed]);
    expect(controller.isAnimating, isFalse);
  });
}
