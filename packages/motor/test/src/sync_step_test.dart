// ignore_for_file: cascade_invocations, unawaited_futures

import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:motor/src/simulations/step_playback.dart';

import 'util.dart';

// Several tests below pin the autoplay jump regression: a track that waits at
// a sync barrier must start its next step fresh on release. Counting the wait
// against the next step made it complete instantly, a visible jump.
void main() {
  // ─────────────────────────────────────────────────────────────────────────
  // StepPlayback with StepSync (unit-level, no widgets)
  // ─────────────────────────────────────────────────────────────────────────

  group('StepPlayback with StepSync', () {
    const linear100 = Motion.linear(Duration(milliseconds: 100));

    test('holds at a barrier until released, then starts the next step fresh',
        () {
      final playback = StepPlayback<double>(
        steps: [
          const StepTo(1.0, motion: linear100),
          const StepSync(token: #phaseB),
          const StepTo(2.0, motion: linear100),
        ],
        converter: MotionConverter.single,
        start: 0.0,
      );

      playback.advanceTo(0.12);
      expect(playback.isWaitingForSync, isTrue);
      expect(playback.syncToken, equals(#phaseB));
      expect(playback.isDone, isFalse);
      expect(playback.values.first, closeTo(1.0, error));

      final valueAtSync = playback.values.first;
      final velocityAtSync = playback.velocities.first;
      for (final seconds in [0.2, 0.3, 0.4]) {
        playback.advanceTo(seconds);
        expect(playback.isWaitingForSync, isTrue, reason: '${seconds}s');
        expect(
          playback.values.first,
          equals(valueAtSync),
          reason: '${seconds}s',
        );
        expect(
          playback.velocities.first,
          equals(velocityAtSync),
          reason: '${seconds}s',
        );
      }

      playback.releaseSync(atSeconds: playback.lastElapsedSeconds);
      expect(playback.isWaitingForSync, isFalse);

      playback.advanceTo(0.41);
      expect(
        playback.values.first,
        closeTo(1.1, error),
        reason: 'After sync release, the next animation should start fresh — '
            'not jump ahead by the time spent waiting at the barrier.',
      );
      playback.advanceTo(0.45);
      expect(playback.values.first, closeTo(1.5, error));

      // Seeking back over the released barrier shows the recorded release.
      playback.advanceTo(0.35);
      expect(playback.values.first, closeTo(1.0, error));
      expect(playback.isWaitingForSync, isFalse);
      playback.advanceTo(0.05);
      expect(playback.values.first, closeTo(0.5, error));

      playback.advanceTo(0.6);
      expect(playback.values.first, closeTo(2.0, error));
      expect(playback.isDone, isTrue);
    });

    test('waits at each unreleased barrier, even when jumping far ahead', () {
      final playback = StepPlayback<double>(
        steps: [
          const StepTo(1.0, motion: linear100),
          const StepSync(token: #phaseB),
          const StepTo(2.0, motion: linear100),
          const StepSync(token: #phaseC),
          const StepTo(3.0, motion: linear100),
        ],
        converter: MotionConverter.single,
        start: 0.0,
      );

      playback.advanceTo(10.0);
      expect(playback.isWaitingForSync, isTrue);
      expect(playback.syncToken, equals(#phaseB));
      expect(playback.isDone, isFalse);
      expect(playback.values.first, closeTo(1.0, error));

      playback.releaseSync(atSeconds: playback.lastElapsedSeconds);
      playback.advanceTo(10.2);
      expect(playback.isWaitingForSync, isTrue);
      expect(playback.syncToken, equals(#phaseC));
      expect(playback.values.first, closeTo(2.0, error));

      playback.releaseSync(atSeconds: playback.lastElapsedSeconds);
      playback.advanceTo(10.4);
      expect(playback.isDone, isTrue);
      expect(playback.values.first, closeTo(3.0, error));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // TrackController sync coordination (widget tests)
  // ─────────────────────────────────────────────────────────────────────────

  group('TrackController sync coordination', () {
    const linear50 = Motion.linear(Duration(milliseconds: 50));
    const linear150 = Motion.linear(Duration(milliseconds: 150));
    const linear100 = Motion.linear(Duration(milliseconds: 100));

    late TrackController controller;
    final trackA = Track<double>(MotionConverter.single, initial: 0.0);
    final trackB = Track<double>(MotionConverter.single, initial: 0.0);
    final trackC = Track<double>(MotionConverter.single, initial: 0.0);

    tearDown(() {
      controller.dispose();
    });

    testWidgets(
        'holds every participant until the slowest arrives, then starts '
        'their next steps fresh', (tester) async {
      controller = TrackController(vsync: tester);
      List<TrackStep<double>> steps(int firstMs) => [
            StepTo(
              1.0,
              motion: Motion.linear(Duration(milliseconds: firstMs)),
            ),
            const StepSync(token: #meet),
            const StepTo(2.0, motion: linear100),
          ];

      controller.animate([
        trackA(steps(100)),
        trackB(steps(250)),
        trackC(steps(400)),
      ]);
      await tester.pump();

      await tester.pump(const Duration(milliseconds: 120));
      expect(controller.value(trackA), closeTo(1.0, error));
      expect(controller.value(trackB), lessThan(1.0));
      expect(controller.value(trackC), lessThan(1.0));
      expect(controller.isAnimating, isTrue);

      await tester.pump(const Duration(milliseconds: 140));
      expect(controller.value(trackA), closeTo(1.0, error));
      expect(controller.value(trackB), closeTo(1.0, error));
      expect(controller.value(trackC), lessThan(1.0));

      // Released at 400ms, 20ms into every 100ms last step. trackA waited
      // 300ms, three times its next step's duration.
      await tester.pump(const Duration(milliseconds: 160));
      for (final track in [trackA, trackB, trackC]) {
        expect(
          controller.value(track),
          closeTo(1.2, error),
          reason: 'the time spent waiting at the barrier must not count '
              'against the next step',
        );
      }

      await tester.pumpAndSettle();
      expect(controller.value(trackA), closeTo(2.0, error));
      expect(controller.value(trackB), closeTo(2.0, error));
      expect(controller.value(trackC), closeTo(2.0, error));
      expect(controller.isAnimating, isFalse);
    });

    testWidgets('a barrier only waits for tracks that share its token',
        (tester) async {
      controller = TrackController(vsync: tester);
      final other = Track<double>(MotionConverter.single, initial: 0.0);
      final unsynced = Track<double>(MotionConverter.single, initial: 0.0);

      controller.animate([
        trackA([
          const StepTo(1.0, motion: linear50),
          const StepSync(token: #solo),
          const StepTo(2.0, motion: linear100),
        ]),
        trackB([
          const StepTo(1.0, motion: linear50),
          const StepSync(token: #pair),
          const StepTo(2.0, motion: linear100),
        ]),
        trackC([
          const StepTo(1.0, motion: linear50),
          const StepSync(token: #pair),
          const StepTo(2.0, motion: linear100),
        ]),
        other([
          const StepTo(1.0, motion: linear150),
          const StepSync(token: #other),
          const StepTo(2.0, motion: linear100),
        ]),
        unsynced([const StepTo(5.0, motion: linear150)]),
      ]);
      await tester.pump();

      // Every barrier at 50ms is complete on arrival, so those tracks are
      // 10ms into their last step at 60ms.
      await tester.pump(const Duration(milliseconds: 60));
      expect(controller.value(trackA), closeTo(1.1, error));
      expect(controller.value(trackB), closeTo(1.1, error));
      expect(controller.value(trackC), closeTo(1.1, error));
      expect(controller.value(other), closeTo(0.4, error));
      expect(controller.value(unsynced), closeTo(2.0, error));

      controller.stop(canceled: true);
    });

    testWidgets('a faster track in a loop waits for a slower one each cycle',
        (tester) async {
      controller = TrackController(vsync: tester);
      controller.animate(
        [
          trackA([
            const StepTo(1.0, motion: linear100),
            const StepSync(token: #beat),
            const StepTo(0.0, motion: linear100),
          ]),
          trackB([
            const StepTo(
              1.0,
              motion: Motion.linear(Duration(milliseconds: 300)),
            ),
            const StepSync(token: #beat),
            const StepTo(
              0.0,
              motion: Motion.linear(Duration(milliseconds: 500)),
            ),
          ]),
        ],
        loop: LoopMode.seamless,
      );
      await tester.pump();

      // Both meet at 300ms. trackA's next cycle reaches the barrier at 500ms
      // and has to wait for trackB, which gets there at 1100ms.
      await tester.pump(const Duration(milliseconds: 600));
      for (final ms in [600, 800, 1000]) {
        expect(
          controller.value(trackA),
          closeTo(1.0, error),
          reason: '${ms}ms',
        );
        await tester.pump(const Duration(milliseconds: 200));
      }
      // Now at 1200ms: released at 1100ms, 100ms into the next steps.
      expect(controller.value(trackA), closeTo(0.0, error));
      expect(controller.value(trackB), closeTo(0.8, error));
      controller.stop(canceled: true);
    });

    testWidgets('one large frame gap matches many small frames',
        (tester) async {
      List<TrackAnimation> plan() => [
            trackA([
              const StepTo(1.0, motion: linear50),
              const StepSync(token: #meet),
              const StepTo(2.0, motion: linear100),
              const StepSync(token: #again),
              const StepTo(3.0, motion: linear100),
            ]),
            trackB([
              const StepTo(1.0, motion: linear150),
              const StepSync(token: #meet),
              const StepTo(2.0, motion: linear50),
              const StepSync(token: #again),
              const StepTo(3.0, motion: linear100),
            ]),
          ];

      controller = TrackController(vsync: tester);
      controller.animate(plan());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final largeGap = [controller.value(trackA), controller.value(trackB)];
      controller
        ..stop(canceled: true)
        ..dispose();

      controller = TrackController(vsync: tester);
      controller.animate(plan());
      await tester.pump();
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      final smallFrames = [controller.value(trackA), controller.value(trackB)];

      // Both barriers release at 150ms and 250ms: 50ms into the last step.
      expect(largeGap[0], closeTo(2.5, error));
      expect(largeGap[1], closeTo(2.5, error));
      expect(smallFrames[0], closeTo(largeGap[0], error));
      expect(smallFrames[1], closeTo(largeGap[1], error));
      controller.stop(canceled: true);
    });

    testWidgets('stopping all tracks clears sync state for later animations',
        (tester) async {
      controller = TrackController(vsync: tester);

      controller.animate([
        trackA([
          const StepTo(1, motion: linear50),
          const StepSync(token: #barrier),
          const StepTo(2, motion: linear100),
        ]),
        trackB([
          const StepTo(1, motion: linear150),
          const StepSync(token: #barrier),
          const StepTo(2, motion: linear100),
        ]),
      ]);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(controller.value(trackA), closeTo(1, error));

      controller.stop(canceled: true);
      expect(controller.isAnimating, isFalse);

      // Reuses the old token, then a fresh one.
      List<TrackStep<double>> replay() => const [
            StepTo(3, motion: linear50),
            StepSync(token: #barrier),
            StepTo(4, motion: linear50),
            StepSync(token: #fresh),
            StepTo(5, motion: linear50),
          ];
      controller.animate([trackA(replay()), trackB(replay())]);

      await tester.pump();
      await tester.pumpAndSettle();
      expect(controller.value(trackA), closeTo(5, error));
      expect(controller.value(trackB), closeTo(5, error));
      expect(controller.isAnimating, isFalse);
    });

    final springTrack = Track<double>(
      MotionConverter.single,
      initial: 0.0,
      motion: const CupertinoMotion.smooth(),
    );
    for (final (name, stopped, stoppedMotion, canceled) in [
      ('canceled', trackC, linear150, true),
      ('gracefully stopped spring', springTrack, null, false),
    ]) {
      testWidgets('stops waiting for a $name participant, not for active ones',
          (tester) async {
        controller = TrackController(vsync: tester);

        controller.animate([
          stopped([
            StepTo(1, motion: stoppedMotion),
            const StepSync(token: #barrier),
            StepTo(2, motion: stoppedMotion),
          ]),
          trackA([
            const StepTo(1, motion: linear50),
            const StepSync(token: #barrier),
            const StepTo(2, motion: linear100),
          ]),
          trackB([
            const StepTo(1, motion: linear150),
            const StepSync(token: #barrier),
            const StepTo(2, motion: linear100),
          ]),
        ]);

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 30));
        controller.stop(tracks: [stopped], canceled: canceled);

        await tester.pump(const Duration(milliseconds: 40));
        expect(controller.value(trackA), closeTo(1, error));
        expect(controller.value(trackB), lessThan(1));

        await tester.pump(const Duration(milliseconds: 50));
        expect(controller.value(trackA), closeTo(1, error));
        expect(controller.value(trackB), lessThan(1));

        await tester.pump(const Duration(milliseconds: 40));
        await tester.pump(const Duration(milliseconds: 20));
        expect(controller.value(trackA), greaterThan(1));
        expect(controller.value(trackB), greaterThan(1));

        controller.stop(canceled: true);
      });
    }

    testWidgets('stopping the last missing participant releases waiters',
        (tester) async {
      controller = TrackController(vsync: tester);

      controller.animate([
        trackA([
          const StepTo(1, motion: linear50),
          const StepSync(token: #barrier),
          const StepTo(2, motion: linear100),
        ]),
        trackB([
          const StepTo(1, motion: linear50),
          const StepSync(token: #barrier),
          const StepTo(2, motion: linear100),
        ]),
        trackC([
          const StepTo(1, motion: linear150),
          const StepSync(token: #barrier),
          const StepTo(2, motion: linear100),
        ]),
      ]);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(controller.value(trackA), closeTo(1, error));
      expect(controller.value(trackB), closeTo(1, error));
      expect(controller.value(trackC), lessThan(1));

      controller.stop(tracks: [trackC], canceled: true);
      await tester.pump(const Duration(milliseconds: 10));

      expect(controller.value(trackA), greaterThan(1));
      expect(controller.value(trackB), greaterThan(1));

      controller.stop(canceled: true);
    });

    testWidgets('does not deadlock when a waiting participant is redirected',
        (tester) async {
      controller = TrackController(vsync: tester);

      controller.animate([
        trackA([
          const StepTo(1, motion: linear50),
          const StepSync(token: #barrier),
          const StepTo(2, motion: linear100),
        ]),
        trackB([
          const StepTo(1, motion: linear150),
          const StepSync(token: #barrier),
          const StepTo(2, motion: linear100),
        ]),
      ]);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(controller.value(trackA), closeTo(1, error));

      controller.animate([trackA.to(3, motion: linear100)]);
      await tester.pump(const Duration(milliseconds: 50));
      expect(controller.value(trackA), greaterThan(1));

      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 20));
      expect(controller.value(trackB), greaterThan(1));

      await tester.pumpAndSettle();
      expect(controller.value(trackA), closeTo(3, error));
      expect(controller.value(trackB), closeTo(2, error));
    });

    testWidgets('calls onSyncReleased once per released token', (tester) async {
      final recordingController = _RecordingTrackController(vsync: tester);
      controller = recordingController;

      controller.animate([
        trackA([
          const StepTo(1, motion: linear50),
          const StepSync(token: #first),
          const StepTo(2, motion: linear50),
          const StepSync(token: #second),
          const StepTo(3, motion: linear50),
        ]),
        trackB([
          const StepTo(1, motion: linear50),
          const StepSync(token: #first),
          const StepTo(2, motion: linear50),
          const StepSync(token: #second),
          const StepTo(3, motion: linear50),
        ]),
      ]);

      await tester.pump();
      await tester.pumpAndSettle();

      expect(recordingController.releasedTokens, [#first, #second]);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // TrackPhaseTimeline + PhaseTrackController integration
  // ─────────────────────────────────────────────────────────────────────────

  group('PhaseTrackController phases', () {
    const linear100 = Motion.linear(Duration(milliseconds: 100));
    const linear400 = Motion.linear(Duration(milliseconds: 400));

    late PhaseTrackController<String> controller;
    final size = Track<double>(MotionConverter.single, initial: 0.0);
    final opacity = Track<double>(MotionConverter.single, initial: 0.0);
    final fast = Track<double>(MotionConverter.single, initial: 0.0);
    final slow = Track<double>(MotionConverter.single, initial: 0.0);

    tearDown(() {
      controller.dispose();
    });

    testWidgets(
      'phase autoplay does not jump when tracks have different durations',
      (tester) async {
        controller = PhaseTrackController<String>(vsync: tester);

        final phaseTransitions = <PhaseTransition<String>>[];

        // The slow track in phase "a" delays the sync barrier by ~300ms.
        // After release, phase "b" animations should play smoothly.
        controller.playPhases(
          TrackPhaseTimeline({
            'a': [
              fast.to(1.0, motion: linear100),
              slow.to(1.0, motion: linear400),
            ],
            'b': [
              fast.to(2.0, motion: linear100),
              slow.to(2.0, motion: linear100),
            ],
            'c': [
              fast.to(3.0, motion: linear100),
              slow.to(3.0, motion: linear100),
            ],
          }),
          onTransition: phaseTransitions.add,
        );

        await tester.pump();
        expect(controller.currentPhase, equals('a'));

        await tester.pump(const Duration(milliseconds: 420));
        expect(
          phaseTransitions,
          contains(const PhaseTransitioning(from: 'a', to: 'b')),
        );

        // One tick into phase "b".
        await tester.pump(const Duration(milliseconds: 17));

        // It should be barely past 1.0 since only ~17ms of phase "b" elapsed.
        final fastVal = controller.value(fast);
        expect(
          fastVal,
          lessThan(1.5),
          reason: 'fast track jumped to $fastVal in phase "b" — '
              'sync wait time bled into the animation.',
        );

        await tester.pumpAndSettle();

        expect(controller.value(fast), closeTo(3.0, error));
        expect(controller.value(slow), closeTo(3.0, error));
        expect(
          phaseTransitions,
          equals(
            const [
              PhaseTransitioning(from: 'a', to: 'b'),
              PhaseTransitioning(from: 'b', to: 'c'),
              PhaseSettled('c'),
            ],
          ),
        );
      },
    );

    testWidgets(
      'looping autoplay restarts from the first phase without drifting',
      (tester) async {
        controller = PhaseTrackController<String>(vsync: tester);

        final phasesVisited = <String>[];
        // Capture the fast-track value at every 'b' entry (one per cycle), not
        // just the last, so we can verify it stays put across cycles.
        final fastValuesAtBEntry = <double>[];

        controller.playPhases(
          TrackPhaseTimeline(
            {
              'a': [
                fast.to(1.0, motion: linear100),
                slow.to(1.0, motion: linear400),
              ],
              'b': [
                fast.to(2.0, motion: linear100),
                slow.to(2.0, motion: linear100),
              ],
            },
            phaseLoop: LoopMode.loop,
          ),
          onTransition: (transition) {
            if (transition is PhaseTransitioning<String>) {
              final phase = transition.to;
              phasesVisited.add(phase);
              if (phase == 'b') {
                fastValuesAtBEntry.add(controller.value(fast));
              }
            }
          },
        );

        await tester.pump();

        // Run through several cycles with fine-grained pumps to catch jumps.
        for (var i = 0; i < 80; i++) {
          await tester.pump(const Duration(milliseconds: 20));
        }

        controller.stop(canceled: true);

        expect(phasesVisited.take(4), ['b', 'a', 'b', 'a']);
        expect(
          fastValuesAtBEntry.length,
          greaterThanOrEqualTo(2),
          reason: 'Should have entered phase b at least twice in a loop.',
        );

        // The fast track reaches 1.0 at 100ms and then holds at the sync
        // barrier until the slow track finishes phase 'a' at 400ms. So every
        // time we enter phase 'b', fast must be at ~1.0. If time drift
        // accumulated across cycles, later entries would already have advanced
        // toward the phase 'b' target (2.0). The 0.25 tolerance only absorbs
        // the 20ms pump granularity, not a whole extra leg.
        for (final value in fastValuesAtBEntry) {
          expect(
            value,
            closeTo(1.0, 0.25),
            reason: 'fast should be at the phase "a" target (1.0) on every '
                'phase "b" entry; drift would push it toward 2.0. '
                'Captured: $fastValuesAtBEntry',
          );
        }
      },
    );

    testWidgets("goToPhase plays only that phase's animations", (tester) async {
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

    testWidgets('a single-phase timeline plays without sync steps',
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

    testWidgets(
        'a track present in only some phases still participates in sync',
        (tester) async {
      controller = PhaseTrackController<String>(vsync: tester);

      controller.playPhases(
        TrackPhaseTimeline({
          'phase1': [
            size.to(1.0, motion: linear100),
            opacity.to(
              1.0,
              motion: const Motion.linear(Duration(milliseconds: 200)),
            ),
          ],
          'phase2': [
            size.to(2.0, motion: linear100),
          ],
        }),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      expect(controller.value(size), closeTo(2.0, error));
      // opacity animated to 1.0 in phase1 and stayed (no step in phase2)
      expect(controller.value(opacity), closeTo(1.0, error));
    });

    testWidgets('back-to-back playPhases calls only play the latest timeline',
        (tester) async {
      controller = PhaseTrackController<String>(vsync: tester);

      controller.playPhases(
        TrackPhaseTimeline({
          'a': [size.to(1.0, motion: linear100)],
          'b': [size.to(2.0, motion: linear100)],
        }),
      );
      controller.playPhases(
        TrackPhaseTimeline({
          'x': [size.to(10.0, motion: linear100)],
          'y': [size.to(20.0, motion: linear100)],
        }),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      expect(controller.value(size), closeTo(20.0, error));
    });

    testWidgets(
        'disposing the controller while waiting at a barrier does not throw',
        (tester) async {
      controller = PhaseTrackController<String>(vsync: tester);

      controller.playPhases(
        TrackPhaseTimeline({
          'a': [
            size.to(1.0, motion: linear100),
            opacity.to(
              1.0,
              motion: const Motion.linear(Duration(milliseconds: 300)),
            ),
          ],
          'b': [size.to(2.0, motion: linear100)],
        }),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 110));
      expect(controller.value(size), closeTo(1.0, error));
      expect(controller.value(opacity), lessThan(1.0));
      expect(controller.isAnimating, isTrue);

      controller.dispose();

      // Create a fresh controller so tearDown doesn't double-dispose
      controller = PhaseTrackController<String>(vsync: tester);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Type safety regression: non-double tracks with playPhases
  // ─────────────────────────────────────────────────────────────────────────

  group('PhaseTrackController type safety with Track<Offset>', () {
    const linear100 = Motion.linear(Duration(milliseconds: 100));

    final offset = Track<Offset>(
      MotionConverter.offset,
      initial: Offset.zero,
      motion: linear100,
    );
    final scale = Track<double>(
      MotionConverter.single,
      initial: 1.0,
      motion: linear100,
    );

    late PhaseTrackController<String> controller;

    tearDown(() {
      controller.dispose();
    });

    // Reading a value creates the track's slot with its concrete type, which
    // used to make playPhases throw "List<TrackStep<Object>> is not a subtype
    // of List<TrackStep<Offset>>".
    for (final (name, prepare) in <(String, void Function())>[
      ('without touching the tracks first', () {}),
      (
        'after reading the values',
        () {
          expect(controller.value(offset), Offset.zero);
          controller.value(scale);
        },
      ),
      (
        // Mimics a drag gesture, as card_stack.dart does in _onPanUpdate.
        'after set()',
        () {
          final current = controller.value(offset);
          controller.set([offset.value(current + const Offset(10, 20))]);
        },
      ),
    ]) {
      testWidgets('playPhases $name completes', (tester) async {
        controller = PhaseTrackController<String>(vsync: tester);
        prepare();

        controller.playPhases(
          TrackPhaseTimeline({
            'grow': [
              offset.to(const Offset(50, 50), motion: linear100),
              scale.to(2.0, motion: linear100),
            ],
            'shrink': [
              offset.to(const Offset(100, 100), motion: linear100),
              scale.to(1.0, motion: linear100),
            ],
          }),
          onTransition: (_) {},
        );

        await tester.pump();
        await tester.pumpAndSettle();

        expect(controller.value(offset), const Offset(100, 100));
        expect(controller.value(scale), closeTo(1.0, error));
      });
    }
  });
}

class _RecordingTrackController extends TrackController {
  _RecordingTrackController({required super.vsync});

  final releasedTokens = <Object>[];

  @override
  void onSyncReleased(Object token) {
    releasedTokens.add(token);
  }
}
