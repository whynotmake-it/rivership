// ignore_for_file: cascade_invocations, unawaited_futures

import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:motor/src/simulations/step_playback.dart';

/// These tests pin down the agreed LoopMode semantics, matching the legacy
/// sequence controllers:
///
/// - [LoopMode.loop]: animates back to the start after the last step/phase.
/// - [LoopMode.seamless]: jumps back to the start and animates immediately
///   again (assumes the first and last step/phase are identical, so the jump
///   is invisible in well-formed timelines).
void main() {
  const linear100 = Motion.linear(Duration(milliseconds: 100));

  // ───────────────────────────────────────────────────────────────────────
  // Looping timelines (single value via StepPlayback).
  // ───────────────────────────────────────────────────────────────────────
  group('StepPlayback loop semantics', () {
    StepPlayback<double> playback(LoopMode loop) => StepPlayback<double>(
          steps: const [StepTo(1, motion: linear100)],
          converter: MotionConverter.single,
          start: 0,
          loop: loop,
        );

    test('loop animates back to the start after the last step', () {
      final p = playback(LoopMode.loop);

      // Forward leg almost done: value near the last step's target (1.0).
      p.advanceTo(0.099);
      expect(p.values.single, closeTo(1, 0.05));

      // Shortly after the last step, loop is unwinding 1 -> 0, so the value is
      // still high. It must NOT have jumped back to 0.
      p.advanceTo(0.12);
      expect(
        p.values.single,
        greaterThan(0.5),
        reason: 'loop should animate back to the start, not jump',
      );

      // Halfway through the return leg.
      p.advanceTo(0.15);
      expect(p.values.single, closeTo(0.5, 0.05));

      // End of the return leg: back at the start.
      p.advanceTo(0.2);
      expect(p.values.single, closeTo(0, 0.05));
      expect(p.isDone, isFalse);
    });

    test('seamless jumps back to the start after the last step', () {
      final p = playback(LoopMode.seamless);

      // Forward leg almost done: value near the last step's target (1.0).
      p.advanceTo(0.099);
      expect(p.values.single, closeTo(1, 0.05));

      // Shortly after the last step, seamless has already jumped to 0 and is
      // animating forward again, so the value is low.
      p.advanceTo(0.12);
      expect(
        p.values.single,
        lessThan(0.5),
        reason: 'seamless should jump to the start, not animate back',
      );
      expect(p.values.single, closeTo(0.2, 0.05));
      expect(p.isDone, isFalse);
    });

    test('loop runs start -> end -> start -> end indefinitely', () {
      final p = playback(LoopMode.loop);

      // Cycle length is 200ms: 100ms forward + 100ms return.
      p.advanceTo(0.2); // back at start
      expect(p.values.single, closeTo(0, 0.05));
      p.advanceTo(0.25); // 50ms into the second forward leg
      expect(p.values.single, closeTo(0.5, 0.05));
      p.advanceTo(0.3); // reached the target again
      expect(p.values.single, closeTo(1, 0.05));
      expect(p.isDone, isFalse);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Phase looping (PhaseTrackController).
  // ───────────────────────────────────────────────────────────────────────
  group('PhaseTrackController phase loop semantics', () {
    final size = Track<double>(MotionConverter.single, origin: 0);
    late PhaseTrackController<String> controller;

    tearDown(() => controller.dispose());

    TrackPhaseTimeline<String> timeline(LoopMode phaseLoop) =>
        TrackPhaseTimeline(
          {
            'a': [size.to(1, motion: linear100)],
            'b': [size.to(2, motion: linear100)],
          },
          phaseLoop: phaseLoop,
        );

    // Samples the track value every 10ms and returns the largest single-frame
    // drop. An animated return (loop) only ever moves ~0.1 per 10ms frame,
    // whereas a jump (seamless) drops the whole 2 -> 1 distance in one frame.
    Future<double> maxSingleFrameDrop(WidgetTester tester) async {
      var previous = controller.value(size);
      var maxDrop = 0.0;
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 10));
        final current = controller.value(size);
        maxDrop = (previous - current) > maxDrop ? previous - current : maxDrop;
        previous = current;
      }
      return maxDrop;
    }

    testWidgets('loop animates back to the first phase', (tester) async {
      controller = PhaseTrackController<String>(vsync: tester);
      controller.playPhases(timeline(LoopMode.loop));
      await tester.pump();

      // Over a full cycle plus a wrap, loop should never jump: it animates
      // b(2) gradually back to a(1).
      final drop = await maxSingleFrameDrop(tester);
      expect(
        drop,
        lessThan(0.2),
        reason: 'loop should animate back to the first phase, not jump',
      );
      expect(controller.isAnimating, isTrue);
      controller.stop(canceled: true);
    });

    testWidgets('seamless jumps back to the first phase', (tester) async {
      controller = PhaseTrackController<String>(vsync: tester);
      controller.playPhases(timeline(LoopMode.seamless));
      await tester.pump();

      // Over a full cycle plus a wrap, seamless should jump straight from
      // b(2) back to a(1) in a single frame.
      final drop = await maxSingleFrameDrop(tester);
      expect(
        drop,
        greaterThan(0.5),
        reason: 'seamless should jump back to the first phase',
      );
      expect(controller.isAnimating, isTrue);
      controller.stop(canceled: true);
    });
  });
}
