// ignore_for_file: cascade_invocations, unawaited_futures

import 'package:flutter/physics.dart';
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

  testWidgets('motion override replaces target step motions in new plans', (
    tester,
  ) async {
    final controller = TrackController(vsync: tester);
    final track = Track<double>(MotionConverter.single, initial: 0);
    final other = Track<double>(MotionConverter.single, initial: 0);
    const authored = Motion.linear(Duration(seconds: 1));
    const tuned = Motion.linear(Duration(milliseconds: 100));

    controller.motionOverride = (t) => identical(t, track) ? tuned : null;
    controller.animate([
      track([const TrackStep.to(1, motion: authored)]),
      other.to(1, motion: authored),
    ]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(controller.value(track), closeTo(0.5, error));
    expect(controller.value(other), closeTo(0.05, error));

    // Without the override, the authored 1s motion runs from 0.5 back to 0.
    controller.motionOverride = null;
    controller.animate([track.to(0, motion: authored)]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.value(track), closeTo(0.45, error));

    controller.stop(canceled: true);
    controller.dispose();
  });

  testWidgets('records submitted plans with their start values', (
    tester,
  ) async {
    final subscription = MotorInspectionRegistry.attach(_Observer());
    final track = Track<double>(MotionConverter.single);
    final controller = TrackController(
      vsync: tester,
      initialValues: [track.value(5)],
    );

    controller.animate(
      [track.free(const FrictionMotion(), withVelocity: 100)],
      loop: LoopMode.seamless,
    );
    await tester.pump();

    final plan = controller.inspectPlayback().plans.single;
    expect(plan.startValues.single.value, 5);
    expect(plan.loop, LoopMode.seamless);
    expect(plan.animations.single.track, track);

    controller.dispose();
    subscription.dispose();
  });

  testWidgets('records no plans without an inspection observer', (
    tester,
  ) async {
    final track = Track<double>(MotionConverter.single, initial: 0);
    final controller = TrackController(vsync: tester)
      ..animate([track.to(1, motion: const Motion.linear(Duration.zero))]);
    await tester.pump();

    expect(controller.inspectPlayback().plans, isEmpty);
    controller.dispose();
  });
  for (final inspecting in [false, true]) {
    testWidgets(
        'a step without a motion fails when played '
        '${inspecting ? 'with' : 'without'} tooling', (tester) async {
      final subscription =
          inspecting ? MotorInspectionRegistry.attach(_Observer()) : null;
      addTearDown(() => subscription?.dispose());
      final controller = TrackController(vsync: tester);
      addTearDown(controller.dispose);
      final track = Track<double>(MotionConverter.single, initial: 0);
      const linear = Motion.linear(Duration(seconds: 1));
      final steps = [
        const TrackStep.to(1.0, motion: linear),
        const TrackStep.to(2.0),
      ];

      // A regression would start the ticker; stop it so the test fails
      // instead of hanging on the active ticker.
      try {
        expect(
          () => controller.animate([
            track(steps),
          ]),
          throwsAssertionError,
        );
      } finally {
        controller.stop(canceled: true);
      }
    });
  }

  testWidgets('a failure while resolving ahead for tooling does not stop play',
      (tester) async {
    final subscription = MotorInspectionRegistry.attach(_Observer());
    addTearDown(subscription.dispose);
    final controller = TrackController(vsync: tester);
    addTearDown(controller.dispose);
    final track = Track<double>(MotionConverter.single, initial: 0);

    controller.animate([
      track([
        const TrackStep.to(1, motion: Motion.linear(Duration(seconds: 1))),
        const TrackStep.to(2, motion: _ThrowingMotion()),
      ]),
    ]);

    expect(tester.takeException(), isStateError);
    expect(controller.isAnimating, isTrue);
    expect(controller.inspectPlayback().plans, hasLength(1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(controller.value(track), closeTo(0.5, error));
    controller.stop(canceled: true);
  });
}

class _Observer implements MotorInspectionObserver {
  @override
  void didRegisterController(TrackController controller) {}

  @override
  void didUnregisterController(TrackController controller) {}
}

/// A motion whose simulation cannot be created.
class _ThrowingMotion extends Motion {
  const _ThrowingMotion();

  @override
  bool get needsSettle => false;

  @override
  bool get unboundedWillSettle => true;

  @override
  Simulation createSimulation({
    double start = 0,
    double end = 1,
    double velocity = 0,
  }) =>
      throw StateError('no simulation');

  @override
  bool operator ==(Object other) => other is _ThrowingMotion;

  @override
  int get hashCode => (_ThrowingMotion).hashCode;
}
