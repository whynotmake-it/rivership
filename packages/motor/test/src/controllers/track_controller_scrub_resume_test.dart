// ignore_for_file: cascade_invocations, unawaited_futures

import 'package:flutter/animation.dart';
import 'package:flutter/scheduler.dart' show timeDilation;
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';
import 'package:motor/src/simulations/step_playback.dart';

import '../util.dart';

void main() {
  const linear100 = Motion.linear(Duration(milliseconds: 100));
  const linear200 = Motion.linear(Duration(milliseconds: 200));

  const stepsA = <TrackStep<double>>[
    TrackStep.to(1, motion: linear100),
    TrackStep.hold(Duration(milliseconds: 50)),
    TrackStep.to(0, motion: linear100),
  ];
  const stepsB = <TrackStep<double>>[
    TrackStep.to(2, motion: linear200),
  ];

  double expectedAt(List<TrackStep<double>> steps, Duration t) {
    final playback = StepPlayback<double>(
      steps: steps,
      converter: MotionConverter.single,
      start: 0,
    );
    playback.advanceTo(t.inMicroseconds / Duration.microsecondsPerSecond);
    return playback.values.single;
  }

  group('TrackController scrubTo / resume / resync', () {
    late TrackController controller;
    final trackA = Track<double>(MotionConverter.single, initial: 0);
    final trackB = Track<double>(MotionConverter.single, initial: 0);

    tearDown(() {
      controller.dispose();
    });

    testWidgets('scrubTo matches the plan values at each time', (tester) async {
      controller = TrackController(vsync: tester);

      controller.animate([trackA(stepsA), trackB(stepsB)]);
      await tester.pump();

      for (final t in const [
        Duration(milliseconds: 50),
        Duration(milliseconds: 125),
        Duration(milliseconds: 190),
      ]) {
        controller.scrubTo(t);
        expect(
          controller.value(trackA),
          closeTo(expectedAt(stepsA, t), error),
          reason: 'trackA at ${t.inMilliseconds}ms',
        );
        expect(
          controller.value(trackB),
          closeTo(expectedAt(stepsB, t), error),
          reason: 'trackB at ${t.inMilliseconds}ms',
        );
      }

      controller.stop(canceled: true);
    });

    testWidgets('scrubTo after stop(canceled) is a no-op on frozen values',
        (tester) async {
      controller = TrackController(vsync: tester);

      controller.animate([trackA(stepsA), trackB(stepsB)]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      controller.stop(canceled: true);
      expect(controller.isAnimating, isFalse);
      final frozenA = controller.value(trackA);
      final frozenB = controller.value(trackB);

      // CHARACTERIZATION: current behavior — see plans/005. stop(canceled:
      // true) deactivates every track and drops its playback, so scrubbing
      // afterwards does not evaluate the old timeline; values stay frozen
      // where the stop landed.
      for (final t in const [
        Duration(milliseconds: 20),
        Duration(milliseconds: 125),
        Duration(milliseconds: 300),
      ]) {
        controller.scrubTo(t);
        expect(controller.value(trackA), closeTo(frozenA, error));
        expect(controller.value(trackB), closeTo(frozenB, error));
      }
      expect(controller.isAnimating, isFalse);

      // CHARACTERIZATION: current behavior — see plans/005. resume() after a
      // canceled stop is a no-op because no track slot is animating anymore.
      controller.resume();
      expect(controller.isAnimating, isFalse);
    });

    testWidgets('resume() after scrubbing completes to the targets',
        (tester) async {
      controller = TrackController(vsync: tester);

      controller.animate([trackA(stepsA), trackB(stepsB)]);
      await tester.pump();

      controller.scrubTo(const Duration(milliseconds: 125));
      expect(
        controller.value(trackA),
        closeTo(expectedAt(stepsA, const Duration(milliseconds: 125)), error),
      );

      controller.resume();
      expect(controller.isAnimating, isTrue);

      await tester.pumpAndSettle();
      expect(controller.isAnimating, isFalse);
      expect(controller.value(trackA), closeTo(0, error));
      expect(controller.value(trackB), closeTo(2, error));
    });

    testWidgets('resume after scrub continues from the scrubbed position',
        (tester) async {
      controller = TrackController(vsync: tester);
      const linear = Motion.linear(Duration(seconds: 1));
      controller.animate([
        trackA([
          const TrackStep.to(1, motion: linear),
          const TrackStep.to(2, motion: linear),
        ]),
      ]);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      controller.pause();
      controller.scrubTo(const Duration(milliseconds: 600));
      final scrubbed = controller.value(trackA);

      controller.resume();
      await tester.pump(const Duration(milliseconds: 16));

      expect(controller.value(trackA), greaterThanOrEqualTo(scrubbed));
      controller.stop(canceled: true);
    });

    testWidgets('scrubbing resolves barriers like playback', (tester) async {
      controller = TrackController(vsync: tester);
      const linear50 = Motion.linear(Duration(milliseconds: 50));
      const linear150 = Motion.linear(Duration(milliseconds: 150));
      controller.animate([
        trackA([
          const TrackStep.to(1, motion: linear50),
          const TrackStep.sync(token: #meet),
          const TrackStep.to(2, motion: linear200),
        ]),
        trackB([
          const TrackStep.to(1, motion: linear150),
          const TrackStep.sync(token: #meet),
          const TrackStep.to(2, motion: linear200),
        ]),
      ]);

      await tester.pump();
      controller.pause();

      // trackA waits at the barrier until trackB arrives at 150ms.
      controller.scrubTo(const Duration(milliseconds: 100));
      expect(controller.value(trackA), closeTo(1, error));
      expect(controller.value(trackB), closeTo(2 / 3, error));

      controller.scrubTo(const Duration(milliseconds: 170));
      expect(controller.value(trackA), closeTo(1.1, error));
      expect(controller.value(trackB), closeTo(1.1, error));

      controller.scrubTo(const Duration(milliseconds: 100));
      expect(controller.value(trackA), closeTo(1, error));

      controller.resume();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 70));
      expect(controller.value(trackA), closeTo(1.1, error));
      expect(controller.value(trackB), closeTo(1.1, error));
      controller.stop(canceled: true);
    });

    testWidgets('scrub can move backward and forward after touching the end',
        (tester) async {
      controller = TrackController(vsync: tester);
      controller.animate([trackA(stepsA)]);
      await tester.pump();
      controller.pause();

      controller.scrubTo(const Duration(seconds: 2));
      expect(controller.value(trackA), closeTo(0, error));

      controller.scrubTo(const Duration(milliseconds: 50));
      expect(controller.value(trackA), closeTo(0.5, error));

      controller.resume();
      expect(controller.isAnimating, isTrue);
      controller.pause();
      controller.scrubTo(const Duration(milliseconds: 200));
      expect(controller.value(trackA), closeTo(0.5, error));
      expect(controller.isAnimating, isFalse);
      expect(controller.inspectPlayback().tracks, hasLength(1));

      controller.resume();
      await tester.pumpAndSettle();
      expect(controller.value(trackA), closeTo(0, error));
    });

    testWidgets('completed playback remains available for inspection scrubbing',
        (tester) async {
      controller = TrackController(vsync: tester);
      controller.animate([trackA(stepsA)]);
      await tester.pumpAndSettle();
      expect(controller.status, AnimationStatus.dismissed);

      controller.scrubTo(const Duration(milliseconds: 50));
      expect(controller.value(trackA), closeTo(0.5, error));
      controller.scrubTo(const Duration(milliseconds: 200));
      expect(controller.value(trackA), closeTo(0.5, error));

      controller.resume();
      await tester.pumpAndSettle();
      expect(controller.value(trackA), closeTo(0, error));
      expect(controller.status, AnimationStatus.dismissed);
    });

    testWidgets('resync preserves values and the animation still completes',
        (tester) async {
      controller = TrackController(vsync: tester);

      controller.animate([trackA(stepsA), trackB(stepsB)]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      final valueA = controller.value(trackA);
      final valueB = controller.value(trackB);
      expect(controller.isAnimating, isTrue);

      controller.resync(tester);

      expect(controller.value(trackA), closeTo(valueA, error));
      expect(controller.value(trackB), closeTo(valueB, error));
      expect(controller.isAnimating, isTrue);

      await tester.pumpAndSettle();
      expect(controller.value(trackA), closeTo(0, error));
      expect(controller.value(trackB), closeTo(2, error));
    });
  });

  group('TrackController timeline', () {
    const linear1s = Motion.linear(Duration(seconds: 1));
    late TrackController controller;
    final trackA = Track<double>(MotionConverter.single, initial: 0);
    final trackB = Track<double>(MotionConverter.single, initial: 0);

    tearDown(() {
      controller.dispose();
    });

    testWidgets('animating another track while paused continues paused tracks',
        (tester) async {
      controller = TrackController(vsync: tester);
      controller.animate([trackA.to(1, motion: linear1s)]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      controller.pause();

      controller.animate([trackB.to(1, motion: linear1s)]);
      await tester.pump();
      expect(controller.value(trackA), closeTo(0.5, error));

      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.value(trackA), closeTo(0.6, error));
      expect(controller.value(trackB), closeTo(0.1, error));
      controller.stop(canceled: true);
    });

    testWidgets(
        'a barrier that loses a participant releases then, not in the past',
        (tester) async {
      controller = TrackController(vsync: tester);
      controller.animate([
        trackA([
          const TrackStep.to(1, motion: linear100),
          const TrackStep.sync(token: #meet),
          const TrackStep.to(2, motion: linear100),
        ]),
        trackB([
          const TrackStep.to(1, motion: linear200),
          const TrackStep.sync(token: #meet),
        ]),
      ]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(controller.value(trackA), closeTo(1, error));

      controller.animate([trackB.to(0, motion: linear100)]);
      await tester.pump(const Duration(milliseconds: 50));
      expect(controller.value(trackA), closeTo(1.5, error));

      controller.pause();
      controller.scrubTo(const Duration(milliseconds: 120));
      expect(controller.value(trackA), closeTo(1, error));
      controller.stop(canceled: true);
    });

    testWidgets(
        'with tooling, a looping plan with a barrier keeps a bounded, exact '
        'recent history', (tester) async {
      final subscription = MotorInspectionRegistry.attach(_Observer());
      addTearDown(subscription.dispose);
      const linear10 = Motion.linear(Duration(milliseconds: 10));
      controller = TrackController(vsync: tester);
      controller.animate(
        [
          trackA([
            const TrackStep.to(1, motion: linear10),
            const TrackStep.to(0, motion: linear10),
            const TrackStep.sync(token: #cycle),
          ]),
        ],
        loop: LoopMode.loop,
      );
      await tester.pump();
      final recorded = <(Duration, double)>[];
      for (var i = 0; i < 1000; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        recorded.add(
          (controller.inspectPlayback().position, controller.value(trackA)),
        );
      }
      controller.pause();

      expect(
        controller.inspectPlayback().tracks.single.segments.length,
        lessThanOrEqualTo(1100),
      );
      for (final (position, value) in recorded.skip(800)) {
        controller.scrubTo(position);
        expect(controller.value(trackA), closeTo(value, error));
      }
      controller.stop(canceled: true);
    });

    testWidgets('scrubs tracks started at different times on one timeline',
        (tester) async {
      controller = TrackController(vsync: tester);
      controller.animate([trackA.to(1, motion: linear1s)]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      controller
        ..pause()
        ..resume();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      controller.animate([trackB.to(1, motion: linear1s)]);
      await tester.pump();

      controller.scrubTo(const Duration(milliseconds: 250));

      expect(controller.value(trackA), closeTo(0.25, error));
      expect(controller.value(trackB), closeTo(0.1, error));
      controller.stop(canceled: true);
    });

    testWidgets('scrubbing back while running keeps the run elapsed time',
        (tester) async {
      controller = TrackController(vsync: tester);
      controller.animate([trackA.to(1, motion: linear1s)]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      controller.scrubTo(const Duration(milliseconds: 200));
      expect(controller.lastElapsedDuration, const Duration(milliseconds: 500));

      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.lastElapsedDuration, const Duration(milliseconds: 600));
      expect(controller.value(trackA), closeTo(0.3, error));
      controller.stop(canceled: true);
    });

    testWidgets('changing timeDilation mid-run does not jump', (tester) async {
      controller = TrackController(vsync: tester);
      controller.animate([trackA.to(1, motion: linear1s)]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final before = controller.value(trackA);

      timeDilation = 2;
      try {
        // Flutter resets its time epoch here, so this frame advances nothing.
        await tester.pump(const Duration(milliseconds: 100));
        final afterReset = controller.value(trackA);
        expect(afterReset, inInclusiveRange(before, before + 0.05 + error));

        await tester.pump(const Duration(milliseconds: 100));
        expect(controller.value(trackA), closeTo(afterReset + 0.05, error));
      } finally {
        timeDilation = 1;
      }
      controller.stop(canceled: true);
    });

    testWidgets('changing playback speed mid-run does not jump',
        (tester) async {
      controller = TrackController(vsync: tester);
      controller.animate([trackA.to(1, motion: linear1s)]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      controller.playbackSpeed = 0.5;
      await tester.pump();
      expect(controller.value(trackA), closeTo(0.2, error));

      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.value(trackA), closeTo(0.25, error));
      controller.stop(canceled: true);
    });
  });

  group('TrackController history', () {
    const linear1s = Motion.linear(Duration(seconds: 1));
    final track = Track<double>(MotionConverter.single, initial: 0);

    Future<TrackController> redirected(WidgetTester tester) async {
      final controller = TrackController(vsync: tester)
        ..animate([track.to(1, motion: linear1s)]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      controller.animate([track.to(0, motion: linear1s)]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      return controller;
    }

    testWidgets('scrubbing back past a redirect shows the earlier plan',
        (tester) async {
      final subscription = MotorInspectionRegistry.attach(_Observer());
      final controller = await redirected(tester);
      expect(controller.value(track), closeTo(0.4, error));

      controller
        ..pause()
        ..scrubTo(const Duration(milliseconds: 300));
      expect(controller.value(track), closeTo(0.3, error));
      final shown = controller.inspectPlayback().tracks.single.steps.single;
      expect((shown as StepTo<Object>).value, 1);

      controller.scrubTo(const Duration(milliseconds: 600));
      expect(controller.value(track), closeTo(0.45, error));

      controller.stop(canceled: true);
      controller.dispose();
      subscription.dispose();
    });

    testWidgets('resuming before a redirect continues the earlier plan',
        (tester) async {
      final subscription = MotorInspectionRegistry.attach(_Observer());
      final controller = await redirected(tester);

      controller
        ..pause()
        ..scrubTo(const Duration(milliseconds: 300))
        ..resume();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(controller.value(track), closeTo(0.7, error));

      await tester.pump(const Duration(milliseconds: 300));
      expect(controller.value(track), closeTo(1, error));

      controller.stop(canceled: true);
      controller.dispose();
      subscription.dispose();
    });

    testWidgets('a restored plan leaves the sync barriers it replaced',
        (tester) async {
      final subscription = MotorInspectionRegistry.attach(_Observer());
      const linear100 = Motion.linear(Duration(milliseconds: 100));
      final other = Track<double>(MotionConverter.single, initial: 0);
      final controller = TrackController(vsync: tester)
        ..animate(
          [
            track([
              const TrackStep.to(1, motion: linear100),
              const TrackStep.to(0, motion: linear100),
            ]),
          ],
          loop: LoopMode.loop,
        )
        ..animate([
          other([
            const TrackStep.to(1, motion: linear1s),
            const TrackStep.sync(token: #meet),
            const TrackStep.to(0, motion: linear100),
          ]),
        ]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Redirect track into a plan that also meets at #meet, then scrub back
      // into its barrier-free loop and resume there.
      controller.animate([
        track([
          const TrackStep.to(1, motion: linear100),
          const TrackStep.sync(token: #meet),
          const TrackStep.to(0, motion: linear100),
        ]),
      ]);
      await tester.pump(const Duration(milliseconds: 100));
      controller
        ..pause()
        ..scrubTo(const Duration(milliseconds: 200))
        ..resume();
      await tester.pump();
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(controller.value(other), closeTo(0, error));
      controller.stop(canceled: true);
      controller.dispose();
      subscription.dispose();
    });

    testWidgets('forgets history once tooling detaches', (tester) async {
      final subscription = MotorInspectionRegistry.attach(_Observer());
      final controller = await redirected(tester);
      subscription.dispose();

      controller
        ..pause()
        ..scrubTo(const Duration(milliseconds: 300));
      // The current plan started at 500ms from 0.5; there is no earlier plan
      // to show anymore.
      expect(controller.value(track), closeTo(0.5, error));
      expect(controller.inspectPlayback().plans, isEmpty);

      controller.stop(canceled: true);
      controller.dispose();
    });

    testWidgets('keeps no history without inspection tooling', (tester) async {
      final controller = await redirected(tester);

      controller
        ..pause()
        ..scrubTo(const Duration(milliseconds: 300));
      expect(controller.value(track), closeTo(0.5, error));

      controller.stop(canceled: true);
      controller.dispose();
    });
  });
}

class _Observer implements MotorInspectionObserver {
  @override
  void didRegisterController(TrackController controller) {}

  @override
  void didUnregisterController(TrackController controller) {}
}
