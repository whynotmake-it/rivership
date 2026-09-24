// ignore_for_file: deprecated_member_use_from_same_package
// ignore_for_file: unawaited_futures, cascade_invocations

import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

import '../util.dart';

void main() {
  const linear100 = Motion.linear(Duration(milliseconds: 100));

  SequenceMotionController<int, double> legacyController(
    WidgetTester tester,
  ) =>
      SequenceMotionController<int, double>(
        motion: linear100,
        vsync: tester,
        converter: MotionConverter.single,
        initialValue: 0,
      );

  MotionSequence<int, double> sequence(
    LoopMode loop, {
    List<double> values = const [0, 1, 2],
  }) =>
      MotionSequence.steps(values, motion: linear100, loop: loop);

  testWidgets('none plays each phase and settles at the last', (tester) async {
    final controller = legacyController(tester);
    final transitions = <PhaseTransition<int>>[];

    controller.playSequence(
      sequence(LoopMode.none),
      onTransition: transitions.add,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(controller.currentSequencePhase, 1);

    await tester.pump(const Duration(milliseconds: 50));
    expect(controller.value, closeTo(0.5, error));
    await tester.pump(const Duration(milliseconds: 51));
    expect(controller.currentSequencePhase, 2);
    await tester.pump(const Duration(milliseconds: 50));
    expect(controller.value, closeTo(1.5, error));
    await tester.pump(const Duration(milliseconds: 51));

    expect(controller.value, closeTo(2, error));
    expect(controller.isPlayingSequence, isFalse);
    expect(
      transitions,
      [
        const PhaseTransitioning(from: 0, to: 1),
        const PhaseTransitioning(from: 1, to: 2),
        const PhaseSettled(2),
      ],
    );
    controller.dispose();
  });

  testWidgets('loop animates back to phase zero before replaying',
      (tester) async {
    final controller = legacyController(tester);

    controller.playSequence(sequence(LoopMode.loop));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 101));
    await tester.pump(const Duration(milliseconds: 101));

    expect(controller.currentSequencePhase, 0);
    expect(controller.value, closeTo(2, error));

    await tester.pump(const Duration(milliseconds: 25));
    expect(controller.value, closeTo(1.5, error));
    await tester.pump(const Duration(milliseconds: 25));
    expect(controller.value, closeTo(1, error));
    await tester.pump(const Duration(milliseconds: 51));
    expect(controller.value, closeTo(0, error));
    expect(controller.currentSequencePhase, 1);
    expect(controller.isPlayingSequence, isTrue);
    controller.stop(canceled: true);
    controller.dispose();
  });

  testWidgets('seamless jumps to an equal first value without a discontinuity',
      (tester) async {
    final controller = legacyController(tester);
    final settledPhases = <int>[];

    controller.playSequence(
      sequence(LoopMode.seamless, values: const [0, 1, 0]),
      onTransition: (transition) {
        if (transition case PhaseSettled(:final phase)) {
          settledPhases.add(phase);
        }
      },
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 101));
    await tester.pump(const Duration(milliseconds: 99));
    expect(controller.value, closeTo(0.01, error));

    await tester.pump(const Duration(milliseconds: 2));
    expect(controller.value, closeTo(0, error));
    expect(controller.currentSequencePhase, 1);
    expect(settledPhases, [0]);

    await tester.pump(const Duration(milliseconds: 50));
    expect(controller.value, closeTo(0.5, error));
    expect(controller.currentSequencePhase, 1);
    expect(controller.isPlayingSequence, isTrue);
    controller.stop(canceled: true);
    controller.dispose();
  });

  testWidgets('pingPong visits phases forward, backward, then forward',
      (tester) async {
    final controller = legacyController(tester);
    final visited = <int>[0];

    controller.playSequence(
      sequence(LoopMode.pingPong),
      onTransition: (transition) {
        if (transition case PhaseTransitioning(:final to)) visited.add(to);
      },
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(visited, [0, 1]);

    await tester.pump(const Duration(milliseconds: 50));
    expect(controller.value, closeTo(0.5, error));
    await tester.pump(const Duration(milliseconds: 51));
    expect(visited, [0, 1, 2]);
    await tester.pump(const Duration(milliseconds: 101));
    expect(visited, [0, 1, 2, 1]);
    await tester.pump(const Duration(milliseconds: 50));
    expect(controller.value, closeTo(1.5, error));
    await tester.pump(const Duration(milliseconds: 51));
    expect(visited, [0, 1, 2, 1, 0]);
    await tester.pump(const Duration(milliseconds: 101));

    expect(visited, [0, 1, 2, 1, 0, 1]);
    expect(controller.value, closeTo(0, error));
    expect(controller.isPlayingSequence, isTrue);
    controller.stop(canceled: true);
    controller.dispose();
  });

  testWidgets('loop phase order matches the track stack', (tester) async {
    final legacy = legacyController(tester);
    final track = Track<double>(MotionConverter.single, initial: 0);
    final modern = PhaseTrackController<int>(vsync: tester);
    final legacyVisited = <int>[0];
    final modernVisited = <int>[0];

    legacy.playSequence(
      sequence(LoopMode.loop),
      onTransition: (transition) {
        if (transition case PhaseTransitioning(:final to)) {
          legacyVisited.add(to);
        }
      },
    );
    modern.playPhases(
      TrackPhaseTimeline(
        {
          0: [track.to(0, motion: linear100)],
          1: [track.to(1, motion: linear100)],
          2: [track.to(2, motion: linear100)],
        },
        phaseLoop: LoopMode.loop,
      ),
      onTransition: (transition) {
        if (transition case PhaseTransitioning(:final to)) {
          modernVisited.add(to);
        }
      },
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(legacyVisited.take(4), [0, 1, 2, 0]);
    expect(modernVisited.take(4), [0, 1, 2, 0]);
    expect(legacyVisited.take(4), modernVisited.take(4));

    legacy.stop(canceled: true);
    modern.stop(canceled: true);
    legacy.dispose();
    modern.dispose();
  });
}
