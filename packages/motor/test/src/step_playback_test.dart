// ignore_for_file: cascade_invocations

import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:motor/src/simulations/step_playback.dart';

import 'util.dart';

void main() {
  const linear100 = Motion.linear(Duration(milliseconds: 100));
  const linear200 = Motion.linear(Duration(milliseconds: 200));

  group('an .at step arrives exactly at its value and time', () {
    final motions = {
      'curve': const Motion.curved(Duration(milliseconds: 400), Curves.easeOut),
      'smooth spring': const Motion.smoothSpring(),
      'bouncy spring': const Motion.bouncySpring(),
    };
    for (final MapEntry(key: name, value: motion) in motions.entries) {
      test('with a $name', () {
        const arrival = Duration(milliseconds: 2400);
        final playback = StepPlayback<double>(
          steps: [
            const TrackStep.to(340, motion: Motion.bouncySpring()),
            TrackStep.at(arrival, 120, motion: motion),
          ],
          converter: MotionConverter.single,
          start: 0,
        );

        // Just before, it is already there, rather than jumping at the end.
        playback.advanceTo(2.399);
        expect(playback.values.single, closeTo(120, 0.05));
        playback.advanceTo(2.4);
        expect(playback.values.single, 120);
        playback.advanceTo(5);
        expect(playback.values.single, 120);
        expect(playback.isDone, isTrue);
      });
    }
  });

  test('a step after a curve inherits the slope the curve ended with', () {
    final playback = StepPlayback<double>(
      steps: const [
        TrackStep.to(10, motion: Motion.linear(Duration(seconds: 1))),
        TrackStep.to(10, motion: Motion.smoothSpring()),
      ],
      converter: MotionConverter.single,
      start: 0,
    );

    playback.advanceTo(0.5);
    expect(playback.velocities.single, closeTo(10, 1e-6));
    playback.advanceTo(1 + 1e-9);
    expect(playback.currentStepIndex, 1);
    expect(playback.velocities.single, closeTo(10, 1e-3));
  });

  group('a scaled spring', () {
    const spring = CupertinoMotion();

    test('ends exactly on its target', () {
      final playback = StepPlayback<double>(
        steps: [
          TrackStep.to(
            100,
            motion: spring.scaleTo(const Duration(milliseconds: 300)),
          ),
        ],
        converter: MotionConverter.single,
        start: 0,
      );
      playback.advanceTo(0.3);
      expect(playback.values.single, 100);
      expect(playback.isDone, isTrue);
    });

    test('with a zero duration jumps to its target', () {
      final playback = StepPlayback<double>(
        steps: [TrackStep.to(50, motion: spring.scaleTo(Duration.zero))],
        converter: MotionConverter.single,
        start: 0,
      );
      playback.advanceTo(0);
      expect(playback.values.single, 50);
      expect(playback.isDone, isTrue);
    });
  });

  test('pingPong returns over an instant .at step', () {
    const linear100 = Motion.linear(Duration(milliseconds: 100));
    final playback = StepPlayback<double>(
      steps: [
        const TrackStep.to(5, motion: linear100),
        // Arrives the moment the step before ends.
        TrackStep.at(
          const Duration(milliseconds: 100),
          10,
          motion: const CupertinoMotion().scaleTo(Duration.zero),
        ),
        const TrackStep.hold(Duration(milliseconds: 100)),
      ],
      converter: MotionConverter.single,
      start: 0,
      loop: LoopMode.pingPong,
    );

    // Back over the .at at 300 ms, then halfway from 5 to 0.
    playback.advanceTo(0.35);
    expect(playback.values.single, closeTo(2.5, error));
  });

  group('StepPlayback timeline construction', () {
    test('hold then to plays sequentially', () {
      final playback = StepPlayback<double>(
        steps: [
          const TrackStep.hold(Duration(milliseconds: 200)),
          const TrackStep.to(1.0, motion: linear100),
        ],
        converter: MotionConverter.single,
        start: 0.0,
      );

      // During the hold, value stays at 0.
      playback.advanceTo(0.1);
      expect(playback.values.first, closeTo(0.0, error));
      expect(playback.isDone, isFalse);

      // After hold completes (200ms), the to-step begins.
      playback.advanceTo(0.25);
      expect(playback.values.first, greaterThan(0.0));
      expect(playback.values.first, lessThan(1.0));

      // After both complete.
      playback.advanceTo(0.5);
      expect(playback.values.first, closeTo(1.0, error));
      expect(playback.isDone, isTrue);
    });

    test('TrackStep.at with valid future time plays correctly', () {
      final playback = StepPlayback<double>(
        steps: [
          const TrackStep.at(
            Duration(milliseconds: 200),
            1.0,
            motion: linear200,
          ),
        ],
        converter: MotionConverter.single,
        start: 0.0,
      );

      playback.advanceTo(0.1);
      expect(playback.values.first, greaterThan(0.0));
      expect(playback.values.first, lessThan(1.0));

      playback.advanceTo(0.3);
      expect(playback.values.first, closeTo(1.0, error));
      expect(playback.isDone, isTrue);
    });

    test('TrackStep.at after a shorter hold plays correctly', () {
      final playback = StepPlayback<double>(
        steps: [
          const TrackStep.hold(Duration(milliseconds: 100)),
          const TrackStep.at(
            Duration(milliseconds: 300),
            1.0,
            motion: linear200,
          ),
        ],
        converter: MotionConverter.single,
        start: 0.0,
      );

      // During hold.
      playback.advanceTo(0.05);
      expect(playback.values.first, closeTo(0.0, error));

      // After hold, at-step should be animating.
      playback.advanceTo(0.2);
      expect(playback.values.first, greaterThan(0.0));
      expect(playback.values.first, lessThan(1.0));

      playback.advanceTo(0.5);
      expect(playback.values.first, closeTo(1.0, error));
      expect(playback.isDone, isTrue);
    });

    test('hold(1s) then at(0.5s) asserts because at is in the past', () {
      expect(
        () => StepPlayback<double>(
          steps: [
            const TrackStep.hold(Duration(seconds: 1)),
            const TrackStep.at(
              Duration(milliseconds: 500),
              1.0,
              motion: linear100,
            ),
          ],
          converter: MotionConverter.single,
          start: 0.0,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('multiple holds then at in the past asserts', () {
      expect(
        () => StepPlayback<double>(
          steps: [
            const TrackStep.hold(Duration(milliseconds: 400)),
            const TrackStep.hold(Duration(milliseconds: 400)),
            const TrackStep.at(
              Duration(milliseconds: 500),
              1.0,
              motion: linear100,
            ),
          ],
          converter: MotionConverter.single,
          start: 0.0,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('at times must not go backwards', () {
      expect(
        () => StepPlayback<double>(
          steps: [
            const TrackStep.at(
              Duration(milliseconds: 300),
              1.0,
              motion: linear100,
            ),
            const TrackStep.at(
              Duration(milliseconds: 100),
              2.0,
              motion: linear100,
            ),
          ],
          converter: MotionConverter.single,
          start: 0.0,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('sequential to steps play in order', () {
      final playback = StepPlayback<double>(
        steps: [
          const TrackStep.to(1.0, motion: linear100),
          const TrackStep.to(2.0, motion: linear100),
          const TrackStep.to(3.0, motion: linear100),
        ],
        converter: MotionConverter.single,
        start: 0.0,
      );

      playback.advanceTo(0.05);
      expect(playback.values.first, greaterThan(0.0));
      expect(playback.values.first, lessThan(1.0));

      playback.advanceTo(0.15);
      expect(playback.values.first, greaterThan(1.0));
      expect(playback.values.first, lessThan(2.0));

      playback.advanceTo(0.5);
      expect(playback.values.first, closeTo(3.0, error));
      expect(playback.isDone, isTrue);
    });

    test('hold of zero duration advances immediately', () {
      final playback = StepPlayback<double>(
        steps: [
          const TrackStep.hold(Duration.zero),
          const TrackStep.to(1.0, motion: linear100),
        ],
        converter: MotionConverter.single,
        start: 0.0,
      );

      playback.advanceTo(0.05);
      expect(playback.values.first, greaterThan(0.0));
      expect(playback.values.first, lessThan(1.0));

      playback.advanceTo(0.2);
      expect(playback.values.first, closeTo(1.0, error));
      expect(playback.isDone, isTrue);
    });

    test('TrackStep.at arrives on time when the previous step overruns', () {
      // The first step would take 1s, so it is cut at 300ms to leave the
      // .at motion its natural 200ms to arrive at 500ms.
      final playback = StepPlayback<double>(
        steps: const [
          TrackStep.to(10, motion: Motion.linear(Duration(seconds: 1))),
          TrackStep.at(Duration(milliseconds: 500), 0, motion: linear200),
        ],
        converter: MotionConverter.single,
        start: 0,
      );

      playback.advanceTo(0.3);
      expect(playback.values.single, closeTo(3, error));
      playback.advanceTo(0.4);
      expect(playback.values.single, closeTo(1.5, error));
      playback.advanceTo(0.5);
      expect(playback.values.single, closeTo(0, error));
    });

    StepPlayback<double> towardAtOneSecond(Duration previous) =>
        StepPlayback<double>(
          steps: [
            TrackStep.to(1, motion: Motion.linear(previous)),
            const TrackStep.at(Duration(seconds: 1), 0, motion: linear200),
          ],
          converter: MotionConverter.single,
          start: 0,
        );

    test('TrackStep.at stretches when there is room for its motion', () {
      // The first step ends at 500ms, leaving 500ms >= 200ms: the .at motion
      // stretches over the whole gap.
      final playback = towardAtOneSecond(const Duration(milliseconds: 500));

      playback.advanceTo(0.75);
      expect(playback.values.single, closeTo(0.5, error));
      playback.advanceTo(1);
      expect(playback.values.single, closeTo(0, error));
    });

    test('TrackStep.at cuts the previous step when there is too little room',
        () {
      // The first step would end at 900ms, leaving only 100ms: it is cut at
      // 800ms so the .at motion runs its natural 200ms.
      final playback = towardAtOneSecond(const Duration(milliseconds: 900));

      playback.advanceTo(0.8);
      expect(playback.values.single, closeTo(0.8 / 0.9, error));
      playback.advanceTo(0.9);
      expect(playback.values.single, closeTo(0.4 / 0.9, error));
      playback.advanceTo(1);
      expect(playback.values.single, closeTo(0, error));
    });

    test('TrackStep.at timing changes continuously with the previous end', () {
      for (final (a, b) in const [
        (Duration(milliseconds: 799), Duration(milliseconds: 801)),
        (Duration(milliseconds: 999), Duration(milliseconds: 1001)),
      ]) {
        final early = towardAtOneSecond(a);
        final late = towardAtOneSecond(b);
        for (final t in [0.7, 0.8, 0.85, 0.9, 0.95, 1.0]) {
          early.advanceTo(t);
          late.advanceTo(t);
          expect(
            early.values.single,
            closeTo(late.values.single, 0.01),
            reason: 'previous step of $a vs $b at ${t}s',
          );
        }
      }
    });

    test('TrackStep.at with an unknown-duration motion keeps an early step',
        () {
      final playback = StepPlayback<double>(
        steps: const [
          TrackStep.to(1, motion: linear100),
          TrackStep.at(Duration(seconds: 1), 2, motion: _UnknownDuration()),
        ],
        converter: MotionConverter.single,
        start: 0,
      );

      playback.advanceTo(0.1);
      expect(playback.values.single, closeTo(1, error));
      // Scaling a motion of unknown duration relies on a probed estimate.
      playback.advanceTo(1);
      expect(playback.values.single, closeTo(2, 0.01));
    });

    test('TrackStep.at with no time left arrives immediately', () {
      final playback = StepPlayback<double>(
        steps: const [
          TrackStep.at(Duration.zero, 5, motion: linear100),
          TrackStep.to(0, motion: linear100),
        ],
        converter: MotionConverter.single,
        start: 0,
      );

      playback.advanceTo(0);
      expect(playback.values.single, closeTo(5, error));
      playback.advanceTo(0.05);
      expect(playback.values.single, closeTo(2.5, error));
    });

    test('TrackStep.at at exactly the cumulative time is valid (gap == 0)', () {
      // hold(100ms) then at(100ms) => gap is exactly 0, which is allowed.
      final playback = StepPlayback<double>(
        steps: [
          const TrackStep.hold(Duration(milliseconds: 100)),
          const TrackStep.at(
            Duration(milliseconds: 100),
            1.0,
            motion: linear100,
          ),
        ],
        converter: MotionConverter.single,
        start: 0.0,
      );

      // Should not throw — gap is exactly 0.
      playback.advanceTo(0.3);
      expect(playback.values.first, closeTo(1.0, error));
      expect(playback.isDone, isTrue);
    });

    test('empty steps list asserts', () {
      expect(
        () => StepPlayback<double>(
          steps: [],
          converter: MotionConverter.single,
          start: 0.0,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('single hold step completes after its duration', () {
      final playback = StepPlayback<double>(
        steps: [
          const TrackStep.hold(Duration(milliseconds: 300)),
        ],
        converter: MotionConverter.single,
        start: 5.0,
      );

      playback.advanceTo(0.15);
      expect(playback.values.first, closeTo(5.0, error));
      expect(playback.isDone, isFalse);

      playback.advanceTo(0.5);
      expect(playback.values.first, closeTo(5.0, error));
      expect(playback.isDone, isTrue);
    });

    test('a loop made only of zero-length steps shows where it ends', () {
      final playback = StepPlayback<double>(
        steps: const [
          TrackStep.to(1, motion: Motion.linear(Duration.zero)),
          TrackStep.hold(Duration.zero),
          TrackStep.to(0.5, motion: Motion.linear(Duration.zero)),
        ],
        converter: MotionConverter.single,
        start: 0,
        loop: LoopMode.loop,
      );

      // A loop returns to its start at the end of every cycle.
      playback.advanceTo(10);
      expect(playback.values.single, 0);
    });
  });
}

/// A linear motion that does not report its duration.
class _UnknownDuration extends Motion {
  const _UnknownDuration();

  static const _linear = Motion.linear(Duration(milliseconds: 100));

  @override
  bool get needsSettle => false;

  @override
  bool get unboundedWillSettle => true;

  @override
  Simulation createSimulation({
    double start = 0,
    double end = 1,
    double velocity = 0,
  }) =>
      _linear.createSimulation(start: start, end: end, velocity: velocity);

  @override
  bool operator ==(Object other) => other is _UnknownDuration;

  @override
  int get hashCode => (_UnknownDuration).hashCode;
}
