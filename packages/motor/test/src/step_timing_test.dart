import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:motor/src/simulations/step_playback.dart';

import 'util.dart';

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

/// A spring without a logical length.
class _NoDurationSpring extends Motion {
  const _NoDurationSpring();

  static const _spring = CupertinoMotion.bouncy();

  @override
  bool get needsSettle => true;

  @override
  Simulation createSimulation({
    double start = 0,
    double end = 1,
    double velocity = 0,
  }) =>
      _spring.createSimulation(start: start, end: end, velocity: velocity);

  @override
  bool operator ==(Object other) => other is _NoDurationSpring;

  @override
  int get hashCode => (_NoDurationSpring).hashCode;
}

void main() {
  const spring = CupertinoMotion.bouncy();
  final d = _seconds(spring.duration);
  final settle = _seconds(spring.settlingDuration(end: 300)!);

  group('Motion.duration', () {
    test('is the logical length', () {
      const curve = Duration(milliseconds: 300);
      expect(const Motion.curved(curve).duration, curve);
      expect(const NoMotion(curve).duration, curve);
      expect(spring.duration, const Duration(milliseconds: 500));
      const material = MaterialSpringMotion.standardSpatialDefault();
      expect(material.duration, material.description.duration);
      expect(spring.scaleTo(curve).duration, curve);
      expect(
        const Motion.linear(Duration(seconds: 1))
            .trimmed(fromStart: 0.25, fromEnd: 0.25)
            .duration,
        const Duration(milliseconds: 500),
      );
      expect(spring.trimmed(fromEnd: 0.9).duration, isNull);
      expect(const _NoDurationSpring().duration, isNull);
    });
  });

  group('step timing', () {
    test('the next step takes over after the duration', () {
      final playback = _playback([
        const TrackStep.to(300, motion: spring),
        const TrackStep.to(0, motion: CupertinoMotion.snappy()),
      ]);
      final first = spring.createSimulation(end: 300);
      playback.advanceTo(d - 1e-3);
      expect(playback.currentStepIndex, 0);
      playback.advanceTo(d);
      expect(playback.forwardSegmentSeconds.first, d);
      expect(playback.currentStepIndex, 1);
      // It starts from where the spring was, with its velocity.
      expect(playback.values.single, closeTo(first.x(d), 1e-9));
      expect(playback.velocities.single, closeTo(first.dx(d), 1e-9));
    });

    test('the last step plays out until it has settled', () {
      final playback = _playback([const TrackStep.to(300, motion: spring)])
        ..advanceTo(d + 0.1);
      expect(playback.isDone, isFalse);
      playback.advanceTo(settle);
      expect(playback.isDone, isTrue);
      expect(playback.values.single, 300);
    });

    test('untilSettled makes the next step wait', () {
      final playback = _playback([
        const TrackStep.to(300, motion: spring, untilSettled: true),
        const TrackStep.to(0, motion: CupertinoMotion.snappy()),
      ])
        ..advanceTo(settle + 0.01);
      expect(playback.forwardSegmentSeconds.first, closeTo(settle, 1e-5));
    });

    test('a motion without a duration waits to settle', () {
      final playback = _playback([
        const TrackStep.to(300, motion: _NoDurationSpring()),
        const TrackStep.to(0, motion: CupertinoMotion.snappy()),
      ])
        ..advanceTo(settle + 0.01);
      expect(playback.forwardSegmentSeconds.first, closeTo(settle, 1e-5));
    });

    test('a hold lets the handed-over spring play out', () {
      final playback = _playback([
        const TrackStep.to(300, motion: spring),
        const TrackStep.hold(Duration(milliseconds: 400)),
        const TrackStep.to(0, motion: CupertinoMotion.snappy()),
      ]);
      final first = spring.createSimulation(end: 300);
      for (var t = d; t < d + 0.4; t += 0.05) {
        playback.advanceTo(t);
        expect(playback.values.single, closeTo(first.x(t), 1e-9));
      }
      playback.advanceTo(d + 0.4);
      expect(playback.currentStepIndex, 2);
      expect(playback.values.single, closeTo(first.x(d + 0.4), 1e-9));
      expect(playback.velocities.single, closeTo(first.dx(d + 0.4), 1e-9));
    });

    test('a trimmed spring lasts until its slice ends', () {
      final slice = const Motion.smoothSpring().trimmed(fromEnd: 0.9);
      final playback = _playback([
        TrackStep.to(400, motion: slice),
        const TrackStep.to(0, motion: CupertinoMotion.snappy()),
      ])
        ..advanceTo(1);
      expect(
        playback.forwardSegmentSeconds.first,
        closeTo(_seconds(slice.settlingDuration(end: 400)!), 1e-5),
      );
    });

    test('a trailing hold follows a settled last motion', () {
      final playback = _playback([
        const TrackStep.to(300, motion: spring),
        const TrackStep.hold(Duration(milliseconds: 100)),
      ])
        ..advanceTo(settle + 0.2);
      expect(playback.forwardSegmentSeconds.first, closeTo(settle, 1e-5));
      expect(playback.isDone, isTrue);
    });

    test(
        'a sync barrier is reached after the duration, and waits playing '
        'the spring out', () {
      final playback = _playback([
        const TrackStep.to(300, motion: spring),
        const TrackStep.sync(token: #beat),
        const TrackStep.to(0, motion: CupertinoMotion.snappy()),
      ]);
      final first = spring.createSimulation(end: 300);
      playback.advanceTo(d + 0.2);
      expect(playback.isWaitingForSync, isTrue);
      expect(playback.pendingSyncArrivalSeconds, d);
      expect(playback.values.single, closeTo(first.x(d + 0.2), 1e-9));

      playback.releaseSync(atSeconds: d + 0.2);
      expect(playback.currentStepIndex, 2);
      expect(playback.values.single, closeTo(first.x(d + 0.2), 1e-9));
      expect(playback.velocities.single, closeTo(first.dx(d + 0.2), 1e-9));
    });

    test('.at plans with the duration and lands exactly', () {
      const keyframe = CupertinoMotion();
      final natural = _seconds(keyframe.duration);

      // Enough time: the keyframe starts when the preceding step ends.
      final early = _playback([
        const TrackStep.to(
          1,
          motion: Motion.linear(Duration(milliseconds: 200)),
        ),
        const TrackStep.at(Duration(seconds: 1), 0, motion: keyframe),
      ])
        ..advanceTo(1);
      expect(early.forwardSegmentSeconds.first, closeTo(0.2, 1e-6));
      expect(early.values.single, 0);
      expect(early.isDone, isTrue);

      // Not enough: the preceding step is cut so it runs its duration.
      final late = _playback([
        const TrackStep.to(
          1,
          motion: Motion.linear(Duration(milliseconds: 900)),
        ),
        const TrackStep.at(Duration(seconds: 1), 0, motion: keyframe),
      ])
        ..advanceTo(0.999);
      expect(late.forwardSegmentSeconds.first, closeTo(1 - natural, 1e-6));
      late.advanceTo(1);
      expect(late.values.single, 0);
      expect(late.isDone, isTrue);

      // A spring before a keyframe hands over after its duration.
      final spring = _playback([
        const TrackStep.to(300, motion: CupertinoMotion.bouncy()),
        const TrackStep.at(Duration(seconds: 2), 0, motion: keyframe),
      ])
        ..advanceTo(2);
      expect(spring.forwardSegmentSeconds.first, d);
      expect(spring.values.single, 0);
    });

    test('ticking and seeking agree', () {
      final steps = <TrackStep<double>>[
        const TrackStep.to(300, motion: spring),
        const TrackStep.hold(Duration(milliseconds: 150)),
        const TrackStep.to(-50, motion: CupertinoMotion.snappy()),
        const TrackStep.at(
          Duration(seconds: 2),
          100,
          motion: CupertinoMotion.smooth(),
        ),
        const TrackStep.to(
          20,
          motion: Motion.curved(Duration(milliseconds: 400), Curves.easeOut),
        ),
      ];
      for (final loop in [LoopMode.none, LoopMode.pingPong, LoopMode.loop]) {
        final ticked = _playback(steps, velocity: -800, loop: loop);
        for (var t = 0.0; t <= 6; t += 1 / 240) {
          ticked.advanceTo(t);
          final sought = _playback(steps, velocity: -800, loop: loop)
            ..advanceTo(t);
          final reason = '$loop $t';
          expect(sought.values.single, ticked.values.single, reason: reason);
          expect(
            sought.velocities.single,
            ticked.velocities.single,
            reason: '$loop $t',
          );
        }
      }
    });

    test('a looping spring plan folds', () {
      final playback = _playback(
        const [
          TrackStep.to(300, motion: spring),
          TrackStep.to(0, motion: spring),
        ],
        loop: LoopMode.loop,
      )..advanceTo(30);
      // The loop adds a step back to the start.
      expect(playback.loopPeriodSeconds, closeTo(3 * d, 1e-9));
    });

    test('untilSettled is part of step equality', () {
      const a = TrackStep<double>.to(1, motion: spring);
      const b = TrackStep<double>.to(1, motion: spring, untilSettled: true);
      expect(a, isNot(b));
      expect(a.hashCode, isNot(b.hashCode));
      const same = TrackStep<double>.to(1, motion: spring, untilSettled: true);
      expect(b, same);
    });
  });
}
