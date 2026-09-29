import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:motor/src/simulations/step_playback.dart';

double _seconds(Duration duration) => duration.inMicroseconds / 1e6;

StepPlayback<double> _playback(List<TrackStep<double>> steps) =>
    StepPlayback<double>(
      steps: steps,
      converter: MotionConverter.single,
      start: 0,
    );

/// A plain custom motion, as in 1.x: no timing, so its step lasts until its
/// simulation is done, which motor finds by sampling.
class EaseOutMotion extends Motion {
  const EaseOutMotion({this.timeConstant = 0.1});

  final double timeConstant;

  @override
  bool get needsSettle => false;

  @override
  Simulation createSimulation({
    double start = 0,
    double end = 1,
    double velocity = 0,
  }) =>
      _EaseOutSimulation(start, end, timeConstant, tolerance: tolerance);

  @override
  bool operator ==(Object other) =>
      other is EaseOutMotion && other.timeConstant == timeConstant;

  @override
  int get hashCode => timeConstant.hashCode;
}

class _EaseOutSimulation extends Simulation {
  _EaseOutSimulation(
    this.start,
    this.end,
    this.timeConstant, {
    required super.tolerance,
  });

  final double start;
  final double end;
  final double timeConstant;

  @override
  double x(double time) => end + (start - end) * math.exp(-time / timeConstant);

  @override
  double dx(double time) =>
      (end - start) / timeConstant * math.exp(-time / timeConstant);

  @override
  bool isDone(double time) => (x(time) - end).abs() < tolerance.distance;
}

/// Falls onto `end` as if under gravity, and bounces until it rests there.
///
/// It has no step length, since the bounces depend on the height, so a step
/// with it lasts until it rests. Its simulation says when that is.
class FloorBounceMotion extends Motion {
  const FloorBounceMotion({this.gravity = 8000, this.restitution = 0.5});

  final double gravity;
  final double restitution;

  @override
  bool get needsSettle => true;

  @override
  Simulation createSimulation({
    double start = 0,
    double end = 1,
    double velocity = 0,
  }) =>
      _FloorBounceSimulation(
        start: start,
        floor: end,
        velocity: velocity,
        gravity: gravity,
        restitution: restitution,
        tolerance: tolerance,
      );

  @override
  bool operator ==(Object other) =>
      other is FloorBounceMotion &&
      other.gravity == gravity &&
      other.restitution == restitution;

  @override
  int get hashCode => Object.hash(gravity, restitution);
}

class _FloorBounceSimulation extends Simulation with TimedSimulation {
  _FloorBounceSimulation({
    required double start,
    required this.floor,
    required double velocity,
    required double gravity,
    required double restitution,
    required super.tolerance,
  }) : _gravity = (floor >= start ? 1 : -1) * gravity {
    // Every impact is worked out up front, so x, dx and isDone are pure.
    var time = 0.0;
    var position = start;
    var speed = velocity;
    while (_impacts.length < 64) {
      // The next time position + speed·s + gravity·s²/2 reaches the floor.
      final a = _gravity / 2;
      final c = position - floor;
      final root = math.sqrt(math.max(0, speed * speed - 4 * a * c));
      final s = [(-speed - root) / (2 * a), (-speed + root) / (2 * a)]
          .where((s) => s > 1e-12)
          .fold(double.infinity, math.min);
      _legs.add((time, position, speed));
      time += s;
      _impacts.add(time);
      position = floor;
      speed = -(speed + _gravity * s) * restitution;
      if (speed.abs() < tolerance.velocity) break;
    }
  }

  final double floor;
  final double _gravity;
  final _legs = <(double, double, double)>[];
  final _impacts = <double>[];

  @override
  Duration? get duration => null;

  @override
  Duration get settlesAt =>
      Duration(microseconds: (_impacts.last * 1e6).ceil());

  (double, double, double) _legAt(double time) {
    for (var i = _legs.length - 1; i > 0; i--) {
      if (time >= _legs[i].$1) return _legs[i];
    }
    return _legs.first;
  }

  @override
  double x(double time) {
    if (time >= _impacts.last) return floor;
    final (start, position, speed) = _legAt(time);
    final s = time - start;
    return position + speed * s + _gravity * s * s / 2;
  }

  @override
  double dx(double time) {
    if (time >= _impacts.last) return 0;
    final (start, _, speed) = _legAt(time);
    return speed + _gravity * (time - start);
  }

  @override
  bool isDone(double time) => time >= _impacts.last;
}

/// A wrapper: holds still for [delay], then plays [parent].
///
/// It passes its parent's timing on, shifted by [delay]. A parent without
/// timing gets a wrapper without it too, so that motor samples it.
class DelayedMotion extends Motion {
  DelayedMotion(this.parent, {required this.delay})
      : super(tolerance: parent.tolerance);

  final Motion parent;
  final Duration delay;

  @override
  bool get needsSettle => parent.needsSettle;

  @override
  Simulation createSimulation({
    double start = 0,
    double end = 1,
    double velocity = 0,
  }) {
    final inner =
        parent.createSimulation(start: start, end: end, velocity: velocity);
    return inner is TimedSimulation
        ? _TimedDelayedSimulation(inner, delay, start)
        : _DelayedSimulation(inner, delay, start);
  }

  @override
  bool operator ==(Object other) =>
      other is DelayedMotion && other.parent == parent && other.delay == delay;

  @override
  int get hashCode => Object.hash(parent, delay);
}

class _DelayedSimulation extends Simulation {
  _DelayedSimulation(this.inner, Duration delay, this.start)
      : delay = delay.inMicroseconds / 1e6,
        super(tolerance: inner.tolerance);

  final Simulation inner;
  final double delay;
  final double start;

  @override
  double x(double time) => time < delay ? start : inner.x(time - delay);

  @override
  double dx(double time) => time < delay ? 0 : inner.dx(time - delay);

  @override
  bool isDone(double time) => time >= delay && inner.isDone(time - delay);
}

class _TimedDelayedSimulation extends _DelayedSimulation with TimedSimulation {
  _TimedDelayedSimulation(
    TimedSimulation super.inner,
    super.delay,
    super.start,
  ) : _delay = delay;

  final Duration _delay;

  TimedSimulation get _timed => inner as TimedSimulation;

  @override
  Duration? get duration => switch (_timed.duration) {
        final duration? => _delay + duration,
        null => null,
      };

  @override
  Duration? get settlesAt => switch (_timed.settlesAt) {
        final settlesAt? => _delay + settlesAt,
        null => null,
      };
}

void main() {
  group('authoring', () {
    test('a plain custom motion lasts until it is done', () {
      const motion = EaseOutMotion();
      final simulation = motion.createSimulation();
      // |x - 1| = e^(-t / 0.1) < 1e-3 from 0.1 · ln(1000) on.
      final done = 0.1 * math.log(1000);
      expect(simulation.isDone(done + 1e-6), isTrue);

      final playback = _playback([
        const TrackStep.to(1, motion: motion),
        const TrackStep.to(0, motion: Motion.linear(Duration(seconds: 1))),
      ])
        ..advanceTo(2);
      expect(playback.forwardSegmentSeconds.first, closeTo(done, 1e-6));
    });

    test('a floor bounce rests where its simulation says', () {
      const motion = FloorBounceMotion();
      final simulation =
          motion.createSimulation(end: 300) as _FloorBounceSimulation;
      final rest = _seconds(simulation.settlesAt);
      for (var t = 0.0; t < rest; t += 1e-3) {
        expect(simulation.x(t), lessThanOrEqualTo(300 + 1e-9));
      }
      expect(simulation.isDone(rest), isTrue);

      final playback = _playback([
        const TrackStep.to(300, motion: motion),
        const TrackStep.to(0, motion: Motion.linear(Duration(seconds: 1))),
      ])
        ..advanceTo(rest + 0.5);
      expect(playback.forwardSegmentSeconds.first, rest);
      expect(playback.currentStepIndex, 1);
    });

    test('a wrapper passes its parent timing on', () {
      const spring = CupertinoMotion.bouncy();
      const delay = Duration(milliseconds: 200);
      final delayed = DelayedMotion(spring, delay: delay);
      final simulation = delayed.createSimulation(end: 300) as TimedSimulation;
      final inner = spring.createSimulation(end: 300) as TimedSimulation;
      expect(simulation.duration, delay + spring.duration);
      expect(simulation.settlesAt, delay + inner.settlesAt!);

      final playback = _playback([
        TrackStep.to(300, motion: delayed),
        const TrackStep.to(0, motion: Motion.linear(Duration(seconds: 1))),
      ])
        ..advanceTo(1);
      expect(playback.forwardSegmentSeconds.first, 0.7);

      // Without timing on the parent, the wrapper has none either.
      final plain = DelayedMotion(const EaseOutMotion(), delay: delay);
      expect(plain.createSimulation(), isNot(isA<TimedSimulation>()));
    });
  });

  group('engine', () {
    test('a scaled step continues with the velocity it is handed', () {
      final scaled = SpringMotion(
        SpringDescription.withDampingRatio(
          mass: 1,
          stiffness: 380,
          ratio: .8,
        ),
      ).scaleTo(const Duration(milliseconds: 200));
      final playback = _playback([
        const TrackStep.to(100, motion: CupertinoMotion.bouncy()),
        TrackStep.to(0, motion: scaled),
      ])
        ..advanceTo(0.5);
      final handedOver =
          const CupertinoMotion.bouncy().createSimulation(end: 100).dx(0.5);
      expect(playback.currentStepIndex, 1);
      expect(playback.velocities.single, closeTo(handedOver, 1e-6));
    });

    test('a mixin simulation is not searched for its end', () {
      const motion = FloorBounceMotion();
      final rest = _seconds(
        (motion.createSimulation(end: 300) as TimedSimulation).settlesAt!,
      );
      // An .at after it plans from settlesAt; with a search, the end would
      // only be found to within the grid.
      final playback = _playback([
        const TrackStep.to(300, motion: motion),
        const TrackStep.at(
          Duration(seconds: 3),
          0,
          motion: Motion.linear(Duration(milliseconds: 100)),
        ),
      ])
        ..advanceTo(3);
      expect(playback.forwardSegmentSeconds.first, rest);
      expect(playback.values.single, 0);
    });
  });
}
