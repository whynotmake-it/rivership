// ignore_for_file: cascade_invocations, unawaited_futures

import 'package:flutter_test/flutter_test.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';

import '../util.dart';

void main() {
  const linear50 = Motion.linear(Duration(milliseconds: 50));
  const linear100 = Motion.linear(Duration(milliseconds: 100));

  group('playback inspection', () {
    late TrackController controller;
    final first = Track<double>(MotionConverter.single, initial: 0);
    final second = Track<double>(MotionConverter.single, initial: 0);

    tearDown(() => controller.dispose());

    testWidgets('reports every track and synthetic loop returns',
        (tester) async {
      controller = TrackController(vsync: tester);
      controller.play(
        TrackTimeline(
          [
            first.to(1, motion: linear100),
            second.to(2, motion: linear100),
          ],
          loop: LoopMode.loop,
        ),
      );

      await tester.pump();
      final snapshot = controller.inspectPlayback();

      expect(snapshot.tracks, hasLength(2));
      expect(snapshot.tracks, everyElement(isA<TrackPlayback>()));
      expect(
        snapshot.tracks,
        everyElement(
          isA<TrackPlayback>()
              .having((track) => track.steps, 'steps', hasLength(2))
              .having(
                (track) => track.hasSyntheticReturnStep,
                'synthetic return',
                isTrue,
              )
              .having((track) => track.currentStepIndex, 'step', 0),
        ),
      );

      controller.stop(canceled: true);
    });

    testWidgets('records actual step starts and durations', (tester) async {
      controller = TrackController(vsync: tester);
      controller.animate([
        first([
          const TrackStep.to(1, motion: linear100),
          const TrackStep.to(2, motion: linear100),
        ]),
      ]);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      final playback = controller.inspectPlayback().tracks.single;

      expect(playback.segments[0].start, Duration.zero);
      expect(playback.segments[1].stepIndex, 1);
      expect(
        playback.segments[1].start.inMicroseconds,
        closeTo(
          const Duration(milliseconds: 100).inMicroseconds,
          2,
        ),
      );
      expect(
        playback.stepDurations[0]!.inMicroseconds,
        closeTo(
          const Duration(milliseconds: 100).inMicroseconds,
          2,
        ),
      );
      controller.stop(canceled: true);
    });

    testWidgets('exposes sync waits and recorded release moments',
        (tester) async {
      controller = TrackController(vsync: tester);
      controller.animate([
        first([
          const TrackStep.to(1, motion: linear50),
          const TrackStep.sync(token: #meet),
          const TrackStep.to(2, motion: linear100),
        ]),
        second([
          const TrackStep.to(1, motion: linear100),
          const TrackStep.sync(token: #meet),
          const TrackStep.to(2, motion: linear100),
        ]),
      ]);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final waiting = controller.inspectPlayback().tracks.firstWhere(
            (playback) => identical(playback.track, first),
          );
      expect(waiting.isWaitingForSync, isTrue);
      expect(
        waiting.steps[waiting.currentStepIndex],
        isA<StepSync<Object>>().having((step) => step.token, 'token', #meet),
      );

      await tester.pump(const Duration(milliseconds: 60));
      final released = controller.inspectPlayback().tracks;
      final fast = released.firstWhere(
        (playback) => identical(playback.track, first),
      );
      final slow = released.firstWhere(
        (playback) => identical(playback.track, second),
      );
      Duration startOf(TrackPlayback playback, int step) => playback.segments
          .firstWhere((segment) => segment.stepIndex == step)
          .start;
      expect(
        (startOf(fast, 2) - startOf(slow, 2)).inMicroseconds.abs(),
        lessThanOrEqualTo(const Duration(milliseconds: 20).inMicroseconds),
      );
      controller.stop(canceled: true);
    });

    testWidgets('records a spring actual settle duration', (tester) async {
      controller = TrackController(vsync: tester);
      const spring = CupertinoMotion(
        duration: Duration(milliseconds: 250),
        snapToEnd: false,
      );
      controller.animate([first.to(1, motion: spring)]);

      await tester.pump();
      await tester.pumpAndSettle();
      final duration =
          controller.inspectPlayback().tracks.single.stepDurations.single;

      expect(duration, isNotNull);
      expect(
        duration!.inMicroseconds,
        greaterThanOrEqualTo(spring.duration.inMicroseconds),
      );
    });

    testWidgets('marks segments with their loop cycle', (tester) async {
      controller = TrackController(vsync: tester);
      controller.play(
        TrackTimeline(
          [first.to(1, motion: linear50)],
          loop: LoopMode.pingPong,
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 180));
      final playback = controller.inspectPlayback().tracks.single;
      final cycles = {for (final segment in playback.segments) segment.cycle};
      expect(cycles, containsAll([0, 1]));
      controller.stop(canceled: true);
    });

    testWidgets('lists resolved segments and the loop repetition',
        (tester) async {
      controller = TrackController(vsync: tester);
      controller.play(
        TrackTimeline(
          [
            first([
              const TrackStep.to(1, motion: linear50),
              const TrackStep.hold(Duration(milliseconds: 50)),
            ]),
          ],
          loop: LoopMode.seamless,
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      var playback = controller.inspectPlayback().tracks.single;
      expect(playback.segments.single.stepIndex, 0);
      expect(playback.segments.single.end, const Duration(milliseconds: 50));
      expect(playback.loopPeriod, isNull);

      await tester.pump(const Duration(milliseconds: 300));
      playback = controller.inspectPlayback().tracks.single;
      expect(playback.loopPeriod, const Duration(milliseconds: 100));
      // Every cycle restarts from the same state, so the first one repeats.
      expect(
        [for (final segment in playback.segments) segment.stepIndex],
        [0, 1],
      );
      expect(playback.loopRepeatStart, Duration.zero);
      expect(
        playback.segments.last.end,
        playback.loopRepeatStart! + playback.loopPeriod!,
      );
      controller.stop(canceled: true);
    });

    testWidgets('position follows the controller timeline', (tester) async {
      controller = TrackController(vsync: tester);
      expect(controller.inspectPlayback().position, Duration.zero);

      controller.animate([first.to(1, motion: linear100)]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(
        controller.inspectPlayback().position,
        const Duration(milliseconds: 40),
      );

      controller.pause();
      await tester.pump(const Duration(milliseconds: 40));
      expect(
        controller.inspectPlayback().position,
        const Duration(milliseconds: 40),
      );

      controller.scrubTo(const Duration(milliseconds: 10));
      expect(
        controller.inspectPlayback().position,
        const Duration(milliseconds: 10),
      );
      controller.stop(canceled: true);
    });

    testWidgets('interruption replaces the inspected plan', (tester) async {
      controller = TrackController(vsync: tester);
      controller.animate([first.to(1, motion: linear100)]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      controller.animate([first.to(0.25, motion: linear50)]);
      final snapshot = controller.inspectPlayback();
      final step = snapshot.tracks.single.steps.single as StepTo<Object>;

      expect(step.value, closeTo(0.25, error));
      controller.stop(canceled: true);
    });
  });
}
