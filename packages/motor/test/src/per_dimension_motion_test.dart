// ignore_for_file: cascade_invocations, unawaited_futures
// ignore_for_file: prefer_const_constructors

import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:motor/src/simulations/step_playback.dart';

import 'util.dart';

void main() {
  const linear100 = Motion.linear(Duration(milliseconds: 100));
  const linear200 = Motion.linear(Duration(milliseconds: 200));
  const perDimension = TrackStep.to(
    Offset(1, 1),
    motionPerDimension: [linear100, linear200],
  );

  group('Per-dimension motion in StepPlayback', () {
    // At 100ms a fast (x) dimension is done while a slow (y) one is only
    // halfway. A segment ends when its slow dimension finishes (200ms), and
    // the way back reuses the per-dimension motions.
    for (final (name, step, loop, fallback, samples) in [
      (
        "a step's motionPerDimension drives each dimension",
        perDimension,
        LoopMode.none,
        null,
        [(0.1, Offset(1, 0.5)), (0.2, Offset(1, 1))],
      ),
      (
        'fallbackMotionPerDimension is used when a step omits its motion',
        TrackStep.to(Offset(1, 1)),
        LoopMode.none,
        [linear100, linear200],
        [(0.1, Offset(1, 0.5))],
      ),
      (
        'a single step motion still applies to every dimension',
        TrackStep.to(Offset(1, 1), motion: linear100),
        LoopMode.none,
        null,
        [(0.1, Offset(1, 1))],
      ),
      (
        'a loop replays with per-dimension motion',
        perDimension,
        LoopMode.loop,
        null,
        [
          (0.1, Offset(1, 0.5)),
          (0.25, Offset(0.5, 0.75)),
          (0.4, Offset.zero),
          (0.45, Offset(0.5, 0.25)),
        ],
      ),
      (
        'a pingPong reverses with per-dimension motion',
        perDimension,
        LoopMode.pingPong,
        null,
        [(0.2, Offset(1, 1)), (0.25, Offset(0.5, 0.75)), (0.4, Offset.zero)],
      ),
    ]) {
      test(name, () {
        final playback = StepPlayback<Offset>(
          steps: [step],
          converter: MotionConverter.offset,
          start: Offset.zero,
          loop: loop,
          fallbackMotionPerDimension: fallback,
        );
        for (final (seconds, value) in samples) {
          playback.advanceTo(seconds);
          expect(playback.values[0], closeTo(value.dx, error), reason: 'x');
          expect(playback.values[1], closeTo(value.dy, error), reason: 'y');
          if (loop.isLooping) expect(playback.isDone, isFalse);
        }
      });
    }

    test('step motionPerDimension overrides the track fallback motion', () {
      final playback = StepPlayback<Offset>(
        steps: [perDimension],
        converter: MotionConverter.offset,
        start: Offset.zero,
        // A uniform fallback that would make both dimensions fast — the step's
        // per-dimension motion must win.
        fallbackMotion: linear100,
      );

      playback.advanceTo(0.1);
      expect(playback.values[1], closeTo(0.5, error));
    });
  });

  testWidgets(
      "a Track's motionPerDimension drives dimensions separately, and a "
      "step's overrides it", (tester) async {
    final controller = TrackController(vsync: tester);
    addTearDown(controller.dispose);

    final position = Track<Offset>.motionPerDimension(
      MotionConverter.offset,
      initial: Offset.zero,
      motionPerDimension: const [linear100, linear200],
    );
    // Uniformly fast by default; the step asks for a slow y.
    final overridden = Track<Offset>.motionPerDimension(
      MotionConverter.offset,
      initial: Offset.zero,
      motionPerDimension: const [linear100, linear100],
    );

    controller.animate([
      position.to(const Offset(1, 1)),
      overridden.to(
        const Offset(1, 1),
        motionPerDimension: const [linear100, linear200],
      ),
    ]);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final value = controller.value(position);
    expect(value.dx, closeTo(1, 2e-2));
    expect(value.dy, closeTo(0.5, 5e-2));
    expect(controller.value(overridden).dy, closeTo(0.5, 5e-2));

    await tester.pumpAndSettle();
    expect(controller.value(position).dx, closeTo(1, 1e-3));
    expect(controller.value(position).dy, closeTo(1, 1e-3));
  });

  group('Per-dimension motion step equality and validation', () {
    test('StepTo equality includes motionPerDimension', () {
      expect(
        TrackStep.to(
          const Offset(1, 1),
          motionPerDimension: const [linear100, linear200],
        ),
        TrackStep.to(
          const Offset(1, 1),
          motionPerDimension: const [linear100, linear200],
        ),
      );

      expect(
        TrackStep.to(
          const Offset(1, 1),
          motionPerDimension: const [linear100, linear200],
        ),
        isNot(
          TrackStep.to(
            const Offset(1, 1),
            motionPerDimension: const [linear100, linear100],
          ),
        ),
      );
    });

    test('TrackStep.to asserts motion and motionPerDimension are exclusive',
        () {
      expect(
        () => TrackStep.to(
          const Offset(1, 1),
          motion: linear100,
          motionPerDimension: const [linear100, linear200],
        ),
        throwsAssertionError,
      );
    });
  });
}
