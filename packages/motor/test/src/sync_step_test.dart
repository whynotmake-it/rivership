// ignore_for_file: cascade_invocations

import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:motor/src/simulations/step_playback.dart';

import 'util.dart';

void main() {
  // ─────────────────────────────────────────────────────────────────────────
  // A. StepPlayback with SyncStep (unit-level, no widgets)
  // ─────────────────────────────────────────────────────────────────────────

  group('StepPlayback SyncStep', () {
    const linear100 = Motion.linear(Duration(milliseconds: 100));

    test('A1: single sync step blocks playback', () {
      final playback = StepPlayback<double>(
        steps: [
          const StepTo(1.0, motion: linear100),
          const SyncStep(token: #phaseB),
          const StepTo(2.0, motion: linear100),
        ],
        converter: MotionConverter.single,
        start: 0.0,
      );

      // Advance past first step completion
      playback.advanceTo(0.2);
      expect(playback.isWaitingForSync, isTrue);
      expect(playback.syncToken, equals(#phaseB));
      expect(playback.isDone, isFalse);

      // Value should be at 1.0 (first step target)
      expect(playback.values.first, closeTo(1.0, error));
    });

    test('A2: releaseSync advances past barrier', () {
      final playback = StepPlayback<double>(
        steps: [
          const StepTo(1.0, motion: linear100),
          const SyncStep(token: #phaseB),
          const StepTo(2.0, motion: linear100),
        ],
        converter: MotionConverter.single,
        start: 0.0,
      );

      playback.advanceTo(0.2);
      expect(playback.isWaitingForSync, isTrue);

      playback.releaseSync();
      expect(playback.isWaitingForSync, isFalse);

      // Now advance a small amount — should be animating toward 2.0
      // First step completes at ~0.1s, sync at same time, so segment start
      // for third step is ~0.1s. At 0.15s, local time is ~0.05s = halfway.
      playback.advanceTo(0.15);
      expect(playback.values.first, greaterThan(1.0));
      expect(playback.values.first, lessThan(2.0));

      playback.advanceTo(0.5);
      expect(playback.values.first, closeTo(2.0, error));
      expect(playback.isDone, isTrue);
    });

    test('A3: multiple sync steps in sequence', () {
      final playback = StepPlayback<double>(
        steps: [
          const StepTo(1.0, motion: linear100),
          const SyncStep(token: #phaseB),
          const StepTo(2.0, motion: linear100),
          const SyncStep(token: #phaseC),
          const StepTo(3.0, motion: linear100),
        ],
        converter: MotionConverter.single,
        start: 0.0,
      );

      // Reach first sync
      playback.advanceTo(0.2);
      expect(playback.isWaitingForSync, isTrue);
      expect(playback.syncToken, equals(#phaseB));

      // Release first sync, reach second sync
      playback.releaseSync();
      playback.advanceTo(0.4);
      expect(playback.isWaitingForSync, isTrue);
      expect(playback.syncToken, equals(#phaseC));
      expect(playback.values.first, closeTo(2.0, error));

      // Release second sync, finish
      playback.releaseSync();
      playback.advanceTo(0.6);
      expect(playback.isDone, isTrue);
      expect(playback.values.first, closeTo(3.0, error));
    });

    test('A4: seekTo passes through sync steps freely', () {
      final playback = StepPlayback<double>(
        steps: [
          const StepTo(1.0, motion: linear100),
          const SyncStep(token: #phaseB),
          const StepTo(2.0, motion: linear100),
          const SyncStep(token: #phaseC),
          const StepTo(3.0, motion: linear100),
        ],
        converter: MotionConverter.single,
        start: 0.0,
      );

      // Seek far ahead — should pass through all sync barriers
      playback.seekTo(10.0);
      expect(playback.isWaitingForSync, isFalse);
      expect(playback.isDone, isTrue);
      expect(playback.values.first, closeTo(3.0, error));
    });

    test('A5: sync step preserves current values and zero velocity', () {
      final playback = StepPlayback<double>(
        steps: [
          const StepTo(1.0, motion: linear100),
          const SyncStep(token: #barrier),
          const StepTo(2.0, motion: linear100),
        ],
        converter: MotionConverter.single,
        start: 0.0,
      );

      playback.advanceTo(0.2);
      expect(playback.isWaitingForSync, isTrue);

      final valuesAtSync = playback.values.first;
      final velocityAtSync = playback.velocities.first;

      // Advance time while waiting — values must not change
      playback.advanceTo(1.0);
      expect(playback.isWaitingForSync, isTrue);
      expect(playback.values.first, equals(valuesAtSync));
      expect(playback.velocities.first, equals(velocityAtSync));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // B. TrackController sync coordination (widget tests)
  // ─────────────────────────────────────────────────────────────────────────

  group('TrackController sync coordination', () {
    const linear50 = Motion.linear(Duration(milliseconds: 50));
    const linear150 = Motion.linear(Duration(milliseconds: 150));
    const linear100 = Motion.linear(Duration(milliseconds: 100));

    late TrackController controller;
    final trackA = Track<double>(MotionConverter.single, origin: 0.0);
    final trackB = Track<double>(MotionConverter.single, origin: 0.0);

    tearDown(() {
      controller.dispose();
    });

    testWidgets('B6: two tracks with same-token sync release together',
        (tester) async {
      controller = TrackController(vsync: tester);

      controller.animate([
        trackA([
          const StepTo(1.0, motion: linear50),
          const SyncStep(token: #phaseB),
          const StepTo(2.0, motion: linear100),
        ]),
        trackB([
          const StepTo(1.0, motion: linear150),
          const SyncStep(token: #phaseB),
          const StepTo(2.0, motion: linear100),
        ]),
      ]);

      await tester.pump();

      // At 60ms: trackA done (50ms motion), waiting at sync. trackB animating.
      await tester.pump(const Duration(milliseconds: 60));
      expect(controller.value(trackA), closeTo(1.0, error));
      expect(controller.value(trackB), lessThan(1.0));
      expect(controller.isAnimating, isTrue);

      // At 160ms: trackB done (150ms motion). Both should now be released.
      await tester.pump(const Duration(milliseconds: 100));
      // One more tick for the released tracks to advance
      await tester.pump(const Duration(milliseconds: 20));
      expect(controller.value(trackA), greaterThan(1.0));
      expect(controller.value(trackB), greaterThan(1.0));

      await tester.pumpAndSettle();
      expect(controller.value(trackA), closeTo(2.0, error));
      expect(controller.value(trackB), closeTo(2.0, error));
    });

    testWidgets('B7: different tokens release independently', (tester) async {
      controller = TrackController(vsync: tester);

      // trackA has steps: to(1) -> sync(#x) -> to(2)
      // trackB has steps: to(1) -> sync(#y) -> to(2)
      // Since they have different tokens, each should release independently
      // when that track alone reaches its sync.
      controller.animate([
        trackA([
          const StepTo(1.0, motion: linear50),
          const SyncStep(token: #x),
          const StepTo(2.0, motion: linear100),
        ]),
        trackB([
          const StepTo(1.0, motion: linear150),
          const SyncStep(token: #y),
          const StepTo(2.0, motion: linear100),
        ]),
      ]);

      await tester.pump();

      // At 60ms: trackA reached sync(#x). trackB is still animating but
      // has no sync(#x), so trackA's barrier should release (all tracks
      // with token #x are ready).
      await tester.pump(const Duration(milliseconds: 60));
      // trackA should be released and animating past 1.0
      expect(controller.value(trackA), closeTo(1.0, 0.01));

      // One more tick for the release to take effect
      await tester.pump(const Duration(milliseconds: 10));
      expect(controller.value(trackA), greaterThan(1.0));

      // trackB still animating toward 1.0
      expect(controller.value(trackB), lessThan(1.0));

      controller.stop(canceled: true);
    });

    testWidgets('B8: large elapsed gap resolves sync barriers without collapse',
        (tester) async {
      controller = TrackController(vsync: tester);

      controller.animate([
        trackA([
          const StepTo(1.0, motion: linear50),
          const SyncStep(token: #phase2),
          const StepTo(2.0, motion: linear50),
        ]),
        trackB([
          const StepTo(1.0, motion: linear50),
          const SyncStep(token: #phase2),
          const StepTo(2.0, motion: linear50),
        ]),
      ]);

      await tester.pump();
      await tester.pumpAndSettle();

      // Both tracks should have completed all steps
      expect(controller.value(trackA), closeTo(2.0, error));
      expect(controller.value(trackB), closeTo(2.0, error));
      expect(controller.isAnimating, isFalse);
    });

    testWidgets('B9: stop and resume preserves sync state', (tester) async {
      controller = TrackController(vsync: tester);

      controller.animate([
        trackA([
          const StepTo(1.0, motion: linear50),
          const SyncStep(token: #barrier),
          const StepTo(2.0, motion: linear100),
        ]),
        trackB([
          const StepTo(1.0, motion: linear150),
          const SyncStep(token: #barrier),
          const StepTo(2.0, motion: linear100),
        ]),
      ]);

      await tester.pump();

      // At 60ms: trackA at sync, trackB still animating
      await tester.pump(const Duration(milliseconds: 60));
      expect(controller.value(trackA), closeTo(1.0, error));

      // Stop the controller
      controller.stop(canceled: true);
      expect(controller.isAnimating, isFalse);

      // Replay the same timeline
      controller.animate([
        trackA([
          const StepTo(1.0, motion: linear50),
          const SyncStep(token: #barrier),
          const StepTo(2.0, motion: linear100),
        ]),
        trackB([
          const StepTo(1.0, motion: linear50),
          const SyncStep(token: #barrier),
          const StepTo(2.0, motion: linear100),
        ]),
      ]);

      await tester.pump();
      await tester.pumpAndSettle();

      // Both should reach final values
      expect(controller.value(trackA), closeTo(2.0, error));
      expect(controller.value(trackB), closeTo(2.0, error));
    });

    testWidgets('B10: track not part of sync group does not block release',
        (tester) async {
      controller = TrackController(vsync: tester);
      final trackC = Track<double>(MotionConverter.single, origin: 0.0);

      // trackA and trackB sync on #barrier, trackC has no sync and runs
      // independently with a longer animation
      controller.animate([
        trackA([
          const StepTo(1.0, motion: linear50),
          const SyncStep(token: #barrier),
          const StepTo(2.0, motion: linear50),
        ]),
        trackB([
          const StepTo(1.0, motion: linear50),
          const SyncStep(token: #barrier),
          const StepTo(2.0, motion: linear50),
        ]),
        trackC([
          const StepTo(5.0, motion: linear150),
        ]),
      ]);

      await tester.pump();

      // After 60ms: A and B done with first step, both at sync.
      // C is still animating (150ms total). But C doesn't have token #barrier
      // so A and B should release.
      await tester.pump(const Duration(milliseconds: 60));

      // One more tick for release to propagate
      await tester.pump(const Duration(milliseconds: 10));

      expect(controller.value(trackA), greaterThan(1.0));
      expect(controller.value(trackB), greaterThan(1.0));
      // trackC is just animating independently
      expect(controller.value(trackC), greaterThan(0.0));
      expect(controller.value(trackC), lessThan(5.0));

      controller.stop(canceled: true);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // C. TrackPhaseTimeline + PhaseTrackController integration
  // ─────────────────────────────────────────────────────────────────────────

  group('PhaseTrackController integration', () {
    const linear100 = Motion.linear(Duration(milliseconds: 100));

    late PhaseTrackController<String> controller;
    final size = Track<double>(MotionConverter.single, origin: 0.0);
    final opacity = Track<double>(MotionConverter.single, origin: 0.0);

    tearDown(() {
      controller.dispose();
    });

    testWidgets('C11: playPhases advances through all phases in order',
        (tester) async {
      controller = PhaseTrackController<String>(vsync: tester);

      final phasesVisited = <String>[];
      void recordTransition(PhaseTransition<String> transition) {
        if (transition is PhaseTransitioning<String>) {
          if (phasesVisited.isEmpty) phasesVisited.add(transition.from);
          phasesVisited.add(transition.to);
        }
      }

      controller.playPhases(
        TrackPhaseTimeline({
          'idle': [size.to(1.0, motion: linear100)],
          'active': [size.to(2.0, motion: linear100)],
          'done': [size.to(3.0, motion: linear100)],
        }),
        onTransition: recordTransition,
      );

      await tester.pump();

      // Playback starts at the first phase immediately
      expect(controller.currentPhase, equals('idle'));

      // Let first phase settle, second should begin
      await tester.pumpAndSettle();

      expect(phasesVisited, containsAllInOrder(['idle', 'active', 'done']));
      expect(controller.value(size), closeTo(3.0, error));
    });

    testWidgets("C12: goToPhase plays only that phase's animations",
        (tester) async {
      controller = PhaseTrackController<String>(vsync: tester);

      final timeline = TrackPhaseTimeline({
        'small': [size.to(1.0, motion: linear100)],
        'medium': [size.to(2.0, motion: linear100)],
        'large': [size.to(3.0, motion: linear100)],
      });

      controller.setTimeline(timeline);
      controller.goToPhase('large');

      await tester.pump();
      await tester.pumpAndSettle();

      // Should animate directly to 'large' value without going through others
      expect(controller.value(size), closeTo(3.0, error));
      expect(controller.currentPhase, equals('large'));
    });

    testWidgets('C13: looping restarts from first phase after last completes',
        (tester) async {
      controller = PhaseTrackController<String>(vsync: tester);

      final phasesVisited = <String>[];
      void recordTransition(PhaseTransition<String> transition) {
        if (transition is PhaseTransitioning<String>) {
          if (phasesVisited.isEmpty) phasesVisited.add(transition.from);
          phasesVisited.add(transition.to);
        }
      }

      controller.playPhases(
        TrackPhaseTimeline(
          {
            'a': [size.to(1.0, motion: linear100)],
            'b': [size.to(2.0, motion: linear100)],
          },
          phaseLoop: LoopMode.loop,
        ),
        onTransition: recordTransition,
      );

      await tester.pump();

      // Pump enough for first full cycle (a: 100ms + b: 100ms) + start of 2nd
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      // Should have looped: a -> b -> a (restart)
      expect(phasesVisited.length, greaterThanOrEqualTo(3));
      expect(phasesVisited[0], equals('a'));
      expect(phasesVisited[1], equals('b'));
      expect(phasesVisited[2], equals('a'));

      controller.stop(canceled: true);
    });

    testWidgets('C14: goToPhase interrupts autoplay cleanly', (tester) async {
      controller = PhaseTrackController<String>(vsync: tester);

      controller.playPhases(
        TrackPhaseTimeline({
          'idle': [size.to(1.0, motion: linear100)],
          'active': [size.to(2.0, motion: linear100)],
          'done': [size.to(3.0, motion: linear100)],
        }),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Interrupt mid-playback
      controller.goToPhase('done');

      await tester.pump();
      await tester.pumpAndSettle();

      expect(controller.value(size), closeTo(3.0, error));
      expect(controller.currentPhase, equals('done'));
    });

    testWidgets('C15: single-phase timeline plays without sync steps',
        (tester) async {
      controller = PhaseTrackController<String>(vsync: tester);

      controller.playPhases(
        TrackPhaseTimeline({
          'only': [
            size.to(5.0, motion: linear100),
            opacity.to(1.0, motion: linear100),
          ],
        }),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      expect(controller.value(size), closeTo(5.0, error));
      expect(controller.value(opacity), closeTo(1.0, error));
      expect(controller.isAnimating, isFalse);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // D. Edge cases
  // ─────────────────────────────────────────────────────────────────────────

  group('Edge cases', () {
    const linear100 = Motion.linear(Duration(milliseconds: 100));
    const linear200 = Motion.linear(Duration(milliseconds: 200));

    late PhaseTrackController<String> controller;
    final trackA = Track<double>(MotionConverter.single, origin: 0.0);
    final trackB = Track<double>(MotionConverter.single, origin: 0.0);

    tearDown(() {
      controller.dispose();
    });

    testWidgets('D16: track present in only some phases participates in sync',
        (tester) async {
      controller = PhaseTrackController<String>(vsync: tester);

      // trackA in both phases, trackB only in 'phase1'
      controller.playPhases(
        TrackPhaseTimeline({
          'phase1': [
            trackA.to(1.0, motion: linear100),
            trackB.to(1.0, motion: linear200),
          ],
          'phase2': [
            trackA.to(2.0, motion: linear100),
          ],
        }),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      // Both phases should complete. trackA should be at phase2 target.
      expect(controller.value(trackA), closeTo(2.0, error));
      // trackB animated to 1.0 in phase1 and stayed (no step in phase2)
      expect(controller.value(trackB), closeTo(1.0, error));
    });

    testWidgets('D17: rapid playPhases calls only play the latest',
        (tester) async {
      controller = PhaseTrackController<String>(vsync: tester);

      final timeline1 = TrackPhaseTimeline({
        'a': [trackA.to(1.0, motion: linear100)],
        'b': [trackA.to(2.0, motion: linear100)],
      });
      final timeline2 = TrackPhaseTimeline({
        'x': [trackA.to(10.0, motion: linear100)],
        'y': [trackA.to(20.0, motion: linear100)],
      });

      controller.playPhases(timeline1);
      controller.playPhases(timeline2);

      await tester.pump();
      await tester.pumpAndSettle();

      // Only timeline2 should have played through
      expect(controller.value(trackA), closeTo(20.0, error));
    });

    testWidgets('D18: disposing controller during sync does not crash',
        (tester) async {
      controller = PhaseTrackController<String>(vsync: tester);

      controller.playPhases(
        TrackPhaseTimeline({
          'a': [trackA.to(1.0, motion: linear100)],
          'b': [trackA.to(2.0, motion: linear100)],
        }),
      );

      await tester.pump();
      // Let trackA reach the sync barrier
      await tester.pump(const Duration(milliseconds: 110));

      // Dispose while potentially waiting for sync — should not throw
      controller.dispose();

      // Create a fresh controller so tearDown doesn't double-dispose
      controller = PhaseTrackController<String>(vsync: tester);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // E. Type safety regression: non-double tracks with playPhases
  // ─────────────────────────────────────────────────────────────────────────

  group('PhaseTrackController type safety with Track<Offset>', () {
    const linear100 = Motion.linear(Duration(milliseconds: 100));

    final offset = Track<Offset>(
      MotionConverter.offset,
      origin: Offset.zero,
      motion: linear100,
    );

    late PhaseTrackController<String> controller;

    tearDown(() {
      controller.dispose();
    });

    testWidgets(
      'E1: playPhases with Track<Offset> after reading value does not throw',
      (tester) async {
        controller = PhaseTrackController<String>(vsync: tester);

        // Pre-create the slot with concrete type by reading the value.
        // controller.value(track) calls _slot<T>(Track<T>) with T=Offset,
        // creating a _TrackSlot<Offset>.
        final initial = controller.value(offset);
        expect(initial, Offset.zero);

        // This should not throw "List<Step<Object>> is not a subtype of
        // List<Step<Offset>>"
        controller.playPhases(
          TrackPhaseTimeline({
            'phase1': [offset.to(const Offset(50, 50), motion: linear100)],
            'phase2': [offset.to(const Offset(100, 100), motion: linear100)],
          }),
          onTransition: (_) {},
        );

        await tester.pump();
        await tester.pumpAndSettle();

        expect(
          controller.value(offset),
          const Offset(100, 100),
        );
      },
    );

    testWidgets(
      'E2: playPhases with Track<Offset> without prior set() completes',
      (tester) async {
        controller = PhaseTrackController<String>(vsync: tester);

        controller.playPhases(
          TrackPhaseTimeline({
            'phase1': [offset.to(const Offset(50, 50), motion: linear100)],
            'phase2': [offset.to(const Offset(100, 100), motion: linear100)],
          }),
          onTransition: (_) {},
        );

        await tester.pump();
        await tester.pumpAndSettle();

        expect(
          controller.value(offset),
          const Offset(100, 100),
        );
      },
    );

    testWidgets(
      'E3: playPhases after set() with Track<Offset> does not throw',
      (tester) async {
        controller = PhaseTrackController<String>(vsync: tester);

        // Mimic drag gesture: read value then set with new position.
        // This is what card_stack.dart does in _onPanUpdate.
        final current = controller.value(offset);
        controller.set([offset.value(current + const Offset(10, 20))]);

        controller.playPhases(
          TrackPhaseTimeline({
            'phase1': [offset.to(const Offset(50, 50), motion: linear100)],
            'phase2': [offset.to(const Offset(100, 100), motion: linear100)],
          }),
          onTransition: (_) {},
        );

        await tester.pump();
        await tester.pumpAndSettle();

        expect(
          controller.value(offset),
          const Offset(100, 100),
        );
      },
    );

    testWidgets(
      'E4: playPhases with multiple typed tracks after reading does not throw',
      (tester) async {
        controller = PhaseTrackController<String>(vsync: tester);
        final scale = Track<double>(
          MotionConverter.single,
          origin: 1.0,
          motion: linear100,
        );

        // Pre-create both slots with concrete types via value read
        controller.value(offset);
        controller.value(scale);

        controller.playPhases(
          TrackPhaseTimeline({
            'grow': [
              offset.to(const Offset(20, 20), motion: linear100),
              scale.to(2.0, motion: linear100),
            ],
            'shrink': [
              offset.to(Offset.zero, motion: linear100),
              scale.to(1.0, motion: linear100),
            ],
          }),
          onTransition: (_) {},
        );

        await tester.pump();
        await tester.pumpAndSettle();

        expect(controller.value(offset), Offset.zero);
        expect(controller.value(scale), closeTo(1.0, error));
      },
    );
  });
}
