// ignore_for_file: cascade_invocations, unawaited_futures
// ignore_for_file: prefer_const_constructors

import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:motor/src/simulations/step_playback.dart';

void main() {
  const linear100 = Motion.linear(Duration(milliseconds: 100));
  const linear200 = Motion.linear(Duration(milliseconds: 200));

  group('Per-dimension motion in StepPlayback', () {
    test('step motionPerDimension drives each dimension with its own motion',
        () {
      final playback = StepPlayback<Offset>(
        steps: [
          Step.to(
            const Offset(1, 1),
            motionPerDimension: const [linear100, linear200],
          ),
        ],
        converter: MotionConverter.offset,
        start: Offset.zero,
      );

      // At 100ms the fast (x) dimension is done while the slow (y) one is only
      // halfway.
      playback.advanceTo(0.1);
      expect(playback.values[0], closeTo(1, 1e-3));
      expect(playback.values[1], closeTo(0.5, 1e-2));

      playback.advanceTo(0.2);
      expect(playback.values[1], closeTo(1, 1e-3));
    });

    test('fallbackMotionPerDimension is used when a step omits its motion', () {
      final playback = StepPlayback<Offset>(
        steps: [const Step.to(Offset(1, 1))],
        converter: MotionConverter.offset,
        start: Offset.zero,
        fallbackMotionPerDimension: const [linear100, linear200],
      );

      playback.advanceTo(0.1);
      expect(playback.values[0], closeTo(1, 1e-3));
      expect(playback.values[1], closeTo(0.5, 1e-2));
    });

    test('step motionPerDimension overrides the track fallback motion', () {
      final playback = StepPlayback<Offset>(
        steps: [
          Step.to(
            const Offset(1, 1),
            motionPerDimension: const [linear100, linear200],
          ),
        ],
        converter: MotionConverter.offset,
        start: Offset.zero,
        // A uniform fallback that would make both dimensions fast — the step's
        // per-dimension motion must win.
        fallbackMotion: linear100,
      );

      playback.advanceTo(0.1);
      expect(playback.values[1], closeTo(0.5, 1e-2));
    });

    test('a single step motion still applies to every dimension', () {
      final playback = StepPlayback<Offset>(
        steps: [const Step.to(Offset(1, 1), motion: linear100)],
        converter: MotionConverter.offset,
        start: Offset.zero,
      );

      playback.advanceTo(0.1);
      expect(playback.values[0], closeTo(1, 1e-3));
      expect(playback.values[1], closeTo(1, 1e-3));
    });

    test('loop replays with per-dimension motion', () {
      final playback = StepPlayback<Offset>(
        steps: [
          Step.to(
            const Offset(1, 1),
            motionPerDimension: const [linear100, linear200],
          ),
        ],
        converter: MotionConverter.offset,
        start: Offset.zero,
        loop: LoopMode.loop,
      );

      playback.advanceTo(0.1);
      playback.advanceTo(0.3);
      playback.advanceTo(0.6);
      expect(playback.isDone, isFalse);
    });

    test('pingPong reverses with per-dimension motion', () {
      final playback = StepPlayback<Offset>(
        steps: [
          Step.to(
            const Offset(1, 1),
            motionPerDimension: const [linear100, linear200],
          ),
        ],
        converter: MotionConverter.offset,
        start: Offset.zero,
        loop: LoopMode.pingPong,
      );

      playback.advanceTo(0.2);
      playback.advanceTo(0.4);
      expect(playback.isDone, isFalse);
    });
  });

  group('Per-dimension motion on Track', () {
    testWidgets('Track.motionPerDimension default drives dimensions separately',
        (tester) async {
      final controller = TrackController(vsync: tester);
      addTearDown(controller.dispose);

      final position = Track<Offset>.motionPerDimension(
        MotionConverter.offset,
        origin: Offset.zero,
        motionPerDimension: const [linear100, linear200],
      );

      controller.animate([position.to(const Offset(1, 1))]);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final value = controller.value(position);
      expect(value.dx, closeTo(1, 2e-2));
      expect(value.dy, closeTo(0.5, 5e-2));

      await tester.pumpAndSettle();
      expect(controller.value(position).dx, closeTo(1, 1e-3));
      expect(controller.value(position).dy, closeTo(1, 1e-3));
    });

    testWidgets('a per-step motion override beats the track default',
        (tester) async {
      final controller = TrackController(vsync: tester);
      addTearDown(controller.dispose);

      // Track default is uniformly fast; the step asks for a slow y.
      final position = Track<Offset>.motionPerDimension(
        MotionConverter.offset,
        origin: Offset.zero,
        motionPerDimension: const [linear100, linear100],
      );

      controller.animate([
        position.to(
          const Offset(1, 1),
          motionPerDimension: const [linear100, linear200],
        ),
      ]);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(controller.value(position).dy, closeTo(0.5, 5e-2));
      await tester.pumpAndSettle();
    });
  });

  group('Per-dimension motion step equality and validation', () {
    test('StepTo equality includes motionPerDimension', () {
      expect(
        Step.to(
          const Offset(1, 1),
          motionPerDimension: const [linear100, linear200],
        ),
        Step.to(
          const Offset(1, 1),
          motionPerDimension: const [linear100, linear200],
        ),
      );

      expect(
        Step.to(
          const Offset(1, 1),
          motionPerDimension: const [linear100, linear200],
        ),
        isNot(
          Step.to(
            const Offset(1, 1),
            motionPerDimension: const [linear100, linear100],
          ),
        ),
      );
    });

    test('Step.to asserts motion and motionPerDimension are exclusive', () {
      expect(
        () => Step.to(
          const Offset(1, 1),
          motion: linear100,
          motionPerDimension: const [linear100, linear200],
        ),
        throwsAssertionError,
      );
    });
  });
}
