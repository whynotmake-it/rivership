// ignore_for_file: deprecated_member_use_from_same_package

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
    test('the next step waits until the previous one has settled', () {
      final playback = _playback([
        const TrackStep.to(300, motion: spring),
        const TrackStep.to(0, motion: CupertinoMotion.snappy()),
      ])
        ..advanceTo(d);
      expect(playback.currentStepIndex, 0);
      playback.advanceTo(settle - 1e-3);
      expect(playback.currentStepIndex, 0);
      playback.advanceTo(settle);
      expect(playback.forwardSegmentSeconds.first, closeTo(settle, 1e-5));
      expect(playback.currentStepIndex, 1);
      // It starts from rest on the target.
      expect(playback.values.single, 300);
      expect(playback.velocities.single, closeTo(0, 1e-3));
    });

    test('ending at the duration, the next step takes over', () {
      final playback = _playback([
        const TrackStep.to(
          300,
          motion: spring,
          until: WaitUntil.duration,
        ),
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
      for (final until in WaitUntil.values) {
        final playback = _playback([
          TrackStep.to(
            300,
            motion: spring,
            until: until,
          ),
        ])
          ..advanceTo(d + 0.1);
        expect(playback.isDone, isFalse);
        playback.advanceTo(settle);
        expect(playback.isDone, isTrue);
        expect(playback.values.single, 300);
      }
    });

    test('a motion without a duration waits to settle, whatever its end', () {
      final playback = _playback([
        const TrackStep.to(
          300,
          motion: _NoDurationSpring(),
          until: WaitUntil.duration,
        ),
        const TrackStep.to(0, motion: CupertinoMotion.snappy()),
      ])
        ..advanceTo(settle + 0.01);
      expect(playback.forwardSegmentSeconds.first, closeTo(settle, 1e-5));
    });

    test('a hold lets a spring that ended at its duration play out', () {
      final playback = _playback([
        const TrackStep.to(
          300,
          motion: spring,
          until: WaitUntil.duration,
        ),
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

    test('a hold after a settled spring holds its target', () {
      final playback = _playback([
        const TrackStep.to(300, motion: spring),
        const TrackStep.hold(Duration(milliseconds: 400)),
        const TrackStep.to(0, motion: CupertinoMotion.snappy()),
      ])
        ..advanceTo(settle + 0.2);
      expect(playback.currentStepIndex, 1);
      expect(playback.values.single, 300);
      playback.advanceTo(settle + 0.401);
      expect(playback.currentStepIndex, 2);
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

    test('a trailing hold starts once the spring ended and lets it settle', () {
      final playback = _playback([
        const TrackStep.to(
          300,
          motion: spring,
          until: WaitUntil.duration,
        ),
        const TrackStep.hold(Duration(milliseconds: 100)),
      ]);
      final first = spring.createSimulation(end: 300);
      final entered = <int>[];
      for (var t = 0.0; t < settle; t += 0.05) {
        playback.advanceTo(t);
        entered.addAll(playback.takeEnteredSteps());
        expect(playback.values.single, closeTo(first.x(t), 1e-9));
        expect(playback.isDone, isFalse);
        expect(playback.hasEnded, t >= d + 0.1);
      }
      expect(playback.forwardSegmentSeconds, [d, 0.1]);
      playback.advanceTo(settle + 1e-5);
      entered.addAll(playback.takeEnteredSteps());
      expect(playback.isDone, isTrue);
      expect(playback.values.single, 300);
      expect(entered, [0, 1]);
    });

    test('a trailing barrier waits once the spring ended', () {
      final playback = _playback([
        const TrackStep.to(
          300,
          motion: spring,
          until: WaitUntil.duration,
        ),
        const TrackStep.sync(token: #end),
      ])
        ..advanceTo(d + 0.01);
      expect(playback.isWaitingForSync, isTrue);
      expect(playback.pendingSyncArrivalSeconds, d);
      playback
        ..releaseSync(atSeconds: d + 0.01)
        ..advanceTo(d + 0.02);
      expect(playback.isDone, isFalse, reason: 'the spring still settles');
      playback.advanceTo(settle + 1e-5);
      expect(playback.isDone, isTrue);
      expect(playback.values.single, 300);
    });

    test('a sync barrier is reached once the spring has settled', () {
      final playback = _playback([
        const TrackStep.to(300, motion: spring),
        const TrackStep.sync(token: #beat),
        const TrackStep.to(0, motion: CupertinoMotion.snappy()),
      ])
        ..advanceTo(settle - 1e-3);
      expect(playback.isWaitingForSync, isFalse);
      playback.advanceTo(settle + 0.1);
      expect(playback.isWaitingForSync, isTrue);
      expect(playback.pendingSyncArrivalSeconds, closeTo(settle, 1e-5));
      expect(playback.values.single, 300);
    });

    test(
        'ending at the duration, a sync barrier is reached then, and '
        'waits playing the spring out', () {
      final playback = _playback([
        const TrackStep.to(
          300,
          motion: spring,
          until: WaitUntil.duration,
        ),
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

      // A spring before a keyframe settles first; here too late, so it is
      // cut where the keyframe must start.
      final waits = _playback([
        const TrackStep.to(300, motion: CupertinoMotion.bouncy()),
        const TrackStep.at(Duration(seconds: 2), 0, motion: keyframe),
      ])
        ..advanceTo(2);
      expect(settle, greaterThan(2 - natural));
      expect(waits.forwardSegmentSeconds.first, closeTo(2 - natural, 1e-6));
      expect(waits.values.single, 0);

      // Ending at its duration, it leaves the keyframe time to fill the
      // gap.
      final atDuration = _playback([
        const TrackStep.to(
          300,
          motion: CupertinoMotion.bouncy(),
          until: WaitUntil.duration,
        ),
        const TrackStep.at(Duration(seconds: 2), 0, motion: keyframe),
      ])
        ..advanceTo(2);
      expect(atDuration.forwardSegmentSeconds.first, d);
      expect(atDuration.values.single, 0);
    });

    test('a looping spring plan folds', () {
      final settles = _playback(
        const [
          TrackStep.to(300, motion: spring),
          TrackStep.to(0, motion: spring),
        ],
        loop: LoopMode.loop,
      )..advanceTo(30);
      // Each leg settles over the same distance; the step back to the start
      // is already there.
      expect(settles.loopPeriodSeconds, closeTo(2 * settle, 1e-5));

      final atDuration = _playback(
        const [
          TrackStep.to(
            300,
            motion: spring,
            until: WaitUntil.duration,
          ),
          TrackStep.to(
            0,
            motion: spring,
            until: WaitUntil.duration,
          ),
        ],
        loop: LoopMode.loop,
      )..advanceTo(30);
      // The loop adds a step back to the start, which waits to settle.
      expect(atDuration.loopPeriodSeconds, isNotNull);
    });

    test('until is part of step equality', () {
      const a = TrackStep<double>.to(1, motion: spring);
      const b =
          TrackStep<double>.to(1, motion: spring, until: WaitUntil.duration);
      expect(a, isNot(b));
      expect(a.hashCode, isNot(b.hashCode));
      const same =
          TrackStep<double>.to(1, motion: spring, until: WaitUntil.duration);
      expect(b, same);
      expect(
        const TrackStep<double>.free(
          motion: FrictionMotion(),
          until: WaitUntil.duration,
        ),
        isNot(const TrackStep<double>.free(motion: FrictionMotion())),
      );
    });
  });
}
