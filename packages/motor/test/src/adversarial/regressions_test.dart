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
    );

    testWidgets('scrubbing to one time twice shows the same', (tester) async {
      final controller = TrackController(vsync: tester)..play(timeline);
      addTearDown(controller.dispose);
      await tester.pump();
      controller.pause();
      for (final t in [30.0, 12.345, 30.0, 60.0, 12.345]) {
        final position = Duration(microseconds: (t * 1e6).round());
        controller.scrubTo(position);
        final first = (controller.value(a), controller.value(b));
        controller.scrubTo(position);
        expect((controller.value(a), controller.value(b)), first, reason: '$t');
      }
      controller.stop(canceled: true);
    });

    testWidgets('a zero-length loop through a barrier stays bounded per frame',
        (tester) async {
      final controller = TrackController(vsync: tester);
      addTearDown(controller.dispose);
      var steps = 0;
      controller.animate(
        [
          a(const [
            TrackStep.to(1, motion: Motion.linear(Duration.zero)),
            TrackStep.sync(token: #zero),
          ]),
          b(const [TrackStep.sync(token: #zero)]),
        ],
        loop: LoopMode.loop,
        onStep: (_, __) => steps++,
      );
      final watch = Stopwatch()..start();
      await tester.pump();
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
      expect(steps, lessThan(20 * 5000));
      controller.stop(canceled: true);
    });

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
        final playedValue = played.value(a);
        played.stop(canceled: true);

        final jumped = PhaseTrackController<int>(vsync: tester);
        addTearDown(jumped.dispose);
        jumped
          ..set([a.value(1)])
          ..setTimeline(timeline)
          ..goToPhase(1);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Either way, the keyframe counts from the start of its phase.
        expect(playedValue, closeTo(jumped.value(a), 1e-6));
        expect(playedValue, closeTo(1.5, 1e-6));
        await tester.pumpAndSettle();
      },
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
    );

    testWidgets('keyframes in later phases scrub back as they played',
        (tester) async {
      final subscription = MotorInspectionRegistry.attach(_Observer());
      addTearDown(subscription.dispose);
      final timeline = TrackPhaseTimeline<int>({
        0: [
          a(const [
            TrackStep.to(1, motion: Motion.bouncySpring()),
            TrackStep.hold(Duration(milliseconds: 400)),
          ]),
          b.to(1, motion: const Motion.linear(Duration(milliseconds: 700))),
        ],
        1: [
          a(const [
            TrackStep.at(
              Duration(milliseconds: 100),
              2,
              motion: Motion.smoothSpring(),
            ),
            TrackStep.at(
              Duration(milliseconds: 600),
              0,
              motion: Motion.linear(Duration(milliseconds: 200)),
            ),
          ]),
        ],
        2: [
          b(const [
            TrackStep.at(
              Duration(milliseconds: 50),
              3,
              motion: Motion.linear(Duration(milliseconds: 100)),
            ),
          ]),
        ],
      });
      final live = PhaseTrackController<int>(vsync: tester)
        ..playPhases(timeline);
      addTearDown(live.dispose);
      final recorded = <(Duration, double, double)>[];
      await tester.pump();
      for (var i = 0; i < 180; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        recorded.add(
          (live.inspectPlayback().position, live.value(a), live.value(b)),
        );
      }
      final scrubbed = PhaseTrackController<int>(vsync: tester)
        ..playPhases(timeline)
        ..pause();
      addTearDown(scrubbed.dispose);
      for (final (position, valueA, valueB) in recorded.reversed) {
        scrubbed.scrubTo(position);
        expect(scrubbed.value(a), closeTo(valueA, 1e-9), reason: '$position');
        expect(scrubbed.value(b), closeTo(valueB, 1e-9), reason: '$position');
      }
      live.stop(canceled: true);
      scrubbed.stop(canceled: true);
    });

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

    test('a spring played out after a last hold ends with the hold', () {
      StepPlayback<double> build() => StepPlayback<double>(
            steps: const [
              TrackStep.to(
                1,
                motion: Motion.bouncySpring(),
                until: WaitUntil.duration,
              ),
              TrackStep.hold(Duration(milliseconds: 100)),
            ],
            converter: MotionConverter.single,
            start: 0,
          );
      // The hold ends at 0.6 s; the spring keeps settling after it.
      for (final (t, ended) in [(0.2, false), (0.55, false), (0.7, true)]) {
        final sought = build()..advanceTo(t);
        final played = build()
          ..advanceTo(10)
          ..advanceTo(t);
        expect(sought.hasEnded, ended, reason: 'sought at $t');
        expect(played.hasEnded, ended, reason: 'played back to $t');
        expect(played.isDone, isFalse, reason: 'played back to $t');
      }
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
    );

    test('a flickering step ends the same ticked, sought or looked ahead at',
        () {
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
      for (var t = 0.0; t < 0.6; t += 0.01) {
        final sought = build()..advanceTo(t);
        final looked = build()..segmentsView;
        looked.advanceTo(t);
        final played = build()
          ..advanceTo(2)
          ..advanceTo(t);
        final ticked = build();
        for (var time = 0.0; time < t; time += 1 / 60) {
          ticked.advanceTo(time);
        }
        ticked.advanceTo(t);
        for (final other in [looked, played, ticked]) {
          expect(other.currentStepIndex, sought.currentStepIndex, reason: '$t');
          expect(other.values, sought.values, reason: '$t');
          expect(other.velocities, sought.velocities, reason: '$t');
        }
      }
    });

    test("a loop returns with the first step's motion, the track's if unset",
        () {
      final playback = StepPlayback<double>(
        steps: const [
          TrackStep.to(1),
          TrackStep.to(2, motion: Motion.linear(Duration(seconds: 2))),
        ],
        converter: MotionConverter.single,
        start: 0,
        loop: LoopMode.loop,
        fallbackMotion: const Motion.linear(Duration(milliseconds: 100)),
      )..advanceTo(2.1 + 0.05);
      // Back from 2 to 0 in 100 ms, not in 2 s.
      expect(playback.values.single, closeTo(1, 1e-9));
    });

    group('velocity after a curve', () {
      const linear100 = Motion.linear(Duration(milliseconds: 100));

      StepPlayback<double> chained() => StepPlayback<double>(
            steps: const [
              TrackStep.to(1, motion: linear100),
              TrackStep.to(1, motion: Motion.smoothSpring()),
            ],
            converter: MotionConverter.single,
            start: 0,
          );

      test('a spring chained right after a curve takes over its end slope', () {
        final playback = chained()..advanceTo(0.1001);
        expect(playback.currentStepIndex, 1);
        expect(playback.velocities.single, closeTo(10, 0.1));
        playback.advanceTo(0.2);
        // The spring carries the curve's momentum past the target.
        expect(playback.values.single, greaterThan(1.01));
      });

      test('the handoff is the same whether ticked or sought', () {
        final handoff = (chained()..advanceTo(1)).segmentsView.first.end!;
        for (final t in [handoff, handoff + 1e-7, 0.15, 0.4]) {
          final sought = chained()..advanceTo(t);
          final ticked = chained();
          for (var time = 0.0; time < t; time += 1 / 240) {
            ticked.advanceTo(time);
          }
          ticked.advanceTo(t);
          final played = chained()
            ..advanceTo(5)
            ..advanceTo(t);
          for (final other in [ticked, played]) {
            expect(other.values.single, sought.values.single, reason: '$t');
            expect(
              other.velocities.single,
              sought.velocities.single,
              reason: '$t',
            );
          }
        }
      });

      test("a loop's return curve hands its end slope to the next cycle", () {
        // The return step chains straight into the friction, so the
        // friction takes over its end slope. Each return then covers a
        // longer distance in the same time, so this plan gains energy.
        final playback = StepPlayback<double>(
          steps: const [TrackStep.free(motion: FrictionMotion())],
          converter: MotionConverter.single,
          start: 0,
          velocity: 1,
          loop: LoopMode.loop,
          fallbackMotion: const Motion.linear(Duration(milliseconds: 300)),
        )..advanceTo(20);
        final segments = playback.segmentsView;
        for (var i = 1; i < segments.length; i++) {
          final segment = segments[i];
          if (segment.stepIndex != 0) continue;
          final wrap = segment.start;
          playback.advanceTo(wrap - 1e-9);
          final before = playback.velocities.single;
          playback.advanceTo(wrap + 1e-9);
          expect(
            playback.velocities.single,
            closeTo(before, 1e-3 * before.abs() + 1e-6),
            reason: 'cycle starting at $wrap',
          );
        }
      });

      test('a dimension whose curve ended earlier starts the next step still',
          () {
        StepPlayback<Offset> build() => StepPlayback<Offset>(
              steps: const [
                TrackStep.to(
                  Offset(1, 1),
                  motionPerDimension: [
                    linear100,
                    Motion.linear(Duration(seconds: 1)),
                  ],
                ),
                TrackStep.to(Offset(1, 1), motion: Motion.smoothSpring()),
              ],
              converter: MotionConverter.offset,
              start: Offset.zero,
            );
        final playback = build()..advanceTo(0.5);
        expect(playback.velocities, [0, closeTo(1, 1e-6)]);
        playback.advanceTo(1.2);
        expect(playback.values[0], 1);
        // The slower dimension chained into the spring and overshoots.
        expect(playback.values[1], greaterThan(1));

        final sought = build()..advanceTo(1.2);
        expect(sought.values, playback.values);
        expect(sought.velocities, playback.velocities);
      });

      test('a finished plan is at rest, however it got there', () {
        StepPlayback<double> build() => StepPlayback<double>(
              steps: const [TrackStep.to(1, motion: linear100)],
              converter: MotionConverter.single,
              start: 0,
            );
        final sought = build()..advanceTo(5);
        final ticked = build();
        for (var t = 0.0; t <= 5; t += 1 / 60) {
          ticked.advanceTo(t);
        }
        ticked.advanceTo(5);
        expect(sought.velocities.single, 0);
        expect(ticked.velocities.single, 0);
      });

      test('a loop that rests before it returns starts the return from rest',
          () {
        // The return takes the first step's spring, after the curve and the
        // hold.
        final playback = StepPlayback<double>(
          steps: const [
            TrackStep.to(1, motion: Motion.smoothSpring()),
            TrackStep.to(2, motion: linear100),
            TrackStep.hold(Duration(milliseconds: 200)),
          ],
          converter: MotionConverter.single,
          start: 0,
          loop: LoopMode.loop,
        )..advanceTo(10);
        final returns = playback.segmentsView.firstWhere(
          (segment) => segment.stepIndex == 3,
        );
        final fromRest =
            const Motion.smoothSpring().createSimulation(start: 2, end: 0);
        playback.advanceTo(returns.start + 0.05);
        expect(playback.values.single, closeTo(fromRest.x(0.05), 1e-9));
        expect(playback.velocities.single, closeTo(fromRest.dx(0.05), 1e-9));
      });
    });

    testWidgets('a barrier wait after a curve releases from rest',
        (tester) async {
      final a = Track<double>(MotionConverter.single, initial: 0);
      final b = Track<double>(MotionConverter.single, initial: 0);
      final controller = TrackController(vsync: tester);
      addTearDown(controller.dispose);
      controller.animate([
        a([
          const TrackStep.to(
            1,
            motion: Motion.linear(Duration(milliseconds: 100)),
          ),
          const TrackStep.sync(token: #meet),
          const TrackStep.to(1, motion: Motion.smoothSpring()),
        ]),
        b([
          const TrackStep.hold(Duration(milliseconds: 500)),
          const TrackStep.sync(token: #meet),
        ]),
      ]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(controller.velocity(a), 0);
      await tester.pump(const Duration(milliseconds: 300));
      // Released at 500 ms from rest, the spring has nothing to do.
      expect(controller.value(a), closeTo(1, 1e-9));
      await tester.pumpAndSettle();
    });

    testWidgets('a retarget after a curve ended starts that dimension still',
        (tester) async {
      final offset =
          Track<Offset>(MotionConverter.offset, initial: Offset.zero);
      final controller = TrackController(vsync: tester);
      addTearDown(controller.dispose);
      controller.animate([
        offset.to(
          const Offset(1, 1),
          motionPerDimension: const [
            Motion.linear(Duration(milliseconds: 100)),
            Motion.linear(Duration(seconds: 1)),
          ],
        ),
      ]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(controller.velocity(offset).dx, 0);
      controller.animate([
        offset.to(const Offset(1, 0.4), motion: const Motion.smoothSpring()),
      ]);
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.value(offset).dx, closeTo(1, 1e-9));
      await tester.pumpAndSettle();
    });
  });
}

class _Observer implements MotorInspectionObserver {
  @override
  void didRegisterController(TrackController controller) {}

  @override
  void didUnregisterController(TrackController controller) {}
}
