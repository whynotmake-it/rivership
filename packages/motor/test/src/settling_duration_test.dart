import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:motor/src/simulations/step_playback.dart';

double _seconds(Duration duration) => duration.inMicroseconds / 1e6;

/// The time from which [simulation] stays done, on a 1e-5 s grid.
double _doneForGood(Simulation simulation, double until) {
  const step = 1e-5;
  var last = -step;
  for (var t = 0.0; t < until; t += step) {
    if (!simulation.isDone(t)) last = t;
  }
  return last + step;
}

/// Delegates to [parent] and counts `isDone` calls on its simulations.
class _CountingMotion extends Motion {
  _CountingMotion(this.parent);

  final Motion parent;
  final _calls = _Counter();

  int get isDoneCalls => _calls.count;

  int get settlingDurationCalls => _calls.settlingDuration;

  @override
  bool get needsSettle => parent.needsSettle;

  @override
  bool get unboundedWillSettle => parent.unboundedWillSettle;

  @override
  Duration? settlingDuration({
    double start = 0,
    double end = 1,
    double velocity = 0,
  }) {
    _calls.settlingDuration++;
    return parent.settlingDuration(start: start, end: end, velocity: velocity);
  }

  @override
  Simulation createSimulation({
    double start = 0,
    double end = 1,
    double velocity = 0,
  }) =>
      _CountingSimulation(
        this,
        parent.createSimulation(start: start, end: end, velocity: velocity),
      );

  @override
  bool operator ==(Object other) => identical(this, other);

  @override
  int get hashCode => identityHashCode(this);
}

class _Counter {
  int count = 0;
  int settlingDuration = 0;
}

class _CountingSimulation extends Simulation {
  _CountingSimulation(this.motion, this.parent);

  final _CountingMotion motion;
  final Simulation parent;

  @override
  double x(double time) => parent.x(time);

  @override
  double dx(double time) => parent.dx(time);

  @override
  bool isDone(double time) {
    motion._calls.count++;
    return parent.isDone(time);
  }
}

void main() {
  group('Motion.settlingDuration', () {
    test('curves and NoMotion return their duration', () {
      const duration = Duration(milliseconds: 300);
      expect(const Motion.linear(duration).settlingDuration(), duration);
      expect(const Motion.curved(duration).settlingDuration(), duration);
      expect(const NoMotion(duration).settlingDuration(), duration);
    });

    test('springs end when they are done for good', () {
      final random = math.Random(3);
      final springs = <Motion>[
        const CupertinoMotion(),
        const CupertinoMotion.bouncy(),
        const CupertinoMotion.snappy(),
        const CupertinoMotion.interactive(),
        const MaterialSpringMotion.expressiveSpatialDefault(),
        for (var i = 0; i < 12; i++)
          () {
            final zeta = 0.1 + random.nextDouble() * 2;
            final stiffness = 50 + random.nextDouble() * 1000;
            return SpringMotion(
              SpringDescription(
                mass: 1,
                stiffness: stiffness,
                damping: 2 * zeta * math.sqrt(stiffness),
              ),
            );
          }(),
      ];
      for (final motion in springs) {
        for (final (end, velocity) in [(1.0, 0.0), (300.0, -2000.0)]) {
          final settle = motion.settlingDuration(end: end, velocity: velocity)!;
          final simulation =
              motion.createSimulation(end: end, velocity: velocity);
          expect(
            _seconds(settle),
            closeTo(_doneForGood(simulation, _seconds(settle) + 1), 2e-5),
            reason: '$motion to $end at $velocity',
          );
          expect(simulation.isDone(_seconds(settle)), isTrue);
        }
      }
    });

    test('a spring whose isDone flickers ends after its last swing', () {
      const motion = CupertinoMotion.bouncy();
      final simulation = motion.createSimulation(start: 2.4964, end: 0);
      final settle = _seconds(motion.settlingDuration(start: 2.4964, end: 0)!);

      expect(simulation.isDone(1.03), isTrue);
      expect(settle, greaterThan(1.2));
      expect(_doneForGood(simulation, 2), closeTo(settle, 2e-5));
    });

    test('a spring at rest on its target is done at once', () {
      expect(
        const CupertinoMotion.bouncy().settlingDuration(start: 1),
        Duration.zero,
      );
    });

    test('wrappers ask their parent', () {
      const spring = CupertinoMotion.bouncy();
      const duration = Duration(milliseconds: 400);
      expect(spring.scaleTo(duration).settlingDuration(), duration);

      final trimmed = spring.trimmed(fromStart: 0.2, fromEnd: 0.2);
      final parent = spring.settlingDuration(start: -0.12, end: 1.12)!;
      expect(
        _seconds(trimmed.settlingDuration()!),
        closeTo(_seconds(parent) * 0.6 - spring.tolerance.time, 1e-5),
      );
    });
  });

  group('playback', () {
    test('a spring step ends at its settlingDuration', () {
      const motion = CupertinoMotion.bouncy();
      final playback = StepPlayback<double>(
        steps: const [TrackStep.to(300, motion: motion)],
        converter: MotionConverter.single,
        start: 0,
      );
      final settle = _seconds(motion.settlingDuration(end: 300)!);

      playback.advanceTo(settle - 1e-4);
      expect(playback.isDone, isFalse);
      playback.advanceTo(settle);
      expect(playback.isDone, isTrue);
      expect(playback.values.single, 300);
    });

    test('asks the motion only once the step is done', () {
      final motion = _CountingMotion(const CupertinoMotion.bouncy());
      final playback = StepPlayback<double>(
        steps: [TrackStep.to(300, motion: motion)],
        converter: MotionConverter.single,
        start: 0,
      );
      final simulation = motion.parent.createSimulation(end: 300);

      var t = 0.0;
      for (; !simulation.isDone(t); t += 1 / 60) {
        playback.advanceTo(t);
      }
      expect(motion.settlingDurationCalls, 0);
      for (; !playback.isDone; t += 1 / 60) {
        playback.advanceTo(t);
      }
      expect(motion.settlingDurationCalls, 1);
    });

    test('a trimmed step ends exactly where its simulation is done', () {
      final motion = const Motion.linear(Duration(seconds: 1))
          .trimmed(fromStart: 0.25, fromEnd: 0.25);
      final simulation = motion.createSimulation();
      final playback = StepPlayback<double>(
        steps: [
          TrackStep.to(1, motion: motion),
          const TrackStep.to(0, motion: Motion.linear(Duration(seconds: 1))),
        ],
        converter: MotionConverter.single,
        start: 0,
      )..advanceTo(1);

      final end = playback.forwardSegmentSeconds.first!;
      expect(end, closeTo(0.499, 1e-9));
      expect(simulation.isDone(end), isTrue);
      expect(simulation.isDone(end - 1e-12), isFalse);
    });

    test('planning a following .at step does not search the spring', () {
      final motion = _CountingMotion(const CupertinoMotion.bouncy());
      final playback = StepPlayback<double>(
        steps: [
          TrackStep.to(300, motion: motion),
          const TrackStep.at(
            Duration(seconds: 3),
            0,
            motion: Motion.linear(Duration(milliseconds: 300)),
          ),
        ],
        converter: MotionConverter.single,
        start: 0,
      );
      for (var t = 0.0; t <= 3.1; t += 1 / 60) {
        playback.advanceTo(t);
      }

      expect(playback.values.single, 0);
      // Only the check that the reported end is really done.
      expect(motion.isDoneCalls, lessThanOrEqualTo(2));
    });
  });
}
