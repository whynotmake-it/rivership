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

    test('lasts its new duration and keeps settling after it', () {
      final scaled = spring.scaleTo(const Duration(milliseconds: 300));
      final playback = StepPlayback<double>(
        steps: [
          TrackStep.to(100, motion: scaled, until: WaitUntil.duration),
          const TrackStep.to(0, motion: Motion.linear(Duration(seconds: 1))),
        ],
        converter: MotionConverter.single,
        start: 0,
      )..advanceTo(0.3 - 1e-3);
      expect(playback.currentStepIndex, 0);
      playback.advanceTo(0.3);
      expect(playback.currentStepIndex, 1);

      final last = StepPlayback<double>(
        steps: [TrackStep.to(100, motion: scaled)],
        converter: MotionConverter.single,
        start: 0,
      )..advanceTo(0.3);
      expect(last.isDone, isFalse);
      final settle =
          (scaled.createSimulation(end: 100) as SettlingSimulation).settlesAt!;
      last.advanceTo(settle.inMicroseconds / 1e6);
      expect(last.values.single, 100);
      expect(last.isDone, isTrue);
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

  group('StepPlayback plays', () {
    StepPlayback<double> towardAtOneSecond(Duration previous) =>
        StepPlayback<double>(
          steps: [
            TrackStep.to(1, motion: Motion.linear(previous)),
            const TrackStep.at(Duration(seconds: 1), 0, motion: linear200),
          ],
          converter: MotionConverter.single,
          start: 0,
        );

    // Each timeline is sampled in order; it is done at the last sample only
    // if `done` says so, and never before.
    for (final timeline in <_Timeline>[
      const _Timeline(
        'a hold, then a step',
        [
          TrackStep.hold(Duration(milliseconds: 200)),
          TrackStep.to(1, motion: linear100),
        ],
        [(0.1, 0), (0.25, 0.5), (0.5, 1)],
        done: true,
      ),
      const _Timeline(
        'a zero-length hold, then a step',
        [
          TrackStep.hold(Duration.zero),
          TrackStep.to(1, motion: linear100),
        ],
        [(0.05, 0.5), (0.2, 1)],
        done: true,
      ),
      const _Timeline(
        'a lone hold',
        [TrackStep.hold(Duration(milliseconds: 300))],
        [(0.15, 5), (0.5, 5)],
        start: 5,
        done: true,
      ),
      const _Timeline(
        'steps in order',
        [
          TrackStep.to(1, motion: linear100),
          TrackStep.to(2, motion: linear100),
          TrackStep.to(3, motion: linear100),
        ],
        [(0.05, 0.5), (0.15, 1.5), (0.5, 3)],
        done: true,
      ),
      const _Timeline(
        'a first .at step over its own motion',
        [TrackStep.at(Duration(milliseconds: 200), 1, motion: linear200)],
        [(0.1, 0.5), (0.3, 1)],
        done: true,
      ),
      const _Timeline(
        'an .at step right after a shorter hold',
        [
          TrackStep.hold(Duration(milliseconds: 100)),
          TrackStep.at(Duration(milliseconds: 300), 1, motion: linear200),
        ],
        [(0.05, 0), (0.2, 0.5), (0.5, 1)],
        done: true,
      ),
      const _Timeline(
        'an .at step at exactly the time the holds before it end',
        [
          TrackStep.hold(Duration(milliseconds: 100)),
          TrackStep.at(Duration(milliseconds: 100), 1, motion: linear100),
        ],
        [(0.3, 1)],
        done: true,
      ),
      // The first step would take 1s, so it is cut at 300ms to leave the
      // .at motion its natural 200ms to arrive at 500ms.
      const _Timeline(
        'an .at step that cuts a step overrunning it',
        [
          TrackStep.to(10, motion: Motion.linear(Duration(seconds: 1))),
          TrackStep.at(Duration(milliseconds: 500), 0, motion: linear200),
        ],
        [(0.3, 3), (0.4, 1.5), (0.5, 0)],
        done: true,
      ),
      // The first step ends at 500ms, leaving 500ms >= 200ms: the .at motion
      // stretches over the whole gap.
      const _Timeline(
        'an .at step stretched over the room it has',
        [
          TrackStep.to(1, motion: Motion.linear(Duration(milliseconds: 500))),
          TrackStep.at(Duration(seconds: 1), 0, motion: linear200),
        ],
        [(0.75, 0.5), (1, 0)],
        done: true,
      ),
      // The first step would end at 900ms, leaving only 100ms: it is cut at
      // 800ms so the .at motion runs its natural 200ms.
      const _Timeline(
        'an .at step that cuts the step before when there is too little room',
        [
          TrackStep.to(1, motion: Motion.linear(Duration(milliseconds: 900))),
          TrackStep.at(Duration(seconds: 1), 0, motion: linear200),
        ],
        [(0.8, 0.8 / 0.9), (0.9, 0.4 / 0.9), (1, 0)],
        done: true,
      ),
      const _Timeline(
        'an .at step with no time left',
        [
          TrackStep.at(Duration.zero, 5, motion: linear100),
          TrackStep.to(0, motion: linear100),
        ],
        [(0, 5), (0.05, 2.5)],
      ),
      // A loop returns to its start at the end of every cycle.
      const _Timeline(
        'a loop of zero-length steps',
        [
          TrackStep.to(1, motion: Motion.linear(Duration.zero)),
          TrackStep.hold(Duration.zero),
          TrackStep.to(0.5, motion: Motion.linear(Duration.zero)),
        ],
        [(10, 0)],
        loop: LoopMode.loop,
        tolerance: 0,
      ),
      const _Timeline(
        'a pingPong reversing a hold before returning to the start',
        [
          TrackStep.to(1, motion: linear100),
          TrackStep.hold(Duration(milliseconds: 100)),
        ],
        [(0.05, 0.5), (0.15, 1), (0.25, 1), (0.35, 0.5), (0.4, 0), (0.45, 0.5)],
        loop: LoopMode.pingPong,
      ),
      const _Timeline(
        'a pingPong reversing through each previous waypoint',
        [
          TrackStep.to(0.5, motion: linear100),
          TrackStep.to(1, motion: linear100),
        ],
        [
          (0.05, 0.25),
          (0.15, 0.75),
          (0.25, 0.75),
          (0.3, 0.5),
          (0.35, 0.25),
          (0.4, 0),
          (0.45, 0.25),
        ],
        loop: LoopMode.pingPong,
      ),
      const _Timeline(
        'a pingPong mirroring .at timing on the reverse leg',
        [
          TrackStep.to(1, motion: linear100),
          TrackStep.at(Duration(milliseconds: 300), 2, motion: linear100),
        ],
        [
          (0.1, 1),
          (0.2, 1.5),
          (0.3, 2),
          (0.35, 1.75),
          (0.4, 1.5),
          (0.45, 1.25),
          (0.5, 1),
          (0.55, 0.5),
          (0.6, 0),
        ],
        loop: LoopMode.pingPong,
      ),
      // Back over the .at, which arrives the moment the step before ends, at
      // 300 ms, then halfway from 5 to 0.
      _Timeline(
        'a pingPong returning over an instant .at step',
        [
          const TrackStep.to(5, motion: linear100),
          TrackStep.at(
            const Duration(milliseconds: 100),
            10,
            motion: const CupertinoMotion().scaleTo(Duration.zero),
          ),
          const TrackStep.hold(Duration(milliseconds: 100)),
        ],
        [(0.35, 2.5)],
        loop: LoopMode.pingPong,
      ),
    ]) {
      test(timeline.name, () {
        final playback = StepPlayback<double>(
          steps: timeline.steps,
          converter: MotionConverter.single,
          start: timeline.start,
          loop: timeline.loop,
        );
        for (final (index, (seconds, value)) in timeline.samples.indexed) {
          playback.advanceTo(seconds);
          expect(
            playback.values.single,
            closeTo(value, timeline.tolerance),
            reason: 'at ${seconds}s',
          );
          final last = index == timeline.samples.length - 1;
          expect(
            playback.isDone,
            last && timeline.done,
            reason: 'isDone at ${seconds}s',
          );
        }
      });
    }

    test('a pingPong holds instead of reversing a free step', () {
      final playback = StepPlayback<double>(
        steps: const [TrackStep.free(motion: FrictionMotion(drag: 0.1))],
        converter: MotionConverter.single,
        start: 0,
        velocity: 10,
        loop: LoopMode.pingPong,
      );

      playback.advanceTo(10);
      final settledValue = playback.values.single;
      expect(settledValue, greaterThan(0));

      playback.advanceTo(20);
      expect(playback.values.single, closeTo(settledValue, error));
      expect(playback.velocities.single, closeTo(0, error));
      expect(playback.isDone, isFalse);
    });

    test('an .at step changes continuously with the end of the step before',
        () {
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

    test('an .at step with an unknown-duration motion keeps an early step', () {
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

    test('invalid plans assert', () {
      for (final (name, steps) in const <(String, List<TrackStep<double>>)>[
        ('no steps', []),
        (
          'an .at step before the holds before it',
          [
            TrackStep.hold(Duration(milliseconds: 400)),
            TrackStep.hold(Duration(milliseconds: 400)),
            TrackStep.at(Duration(milliseconds: 500), 1, motion: linear100),
          ]
        ),
        (
          '.at times going backwards',
          [
            TrackStep.at(Duration(milliseconds: 300), 1, motion: linear100),
            TrackStep.at(Duration(milliseconds: 100), 2, motion: linear100),
          ]
        ),
      ]) {
        expect(
          () => StepPlayback<double>(
            steps: steps,
            converter: MotionConverter.single,
            start: 0,
          ),
          throwsAssertionError,
          reason: name,
        );
      }
    });
  });
}

/// Values a plan played from rest shows at given times, in seconds.
class _Timeline {
  const _Timeline(
    this.name,
    this.steps,
    this.samples, {
    this.start = 0,
    this.loop = LoopMode.none,
    this.done = false,
    this.tolerance = error,
  });

  final String name;
  final List<TrackStep<double>> steps;
  final List<(double, double)> samples;
  final double start;
  final LoopMode loop;
  final bool done;
  final double tolerance;
}

/// A linear motion that does not report its duration.
class _UnknownDuration extends Motion {
  const _UnknownDuration();

  static const _linear = Motion.linear(Duration(milliseconds: 100));

  @override
  bool get needsSettle => false;

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
