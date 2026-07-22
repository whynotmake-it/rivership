// ignore_for_file: cascade_invocations, unawaited_futures

import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
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
    playback.seekTo(t.inMicroseconds / Duration.microsecondsPerSecond);
    return playback.values.single;
  }

  group('TrackController scrubTo / resume / resync', () {
    late TrackController controller;
    final trackA = Track<double>(MotionConverter.single, initial: 0);
    final trackB = Track<double>(MotionConverter.single, initial: 0);

    tearDown(() {
      controller.dispose();
    });

    testWidgets('scrubTo matches seekTo-derived values on active tracks',
        (tester) async {
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
      // afterwards does not evaluate the old timeline (plan 001 assumed it
      // would match seekTo); values stay frozen where the stop landed.
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

    testWidgets('scrubbing past a barrier releases waiting peers',
        (tester) async {
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
      controller.scrubTo(const Duration(milliseconds: 100));
      expect(controller.value(trackA), greaterThan(1));
      expect(controller.value(trackB), lessThan(1));

      controller.resume();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 20));

      expect(controller.value(trackA), greaterThan(1));
      expect(controller.value(trackB), greaterThan(1));
      controller.stop(canceled: true);
    });

    testWidgets('scrub to end completes cleanly', (tester) async {
      controller = TrackController(vsync: tester);
      controller.animate([trackA(stepsA)]);
      await tester.pump();
      controller.pause();

      controller.scrubTo(const Duration(seconds: 2));

      expect(controller.status, AnimationStatus.completed);
      expect(controller.isAnimating, isFalse);
      expect(controller.value(trackA), closeTo(0, error));

      controller.animate([trackA.to(1, motion: linear100)]);
      await tester.pump();
      await tester.pumpAndSettle();
      expect(controller.value(trackA), closeTo(1, error));
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
}
