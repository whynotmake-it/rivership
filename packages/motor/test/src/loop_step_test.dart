// ignore_for_file: cascade_invocations, unawaited_futures

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

import 'util.dart';

void main() {
  const linear100 = Motion.linear(Duration(milliseconds: 100));
  const linear200 = Motion.linear(Duration(milliseconds: 200));
  const linear300 = Motion.linear(Duration(milliseconds: 300));
  const hold100 = Duration(milliseconds: 100);
  const bouncy = CupertinoMotion.bouncy();

  group('no-op TrackStep.to takes no time', () {
    testWidgets(
      'curve and spring at rest skip in 0ms (including until: .ended), '
      'while a spring with velocity still overshoots and .at still waits',
      (tester) async {
        final curveTrack = Track<double>(MotionConverter.single, initial: 0);
        final springTrack = Track<double>(MotionConverter.single, initial: 0);
        final movingSpring = Track<double>(MotionConverter.single, initial: 0);
        final atTrack = Track<double>(MotionConverter.single, initial: 0);

        final controller = TrackController(vsync: tester);
        addTearDown(controller.dispose);

        final curveSteps = <int>[];
        final future = controller.animate(
          [
            // Leading no-op to 0 (with until: .ended) takes 0ms, then 0 -> 1
            // takes 100ms, then trailing no-op to 1 takes 0ms.
            curveTrack([
              const TrackStep.to(0, motion: linear300, until: WaitUntil.ended),
              const TrackStep.to(1, motion: linear100, until: WaitUntil.ended),
              const TrackStep.to(1, motion: linear300, until: WaitUntil.ended),
            ]),
            // Spring at rest on target skips straight to the real move.
            springTrack([
              const TrackStep.to(0, motion: bouncy, until: WaitUntil.ended),
              const TrackStep.to(1, motion: linear100),
            ]),
            // Spring on target WITH velocity must still overshoot before
            // moving.
            movingSpring(
              [
                const TrackStep.to(0, motion: bouncy),
                const TrackStep.to(1, motion: linear100),
              ],
              withVelocity: 20,
            ),
            // .at to the current value still waits until its timestamp.
            atTrack([
              const TrackStep.at(
                Duration(milliseconds: 200),
                0,
                motion: linear100,
              ),
              const TrackStep.to(1, motion: linear100),
            ]),
          ],
          onStep: (track, index) {
            if (identical(track, curveTrack)) curveSteps.add(index);
          },
        );

        var ended = false;
        future.ended.then((_) => ended = true);

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // Curve and resting spring skipped their no-op .to(0) immediately and
        // are already halfway through 0 -> 1.
        expect(controller.value(curveTrack), closeTo(0.5, 0.02));
        expect(controller.value(springTrack), closeTo(0.5, 0.02));
        // Spring with velocity overshot away from 0 instead of skipping.
        expect(controller.value(movingSpring), greaterThan(0.1));
        // .at(200ms, 0) is still holding at 0 until 200ms.
        expect(controller.value(atTrack), closeTo(0, error));

        await tester.pump(const Duration(milliseconds: 50));
        expect(controller.value(curveTrack), closeTo(1, error));
        expect(controller.value(springTrack), closeTo(1, error));
        // Every authored step on curveTrack still reported to onStep.
        expect(curveSteps, [0, 1, 2]);
        expect(ended, isFalse); // atTrack & movingSpring still running

        // At 250ms, atTrack has passed its 200ms keyframe and is halfway to 1.
        await tester.pump(const Duration(milliseconds: 150));
        expect(controller.value(atTrack), closeTo(0.5, 0.02));

        await tester.pumpAndSettle();
        expect(ended, isTrue);
        expect(controller.value(movingSpring), closeTo(1, error));
        expect(controller.value(atTrack), closeTo(1, error));
      },
    );
  });

  group('TrackStep.loop modes (first-target anchor)', () {
    testWidgets(
      '.loop repeats steps directly with no hidden return step, preserving '
      'exact 30ms keyframe timing and supporting intros without dragging '
      'the pre-loop value into the cycle',
      (tester) async {
        final track = Track<double>(MotionConverter.single, initial: 0);
        final introTrack = Track<double>(MotionConverter.single, initial: 0.5);
        final controller = TrackController(vsync: tester);
        addTearDown(controller.dispose);

        var moves = 0;
        const m30 = Motion.linear(Duration(milliseconds: 30));
        controller.animate(
          [
            // Repro from merging_dots: 4 x 30ms steps looped for 480ms = 16
            // moves (+1 entry), not 13 from a hidden return step.
            track([
              TrackStep.loop([
                for (var i = 0; i < 4; i++)
                  TrackStep.to(
                    i.isEven ? 1.0 : 0.0,
                    motion: m30,
                    until: WaitUntil.ended,
                  ),
              ]),
            ]),
            // Intro to 0.5 (already there -> 0ms), then loop between 1 and 0:
            // never returns to 0.5 after cycle 0.
            introTrack([
              const TrackStep.to(0.5, motion: linear100),
              const TrackStep.loop([
                TrackStep.to(1, motion: linear100),
                TrackStep.to(0, motion: linear100),
              ]),
            ]),
          ],
          onStep: (t, _) {
            if (identical(t, track)) moves++;
          },
        );

        await tester.pump();
        for (var i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }

        // 480ms / 30ms = 16 transitions (+1 initial entry).
        expect(moves, 17);

        // Check introTrack at exact cycle points via scrubTo:
        // 0..100ms: 0.5 -> 1; 100..200ms: 1 -> 0; 200..300ms: 0 -> 1;
        // 300..400ms: 1 -> 0. Never stops at or returns to 0.5 at cycle wrap.
        controller.pause();
        controller.scrubTo(const Duration(milliseconds: 100));
        expect(controller.value(introTrack), closeTo(1.0, error));
        controller.scrubTo(const Duration(milliseconds: 200));
        expect(controller.value(introTrack), closeTo(0.0, error));
        controller.scrubTo(const Duration(milliseconds: 250));
        expect(controller.value(introTrack), closeTo(0.5, error));
        controller.scrubTo(const Duration(milliseconds: 300));
        expect(controller.value(introTrack), closeTo(1.0, error));
        controller.scrubTo(const Duration(milliseconds: 400));
        expect(controller.value(introTrack), closeTo(0.0, error));
      },
    );

    testWidgets(
      '.seamless jumps to the first target (ignoring start != step 0) and '
      'handles leading, middle, and trailing holds plus launch + .free',
      (tester) async {
        final offsetStart = Track<double>(MotionConverter.single, initial: 0.5);
        final leadHold = Track<double>(MotionConverter.single, initial: 0.5);
        final trailHold = Track<double>(MotionConverter.single, initial: 0);
        final launchFree = Track<double>(MotionConverter.single, initial: 0);

        final controller = TrackController(vsync: tester);
        addTearDown(controller.dispose);

        controller.animate([
          // Starts at 0.5 -> 0 (100ms) -> 1 (100ms), then jumps 1 ~> 0 and
          // repeats 0 -> 1 every 100ms (never jumps back to 0.5).
          offsetStart([
            const TrackStep.loop(
              [
                TrackStep.to(0, motion: linear100),
                TrackStep.to(1, motion: linear100),
              ],
              mode: LoopMode.seamless,
            ),
          ]),
          // Leading hold: cycle 0 holds 100ms at 0.5, 0.5->0 (100ms),
          // 0->1 (100ms); cycle 1 jumps 1 ~> 0, holds 100ms at 0, skips
          // .to(0) in 0ms, moves 0->1 (100ms).
          leadHold([
            const TrackStep.loop(
              [
                TrackStep.hold(hold100),
                TrackStep.to(0, motion: linear100),
                TrackStep.to(1, motion: linear100),
              ],
              mode: LoopMode.seamless,
            ),
          ]),
          // Trailing hold: 0->1 (100ms), holds 100ms at 1, jumps 1 ~> 0,
          // 0->1 (100ms), holds 100ms at 1.
          trailHold([
            const TrackStep.loop(
              [
                TrackStep.to(0, motion: linear100),
                TrackStep.to(1, motion: linear100),
                TrackStep.hold(hold100),
              ],
              mode: LoopMode.seamless,
            ),
          ]),
          // Launch with velocity into friction coast, then seamless jump to 0.
          launchFree([
            const TrackStep.loop(
              [
                TrackStep.to(0, motion: linear100),
                TrackStep.to(
                  100,
                  motion: Motion.linear(Duration(milliseconds: 100)),
                  until: WaitUntil.ended,
                ),
                TrackStep.free(motion: FreeMotion.friction(drag: 0.005)),
              ],
              mode: LoopMode.seamless,
            ),
          ]),
        ]);

        controller.pause();

        // offsetStart: 0.5->0 (0..100ms), 0->1 (100..200ms), jump 0,
        // 0->1 (200..300ms), jump 0, 0->1 (300..400ms).
        controller.scrubTo(const Duration(milliseconds: 250));
        expect(controller.value(offsetStart), closeTo(0.5, error));
        controller.scrubTo(const Duration(milliseconds: 325));
        expect(controller.value(offsetStart), closeTo(0.25, error));

        // leadHold: cycle 0 ends at 300ms (100 hold + 100 to 0 + 100 to 1);
        // cycle 1 jumps to 0 at 300ms, holds at 0 until 400ms, moves 0->1
        // from 400..500ms.
        controller.scrubTo(const Duration(milliseconds: 350));
        expect(controller.value(leadHold), closeTo(0.0, error));
        controller.scrubTo(const Duration(milliseconds: 450));
        expect(controller.value(leadHold), closeTo(0.5, error));

        // trailHold: 0->1 (0..100ms), hold at 1 (100..200ms), jump 0,
        // 0->1 (200..300ms), hold at 1 (300..400ms).
        controller.scrubTo(const Duration(milliseconds: 150));
        expect(controller.value(trailHold), closeTo(1.0, error));
        controller.scrubTo(const Duration(milliseconds: 250));
        expect(controller.value(trailHold), closeTo(0.5, error));
        controller.scrubTo(const Duration(milliseconds: 350));
        expect(controller.value(trailHold), closeTo(1.0, error));

        // launchFree coasts past 100, then resets to 0 and launches again.
        controller.scrubTo(const Duration(milliseconds: 200));
        final coasting = controller.value(launchFree);
        expect(coasting, greaterThan(100));
        // Still running well into later cycles without settling.
        controller.scrubTo(const Duration(seconds: 5));
        expect(controller.isAnimating, isFalse); // paused
        controller.resume();
        expect(controller.isAnimating, isTrue);
        controller.stop(canceled: true);
      },
    );

    testWidgets(
      '.pingPong bounces between first and last target, never doubles '
      'turnaround holds, and plays interior holds in both directions',
      (tester) async {
        final offsetStart = Track<double>(MotionConverter.single, initial: 0.5);
        final leadHold = Track<double>(MotionConverter.single, initial: 0.5);
        final midHold = Track<double>(MotionConverter.single, initial: 0);
        final trailHold = Track<double>(MotionConverter.single, initial: 0);
        final interiorHold = Track<double>(MotionConverter.single, initial: 0);

        final controller = TrackController(vsync: tester);
        addTearDown(controller.dispose);

        controller.animate([
          // 0.5->0 (100ms), 0->1 (100ms), 1->0 (100ms), 0->1 (100ms)...
          // Never returns to 0.5.
          offsetStart([
            const TrackStep.loop(
              [
                TrackStep.to(0, motion: linear100),
                TrackStep.to(1, motion: linear100),
              ],
              mode: LoopMode.pingPong,
            ),
          ]),
          // Leading hold: 100ms hold at 0.5, 0.5->0 (100ms), 0->1 (100ms),
          // rev 1->0 (100ms), then holds ONCE (100ms) at 0, then 0->1 (100ms).
          leadHold([
            const TrackStep.loop(
              [
                TrackStep.hold(hold100),
                TrackStep.to(0, motion: linear100),
                TrackStep.to(1, motion: linear100),
              ],
              mode: LoopMode.pingPong,
            ),
          ]),
          // Hold right after first target: plays ONCE at 0 each cycle.
          // 0..100 hold at 0, 100..200 0->1, 200..300 1->0, 300..400 hold at 0,
          // 400..500 0->1.
          midHold([
            const TrackStep.loop(
              [
                TrackStep.to(0, motion: linear100),
                TrackStep.hold(hold100),
                TrackStep.to(1, motion: linear100),
              ],
              mode: LoopMode.pingPong,
            ),
          ]),
          // Trailing hold: plays ONCE at 1 (not doubled to 200ms).
          // 0..100 0->1, 100..200 hold at 1, 200..300 1->0, 300..400 0->1.
          trailHold([
            const TrackStep.loop(
              [
                TrackStep.to(0, motion: linear100),
                TrackStep.to(1, motion: linear100),
                TrackStep.hold(hold100),
              ],
              mode: LoopMode.pingPong,
            ),
          ]),
          // Interior hold between 3 targets: plays at 0.5 going UP and DOWN.
          // Fwd: 0..100 0->0.5, 100..200 hold at 0.5, 200..300 0.5->1.
          // Rev: 300..400 1->0.5, 400..500 hold at 0.5, 500..600 0.5->0.
          interiorHold([
            const TrackStep.loop(
              [
                TrackStep.to(0, motion: linear100),
                TrackStep.to(0.5, motion: linear100),
                TrackStep.hold(hold100),
                TrackStep.to(1, motion: linear100),
              ],
              mode: LoopMode.pingPong,
            ),
          ]),
        ]);

        controller.pause();

        // offsetStart bounces 0 <-> 1 after entering from 0.5.
        controller.scrubTo(const Duration(milliseconds: 200));
        expect(controller.value(offsetStart), closeTo(1.0, error));
        controller.scrubTo(const Duration(milliseconds: 300));
        expect(controller.value(offsetStart), closeTo(0.0, error));
        controller.scrubTo(const Duration(milliseconds: 350));
        expect(controller.value(offsetStart), closeTo(0.5, error));
        controller.scrubTo(const Duration(milliseconds: 400));
        expect(controller.value(offsetStart), closeTo(1.0, error));

        // leadHold: 400..500 hold at 0, 500..600 0->1.
        controller.scrubTo(const Duration(milliseconds: 450));
        expect(controller.value(leadHold), closeTo(0.0, error));
        controller.scrubTo(const Duration(milliseconds: 550));
        expect(controller.value(leadHold), closeTo(0.5, error));

        // midHold: 300..400 hold at 0 (only 100ms, not 200ms!), 400..500 0->1.
        controller.scrubTo(const Duration(milliseconds: 350));
        expect(controller.value(midHold), closeTo(0.0, error));
        controller.scrubTo(const Duration(milliseconds: 450));
        expect(controller.value(midHold), closeTo(0.5, error));

        // trailHold: 100..200 hold at 1 (100ms, not 200ms!), 200..300 1->0.
        controller.scrubTo(const Duration(milliseconds: 150));
        expect(controller.value(trailHold), closeTo(1.0, error));
        controller.scrubTo(const Duration(milliseconds: 250));
        expect(controller.value(trailHold), closeTo(0.5, error));

        // interiorHold: holds at 0.5 both going up (150ms) and down (450ms).
        controller.scrubTo(const Duration(milliseconds: 150));
        expect(controller.value(interiorHold), closeTo(0.5, error));
        controller.scrubTo(const Duration(milliseconds: 350));
        expect(controller.value(interiorHold), closeTo(0.75, error));
        controller.scrubTo(const Duration(milliseconds: 450));
        expect(controller.value(interiorHold), closeTo(0.5, error));
        controller.scrubTo(const Duration(milliseconds: 550));
        expect(controller.value(interiorHold), closeTo(0.25, error));
      },
    );

    testWidgets(
      '.none plays once (ignoring count) and finite count loops exit into '
      'following steps and settle their MotionFuture',
      (tester) async {
        final once = Track<double>(MotionConverter.single, initial: 0);
        final shake = Track<double>(MotionConverter.single, initial: 0);
        final bounce = Track<double>(MotionConverter.single, initial: 0);

        final controller = TrackController(vsync: tester);
        addTearDown(controller.dispose);

        final future = controller.animate([
          once([
            const TrackStep.loop(
              [
                TrackStep.to(1, motion: linear100),
                TrackStep.to(0, motion: linear100),
              ],
              mode: LoopMode.none,
              count: 5,
            ),
            const TrackStep.to(2, motion: linear100),
          ]),
          // 2 cycles of (-1 -> 1) = 400ms, then settle to 0 (100ms) = 500ms.
          shake([
            const TrackStep.loop(
              [
                TrackStep.to(-1, motion: linear100),
                TrackStep.to(1, motion: linear100),
              ],
              count: 2,
            ),
            const TrackStep.to(0, motion: linear100),
          ]),
          // 2 full pingPong round-trips (0->1->0, 0->1->0) = 400ms, then -> 2.
          bounce([
            const TrackStep.loop(
              [
                TrackStep.to(0, motion: linear100),
                TrackStep.to(1, motion: linear100),
              ],
              mode: LoopMode.pingPong,
              count: 2,
            ),
            const TrackStep.to(2, motion: linear100),
          ]),
        ]);

        var settled = false;
        future.then((_) => settled = true);

        controller.pause();
        // once: 0..100 (0->1), 100..200 (1->0), 200..300 (0->2).
        controller.scrubTo(const Duration(milliseconds: 250));
        expect(controller.value(once), closeTo(1.0, error));
        controller.scrubTo(const Duration(milliseconds: 300));
        expect(controller.value(once), closeTo(2.0, error));

        // shake: 0..400ms loops, 400..500ms returns 1 -> 0.
        controller.scrubTo(const Duration(milliseconds: 450));
        expect(controller.value(shake), closeTo(0.5, error));
        controller.scrubTo(const Duration(milliseconds: 500));
        expect(controller.value(shake), closeTo(0.0, error));

        // bounce: 0..400ms two round-trips, 400..500ms 0 -> 2.
        controller.scrubTo(const Duration(milliseconds: 450));
        expect(controller.value(bounce), closeTo(1.0, error));
        controller.scrubTo(const Duration(milliseconds: 501));
        expect(controller.value(bounce), closeTo(2.0, error));

        await tester.idle();
        expect(settled, isTrue);
      },
    );
  });

  group('TrackStep.loop together lockstep', () {
    testWidgets(
      'loops sharing a together token wait for each other each cycle, '
      'finite loops release siblings cleanly on exit, and unrelated tracks '
      'are never blocked',
      (tester) async {
        final fast = Track<double>(MotionConverter.single, initial: 0);
        final slow = Track<double>(MotionConverter.single, initial: 0);
        final finite = Track<double>(MotionConverter.single, initial: 0);
        final solo = Track<double>(MotionConverter.single, initial: 0);
        final pulse = Object();

        final controller = TrackController(vsync: tester);
        addTearDown(controller.dispose);

        controller.animate([
          // Fast loop: 200ms per cycle, synced with slow (400ms) and finite.
          fast([
            TrackStep.loop(
              const [
                TrackStep.to(1, motion: linear100),
                TrackStep.to(0, motion: linear100),
              ],
              together: pulse,
            ),
          ]),
          // Slow loop: 400ms per cycle.
          slow([
            TrackStep.loop(
              const [
                TrackStep.to(1, motion: linear200),
                TrackStep.to(0, motion: linear200),
              ],
              together: pulse,
            ),
          ]),
          // Exits after 1 cycle into a long 1s move: must NOT deadlock fast &
          // slow on cycle 2!
          finite([
            TrackStep.loop(
              const [
                TrackStep.to(1, motion: linear100),
                TrackStep.to(0, motion: linear100),
              ],
              count: 1,
              together: pulse,
            ),
            const TrackStep.to(
              10,
              motion: Motion.linear(Duration(seconds: 1)),
            ),
          ]),
          // Unrelated track without together: runs at its own 200ms pace.
          solo([
            const TrackStep.loop([
              TrackStep.to(1, motion: linear100),
              TrackStep.to(0, motion: linear100),
            ]),
          ]),
        ]);

        controller.pause();

        // At 300ms: fast finished its 200ms cycle and is waiting at 0 for slow;
        // solo is already halfway through cycle 2 (at 1.0!).
        controller.scrubTo(const Duration(milliseconds: 300));
        expect(controller.value(fast), closeTo(0.0, error));
        expect(controller.value(slow), closeTo(0.5, error));
        expect(controller.value(solo), closeTo(1.0, error));

        // At 400ms: slow arrives, barrier releases!
        // At 450ms: fast & slow start cycle 2 together, while finite has moved
        // on to its 1s post-loop step without blocking them.
        controller.scrubTo(const Duration(milliseconds: 450));
        expect(controller.value(fast), closeTo(0.5, error));
        expect(controller.value(slow), closeTo(0.25, error));
        expect(controller.value(finite), closeTo(0.5, error));

        // At 850ms (cycle 3, while finite is STILL animating its 1s step!):
        // fast & slow keep cycling cleanly without deadlocking on finite.
        controller.scrubTo(const Duration(milliseconds: 850));
        expect(controller.value(fast), closeTo(0.5, error));
        expect(controller.value(slow), closeTo(0.25, error));
        expect(controller.value(finite), closeTo(4.5, error));
      },
    );

    testWidgets(
      'pingPong loops sharing a together token sync at turnaround and '
      'cycle end',
      (tester) async {
        final fast = Track<double>(MotionConverter.single, initial: 0);
        final slow = Track<double>(MotionConverter.single, initial: 0);
        final pulse = Object();

        final controller = TrackController(vsync: tester);
        addTearDown(controller.dispose);

        controller.animate([
          fast([
            TrackStep.loop(
              const [
                TrackStep.to(0, motion: linear100),
                TrackStep.to(1, motion: linear100),
              ],
              mode: LoopMode.pingPong,
              together: pulse,
            ),
          ]),
          slow([
            TrackStep.loop(
              const [
                TrackStep.to(0, motion: linear200),
                TrackStep.to(1, motion: linear200),
              ],
              mode: LoopMode.pingPong,
              together: pulse,
            ),
          ]),
        ]);

        controller.pause();
        // At 150ms: fast reached 1 at 100ms and waits at turnaround for slow.
        controller.scrubTo(const Duration(milliseconds: 150));
        expect(controller.value(fast), closeTo(1.0, error));
        expect(controller.value(slow), closeTo(0.75, error));

        // At 250ms: both turned around together at 200ms.
        controller.scrubTo(const Duration(milliseconds: 250));
        expect(controller.value(fast), closeTo(0.5, error));
        expect(controller.value(slow), closeTo(0.75, error));

        // At 350ms: fast reached 0 at 300ms and waits at cycle end for slow.
        controller.scrubTo(const Duration(milliseconds: 350));
        expect(controller.value(fast), closeTo(0.0, error));
        expect(controller.value(slow), closeTo(0.25, error));

        // At 450ms: both started cycle 2 together at 400ms.
        controller.scrubTo(const Duration(milliseconds: 450));
        expect(controller.value(fast), closeTo(0.5, error));
        expect(controller.value(slow), closeTo(0.25, error));
      },
    );

    testWidgets(
      'zero-duration barrier loop does not spin across frames',
      (tester) async {
        final a = Track<double>(MotionConverter.single, initial: 1);
        final b = Track<double>(MotionConverter.single, initial: 1);
        final token = Object();
        var stepCallbacks = 0;

        final controller = TrackController(vsync: tester);
        addTearDown(controller.dispose);

        controller.animate(
          [
            a([
              TrackStep.loop(
                const [TrackStep.to(1, motion: linear100)],
                together: token,
              ),
            ]),
            b([
              TrackStep.loop(
                const [TrackStep.to(1, motion: linear100)],
                together: token,
              ),
            ]),
          ],
          onStep: (_, __) => stepCallbacks++,
        );

        await tester.pump();
        final afterFirst = stepCallbacks;
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        // Must not keep firing 100 barrier passes every single frame.
        expect(stepCallbacks - afterFirst, lessThan(10));
        controller.stop(canceled: true);
      },
    );
  });

  group('TrackBuilder mixing looping and non-looping tracks', () {
    testWidgets(
      'one TrackBuilder runs a one-shot track alongside a looping track '
      'without restarting the loop when another track updates',
      (tester) async {
        final appear = Track<double>(MotionConverter.single, initial: 0);
        final pulse = Track<double>(MotionConverter.single, initial: 1);
        var target = 0.0;
        late StateSetter setHostState;
        late TrackValueReader reader;

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              setHostState = setState;
              return TrackBuilder(
                animations: [
                  appear([TrackStep.to(target, motion: linear100)]),
                  pulse([
                    const TrackStep.loop([
                      TrackStep.to(0.5, motion: linear200),
                      TrackStep.to(1, motion: linear200),
                    ]),
                  ]),
                ],
                builder: (context, value, _) {
                  reader = value;
                  return const SizedBox();
                },
              );
            },
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(reader(pulse), closeTo(0.75, 0.02));

        // Redirecting `appear` must leave `pulse` mid-cycle without resetting.
        setHostState(() => target = 1.0);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(reader(appear), closeTo(1.0, error));
        expect(reader(pulse), closeTo(0.5, 0.02));
      },
    );
  });

  group('PhaseTrackController rebuilt on TrackStep.loop', () {
    testWidgets(
      'looping phases advance across cycle wraps at until: .ended with '
      'momentum (no spring settling tail) and support scrubTo across cycles',
      (tester) async {
        final x = Track<double>(MotionConverter.single, initial: 0);
        final controller = PhaseTrackController<String>(vsync: tester);
        addTearDown(controller.dispose);

        const spring = CupertinoMotion.bouncy(
          duration: Duration(milliseconds: 200),
        );
        final transitions = <PhaseTransition<String>>[];

        controller.playPhases(
          TrackPhaseTimeline(
            {
              'a': [
                x([
                  const TrackStep.to(
                    100,
                    motion: spring,
                    until: WaitUntil.ended,
                  ),
                ]),
              ],
              'b': [
                x([
                  const TrackStep.to(
                    0,
                    motion: spring,
                    until: WaitUntil.ended,
                  ),
                ]),
              ],
            },
            loop: LoopMode.loop,
          ),
          onTransition: transitions.add,
        );

        await tester.pump();
        // Each phase lasts exactly 200ms (spring.duration), NOT ~500ms settle.
        // After 650ms we must be in phase 'b' of cycle 2 (a@0, b@200, a@400,
        // b@600).
        for (var i = 0; i < 65; i++) {
          await tester.pump(const Duration(milliseconds: 10));
        }

        expect(
          transitions,
          const [
            PhaseTransitioning(from: 'a', to: 'b'),
            PhaseTransitioning(from: 'b', to: 'a'),
            PhaseTransitioning(from: 'a', to: 'b'),
          ],
        );
        expect(controller.currentPhase, 'b');

        // Scrubbing works seamlessly across multiple loop cycles.
        controller.pause();
        controller.scrubTo(const Duration(milliseconds: 1000));
        expect(controller.value(x), isNotNaN);
        controller.scrubTo(const Duration(milliseconds: 100));
        expect(controller.value(x), greaterThan(0));
      },
    );

    testWidgets(
      'pingPong and seamless phase loops work with exact timing and '
      'finite .loop steps nested inside a phase',
      (tester) async {
        final x = Track<double>(MotionConverter.single, initial: 0);
        final controller = PhaseTrackController<String>(vsync: tester);
        addTearDown(controller.dispose);

        // 1. PingPong with a nested finite loop inside phase 'a':
        //    'a' wiggles 0->1->0 twice (200ms), 'b' moves to 2 (100ms),
        //    'c' moves to 3 (100ms), then reverse visits 'b' (playing forward)
        //    then 'a' (playing forward).
        final pingTransitions = <PhaseTransition<String>>[];
        controller.playPhases(
          TrackPhaseTimeline(
            {
              'a': [
                x([
                  const TrackStep.loop(
                    [
                      TrackStep.to(
                        1,
                        motion: Motion.linear(Duration(milliseconds: 50)),
                      ),
                      TrackStep.to(
                        0,
                        motion: Motion.linear(Duration(milliseconds: 50)),
                      ),
                    ],
                    count: 2,
                  ),
                ]),
              ],
              'b': [
                x([const TrackStep.to(2, motion: linear100)]),
              ],
              'c': [
                x([const TrackStep.to(3, motion: linear100)]),
              ],
            },
            loop: LoopMode.pingPong,
          ),
          onTransition: pingTransitions.add,
        );

        await tester.pump();
        // a(200) -> b(100) -> c(100) -> b(100) -> a(200) -> b(100) = 800ms.
        for (var i = 0; i < 75; i++) {
          await tester.pump(const Duration(milliseconds: 10));
        }

        expect(
          pingTransitions,
          const [
            PhaseTransitioning(from: 'a', to: 'b'),
            PhaseTransitioning(from: 'b', to: 'c'),
            PhaseTransitioning(from: 'c', to: 'b'),
            PhaseTransitioning(from: 'b', to: 'a'),
            PhaseTransitioning(from: 'a', to: 'b'),
          ],
        );

        // 2. Seamless phase loop jumps to phase 'start' resting value (0) and
        //    continues with 'end' (360) without stalling.
        final seamlessTransitions = <PhaseTransition<String>>[];
        final angle = Track<double>(MotionConverter.single, initial: 0);
        controller.playPhases(
          TrackPhaseTimeline(
            {
              'start': [
                angle([const TrackStep.to(0, motion: linear100)]),
              ],
              'end': [
                angle([const TrackStep.to(360, motion: linear100)]),
              ],
            },
            loop: LoopMode.seamless,
          ),
          onTransition: seamlessTransitions.add,
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));
        expect(controller.value(angle), closeTo(180, 1));
        expect(
          seamlessTransitions,
          const [
            PhaseTransitioning(from: 'start', to: 'end'),
            PhaseTransitioning(from: 'end', to: 'start'),
            PhaseTransitioning(from: 'start', to: 'end'),
          ],
        );
        controller.stop(canceled: true);
      },
    );
  });

  group('Stalled loops settle instead of ticking forever', () {
    testWidgets(
      'single-step, identical-target, settled-free, and zero-duration loops '
      'stop ticking and notifying listeners once nothing can change',
      (tester) async {
        final track = Track<double>(MotionConverter.single, initial: 0);
        final controller = TrackController(vsync: tester);
        addTearDown(controller.dispose);

        var notifications = 0;
        controller.addListener(() => notifications++);

        Future<void> expectSettlesCleanly(
          String label,
          TrackAnimation<double> animation, {
          double? expectedValue,
          Duration settleWindow = const Duration(milliseconds: 250),
        }) async {
          controller.set([track.value(0)]);
          var settled = false;
          final future = controller.animate([animation]);
          future.then((_) => settled = true);

          await tester.pump();
          for (var t = Duration.zero;
              t < settleWindow;
              t += const Duration(milliseconds: 16)) {
            await tester.pump(const Duration(milliseconds: 16));
          }

          if (expectedValue != null) {
            expect(
              controller.value(track),
              closeTo(expectedValue, 1e-2),
              reason: '$label value',
            );
          }
          expect(controller.isAnimating, isFalse, reason: '$label isAnimating');
          expect(settled, isTrue, reason: '$label settled');

          final countAfterSettle = notifications;
          for (var i = 0; i < 10; i++) {
            await tester.pump(const Duration(milliseconds: 16));
          }
          expect(
            notifications,
            countAfterSettle,
            reason: '$label should stop notifying listeners after settling',
          );
        }

        // Single-step loop in every repeating mode animates once then settles.
        for (final mode in [
          LoopMode.loop,
          LoopMode.pingPong,
          LoopMode.seamless,
        ]) {
          await expectSettlesCleanly(
            'single-step $mode',
            track([
              TrackStep.loop(
                const [TrackStep.to(1, motion: linear100)],
                mode: mode,
              ),
            ]),
            expectedValue: 1,
          );
        }

        // Identical targets have nowhere else to move after reaching 1.
        await expectSettlesCleanly(
          'identical targets',
          track([
            const TrackStep.loop([
              TrackStep.to(1, motion: linear100),
              TrackStep.to(1, motion: linear100),
            ]),
          ]),
          expectedValue: 1,
        );

        // Single-step free loop coasts to rest then settles.
        await expectSettlesCleanly(
          'single-step free',
          track(
            const [
              TrackStep.loop([
                TrackStep.free(motion: FrictionMotion(drag: 0.1)),
              ]),
            ],
            withVelocity: 10,
          ),
          settleWindow: const Duration(seconds: 5),
        );
        expect(controller.value(track), greaterThan(0));

        // Zero-duration hold loop settles immediately.
        await expectSettlesCleanly(
          'zero-duration hold',
          track([
            const TrackStep.loop([TrackStep.hold(Duration.zero)]),
          ]),
          expectedValue: 0,
        );
      },
    );
  });

  group('TrackStep.loop from: anchor', () {
    testWidgets(
      'seamless, pingPong (with together turnaround), loop, and count work '
      'with a single step + from:, without shifting onStep indices',
      (tester) async {
        final controller = TrackController(vsync: tester);
        addTearDown(controller.dispose);

        // 1. Seamless: from: 0 with single .to(1) loops 0 -> 1 ~> 0 -> 1.
        final shimmer = Track<double>(MotionConverter.single, initial: 0.5);
        final entered = <int>[];
        controller.animate(
          [
            shimmer([
              const TrackStep.loop(
                [TrackStep.to(1, motion: linear100)],
                from: 0,
                mode: LoopMode.seamless,
              ),
            ]),
          ],
          onStep: (_, index) => entered.add(index),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(controller.value(shimmer), closeTo(0.5, 1e-2));
        await tester.pump(const Duration(milliseconds: 100)); // t = 150ms
        expect(controller.value(shimmer), closeTo(0.5, 1e-2));
        expect(entered, [0, 0]);
        controller.stop(canceled: true);

        // 2. PingPong with from: 0 + together: bounces 0 -> 1 -> 0 and
        //    synchronizes turnaround with a sibling loop.
        final fast = Track<double>(MotionConverter.single, initial: 0);
        final slow = Track<double>(MotionConverter.single, initial: 0);
        controller.animate([
          fast([
            const TrackStep.loop(
              [TrackStep.to(1, motion: linear100)],
              from: 0,
              mode: LoopMode.pingPong,
              together: #bounce,
            ),
          ]),
          slow([
            const TrackStep.loop(
              [
                TrackStep.to(
                  1,
                  motion: Motion.linear(Duration(milliseconds: 200)),
                ),
              ],
              from: 0,
              mode: LoopMode.pingPong,
              together: #bounce,
            ),
          ]),
        ]);
        await tester.pump();
        // At 150ms, fast reached 1 at 100ms and must hold at 1 until slow
        // arrives at 200ms (turnaround barrier).
        await tester.pump(const Duration(milliseconds: 150));
        expect(controller.value(fast), closeTo(1, 1e-2));
        expect(controller.value(slow), closeTo(0.75, 1e-2));
        // At 250ms (50ms into reverse leg), fast is halfway back to 0.
        await tester.pump(const Duration(milliseconds: 100));
        expect(controller.value(fast), closeTo(0.5, 1e-2));
        expect(controller.value(slow), closeTo(0.75, 1e-2));
        controller.stop(canceled: true);

        // 3. Finite count: 2 with from: 0 exits cleanly into following step.
        final bell = Track<double>(MotionConverter.single, initial: 0.8);
        var settled = false;
        controller
            .animate([
              bell([
                const TrackStep.loop(
                  [TrackStep.to(1, motion: linear100)],
                  from: 0,
                  mode: LoopMode.pingPong,
                  count: 2,
                ),
                const TrackStep.to(0.25, motion: linear100),
              ]),
            ])
            .then((_) => settled = true);
        await tester.pump();
        // 2 pingPong cycles = 400ms, then 0 -> 0.25 (100ms) = 500ms.
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(settled, isTrue);
        expect(controller.value(bell), closeTo(0.25, 1e-2));
      },
    );
  });

  group('TrackBuilder in-place motion updates', () {
    testWidgets(
      'updating LinearMotion duration every frame inside a seamless loop '
      'keeps phase continuity at the true new speed without snapping or '
      'restarting (including after folding)',
      (tester) async {
        final progress = Track<double>(MotionConverter.single, initial: 0);
        var current = 0.0;

        Widget build(Duration lapDuration) => TrackBuilder(
              animations: [
                progress([
                  TrackStep.loop(
                    [TrackStep.to(1, motion: Motion.linear(lapDuration))],
                    from: 0,
                    mode: LoopMode.seamless,
                  ),
                ]),
              ],
              builder: (context, value, child) {
                current = value(progress);
                return const SizedBox();
              },
            );

        // Start at 1000ms per lap (speed 1.0/s) and run 2.25s so the loop
        // has already folded before we start changing duration.
        await tester.pumpWidget(build(const Duration(milliseconds: 1000)));
        await tester.pump();
        for (var i = 0; i < 45; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(current, closeTo(0.25, 0.02));

        // Now change duration every 16ms frame (250ms per lap => 4.0/s).
        // Over 10 frames (160ms), progress should advance by ~0.64 (from ~0.25
        // to ~0.89) with zero snap back to 0 and no exponential slowdown.
        var previous = current;
        for (var i = 0; i < 10; i++) {
          final lapMs = 250 + (i % 2) * 2; // changes every single frame
          await tester.pumpWidget(build(Duration(milliseconds: lapMs)));
          await tester.pump(const Duration(milliseconds: 16));
          expect(
            current,
            greaterThan(previous + 0.05),
            reason: 'frame $i should advance at ~4/s without Zeno slowdown',
          );
          previous = current;
        }
        expect(current, closeTo(0.89, 0.04));

        // Pump 100ms more: wraps seamlessly past 1.0 into the next lap.
        await tester.pump(const Duration(milliseconds: 100));
        expect(current, closeTo(0.29, 0.05));
      },
    );

    testWidgets(
      'swapping a spring motion mid-sequence stays on the current step '
      'and idle settled animations do not restart on motion-only rebuilds',
      (tester) async {
        final x = Track<double>(MotionConverter.single, initial: 0);
        final entered = <int>[];
        var current = 0.0;

        Widget build(Motion secondMotion) => TrackBuilder(
              onStep: (_, step) => entered.add(step),
              animations: [
                x([
                  const TrackStep.to(100, motion: linear100),
                  TrackStep.to(200, motion: secondMotion),
                ]),
              ],
              builder: (context, value, child) {
                current = value(x);
                return const SizedBox();
              },
            );

        await tester.pumpWidget(build(const Motion.smoothSpring()));
        await tester.pump();
        // Finish step 0 (100ms) and advance 80ms into step 1.
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 80));
        expect(entered, [0, 1]);
        final midStep1 = current;
        expect(midStep1, greaterThan(105));
        expect(midStep1, lessThan(195));

        // Swap step 1's motion to a bouncy spring mid-flight: must NOT restart
        // step 0 or jump value.
        await tester.pumpWidget(build(const Motion.bouncySpring()));
        expect(current, closeTo(midStep1, 1e-6));
        expect(entered, [0, 1]);

        await tester.pumpAndSettle();
        expect(current, closeTo(200, 1e-3));
        expect(entered, [0, 1]);

        // Once settled, changing motion again does not restart the animation.
        await tester.pumpWidget(build(const Motion.snappySpring()));
        await tester.pump(const Duration(milliseconds: 50));
        expect(current, closeTo(200, 1e-3));
        expect(entered, [0, 1]);
      },
    );
  });

  group('TrackBuilder(active: false) and start value precedence', () {
    testWidgets(
      'respects animation.from > initialValues > Track.initial on inactive '
      'mount and restartTrigger replay',
      (tester) async {
        final withInitial = Track<double>(MotionConverter.single, initial: 0);
        final withoutInitial = Track<double>(MotionConverter.single);
        final withFrom = Track<double>(MotionConverter.single, initial: 0);
        final velocitySeeded = Track<double>(
          MotionConverter.single,
          initial: 0,
        );

        var a = -1.0;
        var b = -1.0;
        var c = -1.0;
        var dPeak = 0.0;

        Widget build({required bool active, int restart = 0}) => TrackBuilder(
              active: active,
              restartTrigger: restart,
              initialValues: [
                withInitial.value(1),
                withoutInitial.value(42),
                withFrom.value(10),
                velocitySeeded.velocity(200),
              ],
              animations: [
                withInitial([const TrackStep.to(2, motion: linear100)]),
                withoutInitial([const TrackStep.to(100, motion: linear100)]),
                withFrom(
                  [const TrackStep.to(100, motion: linear100)],
                  from: 50,
                ),
                velocitySeeded([
                  const TrackStep.to(0, motion: CupertinoMotion()),
                ]),
              ],
              builder: (context, value, child) {
                a = value(withInitial);
                b = value(withoutInitial);
                c = value(withFrom);
                if (value(velocitySeeded) > dPeak) {
                  dPeak = value(velocitySeeded);
                }
                return const SizedBox();
              },
            );

        // Mounted inactive: must honor initialValues (1 and 42) and let
        // animation.from (50) beat initialValues (10).
        await tester.pumpWidget(build(active: false));
        expect(a, 1);
        expect(b, 42);
        expect(c, 50);

        // Turning active plays from those exact start values, then restarting
        // preserves from > initialValues > Track.initial and keeps velocity.
        await tester.pumpWidget(build(active: true));
        await tester.pumpAndSettle();
        expect(a, closeTo(2, 1e-3));
        expect(c, closeTo(100, 1e-3));

        dPeak = 0;
        await tester.pumpWidget(build(active: true, restart: 1));
        expect(a, 1);
        expect(b, 42);
        expect(c, 50);
        await tester.pumpAndSettle();
        expect(dPeak, greaterThan(0.5));
      },
    );
  });

  group('TrackController dispose guard', () {
    testWidgets('animate after dispose asserts clearly', (tester) async {
      final track = Track<double>(MotionConverter.single, initial: 0);
      final controller = TrackController(vsync: tester)..dispose();

      expect(
        () => controller.animate([
          track([const TrackStep.to(1, motion: linear100)]),
        ]),
        throwsAssertionError,
      );
    });
  });
}
