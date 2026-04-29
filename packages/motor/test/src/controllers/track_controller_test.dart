import 'dart:math' as math;

// ignore_for_file: cascade_invocations, unawaited_futures

import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

import '../util.dart';

void main() {
  group('TrackController', () {
    late TrackController controller;
    final opacity = Track<double>(MotionConverter.single, initial: 0.0);
    final scale = Track<double>(MotionConverter.single, initial: 1.0);

    tearDown(() {
      controller.dispose();
    });

    testWidgets('resolves initial values from track declarations',
        (tester) async {
      controller = TrackController(vsync: tester);

      expect(controller, isA<Animation<TrackValueReader>>());
      expect(controller.value(opacity), equals(0));
      expect(controller.value(scale), equals(1));
    });

    testWidgets('resolves constructor from overrides', (tester) async {
      controller = TrackController(
        vsync: tester,
        from: [opacity.value(0.5)],
      );

      expect(controller.value(opacity), equals(0.5));
    });

    testWidgets('plays multiple tracks', (tester) async {
      controller = TrackController(vsync: tester);
      controller.play(
        TrackTimeline([
          opacity.to(
            1,
            motion: const Motion.linear(Duration(milliseconds: 100)),
          ),
          scale.to(
            2,
            motion: const Motion.linear(Duration(milliseconds: 100)),
          ),
        ]),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(controller.value(opacity), greaterThan(0));
      expect(controller.value(opacity), lessThan(1));
      expect(controller.value(scale), greaterThan(1));
      expect(controller.value(scale), lessThan(2));

      await tester.pumpAndSettle();

      expect(controller.value(opacity), closeTo(1, error));
      expect(controller.value(scale), closeTo(2, error));
      expect(controller.isAnimating, isFalse);
      expect(controller.status, AnimationStatus.completed);
    });

    testWidgets('uses timeline from overrides for lazy slots', (tester) async {
      controller = TrackController(vsync: tester);
      controller.play(
        TrackTimeline(
          [
            opacity.to(
              1.0,
              motion: const Motion.linear(Duration(milliseconds: 100)),
            ),
          ],
          from: [opacity.value(0.5)],
        ),
      );

      await tester.pump();
      expect(controller.value(opacity), equals(0.5));
      controller.stop(canceled: true);
    });

    testWidgets('calls onStep per track', (tester) async {
      controller = TrackController(vsync: tester);
      final calls = <(Track, int)>[];

      controller.play(
        TrackTimeline([
          opacity([
            const Step.to(
              1,
              motion: Motion.linear(Duration(milliseconds: 100)),
            ),
            const Step.to(
              0,
              motion: Motion.linear(Duration(milliseconds: 100)),
            ),
          ]),
        ]),
        onStep: (track, stepIndex) => calls.add((track, stepIndex)),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      expect(calls, containsAllInOrder([(opacity, 0), (opacity, 1)]));
    });

    testWidgets('loops timelines until stopped', (tester) async {
      controller = TrackController(vsync: tester);

      controller.play(
        TrackTimeline(
          [
            opacity.to(
              1,
              motion: const Motion.linear(Duration(milliseconds: 100)),
            ),
          ],
          loop: LoopMode.loop,
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(controller.isAnimating, isTrue);

      controller.stop(canceled: true);
      await tester.pump();
      expect(controller.isAnimating, isFalse);
    });

    testWidgets('playing a new timeline leaves unrelated tracks running',
        (tester) async {
      controller = TrackController(vsync: tester);
      controller.play(
        TrackTimeline(
          [
            opacity.to(
              1,
              motion: const Motion.linear(Duration(milliseconds: 100)),
            ),
          ],
          loop: LoopMode.loop,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(controller.isAnimating, isTrue);

      // Playing a different track does not stop the looping opacity track.
      controller.play(
        TrackTimeline([
          scale.to(
            2,
            motion: const Motion.linear(Duration(milliseconds: 100)),
          ),
        ]),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The scale track reached its target while opacity keeps looping.
      expect(controller.value(scale), closeTo(2, error));
      expect(controller.isAnimating, isTrue);

      controller.stop(canceled: true);
      await tester.pump();
      expect(controller.isAnimating, isFalse);
    });

    testWidgets('animating a track does not interrupt another running track',
        (tester) async {
      controller = TrackController(vsync: tester);
      const motion = Motion.linear(Duration(milliseconds: 200));

      controller.animate([opacity.to(1, motion: motion)]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final opacityMidway = controller.value(opacity);
      expect(opacityMidway, greaterThan(0));
      expect(opacityMidway, lessThan(1));

      // Animating a second track must not cancel the first.
      controller.animate([scale.to(2, motion: motion)]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Opacity kept progressing toward its target rather than freezing.
      expect(controller.value(opacity), greaterThan(opacityMidway));
      expect(controller.value(scale), greaterThan(1));

      await tester.pumpAndSettle();
      expect(controller.value(opacity), closeTo(1, error));
      expect(controller.value(scale), closeTo(2, error));
    });

    testWidgets('stop with tracks halts only the listed tracks',
        (tester) async {
      controller = TrackController(vsync: tester);
      const motion = Motion.linear(Duration(milliseconds: 200));

      controller.animate([
        opacity.to(1, motion: motion),
        scale.to(2, motion: motion),
      ]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final scaleWhenStopped = controller.value(scale);
      controller.stop(tracks: [scale], canceled: true);

      // The controller is still animating opacity.
      expect(controller.isAnimating, isTrue);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Scale froze where it was stopped; opacity continued.
      expect(controller.value(scale), closeTo(scaleWhenStopped, error));
      expect(controller.value(opacity), greaterThan(0));

      await tester.pumpAndSettle();
      expect(controller.value(opacity), closeTo(1, error));
      expect(controller.value(scale), closeTo(scaleWhenStopped, error));
    });

    testWidgets(
        'sequential animate calls after a settle start without a stale delay',
        (tester) async {
      controller = TrackController(vsync: tester);
      const motion = Motion.linear(Duration(milliseconds: 100));

      // Run a track to completion so the ticker stops with a large elapsed.
      controller.animate([opacity.to(1, motion: motion)]);
      await tester.pump();
      await tester.pumpAndSettle();
      expect(controller.isAnimating, isFalse);
      expect(controller.value(opacity), closeTo(1, error));

      // Two animate calls in the same frame: the first restarts the stopped
      // ticker, the second must not inherit a stale elapsed start offset.
      controller.animate([opacity.to(0, motion: motion)]);
      controller.animate([scale.to(2, motion: motion)]);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Both tracks are progressing at the halfway mark, not frozen waiting
      // for the ticker to catch up to a stale offset.
      expect(controller.value(opacity), lessThan(1));
      expect(controller.value(opacity), greaterThan(0));
      expect(controller.value(scale), greaterThan(1));
      expect(controller.value(scale), lessThan(2));

      await tester.pumpAndSettle();
      expect(controller.value(opacity), closeTo(0, error));
      expect(controller.value(scale), closeTo(2, error));
    });

    testWidgets('redirects from current value and velocity', (tester) async {
      controller = TrackController(vsync: tester);
      const motion = Motion.smoothSpring(duration: Duration(milliseconds: 500));

      controller.play(
        TrackTimeline([
          opacity.to(1.0, motion: motion),
        ]),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      final redirectedFrom = controller.value(opacity);
      final redirectedVelocity = controller.velocity(opacity);

      controller.play(
        TrackTimeline([
          opacity.to(2.0, motion: motion),
        ]),
      );

      expect(controller.value(opacity), closeTo(redirectedFrom, error));
      expect(
        controller.velocity(opacity),
        closeTo(redirectedVelocity, error),
      );
      controller.stop(canceled: true);
    });

    testWidgets('settles interrupted tap playground reset at zero rotation',
        (tester) async {
      controller = TrackController(vsync: tester);
      final rotation = Track<double>(MotionConverter.single, initial: 0.0);
      const motion = Motion.smoothSpring(duration: Duration(milliseconds: 420));

      controller.play(
        TrackTimeline([
          rotation.to(math.pi / 10, motion: motion),
        ]),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      controller.play(
        TrackTimeline([
          rotation.to(0.0, motion: motion),
        ]),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(controller.isAnimating, isFalse);
      expect(controller.value(rotation), closeTo(0.0, error));
    });

    testWidgets('reports timeline-scoped status', (tester) async {
      controller = TrackController(vsync: tester);
      final statuses = <AnimationStatus>[];
      controller.addStatusListener(statuses.add);

      controller.play(
        TrackTimeline([
          opacity.to(
            1,
            motion: const Motion.linear(Duration(milliseconds: 100)),
          ),
        ]),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(
        statuses,
        containsAllInOrder([
          AnimationStatus.forward,
          AnimationStatus.completed,
        ]),
      );
    });

    testWidgets('animates a single track imperatively', (tester) async {
      controller = TrackController(vsync: tester);
      controller.animate([
        opacity.to(
          1.0,
          motion: const Motion.linear(Duration(milliseconds: 100)),
        ),
      ]);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(controller.value(opacity), greaterThan(0));

      controller.stop(tracks: [opacity], canceled: true);
      await tester.pump();
      expect(controller.isAnimating, isFalse);
    });

    testWidgets('animate redirects from current track value', (tester) async {
      controller = TrackController(
        vsync: tester,
        from: [opacity.value(0.5)],
      );
      const motion = Motion.linear(Duration(milliseconds: 100));

      controller.play(
        TrackTimeline([
          opacity.to(0.8, motion: motion),
        ]),
      );
      await tester.pump();
      await tester.pumpAndSettle();
      expect(controller.value(opacity), closeTo(0.8, error));

      controller.animate([opacity.to(1.0, motion: motion)]);

      expect(controller.value(opacity), closeTo(0.8, error));
      controller.stop(canceled: true);
    });

    testWidgets('animate throws when given two animations for one track',
        (tester) async {
      controller = TrackController(vsync: tester);
      const motion = Motion.linear(Duration(milliseconds: 100));

      expect(
        () => controller.animate([
          opacity.to(1, motion: motion),
          opacity.to(0, motion: motion),
        ]),
        throwsA(isA<AssertionError>()),
      );
    });

    testWidgets('callable sequence on one track does not throw',
        (tester) async {
      controller = TrackController(vsync: tester);
      const motion = Motion.linear(Duration(milliseconds: 100));

      controller.animate([
        opacity([
          const Step.to(1, motion: motion),
          const Step.to(0, motion: motion),
        ]),
      ]);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(controller.value(opacity), greaterThan(0));

      controller.stop(canceled: true);
    });

    group('looping', () {
      const linear100 = Motion.linear(Duration(milliseconds: 100));

      testWidgets('LoopMode.loop resets to initial values each cycle',
          (tester) async {
        controller = TrackController(vsync: tester);

        controller.play(
          TrackTimeline(
            [
              opacity.to(1, motion: linear100),
            ],
            loop: LoopMode.loop,
          ),
        );

        await tester.pump();

        // First cycle: 0 -> 1
        await tester.pump(const Duration(milliseconds: 50));
        expect(controller.value(opacity), greaterThan(0));
        expect(controller.value(opacity), lessThan(1));

        await tester.pump(const Duration(milliseconds: 60));
        // After 110ms, first step is done and loop restarted.
        // Value should have reset toward 0 and be animating to 1 again.
        expect(controller.value(opacity), lessThan(1));
        expect(controller.isAnimating, isTrue);

        controller.stop(canceled: true);
      });

      testWidgets('LoopMode.loop with multi-step cycles through all steps',
          (tester) async {
        controller = TrackController(vsync: tester);

        controller.play(
          TrackTimeline(
            [
              opacity([
                const Step.to(0.5, motion: linear100),
                const Step.to(1.0, motion: linear100),
              ]),
            ],
            loop: LoopMode.loop,
          ),
        );

        await tester.pump();

        // Step 0: 0 -> 0.5 in 100ms
        await tester.pump(const Duration(milliseconds: 50));
        expect(controller.value(opacity), greaterThan(0));
        expect(controller.value(opacity), lessThan(0.5));

        // Step 1: 0.5 -> 1.0
        await tester.pump(const Duration(milliseconds: 60));
        expect(controller.value(opacity), greaterThan(0.4));

        // Let the cycle complete and loop restart
        await tester.pump(const Duration(milliseconds: 100));
        // After looping, value should have reset toward 0 and be
        // animating toward 0.5 again
        final v = controller.value(opacity);
        expect(v, lessThan(1.0));
        expect(controller.isAnimating, isTrue);

        controller.stop(canceled: true);
      });

      testWidgets('LoopMode.pingPong reverses direction at boundaries',
          (tester) async {
        controller = TrackController(vsync: tester);

        controller.play(
          TrackTimeline(
            [
              opacity([
                const Step.to(0.5, motion: linear100),
                const Step.to(1.0, motion: linear100),
              ]),
            ],
            loop: LoopMode.pingPong,
          ),
        );

        await tester.pump();

        // Forward pass: 0 -> 0.5 (100ms) then 0.5 -> 1.0 (100ms)
        await tester.pump(const Duration(milliseconds: 50));
        expect(controller.value(opacity), greaterThan(0));
        expect(controller.value(opacity), lessThan(0.5));

        await tester.pump(const Duration(milliseconds: 60));
        expect(controller.value(opacity), greaterThan(0.4));

        await tester.pump(const Duration(milliseconds: 100));
        // After 210ms total, forward pass is done. Reverse should have started.
        // In reverse: targets go 1.0 -> 0.5 -> 0.0
        // The value should still be above 0.5 (just started reversing)
        expect(controller.value(opacity), greaterThan(0.4));

        // Continue reverse
        await tester.pump(const Duration(milliseconds: 200));
        final afterReverse = controller.value(opacity);
        // After 410ms total: 200ms forward + 200ms reverse => near 0
        expect(afterReverse, lessThan(0.5));

        expect(controller.isAnimating, isTrue);
        controller.stop(canceled: true);
      });

      testWidgets(
          'LoopMode.pingPong single step oscillates between start and end',
          (tester) async {
        controller = TrackController(vsync: tester);

        controller.play(
          TrackTimeline(
            [opacity.to(1, motion: linear100)],
            loop: LoopMode.pingPong,
          ),
        );

        await tester.pump();

        // Forward: 0 -> 1 (100ms)
        await tester.pump(const Duration(milliseconds: 110));
        // Should be reversing now: animating back toward 0
        await tester.pump(const Duration(milliseconds: 50));
        expect(controller.value(opacity), lessThan(1));
        expect(controller.value(opacity), greaterThan(0));

        // Complete reverse, should go forward again
        await tester.pump(const Duration(milliseconds: 60));
        await tester.pump(const Duration(milliseconds: 50));
        expect(controller.value(opacity), greaterThan(0));

        expect(controller.isAnimating, isTrue);
        controller.stop(canceled: true);
      });

      testWidgets('LoopMode.seamless does not reset to initial values',
          (tester) async {
        controller = TrackController(vsync: tester);

        controller.play(
          TrackTimeline(
            [
              opacity([
                const Step.to(0.5, motion: linear100),
                const Step.to(1.0, motion: linear100),
              ]),
            ],
            loop: LoopMode.seamless,
          ),
        );

        await tester.pump();

        // After first cycle completes (200ms), the seamless wrap should NOT
        // jump back to 0. Instead, it continues from 1.0 toward step 0's
        // target (0.5).
        final values = <double>[];
        controller.addListener(() {
          values.add(controller.value(opacity));
        });

        await tester.pump(const Duration(milliseconds: 210));

        // Verify no value dropped back to ~0 (the initial value)
        for (final v in values) {
          expect(v, greaterThanOrEqualTo(-error));
        }

        expect(controller.isAnimating, isTrue);
        controller.stop(canceled: true);
      });

      testWidgets('looping catches up correctly after large elapsed gap',
          (tester) async {
        controller = TrackController(vsync: tester);

        controller.play(
          TrackTimeline(
            [opacity.to(1, motion: linear100)],
            loop: LoopMode.loop,
          ),
        );

        await tester.pump();

        // Simulate navigating away for 10 seconds
        await tester.pump(const Duration(seconds: 10));

        // Should still be animating and not stuck
        expect(controller.isAnimating, isTrue);

        // Value should be somewhere in [0, 1], not accumulated
        final v = controller.value(opacity);
        expect(v, greaterThanOrEqualTo(-error));
        expect(v, lessThanOrEqualTo(1 + error));

        controller.stop(canceled: true);
      });

      testWidgets(
          'looping does not accumulate timing drift over many cycles',
          (tester) async {
        controller = TrackController(vsync: tester);

        controller.play(
          TrackTimeline(
            [opacity.to(1, motion: linear100)],
            loop: LoopMode.loop,
          ),
        );

        await tester.pump();

        // Run many cycles: 100 cycles * 100ms = 10 seconds
        for (var i = 0; i < 100; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        expect(controller.isAnimating, isTrue);

        // Value should still be in valid range
        final v = controller.value(opacity);
        expect(v, greaterThanOrEqualTo(-error));
        expect(v, lessThanOrEqualTo(1 + error));

        controller.stop(canceled: true);
      });
    });
  });
}
