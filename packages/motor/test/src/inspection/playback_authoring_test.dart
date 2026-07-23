// ignore_for_file: cascade_invocations, unawaited_futures

import 'package:flutter_test/flutter_test.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';

import '../util.dart';

void main() {
  testWidgets('playback speed is controller-local and updates while running', (
    tester,
  ) async {
    final slow = TrackController(vsync: tester, debugLabel: 'Slow');
    final normal = TrackController(vsync: tester, debugLabel: 'Normal');
    final slowTrack = Track<double>(
      MotionConverter.single,
      initial: 0,
      debugLabel: 'opacity',
    );
    final normalTrack = Track<double>(MotionConverter.single, initial: 0);
    const motion = Motion.linear(Duration(seconds: 1));

    slow.playbackSpeed = 0.25;
    slow.animate([slowTrack.to(1, motion: motion)]);
    normal.animate([normalTrack.to(1, motion: motion)]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(slow.value(slowTrack), closeTo(0.1, 0.02));
    expect(normal.value(normalTrack), closeTo(0.4, 0.02));

    slow.dispose();
    normal.dispose();
  });

  testWidgets('motion override replays the last clip from its authored start', (
    tester,
  ) async {
    final controller = TrackController(vsync: tester);
    final track = Track<double>(MotionConverter.single, initial: 0);
    const authored = Motion.linear(Duration(seconds: 1));
    const tuned = Motion.linear(Duration(milliseconds: 100));

    controller.animate([track.to(1, motion: authored)]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.value(track), closeTo(0.3, 0.02));

    controller.setMotionOverride(track, tuned);
    controller.replay();
    await tester.pump();
    expect(controller.value(track), closeTo(0, error));
    await tester.pump(const Duration(milliseconds: 150));

    expect(controller.value(track), closeTo(1, error));
    expect(controller.motionOverrides[track], tuned);

    controller.setMotionOverride(track, null);
    expect(controller.motionOverrides, isEmpty);
    controller.dispose();
  });
}
