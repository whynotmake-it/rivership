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

    test('loop animates back to the start after the last step', () {
      final p = playback(LoopMode.loop);

      // Forward leg at 99ms of a 100ms linear ramp: exactly 0.99.
      p.advanceTo(0.099);
      expect(p.values.single, closeTo(0.99, error));

      // 20ms into the linear return leg (1 -> 0 over 100ms): exactly 0.8.
      // It must NOT have jumped back to 0.
      p.advanceTo(0.12);
      expect(
        p.values.single,
        closeTo(0.8, error),
        reason: 'loop should animate back to the start, not jump',
      );

      // Halfway through the return leg.
      p.advanceTo(0.15);
      expect(p.values.single, closeTo(0.5, error));

      // End of the return leg: back at the start.
      p.advanceTo(0.2);
      expect(p.values.single, closeTo(0, error));
      expect(p.isDone, isFalse);
    });

    test('seamless jumps back to the start after the last step', () {
      final p = playback(LoopMode.seamless);

      // Forward leg at 99ms: exactly 0.99.
      p.advanceTo(0.099);
      expect(p.values.single, closeTo(0.99, error));

      // Seamless jumped to 0 at 100ms and is animating forward again, so at
      // 120ms it is exactly 20ms (0.2) into the new forward leg, not unwinding.
      p.advanceTo(0.12);
      expect(
        p.values.single,
        closeTo(0.2, error),
        reason: 'seamless should jump to the start, not animate back',
      );
      expect(p.isDone, isFalse);
    });

    test('none plays once and stops at the target', () {
      final p = playback(LoopMode.none);

      p.advanceTo(0.05);
      expect(p.values.single, closeTo(0.5, error));
      expect(p.isDone, isFalse);

      // Reaches the target and stays there - no looping back.
      p.advanceTo(0.1);
      expect(p.values.single, closeTo(1, error));

      p.advanceTo(0.5);
      expect(p.values.single, closeTo(1, error));
      expect(p.isDone, isTrue);
    });

    test('pingPong alternates forward and reverse legs', () {
      final p = playback(LoopMode.pingPong);

      // Forward leg 0 -> 1.
      p.advanceTo(0.1);
      expect(p.values.single, closeTo(1, error));

      // Reverse leg 1 -> 0 over the next 100ms.
      p.advanceTo(0.15);
      expect(p.values.single, closeTo(0.5, error));
      p.advanceTo(0.2);
      expect(p.values.single, closeTo(0, error));

      // Forward again.
      p.advanceTo(0.25);
      expect(p.values.single, closeTo(0.5, error));
      expect(p.isDone, isFalse);
    });

    test('loop runs start -> end -> start -> end indefinitely', () {
      final p = playback(LoopMode.loop);

      // Cycle length is 200ms: 100ms forward + 100ms return.
      p.advanceTo(0.2); // back at start
      expect(p.values.single, closeTo(0, error));
      p.advanceTo(0.25); // 50ms into the second forward leg
      expect(p.values.single, closeTo(0.5, error));
      p.advanceTo(0.3); // reached the target again
      expect(p.values.single, closeTo(1, error));
      expect(p.isDone, isFalse);
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

    testWidgets('pingPong visits three phases in both directions',
        (tester) async {
      controller = PhaseTrackController<String>(vsync: tester);
      final transitions = <String>[];
      final pingPongTimeline = TrackPhaseTimeline(
        {
          'a': [size.to(1, motion: linear100)],
          'b': [size.to(2, motion: linear100)],
          'c': [size.to(3, motion: linear100)],
        },
        phaseLoop: LoopMode.pingPong,
      );

      controller.playPhases(
        pingPongTimeline,
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

      for (final target in [1.0, 2.0, 3.0, 2.0, 1.0, 2.0, 3.0]) {
        await tester.pump(const Duration(milliseconds: 101));
        expect(controller.value(size), closeTo(target, error));
      }

      expect(
        transitions,
        [
          'a->b',
          'b->c',
          'c->b',
          'b->a',
          'a->b',
          'b->c',
          'c->b',
        ],
      );
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

      for (final target in [1.0, 2.0, 1.0, 2.0, 1.0]) {
        await tester.pump(const Duration(milliseconds: 101));
        expect(controller.value(size), closeTo(target, error));
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
