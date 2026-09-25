import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:motor/src/simulations/step_playback.dart';

double _seconds(Duration duration) => duration.inMicroseconds / 1e6;

StepPlayback<double> _playback(
  List<TrackStep<double>> steps, {
  double velocity = 0,
  LoopMode loop = LoopMode.none,
}) =>
    StepPlayback<double>(
      steps: steps,
      converter: MotionConverter.single,
      start: 0,
      velocity: velocity,
      loop: loop,
    );

void main() {
  group('CutMotion', () {
    const spring = CupertinoMotion.bouncy();
    final cut = spring.cutShort();
    final d = _seconds(spring.duration);

    test('ends at exactly its duration for every move', () {
      for (final (end, velocity) in [
        (1.0, 0.0),
        (300.0, -5000.0),
        (0.0, 2000.0),
      ]) {
        expect(
          cut.settlingDuration(end: end, velocity: velocity),
          spring.duration,
        );
        final simulation = cut.createSimulation(end: end, velocity: velocity);
        expect(simulation.x(d), end);
        expect(simulation.isDone(d), isTrue);
        expect(simulation.isDone(d - 1e-9), isFalse);
      }
    });

    test('keeps the start value and velocity', () {
      final simulation =
          cut.createSimulation(start: 10, end: 300, velocity: 800);
      expect(simulation.x(0), 10);
      expect(simulation.dx(0), closeTo(800, 1e-9));
    });

    test('scales a move from rest so it lands on the target', () {
      final parent = spring.createSimulation(end: 300);
      final simulation = cut.createSimulation(end: 300);
      final scale = 300 / parent.x(d);
      for (var t = 0.0; t < d; t += 0.01) {
        expect(simulation.x(t), closeTo(parent.x(t) * scale, 1e-9));
      }
    });

    test('stays within the miss at the cut, also for a fling in place', () {
      for (final (end, velocity) in [
        (300.0, 0.0),
        (300.0, -5000.0),
        (0.0, 2000.0),
      ]) {
        final parent = spring.createSimulation(end: end, velocity: velocity);
        final simulation = cut.createSimulation(end: end, velocity: velocity);
        final miss = (parent.x(d) - end).abs();
        var deviation = 0.0;
        for (var t = 0.0; t <= d; t += 1e-3) {
          deviation =
              math.max(deviation, (simulation.x(t) - parent.x(t)).abs());
        }
        expect(deviation, lessThan(miss * 1.1), reason: '$end at $velocity');
      }
      // The fling still carries the value away from where it started.
      final fling = cut.createSimulation(end: 0, velocity: 2000);
      expect(fling.x(0.1), greaterThan(50));
    });

    test('hands on its velocity at the cut', () {
      final simulation = cut.createSimulation(end: 300);
      final parent = spring.createSimulation(end: 300);
      expect(simulation.dx(d), isNot(0));
      expect(
        simulation.dx(d),
        closeTo(parent.dx(d), parent.dx(d).abs() * 0.05),
      );
      expect(simulation.dx(d + 1), simulation.dx(d));
    });

    test('holds a parent that finishes before the cut', () {
      final curve = const Motion.linear(Duration(milliseconds: 200))
          .cutAfter(const Duration(milliseconds: 500));
      final simulation = curve.createSimulation();
      expect(simulation.x(0.1), closeTo(0.5, 1e-9));
      expect(simulation.x(0.3), 1);
      expect(simulation.isDone(0.3), isFalse);
      expect(simulation.isDone(0.5), isTrue);
    });

    test('compares by parent movement and duration', () {
      expect(cut, spring.cutAfter(spring.duration));
      expect(cut.hashCode, spring.cutAfter(spring.duration).hashCode);
      expect(cut, isNot(spring.cutAfter(const Duration(milliseconds: 400))));
      expect(cut, isNot(const CupertinoMotion().cutAfter(spring.duration)));

      const duration = Duration(milliseconds: 300);
      const cutDuration = Duration(milliseconds: 200);
      expect(
        const Motion.linear(duration).cutAfter(cutDuration),
        const Motion.curved(duration).cutAfter(cutDuration),
      );
      expect(
        const Motion.linear(duration).cutAfter(cutDuration).hashCode,
        const Motion.curved(duration).cutAfter(cutDuration).hashCode,
      );
    });
  });

  group('playback', () {
    const spring = CupertinoMotion.bouncy();
    final cut = spring.cutShort();
    final d = _seconds(spring.duration);

    test('plays the same and ends at the cut whatever comes next', () {
      final nexts = <List<TrackStep<double>>>[
        [],
        [const TrackStep.hold(Duration(milliseconds: 100))],
        [const TrackStep.to(0, motion: Motion.linear(Duration(seconds: 1)))],
        [const TrackStep.to(0, motion: CupertinoMotion.snappy())],
        [
          const TrackStep.at(
            Duration(seconds: 3),
            0,
            motion: Motion.linear(Duration(milliseconds: 300)),
          ),
        ],
      ];
      final reference = cut.createSimulation(end: 300, velocity: 400);
      for (final next in nexts) {
        final playback = _playback(
          [TrackStep.to(300, motion: cut), ...next],
          velocity: 400,
        );
        for (var t = 0.0; t < d; t += 1 / 60) {
          playback.advanceTo(t);
          expect(playback.values.single, reference.x(t), reason: '$next at $t');
        }
        playback.advanceTo(d);
        expect(playback.forwardSegmentSeconds.first, d, reason: '$next');
        if (next.isEmpty) {
          expect(playback.isDone, isTrue);
          expect(playback.values.single, 300);
        } else {
          expect(playback.currentStepIndex, 1, reason: '$next');
        }
      }
    });

    test('a following spring starts with the velocity at the cut', () {
      final playback = _playback([
        TrackStep.to(300, motion: cut),
        const TrackStep.to(0, motion: CupertinoMotion.snappy()),
      ])
        ..advanceTo(d);
      expect(
        playback.velocities.single,
        closeTo(cut.createSimulation(end: 300).dx(d), 1e-9),
      );
    });

    test('.at plans with the cut as its natural length', () {
      final atCut = const CupertinoMotion().cutShort();
      final natural = _seconds(const CupertinoMotion().duration);

      // Enough time: the .at motion starts when the preceding step ends.
      final early = _playback([
        const TrackStep.to(
          1,
          motion: Motion.linear(Duration(milliseconds: 200)),
        ),
        TrackStep.at(const Duration(seconds: 1), 0, motion: atCut),
      ])
        ..advanceTo(1);
      expect(early.forwardSegmentSeconds.first, closeTo(0.2, 1e-6));
      expect(early.values.single, 0);

      // Not enough: the preceding step is cut so the motion runs its cut.
      final late = _playback([
        const TrackStep.to(
          1,
          motion: Motion.linear(Duration(milliseconds: 900)),
        ),
        TrackStep.at(const Duration(seconds: 1), 0, motion: atCut),
      ])
        ..advanceTo(0.999);
      expect(late.forwardSegmentSeconds.first, closeTo(1 - natural, 1e-6));
      late.advanceTo(1);
      expect(late.values.single, 0);
      expect(late.isDone, isTrue);
    });

    test('ticking and seeking agree', () {
      final steps = <TrackStep<double>>[
        TrackStep.to(300, motion: cut),
        TrackStep.to(
          -50,
          motion: const CupertinoMotion.snappy().cutShort(),
        ),
        TrackStep.at(
          const Duration(seconds: 2),
          100,
          motion:
              const Motion.curved(Duration(milliseconds: 400), Curves.easeOut)
                  .cutAfter(const Duration(milliseconds: 250)),
        ),
      ];
      for (final loop in [LoopMode.none, LoopMode.pingPong]) {
        final ticked = _playback(steps, velocity: -800, loop: loop);
        for (var t = 0.0; t <= 5; t += 1 / 240) {
          ticked.advanceTo(t);
          final sought = _playback(steps, velocity: -800, loop: loop)
            ..advanceTo(t);
          expect(
            sought.values.single,
            ticked.values.single,
            reason: '$loop $t',
          );
          expect(
            sought.velocities.single,
            ticked.velocities.single,
            reason: '$loop $t',
          );
        }
      }
    });
  });
}
