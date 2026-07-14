// ignore_for_file: cascade_invocations

import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:motor/src/simulations/step_playback.dart';

import 'util.dart';

void main() {
  const linear100 = Motion.linear(Duration(milliseconds: 100));

  StepPlayback<double> playback(
    List<Step<double>> steps, {
    double velocity = 0,
  }) {
    return StepPlayback<double>(
      steps: steps,
      converter: MotionConverter.single,
      start: 0,
      velocity: velocity,
      loop: LoopMode.pingPong,
    );
  }

  test('pingPong reverses a hold before returning to the initial value', () {
    final p = playback([
      const Step.to(1, motion: linear100),
      const Step.hold(Duration(milliseconds: 100)),
    ]);

    p.advanceTo(0.05);
    expect(p.values.single, closeTo(0.5, error));
    p.advanceTo(0.15);
    expect(p.values.single, closeTo(1, error));
    p.advanceTo(0.25);
    expect(p.values.single, closeTo(1, error));
    p.advanceTo(0.35);
    expect(p.values.single, closeTo(0.5, error));
    p.advanceTo(0.4);
    expect(p.values.single, closeTo(0, error));
    p.advanceTo(0.45);
    expect(p.values.single, closeTo(0.5, error));
    expect(p.isDone, isFalse);
  });

  test('pingPong characterizes Step.at on the reverse leg', () {
    final p = playback([
      const Step.to(1, motion: linear100),
      const Step.at(
        Duration(milliseconds: 300),
        2,
        motion: linear100,
      ),
    ]);

    p.advanceTo(0.1);
    expect(p.values.single, closeTo(1, error));
    p.advanceTo(0.2);
    expect(p.values.single, closeTo(1.5, error));
    p.advanceTo(0.3);
    expect(p.values.single, closeTo(2, error));

    // CHARACTERIZATION: current behavior, believed incorrect — see plans/002.
    // The reverse Step.at uses its unscaled 100ms motion rather than mirroring
    // the forward schedule.
    p.advanceTo(0.35);
    expect(p.values.single, closeTo(1.5, error));
    p.advanceTo(0.4);
    expect(p.values.single, closeTo(1, error));
    p.advanceTo(0.45);
    expect(p.values.single, closeTo(0.5, error));
    p.advanceTo(0.5);
    expect(p.values.single, closeTo(0, error));
  });

  test('pingPong substitutes a hold for a reverse free step', () {
    final p = playback(
      [const Step.free(motion: FrictionMotion(drag: 0.1))],
      velocity: 10,
    );

    p.advanceTo(10);
    final settledValue = p.values.single;
    expect(settledValue, greaterThan(0));

    p.advanceTo(20);
    expect(p.values.single, closeTo(settledValue, error));
    expect(p.velocities.single, closeTo(0, error));
    expect(p.isDone, isFalse);
  });

  test('pingPong reverses through each previous waypoint', () {
    final p = playback([
      const Step.to(0.5, motion: linear100),
      const Step.to(1, motion: linear100),
    ]);

    p.advanceTo(0.05);
    expect(p.values.single, closeTo(0.25, error));
    p.advanceTo(0.15);
    expect(p.values.single, closeTo(0.75, error));
    p.advanceTo(0.25);
    expect(p.values.single, closeTo(0.75, error));
    p.advanceTo(0.3);
    expect(p.values.single, closeTo(0.5, error));
    p.advanceTo(0.35);
    expect(p.values.single, closeTo(0.25, error));
    p.advanceTo(0.4);
    expect(p.values.single, closeTo(0, error));
    p.advanceTo(0.45);
    expect(p.values.single, closeTo(0.25, error));
    expect(p.isDone, isFalse);
  });
}
