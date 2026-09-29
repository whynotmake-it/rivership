// ignore_for_file: cascade_invocations

import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:motor/src/simulations/step_playback.dart';

import 'util.dart';

const _linear100 = Motion.linear(Duration(milliseconds: 100));

StepPlayback<double> _playback(
  List<TrackStep<double>> steps, {
  LoopMode loop = LoopMode.none,
  double start = 0,
  double? velocity,
}) {
  return StepPlayback<double>(
    steps: steps,
    converter: MotionConverter.single,
    start: start,
    velocity: velocity,
    loop: loop,
  );
}

/// Advances to [seconds], releasing every barrier the moment it is reached,
/// as a lone controller participant would. Returns false if it gave up
/// because a loop kept reaching barriers without time passing.
bool _advance(StepPlayback<double> playback, double seconds) {
  playback.advanceTo(seconds);
  for (var i = 0; playback.pendingSyncToken != null; i++) {
    if (i == 1000) return false;
    playback
      ..releaseSync(atSeconds: playback.pendingSyncArrivalSeconds)
      ..advanceTo(seconds);
  }
  return true;
}

void _expectSameState(
  StepPlayback<double> actual,
  StepPlayback<double> expected,
  String reason,
) {
  expect(
    actual.values.single,
    closeTo(expected.values.single, error),
    reason: 'value, $reason',
  );
  expect(
    actual.velocities.single,
    closeTo(expected.velocities.single, error),
    reason: 'velocity, $reason',
  );
  expect(actual.isDone, expected.isDone, reason: 'isDone, $reason');
}

/// A free motion that drifts at its start velocity forever.
class _Drift extends FreeMotion {
  const _Drift();

  @override
  Simulation createSimulation({double start = 0, double velocity = 0}) =>
      GravitySimulation(0, start, double.infinity, velocity);

  @override
  bool operator ==(Object other) => other is _Drift;

  @override
  int get hashCode => (_Drift).hashCode;
}

/// Moves linearly to its end over 0.3 s, but reports done early, at 0.1 s
/// to 0.2 s, as an underdamped spring can near a peak.
class _FlickeringMotion extends Motion {
  const _FlickeringMotion();

  @override
  bool get needsSettle => false;

  @override
  Simulation createSimulation({
    double start = 0,
    double end = 1,
    double velocity = 0,
  }) =>
      _FlickeringSimulation(start, end);

  @override
  bool operator ==(Object other) => other is _FlickeringMotion;

  @override
  int get hashCode => (_FlickeringMotion).hashCode;
}

class _FlickeringSimulation extends Simulation {
  _FlickeringSimulation(this.start, this.end);

  final double start;
  final double end;

  @override
  double x(double time) => start + (end - start) * (time / 0.3).clamp(0.0, 1.0);

  @override
  double dx(double time) => time < 0.3 ? (end - start) / 0.3 : 0;

  @override
  bool isDone(double time) => (time >= 0.1 && time < 0.2) || time >= 0.3;
}

/// Random step lists with valid `.at` times.
List<TrackStep<double>> _randomSteps(math.Random random) {
  final motions = <Motion>[
    _linear100,
    const Motion.linear(Duration.zero),
    const Motion.curved(Duration(milliseconds: 250), Curves.easeInOut),
    const Motion.none(Duration(milliseconds: 40)),
    const Motion.smoothSpring(),
    const Motion.bouncySpring(duration: Duration(milliseconds: 300)),
  ];
  Motion motion() => motions[random.nextInt(motions.length)];
  double value() => (random.nextDouble() * 4 - 2).roundToDouble();

  final steps = <TrackStep<double>>[];
  // Holds and keyframes add up to the earliest time the next keyframe may use.
  var earliest = 0.0;
  final count = 1 + random.nextInt(6);
  for (var i = 0; i < count; i++) {
    switch (random.nextInt(6)) {
      case 0 || 1:
        steps.add(TrackStep.to(value(), motion: motion()));
      case 2:
        final ms = [0, 30, 120][random.nextInt(3)];
        earliest += ms / 1000;
        steps.add(TrackStep.hold(Duration(milliseconds: ms)));
      case 3:
        final at = earliest + random.nextDouble() * 0.6;
        earliest = at;
        steps.add(
          TrackStep.at(
            Duration(microseconds: (at * 1e6).ceil()),
            value(),
            motion: motion(),
          ),
        );
      case 4:
        steps.add(const TrackStep.sync(token: #barrier));
      case _:
        steps.add(const TrackStep.free(motion: FrictionMotion(drag: 0.01)));
    }
  }
  return steps;
}

void main() {
  group('StepPlayback under adversarial input', () {
    test('any schedule of ticks and seeks matches seeking straight there', () {
      final random = math.Random(20260925);
      const loops = [
        LoopMode.none,
        LoopMode.loop,
        LoopMode.pingPong,
        LoopMode.seamless,
      ];
      for (var run = 0; run < 150; run++) {
        final steps = _randomSteps(random);
        final loop = loops[random.nextInt(loops.length)];
        final start = random.nextDouble();
        final ticked = _playback(steps, loop: loop, start: start);
        // Loops with barriers keep only their latest cycles, so they can't be
        // revisited far back.
        final canSeekBack =
            !loop.isLooping || !steps.any((step) => step is StepSync);

        var time = 0.0;
        for (var tick = 0; tick < 60; tick++) {
          time = switch (random.nextInt(8)) {
            0 => time,
            1 => time + 1e-9,
            2 => time + random.nextDouble() * 5,
            3 when canSeekBack => random.nextDouble() * time,
            _ => time + 1 / 60,
          };
          if (!_advance(ticked, time)) break;

          final sought = _playback(steps, loop: loop, start: start);
          if (!_advance(sought, time)) break;
          _expectSameState(ticked, sought, 'run $run, $steps, $loop, t=$time');
        }
      }
    });

    group('degenerate steps', () {
      test('zero-length steps resolve within a moment', () {
        final playback = _playback(const [
          TrackStep.to(1, motion: Motion.linear(Duration.zero)),
          TrackStep.hold(Duration.zero),
          TrackStep.hold(Duration.zero),
          TrackStep.at(Duration.zero, 2, motion: _linear100),
          TrackStep.to(3, motion: Motion.linear(Duration.zero)),
        ]);

        playback.advanceTo(1e-6);
        expect(playback.values.single, 3);
        expect(playback.isDone, isTrue);
      });

      test('two keyframes at the same time land on the later value', () {
        final playback = _playback(const [
          TrackStep.at(Duration(milliseconds: 200), 1, motion: _linear100),
          TrackStep.at(Duration(milliseconds: 200), 2, motion: _linear100),
        ]);

        playback.advanceTo(0.2);
        expect(playback.values.single, closeTo(2, error));
        playback.advanceTo(1);
        expect(playback.values.single, 2);
        expect(playback.isDone, isTrue);
      });

      test('a keyframe to the current value holds it', () {
        final playback = _playback(
          const [
            TrackStep.at(Duration(milliseconds: 300), 1, motion: _linear100),
          ],
          start: 1,
        );

        for (final t in [0.0, 0.1, 0.25, 0.3, 1.0]) {
          playback.advanceTo(t);
          expect(playback.values.single, 1, reason: 't=$t');
        }
      });
    });

    group('boundaries', () {
      test('nudging a keyframe across the previous end never jumps', () {
        double valueAt(double at, double t) {
          final playback = _playback([
            const TrackStep.to(1, motion: _linear100),
            TrackStep.at(
              Duration(microseconds: (at * 1e6).round()),
              2,
              motion: _linear100,
            ),
          ]);
          playback.advanceTo(t);
          return playback.values.single;
        }

        // The keyframe's natural run (0.1 s) exactly fills the gap at 0.2 s.
        for (final t in [0.1, 0.15, 0.19]) {
          final early = valueAt(0.2 - 1e-6, t);
          final exact = valueAt(0.2, t);
          final late = valueAt(0.2 + 1e-6, t);
          expect(early, closeTo(exact, 1e-3), reason: 't=$t');
          expect(late, closeTo(exact, 1e-3), reason: 't=$t');
        }
      });

      test('keyframe times restart every loop cycle', () {
        final playback = _playback(
          const [
            TrackStep.at(Duration(milliseconds: 300), 1, motion: _linear100),
            TrackStep.to(0, motion: _linear100),
          ],
          loop: LoopMode.loop,
        );

        final period = () {
          final probe = _playback(
            const [
              TrackStep.at(Duration(milliseconds: 300), 1, motion: _linear100),
              TrackStep.to(0, motion: _linear100),
            ],
            loop: LoopMode.loop,
          )..advanceTo(5);
          return probe.loopPeriodSeconds!;
        }();

        for (var cycle = 0; cycle < 5; cycle++) {
          playback.advanceTo(cycle * period + 0.3);
          expect(playback.values.single, closeTo(1, error), reason: '$cycle');
        }
      });

      test('a jump far into a pingPong stays bounded and periodic', () {
        final steps = <TrackStep<double>>[
          const TrackStep.to(1, motion: Motion.smoothSpring()),
          const TrackStep.to(-1, motion: _linear100),
        ];
        final watch = Stopwatch()..start();
        final far = _playback(steps, loop: LoopMode.pingPong)..advanceTo(1e6);
        final period = far.loopPeriodSeconds!;
        final farther = _playback(steps, loop: LoopMode.pingPong)
          ..advanceTo(1e6 + period);

        expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
        expect(far.values.single, inInclusiveRange(-1.5, 1.5));
        expect(farther.values.single, closeTo(far.values.single, 1e-3));
      });
    });

    group('hostile simulations', () {
      test('a flickering isDone ends the step the same when ticked or sought',
          () {
        final steps = <TrackStep<double>>[
          const TrackStep.to(1, motion: _FlickeringMotion()),
          const TrackStep.to(2, motion: _linear100),
        ];
        final ticked = _playback(steps);
        for (var t = 0.0; t <= 0.6; t += 1 / 240) {
          ticked.advanceTo(t);
          final sought = _playback(steps)..advanceTo(t);
          _expectSameState(ticked, sought, 't=$t');
        }
        expect(ticked.isDone, isTrue);
        expect(ticked.values.single, 2);
      });

      test('a keyframe cuts a free motion that never settles on time', () {
        final playback = _playback(
          const [
            TrackStep.free(motion: _Drift()),
            TrackStep.at(Duration(seconds: 1), 5, motion: _linear100),
          ],
          velocity: 10,
        );

        playback.advanceTo(0.5);
        expect(playback.values.single, closeTo(5, error));
        playback.advanceTo(0.9);
        expect(playback.values.single, closeTo(9, error));
        playback.advanceTo(1);
        expect(playback.values.single, closeTo(5, error));
        expect(playback.isDone, isTrue);
      });

      test('a free motion that never settles never advances', () {
        final playback = _playback(
          const [
            TrackStep.free(motion: _Drift()),
            TrackStep.to(0, motion: _linear100),
          ],
          velocity: 1,
        );

        playback.advanceTo(1000);
        expect(playback.isDone, isFalse);
        expect(playback.currentStepIndex, 0);
        expect(playback.values.single, closeTo(1000, error));
      });
    });

    group('extremes', () {
      test('very large values land exactly', () {
        final playback = _playback(
          const [TrackStep.to(1e12, motion: _linear100)],
        )..advanceTo(1);
        expect(playback.values.single, 1e12);
      });

      test('time zero shows the start, and negative times assert', () {
        final playback = _playback(
          const [TrackStep.to(1, motion: _linear100)],
          start: 0.5,
        )..advanceTo(0);
        expect(playback.values.single, 0.5);
        expect(playback.isDone, isFalse);
        expect(() => playback.advanceTo(-1), throwsAssertionError);
      });

      test('dimensions that finish far apart finish independently', () {
        final playback = StepPlayback<Offset>(
          steps: const [
            TrackStep.to(
              Offset(1, 1),
              motionPerDimension: [
                _linear100,
                Motion.linear(Duration(seconds: 10)),
              ],
            ),
          ],
          converter: MotionConverter.offset,
          start: Offset.zero,
        );

        playback.advanceTo(5);
        expect(playback.values[0], 1);
        expect(playback.values[1], closeTo(0.5, error));
        expect(playback.isDone, isFalse);
        playback.advanceTo(10.001);
        expect(playback.values, [1, 1]);
        expect(playback.isDone, isTrue);
      });
    });
  });
}
