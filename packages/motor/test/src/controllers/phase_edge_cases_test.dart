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
          'a': [
            track([const TrackStep.to(1, motion: linear40)]),
          ],
          'b': [
            track([const TrackStep.to(2, motion: linear40)]),
          ],
          'c': [
            track([const TrackStep.to(3, motion: linear40)]),
          ],
        },
        loop: loop,
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
      for (final (atPhase, firstFrameValue, expected) in [
        (
          'b',
          1.05,
          const [PhaseTransitioning(from: 'b', to: 'c'), PhaseSettled('c')],
        ),
        ('c', 1.575, const [PhaseSettled('c')]),
      ]) {
        testWidgets(
            'at $atPhase without a loop plays the remaining phases and settles',
            (tester) async {
          controller = PhaseTrackController(vsync: tester);
          controller.playPhases(
            timeline(LoopMode.none),
            atPhase: atPhase,
            onTransition: transitions.add,
          );
          expect(controller.currentPhase, atPhase);

          await tester.pump();
          await pumpFrames(tester, 1);
          expect(
            controller.value(track),
            closeTo(firstFrameValue, error),
            reason: 'playback should animate from 0 straight toward phase '
                '$atPhase, not start at phase a',
          );

          await pumpFrames(tester, 7);
          expect(transitions, expected);
          expect(controller.value(track), closeTo(3, error));
          expect(controller.isAnimating, isFalse);
        });
      }

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

    testWidgets(
        'goToPhase during playPhases stops tracks the phase does not name',
        (tester) async {
      const linear100 = Motion.linear(Duration(milliseconds: 100));
      final x = Track<double>(MotionConverter.single, initial: 0);
      final y = Track<double>(MotionConverter.single, initial: 0);
      controller = PhaseTrackController(vsync: tester);
      controller.playPhases(
        TrackPhaseTimeline({
          'a': [
            x([const TrackStep.to(1, motion: linear100)]),
          ],
          'b': [
            x([const TrackStep.to(2, motion: linear100)]),
            y([const TrackStep.to(5, motion: linear100)]),
          ],
          'c': [
            x([const TrackStep.to(3, motion: linear100)]),
            y([const TrackStep.to(9, motion: linear100)]),
          ],
        }),
        onTransition: transitions.add,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      controller.goToPhase('a');
      await tester.pumpAndSettle();

      expect(controller.value(x), closeTo(1, error));
      expect(controller.value(y), 0);
      expect(controller.currentPhase, 'a');
      expect(
        transitions.whereType<PhaseTransitioning<String>>(),
        isEmpty,
      );
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

  testWidgets('a sync token equal to a phase value is not a phase change',
      (tester) async {
    final transitions = <PhaseTransition<String>>[];
    final controller = PhaseTrackController<String>(vsync: tester);
    addTearDown(controller.dispose);

    controller.playPhases(
      TrackPhaseTimeline({
        'a': [
          track([
            const TrackStep.to(1, motion: linear40),
            const TrackStep.sync(token: 'c'),
            const TrackStep.to(1.5, motion: linear40),
          ]),
        ],
        'b': [
          track([const TrackStep.to(2, motion: linear40)]),
        ],
        'c': [
          track([const TrackStep.to(3, motion: linear40)]),
        ],
      }),
      onTransition: transitions.add,
    );
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 21));
    }

    // Releasing the user's 'c' barrier inside phase 'a' must not report
    // phase 'c'; only the phase barriers do.
    expect(
      transitions.first,
      const PhaseTransitioning(from: 'a', to: 'b'),
    );
    await tester.pumpAndSettle();
    expect(controller.currentPhase, 'c');
  });
}
