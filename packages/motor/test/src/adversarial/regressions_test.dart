// ignore_for_file: cascade_invocations, unawaited_futures

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';
import 'package:motor/src/simulations/step_playback.dart';

import 'fuzz_support.dart';

/// Minimal reproductions of bugs the adversarial fuzzers found.
void main() {
  group('TrackController', () {
    final a = Track<double>(MotionConverter.single, initial: 0);
    final b = Track<double>(MotionConverter.single, initial: 0);
    final timeline = TrackTimeline(
      [
        a([
          const TrackStep.to(
            1,
            motion: Motion.linear(Duration(milliseconds: 50)),
          ),
          const TrackStep.sync(token: #meet),
          const TrackStep.to(
            0,
            motion: Motion.linear(Duration(milliseconds: 50)),
          ),
        ]),
        b([
          const TrackStep.to(
            1,
            motion: Motion.linear(Duration(milliseconds: 30)),
          ),
          const TrackStep.sync(token: #meet),
          const TrackStep.to(
            0,
            motion: Motion.linear(Duration(milliseconds: 70)),
          ),
        ]),
      ],
      loop: LoopMode.loop,
    );

    testWidgets(
      'one long frame through many barrier rounds shows what ticking shows',
      (tester) async {
        final ticked = TrackController(vsync: tester)..play(timeline);
        addTearDown(ticked.dispose);
        final jumped = TrackController(vsync: tester)..play(timeline);
        addTearDown(jumped.dispose);
        await tester.pump();
        jumped.pause();
        // 60 fps for 30 s: 300 cycles of 100 ms, one barrier round each.
        for (var i = 0; i < 1800; i++) {
          await tester.pump(const Duration(microseconds: 16667));
        }
        final position = ticked.inspectPlayback().position;
        jumped.scrubTo(position);

        expect(jumped.value(a), closeTo(ticked.value(a), 1e-9));
        expect(jumped.value(b), closeTo(ticked.value(b), 1e-9));
        ticked.stop(canceled: true);
      },
      // Needs a decision: TrackController._advanceTracks releases at most
      // _maxBarrierPasses (100) barrier rounds per frame or scrub, counting
      // rounds that take time too. A longer jump (a muted ticker, a scrub)
      // leaves tracks waiting at a barrier in the past, showing stale
      // values, and later frames or scrubs to the same time show other
      // values.
      skip: true,
    );

    testWidgets(
      'a keyframe in a later phase lands the same however the phase starts',
      (tester) async {
        final timeline = TrackPhaseTimeline<int>({
          0: [
            a.to(1, motion: const Motion.linear(Duration(milliseconds: 300))),
          ],
          1: [
            a([
              const TrackStep.at(
                Duration(milliseconds: 200),
                2,
                motion: Motion.linear(Duration(milliseconds: 100)),
              ),
            ]),
          ],
        });
        final played = PhaseTrackController<int>(vsync: tester);
        addTearDown(played.dispose);
        played.playPhases(timeline);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 310));
        expect(played.currentPhase, 1);
        await tester.pump(const Duration(milliseconds: 90));

        final jumped = PhaseTrackController<int>(vsync: tester);
        addTearDown(jumped.dispose);
        jumped
          ..set([a.value(1)])
          ..setTimeline(timeline)
          ..goToPhase(1);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Played through, the keyframe counts from the start of the whole
        // timeline, so it has passed and the step runs late (2 here);
        // jumped to, it counts from the phase start (1.5 here).
        expect(played.value(a), closeTo(jumped.value(a), 1e-6));
        await tester.pumpAndSettle();
      },
      // Needs a decision: phases are flattened into one plan, so a `.at` in a
      // later phase is measured from the start of the timeline when played
      // through, but from the phase start after goToPhase or
      // playPhases(atPhase:). The timeline docs don't say which is meant.
      skip: true,
    );

    testWidgets(
      'a keyframe in a later phase after long holds does not assert',
      (tester) async {
        final controller = PhaseTrackController<int>(vsync: tester);
        addTearDown(controller.dispose);
        controller.playPhases(
          TrackPhaseTimeline<int>({
            0: [
              a(const [TrackStep.hold(Duration(milliseconds: 500))]),
            ],
            1: [
              a(const [
                TrackStep.at(
                  Duration(milliseconds: 200),
                  2,
                  motion: Motion.linear(Duration(milliseconds: 100)),
                ),
              ]),
            ],
          }),
        );
        await tester.pumpAndSettle();
        expect(controller.value(a), 2);
      },
      // Needs a decision, same cause as the previous test: the flattened
      // plan's `.at(200ms)` comes after 500 ms of holds, which StepPlayback
      // asserts is going back in time, from inside playPhases (or a
      // PhaseTrackBuilder's build).
      skip: true,
    );

    testWidgets(
      'setting a looping track leaves its future unsettled',
      (tester) async {
        final controller = TrackController(vsync: tester);
        addTearDown(controller.dispose);
        final events = <String>[];
        final future = controller.animate(
          [a.to(1, motion: const Motion.linear(Duration(milliseconds: 100)))],
          loop: LoopMode.pingPong,
        );
        unawaited(future.ended.then((_) => events.add('ended')));
        unawaited(
          future.orCancel.then(
            (_) => events.add('settled'),
            onError: (Object _) => events.add('canceled'),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));
        controller.set([a.value(0.5)]);
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 16));

        expect(events, ['canceled']);
      },
      // Needs a decision: set() stops the track without canceling its
      // future, so the next frame settles it as if it had come to rest,
      // though loops never end or settle. AnimationController's value
      // setter cancels its TickerFuture.
      skip: true,
    );
  });

  group('StepPlayback', () {
    test('a seek to an exact step boundary shows what playback showed', () {
      // The boundaries fall where rounding makes `end - start` a hair less
      // than the step's length, although `start + length` is `end`.
      StepPlayback<double> build() => StepPlayback<double>(
            steps: const [
              TrackStep.to(
                1,
                motion: Motion.linear(Duration(milliseconds: 400)),
              ),
              TrackStep.hold(Duration(milliseconds: 200)),
              TrackStep.to(
                3,
                motion: Motion.linear(Duration(milliseconds: 700)),
              ),
              TrackStep.hold(Duration(milliseconds: 200)),
            ],
            converter: MotionConverter.single,
            start: 0,
          );
      final boundaries = [
        for (final segment in (build()..advanceTo(10)).segmentsView)
          segment.end!,
      ];
      for (final boundary in boundaries) {
        final played = build()
          ..advanceTo(10)
          ..advanceTo(boundary);
        final sought = build()..advanceTo(boundary);
        final reason = 'at $boundary';
        expect(sought.isDone, played.isDone, reason: reason);
        expect(
          sought.currentStepIndex,
          played.currentStepIndex,
          reason: reason,
        );
        expect(sought.values.single, played.values.single, reason: reason);
        expect(
          sought.velocities.single,
          played.velocities.single,
          reason: reason,
        );
      }
    });

    test('a hold after a curve that handed over is at rest', () {
      final playback = StepPlayback<double>(
        steps: const [
          TrackStep.to(
            1,
            motion: Motion.linear(Duration(milliseconds: 100)),
            until: WaitUntil.duration,
          ),
          TrackStep.hold(Duration(seconds: 1)),
          TrackStep.to(1, motion: Motion.smoothSpring()),
        ],
        converter: MotionConverter.single,
        start: 0,
      );

      playback.advanceTo(0.5);
      expect(playback.values.single, 1);
      expect(playback.velocities.single, 0);
      // The spring to where the track already is has nothing to do.
      for (var t = 1.1; t < 2; t += 0.05) {
        playback.advanceTo(t);
        expect(playback.values.single, closeTo(1, 1e-9), reason: 't=$t');
      }
    });

    test('a zero-length hold after a curve keeps its velocity', () {
      final playback = StepPlayback<double>(
        steps: const [
          TrackStep.to(
            1,
            motion: Motion.linear(Duration(milliseconds: 100)),
            until: WaitUntil.duration,
          ),
          TrackStep.hold(Duration.zero),
          TrackStep.to(2, motion: Motion.smoothSpring()),
        ],
        converter: MotionConverter.single,
        start: 0,
      )..advanceTo(0.1 + 1e-6);

      expect(playback.velocities.single, closeTo(10, 0.1));
    });

    test('a plan played to its end and sought back into it has ended', () {
      StepPlayback<double> build() => StepPlayback<double>(
            steps: const [
              TrackStep.to(
                1,
                motion: Motion.linear(Duration(milliseconds: 100)),
              ),
              TrackStep.to(2, motion: Motion.bouncySpring()),
            ],
            converter: MotionConverter.single,
            start: 0,
          );
      // Past the spring's 500 ms duration, before it settles.
      const t = 0.1 + 0.6;
      final sought = build()..advanceTo(t);
      final played = build()
        ..advanceTo(10)
        ..advanceTo(t);

      expect(sought.hasEnded, isTrue);
      expect(sought.isDone, isFalse);
      expect(played.isDone, isFalse);
      expect(played.hasEnded, isTrue);
    });

    test(
      'looking ahead at a step does not change when it ends',
      () {
        // One dimension flickers done at 0.1 s to 0.2 s and is done from
        // 0.3 s; the other ramps and says it settles at 0.2 s. Asked, the
        // step ends at 0.2 s; found on the grid, at the first point where
        // both are done, 0.3 s, and then asked.
        StepPlayback<Offset> build() => StepPlayback<Offset>(
              steps: const [
                TrackStep.to(
                  Offset(1, 1),
                  motionPerDimension: [FlickeringMotion(), ReportingMotion()],
                ),
                TrackStep.to(
                  Offset.zero,
                  motion: Motion.linear(Duration(seconds: 1)),
                ),
              ],
              converter: MotionConverter.offset,
              start: Offset.zero,
            );
        final looked = build();
        // Inspection snapshots read this, and so does a following `.at`.
        looked.segmentsView;
        looked.advanceTo(0.25);
        final unlooked = build()..advanceTo(0.25);

        expect(unlooked.currentStepIndex, looked.currentStepIndex);
        expect(unlooked.values, looked.values);
      },
      skip: 'Needs a decision: a look-ahead asks settlesAt right away, while '
          'ticking only asks at the first grid point where every dimension '
          'is done, and the answer is not clamped to the last point that is '
          'not done. With a flickering isDone the two disagree, so attaching '
          'devtools or adding a `.at` can move a step boundary.',
    );

    test(
      'a looping free motion with a curve returning it stays bounded',
      () {
        final playback = StepPlayback<double>(
          steps: const [TrackStep.free(motion: FrictionMotion())],
          converter: MotionConverter.single,
          start: 0,
          velocity: 1,
          loop: LoopMode.loop,
          fallbackMotion: const Motion.linear(Duration(milliseconds: 300)),
        );
        for (var t = 0.0; t < 120; t += 0.5) {
          playback.advanceTo(t);
          expect(playback.values.single.abs(), lessThan(2), reason: 't=$t');
        }
      },
      skip: 'Needs a decision (same cause as the next test): the loop returns '
          'with a settled curve whose end slope the next friction inherits, '
          'so each cycle flings further than the last and the value grows '
          'without bound (221 after 60 s; NaN with FrictionMotion.scaleTo).',
    );

    test(
      'a step after a curve that settled starts from rest',
      () {
        final playback = StepPlayback<double>(
          steps: const [
            TrackStep.to(1, motion: Motion.linear(Duration(milliseconds: 100))),
            TrackStep.to(1, motion: Motion.smoothSpring()),
          ],
          converter: MotionConverter.single,
          start: 0,
        );

        for (var t = 0.1001; t < 1; t += 0.05) {
          playback.advanceTo(t);
          expect(playback.values.single, closeTo(1, 1e-9), reason: 't=$t');
        }
      },
      skip: 'Needs a decision: TrackStep.to and WaitUntil.settled say the next '
          'step starts from rest, but CurveSimulation.dx keeps its end slope '
          'after the end on purpose, so a spring after a settled curve '
          'inherits it (here overshooting to 1.026).',
    );
  });
}
