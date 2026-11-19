// ignore_for_file: cascade_invocations
// ignore_for_file: deprecated_member_use_from_same_package

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

void main() {
  group('StepPlayback under adversarial input', () {
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
        final far = _playback(steps, loop: LoopMode.pingPong)..advanceTo(1e6);
        final period = far.loopPeriodSeconds!;
        final farther = _playback(steps, loop: LoopMode.pingPong)
          ..advanceTo(1e6 + period);

        expect(far.values.single, inInclusiveRange(-1.5, 1.5));
        expect(farther.values.single, closeTo(far.values.single, 1e-3));
      });
    });

    group('hostile simulations', () {
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
