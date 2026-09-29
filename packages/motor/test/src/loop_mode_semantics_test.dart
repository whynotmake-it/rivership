// ignore_for_file: cascade_invocations, unawaited_futures

import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:motor/src/simulations/step_playback.dart';

import 'util.dart';

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

    // (seconds, value, reason) samples of a 100ms linear ramp from 0 to 1.
    for (final (loop, samples, isDone) in [
      (
        LoopMode.none,
        [
          (0.05, 0.5, ''),
          (0.1, 1.0, 'reaches the target'),
          (0.5, 1.0, 'stays at the target, no looping back'),
        ],
        true,
      ),
      (
        LoopMode.loop,
        [
          (0.099, 0.99, ''),
          (0.12, 0.8, 'loop should animate back to the start, not jump'),
          (0.15, 0.5, ''),
          (0.2, 0.0, 'end of the return leg: back at the start'),
          (0.25, 0.5, '50ms into the second forward leg'),
          (0.3, 1.0, 'reached the target again'),
        ],
        false,
      ),
      (
        LoopMode.seamless,
        [
          (0.099, 0.99, ''),
          (0.12, 0.2, 'seamless should jump to the start, not animate back'),
        ],
        false,
      ),
      (
        LoopMode.pingPong,
        [
          (0.1, 1.0, 'forward leg 0 -> 1'),
          (0.15, 0.5, 'reverse leg 1 -> 0 over the next 100ms'),
          (0.2, 0.0, ''),
          (0.25, 0.5, 'forward again'),
        ],
        false,
      ),
    ]) {
      test('${loop.name} plays its legs in order', () {
        final p = playback(loop);
        for (final (seconds, value, reason) in samples) {
          p.advanceTo(seconds);
          expect(
            p.values.single,
            closeTo(value, error),
            reason: '${seconds}s $reason',
          );
          if (!isDone || seconds < 0.1) expect(p.isDone, isFalse);
        }
        expect(p.isDone, isDone);
      });
    }

    test('loop snaps to the start when no return motion is available', () {
      const motion = FreeMotion.friction();
      const start = 4.0;
      const velocity = 100.0;
      final simulation = motion.createSimulation(
        start: start,
        velocity: velocity,
      );
      var low = 0.0;
      var high = 100.0;
      for (var i = 0; i < 60; i++) {
        final middle = (low + high) / 2;
        if (simulation.isDone(middle)) {
          high = middle;
        } else {
          low = middle;
        }
      }

      final p = StepPlayback<double>(
        steps: const [StepFree(motion: motion)],
        converter: MotionConverter.single,
        start: start,
        velocity: velocity,
        loop: LoopMode.loop,
      );

      p.advanceTo(low);
      expect(p.values.single, isNot(closeTo(start, error)));

      // Settling times have microsecond resolution.
      p.advanceTo(high + 1e-6);
      expect(p.values.single, closeTo(start, error));
      expect(p.isDone, isFalse);
    });

    test('seeking far into a loop lands on the matching cycle position', () {
      // Cycles last 200ms: 100ms forward, then 100ms back.
      final loop = playback(LoopMode.loop)..advanceTo(1000.25);
      expect(loop.values.single, closeTo(0.5, error));

      final pingPong = playback(LoopMode.pingPong)..advanceTo(1000.15);
      expect(pingPong.values.single, closeTo(0.5, error));

      // Cycles last 100ms and jump back to the start.
      final seamless = playback(LoopMode.seamless)..advanceTo(1000.05);
      expect(seamless.values.single, closeTo(0.5, error));
    });

    test('seeking back after running a loop shows the earlier cycle', () {
      final p = playback(LoopMode.pingPong)
        ..advanceTo(5.15)
        ..advanceTo(0.05);
      expect(p.values.single, closeTo(0.5, error));

      p.advanceTo(0.1);
      expect(p.values.single, closeTo(1, error));
    });

    test('long-running loops keep a bounded number of segments', () {
      final folding = playback(LoopMode.pingPong);
      final withSync = StepPlayback<double>(
        steps: const [
          StepTo(1, motion: linear100),
          StepSync(token: #beat),
          StepTo(0, motion: linear100),
        ],
        converter: MotionConverter.single,
        start: 0,
        loop: LoopMode.loop,
      );

      for (var t = 0.0; t < 60; t += 1 / 60) {
        folding.advanceTo(t);
        withSync.advanceTo(t);
        if (withSync.pendingSyncToken != null) {
          withSync.releaseSync(atSeconds: withSync.pendingSyncArrivalSeconds);
        }
      }

      expect(folding.debugSegmentCount, lessThan(10));
      expect(withSync.debugSegmentCount, lessThan(10));
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Phase looping (PhaseTrackController).
  // ───────────────────────────────────────────────────────────────────────
  group('PhaseTrackController phase loop semantics', () {
    final size = Track<double>(MotionConverter.single, initial: 0);
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

    testWidgets('loop animates back to the first phase', (tester) async {
      controller = PhaseTrackController<String>(vsync: tester);
      controller.playPhases(timeline(LoopMode.loop));
      await tester.pump();

      // Over a full cycle plus a wrap, loop should never jump: it animates
      // b(2) gradually back to a(1), ~0.1 per 10ms frame, where a jump would
      // drop the whole distance in one frame.
      var previous = controller.value(size);
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 10));
        final current = controller.value(size);
        expect(
          previous - current,
          lessThan(0.2),
          reason: 'loop should animate back to the first phase, not jump',
        );
        previous = current;
      }
      expect(controller.isAnimating, isTrue);
      controller.stop(canceled: true);
    });

    testWidgets('pingPong alternates two phases without duplicates',
        (tester) async {
      controller = PhaseTrackController<String>(vsync: tester);
      final transitions = <String>[];

      controller.playPhases(
        timeline(LoopMode.pingPong),
        onTransition: (transition) {
          if (transition
              case PhaseTransitioning<String>(
                :final from,
                :final to,
              )) {
            transitions.add('$from->$to');
          }
        },
      );
      await tester.pump();

      // Each phase takes 100ms; run through five of them.
      for (var frame = 0; frame < 55; frame++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(
        transitions,
        ['a->b', 'b->a', 'a->b', 'b->a', 'a->b'],
      );
      expect(controller.isAnimating, isTrue);
      controller.stop(canceled: true);
    });
  });
}
