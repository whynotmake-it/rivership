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
      final revision = controller.playbackRevision;
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

      await tester.pump(const Duration(milliseconds: 20));
      expect(controller.playbackRevision, revision);
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

      expect(playback.stepStarts[0], Duration.zero);
      expect(
        playback.stepStarts[1]!.inMicroseconds,
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
      expect(waiting.syncToken, #meet);

      await tester.pump(const Duration(milliseconds: 60));
      final released = controller.inspectPlayback().tracks;
      final fast = released.firstWhere(
        (playback) => identical(playback.track, first),
      );
      final slow = released.firstWhere(
        (playback) => identical(playback.track, second),
      );
      expect(fast.stepStarts[2], isNotNull);
      expect(slow.stepStarts[2], isNotNull);
      expect(
        (fast.stepStarts[2]! - slow.stepStarts[2]!).inMicroseconds.abs(),
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

    testWidgets('counts loop boundaries', (tester) async {
      controller = TrackController(vsync: tester);
      controller.play(
        TrackTimeline(
          [first.to(1, motion: linear50)],
          loop: LoopMode.seamless,
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 180));
      final playback = controller.inspectPlayback().tracks.single;
      expect(playback.cycle, greaterThan(0));
      expect(playback.cycleStart, greaterThan(Duration.zero));
      expect(playback.playhead, greaterThan(playback.cycleStart));
      controller.stop(canceled: true);
    });

    testWidgets('revision changes only when plans mutate', (tester) async {
      controller = TrackController(vsync: tester);
      final initial = controller.playbackRevision;

      controller.animate([first.to(1, motion: linear100)]);
      expect(controller.playbackRevision, initial + 1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(controller.playbackRevision, initial + 1);

      controller.stop(canceled: true);
      expect(controller.playbackRevision, initial + 2);
    });

    testWidgets('interruption replaces the inspected plan', (tester) async {
      controller = TrackController(vsync: tester);
      controller.animate([first.to(1, motion: linear100)]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      final before = controller.playbackRevision;

      controller.animate([first.to(0.25, motion: linear50)]);
      final snapshot = controller.inspectPlayback();
      final step = snapshot.tracks.single.steps.single as StepTo<Object>;

      expect(controller.playbackRevision, before + 1);
      expect(step.value, closeTo(0.25, error));
      controller.stop(canceled: true);
    });
  });
}
