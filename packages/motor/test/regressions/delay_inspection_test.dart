// ignore_for_file: unawaited_futures
import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

void main() {
  const linear = Motion.linear(Duration(seconds: 1));
  const delay = Duration(milliseconds: 300);

  testWidgets('during a delay no step is current and the status is neutral',
      (tester) async {
    final a = Track<double>(MotionConverter.single, initial: 1);
    final c = TrackController(vsync: tester);
    addTearDown(c.dispose);
    c.animate([
      a([const TrackStep.to(0, motion: linear)], delay: delay),
    ]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final playback = c.internalInspectPlayback().tracks.single;
    expect(playback.currentStepIndex, -1);
    expect(playback.segments.first.stepIndex, -1);
    expect(c.value(a), 1);

    // The delay is not a move down: a graceful stop of the resting track
    // keeps it resting, not reporting a direction.
    c.stop();
    await tester.pump();
    expect(c.status, isNot(AnimationStatus.reverse));
    c.stop(canceled: true);
  });

  testWidgets('the first step becomes current when the delay ends',
      (tester) async {
    final a = Track<double>(MotionConverter.single, initial: 0);
    final c = TrackController(vsync: tester);
    addTearDown(c.dispose);
    c.animate([
      a([const TrackStep.to(1, motion: linear)], delay: delay),
    ]);
    await tester.pump();
    await tester.pump(delay + const Duration(milliseconds: 100));
    expect(c.internalInspectPlayback().tracks.single.currentStepIndex, 0);
    c.stop(canceled: true);
  });
}
