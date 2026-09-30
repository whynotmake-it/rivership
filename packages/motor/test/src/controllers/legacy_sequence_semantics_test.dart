// ignore_for_file: deprecated_member_use_from_same_package
// ignore_for_file: unawaited_futures, cascade_invocations

import 'package:flutter/widgets.dart';
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

  testWidgets('reports progress while playing', (tester) async {
    final controller = legacyController(tester);
    addTearDown(controller.dispose);

    expect(controller.sequenceProgress, 0);
    controller.playSequence(sequence(LoopMode.none));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(controller.sequenceProgress, 0.5);

    await tester.pump(const Duration(milliseconds: 101));
    await tester.pump(const Duration(milliseconds: 101));
    expect(controller.isPlayingSequence, isFalse);
    expect(controller.sequenceProgress, 0);
  });

  testWidgets('starts at a requested phase', (tester) async {
    final controller = legacyController(tester);
    addTearDown(controller.dispose);
    final visited = <int>[];

    controller.playSequence(
      sequence(LoopMode.none),
      atPhase: 1,
      onTransition: (transition) {
        if (transition case PhaseTransitioning(:final to)) visited.add(to);
      },
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 101));

    expect(visited, [2]);
    expect(controller.value, 2);
    expect(controller.isPlayingSequence, isFalse);
  });

  for (final loop in [LoopMode.loop, LoopMode.pingPong, LoopMode.seamless]) {
    testWidgets('a $loop sequence future completes only when stopped',
        (tester) async {
      final controller = legacyController(tester);
      addTearDown(controller.dispose);

      var completed = false;
      controller.playSequence(sequence(loop)).then((_) => completed = true);
      await tester.pump();
      for (var i = 0; i < 100; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(controller.isPlayingSequence, isTrue);
      expect(completed, isFalse);

      controller.stop();
      await tester.pump();
      expect(completed, isTrue);
    });
  }

  testWidgets('interrupting a looping sequence cancels its future',
      (tester) async {
    final controller = legacyController(tester);
    addTearDown(controller.dispose);

    final canceled = expectLater(
      controller
          .playSequence(sequence(LoopMode.loop, values: const [0, 1]))
          .orCancel,
      throwsA(isA<TickerCanceled>()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    controller.animateTo(5);
    await canceled;
    await tester.pumpAndSettle();
  });

  testWidgets('scrubbing a sequence matches playback', (tester) async {
    final steps = sequence(LoopMode.none, values: const [0, 1, 2, 3]);

    // 1ms frames keep the frame-anchored phase starts within 1ms of exact.
    final live = legacyController(tester)..playSequence(steps);
    await tester.pump();
    for (var i = 0; i < 250; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }

    final scrubbed = legacyController(tester)..playSequence(steps);
    scrubbed.internalInnerController
      ..pause()
      ..scrubTo(const Duration(milliseconds: 250));
    expect(scrubbed.value, closeTo(live.value, 0.05));

    live.stop(canceled: true);
    scrubbed.stop(canceled: true);
    live.dispose();
    scrubbed.dispose();
  });

  group('interrupting MotionController calls', () {
    const motion = CupertinoMotion.smooth();
    const states = MotionSequence<String, Offset>.states(
      {
        'a': Offset.zero,
        'b': Offset(1, 1),
        'c': Offset(2, 2),
      },
      motion: motion,
    );

    SequenceMotionController<String, Offset> offsetController(
      WidgetTester tester,
    ) {
      final controller = SequenceMotionController<String, Offset>(
        motion: motion,
        vsync: tester,
        converter: MotionConverter.offset,
        initialValue: Offset.zero,
      );
      addTearDown(controller.dispose);
      return controller;
    }

    testWidgets('animateTo on the MotionController type stops the sequence',
        (tester) async {
      final controller = offsetController(tester);
      final MotionController<Offset> motionController = controller;

      controller.playSequence(states);
      await tester.pump();
      expect(controller.isPlayingSequence, isTrue);

      motionController.animateTo(const Offset(3, 3));
      await tester.pump();
      expect(controller.isPlayingSequence, isFalse);
      expect(controller.activeSequence, isNull);

      await tester.pumpAndSettle();
      expect(controller.value.dx, moreOrLessEquals(3, epsilon: error));
      expect(controller.value.dy, moreOrLessEquals(3, epsilon: error));
    });

    testWidgets('stop stops the sequence', (tester) async {
      final controller =
          SequenceMotionController<String, Offset>.motionPerDimension(
        motionPerDimension: [motion, motion],
        vsync: tester,
        converter: MotionConverter.offset,
        initialValue: Offset.zero,
      );
      addTearDown(controller.dispose);
      expect(controller.value, equals(Offset.zero));
      expect(controller.motionPerDimension, equals([motion, motion]));

      controller.playSequence(states);
      await tester.pump();
      expect(controller.isPlayingSequence, isTrue);

      controller.stop();
      expect(controller.isPlayingSequence, isFalse);
      expect(controller.activeSequence, isNull);
    });

    testWidgets('setting value stops the sequence', (tester) async {
      final controller = offsetController(tester);

      controller.playSequence(states);
      await tester.pump();
      expect(controller.isPlayingSequence, isTrue);

      controller.value = const Offset(3, 3);
      expect(controller.isPlayingSequence, isFalse);
      expect(controller.activeSequence, isNull);
      expect(controller.value, equals(const Offset(3, 3)));
    });

    group('setting the motion', () {
      const slow = Motion.linear(Duration(seconds: 1));
      const fast = Motion.linear(Duration(milliseconds: 100));

      for (final (name, change) in <(
        String,
        void Function(SequenceMotionController<String, Offset>),
      )>[
        ('motion', (controller) => controller.motion = fast),
        (
          'motionPerDimension',
          (controller) => controller.motionPerDimension = [fast, slow],
        ),
      ]) {
        testWidgets('with $name redirects an animation, like MotionController',
            (tester) async {
          final controller = SequenceMotionController<String, Offset>(
            motion: slow,
            vsync: tester,
            converter: MotionConverter.offset,
            initialValue: Offset.zero,
          );
          addTearDown(controller.dispose);
          controller.animateTo(const Offset(1, 1));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
          expect(controller.value.dx, closeTo(0.2, error));

          change(controller);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          expect(controller.value.dx, closeTo(1, error));
          await tester.pumpAndSettle();
          expect(controller.value, const Offset(1, 1));
        });
      }

      testWidgets("during a sequence leaves the sequence's timing alone",
          (tester) async {
        final controller = SequenceMotionController<String, double>(
          motion: slow,
          vsync: tester,
          converter: MotionConverter.single,
          initialValue: 0,
        );
        addTearDown(controller.dispose);
        // A redirect back to this target would end the sequence.
        controller.animateTo(0);
        await tester.pump();
        controller.playSequence(
          const MotionSequence.states({'a': 1.0, 'b': 2.0}, motion: slow),
        );
        await tester.pump();
        for (var frame = 0; frame < 3; frame++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(controller.value, closeTo(0.4, error));

        controller.motion = fast;
        await tester.pump(const Duration(milliseconds: 100));
        expect(controller.value, closeTo(0.6, error));
        await tester.pump(const Duration(milliseconds: 600));
        expect(controller.value, closeTo(1.8, error));
        await tester.pumpAndSettle();
        expect(controller.value, 2);
      });
    });
  });
}
