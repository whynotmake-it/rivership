// ignore_for_file: cascade_invocations

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:motor/src/simulations/step_playback.dart';

import 'util.dart';

void main() {
  const linear100 = Motion.linear(Duration(milliseconds: 100));

  StepPlayback<double> playback(
    List<TrackStep<double>> steps, {
    LoopMode loop = LoopMode.none,
  }) {
    return StepPlayback<double>(
      steps: steps,
      converter: MotionConverter.single,
      start: 0,
      loop: loop,
    );
  }

  /// Models a lone TrackController participant: the barrier is released at
  /// the moment it is reached.
  void releaseAtArrival(StepPlayback<double> playback, double elapsed) {
    while (playback.pendingSyncToken != null) {
      playback
        ..releaseSync(atSeconds: playback.pendingSyncArrivalSeconds)
        ..advanceTo(elapsed);
    }
  }

  void advanceIncrementally(
    StepPlayback<double> playback,
    double target, {
    bool releaseSync = false,
  }) {
    var elapsed = 0.0;
    while (elapsed < target) {
      elapsed = math.min(elapsed + 0.001, target);
      playback.advanceTo(elapsed);
      if (releaseSync) releaseAtArrival(playback, elapsed);
    }
  }

  void expectParity(
    List<TrackStep<double>> steps,
    double target, {
    LoopMode loop = LoopMode.none,
    bool releaseSync = false,
  }) {
    final advanced = playback(steps, loop: loop);
    final sought = playback(steps, loop: loop);

    advanceIncrementally(advanced, target, releaseSync: releaseSync);
    sought.advanceTo(target);
    if (releaseSync) releaseAtArrival(sought, target);

    expect(
      advanced.values.single,
      closeTo(sought.values.single, error),
      reason: 'values at $target seconds',
    );
    expect(
      advanced.velocities.single,
      closeTo(sought.velocities.single, error),
      reason: 'velocities at $target seconds',
    );
    expect(advanced.isDone, sought.isDone, reason: 'isDone at $target seconds');
  }

  test('small steps and one jump agree on a plain timeline', () {
    final steps = <TrackStep<double>>[
      const TrackStep.to(1, motion: linear100),
      const TrackStep.hold(Duration(milliseconds: 50)),
      const TrackStep.to(0, motion: linear100),
    ];

    for (final target in [0.05, 0.1, 0.26]) {
      expectParity(steps, target);
    }
  });

  test('small steps and one jump agree across loop cycles', () {
    final steps = <TrackStep<double>>[
      const TrackStep.to(1, motion: linear100),
    ];

    for (final target in [0.05, 0.1, 0.25]) {
      expectParity(steps, target, loop: LoopMode.loop);
    }
  });

  test('small steps and one jump agree when sync is released', () {
    final steps = <TrackStep<double>>[
      const TrackStep.to(1, motion: linear100),
      const TrackStep.sync(token: #barrier),
      const TrackStep.to(2, motion: linear100),
    ];

    for (final target in [0.05, 0.1, 0.21]) {
      expectParity(steps, target, releaseSync: true);
    }
  });

  test('advancing backward matches jumping straight there', () {
    final steps = <TrackStep<double>>[
      const TrackStep.to(1, motion: linear100),
      const TrackStep.hold(Duration(milliseconds: 50)),
      const TrackStep.to(0, motion: linear100),
    ];
    final advanced = playback(steps);
    final sought = playback(steps);

    advanced.advanceTo(0.15);
    advanced.advanceTo(0.05);
    sought.advanceTo(0.05);

    expect(advanced.values.single, closeTo(sought.values.single, error));
    expect(
      advanced.velocities.single,
      closeTo(sought.velocities.single, error),
    );
    expect(advanced.isDone, sought.isDone);
  });
}
