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
    expect(controller.isAnimating, isTrue);
    await tester.pumpAndSettle();
  });

  group('PhaseTrackController status', () {
    final track = Track<double>(MotionConverter.single, initial: 0);
    late PhaseTrackController<String> controller;

    tearDown(() => controller.dispose());

    testWidgets('loop follows direction across cycles without completing',
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
          },
          phaseLoop: LoopMode.loop,
        ),
        onTransition: transitions.add,
      );
      await tester.pump();
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 41));
      }

      // Each cycle rises to 'b' and heads back down to 'a'.
      expect(statuses, [
        AnimationStatus.forward,
        AnimationStatus.reverse,
        AnimationStatus.forward,
        AnimationStatus.reverse,
        AnimationStatus.forward,
        AnimationStatus.reverse,
      ]);
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

    testWidgets('pingPong follows direction across cycles without completing',
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

      expect(statuses, [
        AnimationStatus.forward,
        AnimationStatus.reverse,
        AnimationStatus.forward,
        AnimationStatus.reverse,
        AnimationStatus.forward,
      ]);
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

  group('a graceful stop keeps the direction it was moving in', () {
    testWidgets('on a TrackController while settling and after',
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
      expect(controller.animationOf(track).status, AnimationStatus.forward);
      await tester.pumpAndSettle();

      expect(statuses, isEmpty);
      expect(controller.status, AnimationStatus.forward);
      expect(controller.animationOf(track).status, AnimationStatus.forward);
      expect(controller.isAnimating, isFalse);
    });

    testWidgets('on a controller moving down', (tester) async {
      final controller = SingleMotionController(
        motion: const CupertinoMotion.smooth(),
        vsync: tester,
        initialValue: 1,
      );
      addTearDown(controller.dispose);

      controller.animateTo(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      expect(controller.status, AnimationStatus.reverse);

      controller.stop();
      expect(controller.status, AnimationStatus.reverse);
      await tester.pumpAndSettle();
      expect(controller.status, AnimationStatus.reverse);
      expect(controller.isAnimating, isFalse);
    });

    testWidgets('on a bounded controller without a direction in reverse()',
        (tester) async {
      final controller = BoundedMotionController<Offset>(
        motion: const CupertinoMotion.smooth(),
        vsync: tester,
        converter: MotionConverter.offset,
        initialValue: const Offset(1, 1),
        lowerBound: Offset.zero,
        upperBound: const Offset(1, 1),
      );
      addTearDown(controller.dispose);

      controller.reverse();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      expect(controller.status, AnimationStatus.reverse);

      controller.stop();
      await tester.pumpAndSettle();
      expect(controller.status, AnimationStatus.reverse);
    });

    testWidgets('and a new animation afterwards finishes as usual',
        (tester) async {
      final controller = SingleMotionController(
        motion: const Motion.linear(Duration(milliseconds: 40)),
        vsync: tester,
      );
      addTearDown(controller.dispose);

      controller.animateTo(1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      controller.stop();
      expect(controller.status, AnimationStatus.forward);

      controller.animateTo(1);
      await tester.pumpAndSettle();
      expect(controller.status, AnimationStatus.completed);
    });
  });

  group('a downward finish', () {
    testWidgets('is dismissed for the track and the controller',
        (tester) async {
      final track = Track<double>(MotionConverter.single, initial: 1);
      final controller = TrackController(vsync: tester);
      addTearDown(controller.dispose);
      final statuses = <AnimationStatus>[];
      final trackStatuses = <AnimationStatus>[];
      controller.addStatusListener(statuses.add);
      controller.animationOf(track).addStatusListener(trackStatuses.add);

      controller.animate([track.to(0.5, motion: linear40)]);
      await tester.pumpAndSettle();

      const expected = [AnimationStatus.reverse, AnimationStatus.dismissed];
      expect(statuses, expected);
      expect(trackStatuses, expected);
    });

    testWidgets('is dismissed after jumping down with set or value',
        (tester) async {
      final track = Track<double>(MotionConverter.single, initial: 1);
      final trackController = TrackController(vsync: tester);
      addTearDown(trackController.dispose);
      final motionController = SingleMotionController(
        motion: linear40,
        vsync: tester,
        initialValue: 1,
      );
      addTearDown(motionController.dispose);

      expect(trackController.value(track), 1);
      trackController.set([track.value(2)]);
      expect(trackController.status, AnimationStatus.completed);
      trackController.set([track.value(0)]);
      expect(trackController.status, AnimationStatus.dismissed);
      expect(
        trackController.animationOf(track).status,
        AnimationStatus.dismissed,
      );

      motionController.value = 0;
      expect(motionController.status, AnimationStatus.dismissed);
    });

    testWidgets(
        'without a direction, is dismissed only back at the initial value',
        (tester) async {
      final controller = MotionController<Offset>(
        motion: linear40,
        vsync: tester,
        converter: MotionConverter.offset,
        initialValue: const Offset(1, 1),
      );
      addTearDown(controller.dispose);

      controller.animateTo(Offset.zero);
      await tester.pump();
      expect(controller.status, AnimationStatus.forward);
      await tester.pumpAndSettle();
      expect(controller.status, AnimationStatus.completed);

      controller.animateTo(const Offset(1, 1));
      await tester.pumpAndSettle();
      expect(controller.status, AnimationStatus.dismissed);
    });
  });

  testWidgets('a canceled stop keeps the direction it was moving in',
      (tester) async {
    final track = Track<double>(MotionConverter.single, initial: 1);
    final controller = TrackController(vsync: tester);
    addTearDown(controller.dispose);
    final animation = controller.animationOf(track);

    controller.animate([track.to(0, motion: linear40)]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    controller.stop(canceled: true);
    expect(animation.status, AnimationStatus.reverse);
    expect(controller.status, AnimationStatus.reverse);

    controller.animate([track.to(2, motion: linear40)]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    controller.stop(tracks: [track], canceled: true);
    expect(animation.status, AnimationStatus.forward);
    expect(controller.status, AnimationStatus.forward);
  });

  group('with several tracks, the controller', () {
    final down = Track<double>(MotionConverter.single, initial: 1);
    final alsoDown = Track<double>(MotionConverter.single, initial: 1);
    final up = Track<double>(MotionConverter.single, initial: 0);

    testWidgets('reports reverse and dismissed when all tracks head down',
        (tester) async {
      final controller = TrackController(vsync: tester);
      addTearDown(controller.dispose);
      final statuses = <AnimationStatus>[];
      controller.addStatusListener(statuses.add);

      controller.animate([
        down.to(0, motion: linear40),
        alsoDown.to(0, motion: const Motion.linear(Duration(milliseconds: 80))),
      ]);
      await tester.pumpAndSettle();

      expect(statuses, [AnimationStatus.reverse, AnimationStatus.dismissed]);
    });

    testWidgets('reports forward and completed when any track heads up',
        (tester) async {
      final controller = TrackController(vsync: tester);
      addTearDown(controller.dispose);
      final statuses = <AnimationStatus>[];
      controller.addStatusListener(statuses.add);

      controller.animate([
        down.to(0, motion: linear40),
        up.to(1, motion: linear40),
      ]);
      await tester.pumpAndSettle();

      expect(statuses, [AnimationStatus.forward, AnimationStatus.completed]);
    });

    testWidgets('follows the tracks still moving', (tester) async {
      final controller = TrackController(vsync: tester);
      addTearDown(controller.dispose);
      final statuses = <AnimationStatus>[];
      controller.addStatusListener(statuses.add);

      controller.animate([
        up.to(1, motion: linear40),
        down.to(0, motion: const Motion.linear(Duration(milliseconds: 80))),
      ]);
      await tester.pump();
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      expect(statuses, [
        AnimationStatus.forward,
        AnimationStatus.reverse,
        AnimationStatus.completed,
      ]);
    });
  });
}
