// ignore_for_file: cascade_invocations, unawaited_futures

import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

import '../util.dart';

void main() {
  const linear40 = Motion.linear(Duration(milliseconds: 40));
  final track = Track<double>(MotionConverter.single, initial: 0);

  TrackPhaseTimeline<String> timeline(LoopMode loop) => TrackPhaseTimeline(
        {
          'a': [track.to(1, motion: linear40)],
          'b': [track.to(2, motion: linear40)],
          'c': [track.to(3, motion: linear40)],
        },
        phaseLoop: loop,
      );

  group('PhaseTrackController', () {
    late PhaseTrackController<String> controller;
    late List<PhaseTransition<String>> transitions;

    setUp(() => transitions = []);
    tearDown(() => controller.dispose());

    Future<void> pumpFrames(WidgetTester tester, int count) async {
      for (var i = 0; i < count; i++) {
        await tester.pump(const Duration(milliseconds: 21));
      }
    }

    group('playPhases(atPhase:)', () {
      testWidgets('without a loop plays the remaining phases and settles',
          (tester) async {
        controller = PhaseTrackController(vsync: tester);
        controller.playPhases(
          timeline(LoopMode.none),
          atPhase: 'b',
          onTransition: transitions.add,
        );
        await tester.pump();
        await pumpFrames(tester, 8);

        expect(transitions, const [
          PhaseTransitioning(from: 'b', to: 'c'),
          PhaseSettled('c'),
        ]);
        expect(controller.value(track), closeTo(3, error));
        expect(controller.isAnimating, isFalse);
      });

      testWidgets('with loop replays the whole timeline after the last phase',
          (tester) async {
        controller = PhaseTrackController(vsync: tester);
        controller.playPhases(
          timeline(LoopMode.loop),
          atPhase: 'b',
          onTransition: transitions.add,
        );
        await tester.pump();
        await pumpFrames(tester, 10);

        expect(transitions.take(4), const [
          PhaseTransitioning(from: 'b', to: 'c'),
          PhaseTransitioning(from: 'c', to: 'a'),
          PhaseTransitioning(from: 'a', to: 'b'),
          PhaseTransitioning(from: 'b', to: 'c'),
        ]);
        controller.stop(canceled: true);
      });

      testWidgets('with pingPong walks back through the earlier phases',
          (tester) async {
        controller = PhaseTrackController(vsync: tester);
        controller.playPhases(
          timeline(LoopMode.pingPong),
          atPhase: 'b',
          onTransition: transitions.add,
        );
        await tester.pump();
        await pumpFrames(tester, 10);

        expect(transitions.take(4), const [
          PhaseTransitioning(from: 'b', to: 'c'),
          PhaseTransitioning(from: 'c', to: 'b'),
          PhaseTransitioning(from: 'b', to: 'a'),
          PhaseTransitioning(from: 'a', to: 'b'),
        ]);
        controller.stop(canceled: true);
      });

      testWidgets('with seamless jumps to the first phase after the last',
          (tester) async {
        controller = PhaseTrackController(vsync: tester);
        controller.playPhases(
          timeline(LoopMode.seamless),
          atPhase: 'b',
          onTransition: transitions.add,
        );
        await tester.pump();
        await pumpFrames(tester, 3);
        expect(controller.value(track), greaterThan(2));

        await pumpFrames(tester, 1);
        expect(controller.value(track), closeTo(1, error));
        expect(transitions, const [
          PhaseTransitioning(from: 'b', to: 'c'),
          PhaseTransitioning(from: 'c', to: 'a'),
          PhaseTransitioning(from: 'a', to: 'b'),
        ]);
        controller.stop(canceled: true);
      });
    });

    testWidgets('goToPhase during pingPong stops auto-advancing',
        (tester) async {
      controller = PhaseTrackController(vsync: tester);
      controller.playPhases(
        timeline(LoopMode.pingPong),
        onTransition: transitions.add,
      );
      await tester.pump();
      await pumpFrames(tester, 7);
      expect(controller.currentPhase, 'b');
      transitions.clear();

      controller.goToPhase('a');
      await pumpFrames(tester, 14);

      expect(transitions, const [
        PhaseTransitioning(from: 'b', to: 'a'),
        PhaseSettled('a'),
      ]);
      expect(controller.value(track), closeTo(1, error));
      expect(controller.isAnimating, isFalse);
      expect(controller.status, AnimationStatus.dismissed);
    });
  });

  test('a sync token equal to a phase value is rejected', () {
    expect(
      () => TrackPhaseTimeline({
        'a': [
          track([const TrackStep.sync(token: 'b'), const TrackStep.to(1)]),
        ],
        'b': [track.to(2)],
      }),
      throwsAssertionError,
    );
    expect(
      () => TrackPhaseTimeline({
        'a': [
          track([const TrackStep.sync(token: #mine), const TrackStep.to(1)]),
        ],
        'b': [track.to(2)],
      }),
      returnsNormally,
    );
  });
}
