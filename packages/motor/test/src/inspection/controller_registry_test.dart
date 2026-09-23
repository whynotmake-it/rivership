import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';

void main() {
  testWidgets('reports named controller creation and disposal', (tester) async {
    final observer = _RecordingObserver();
    final subscription = MotorInspectionRegistry.attach(observer);
    final controller = TrackController(
      vsync: tester,
      debugLabel: 'Checkout confirmation',
    );

    expect(observer.registered, [controller]);
    expect(controller.debugLabel, 'Checkout confirmation');

    controller.dispose();
    expect(observer.unregistered, [controller]);
    subscription.dispose();
    expect(MotorInspectionRegistry.hasObservers, isFalse);
  });

  testWidgets('a later observer receives controllers held by active tooling', (
    tester,
  ) async {
    final first = _RecordingObserver();
    final firstSubscription = MotorInspectionRegistry.attach(first);
    final controller = TrackController(vsync: tester);
    final second = _RecordingObserver();
    final secondSubscription = MotorInspectionRegistry.attach(second);

    expect(second.registered, [controller]);

    secondSubscription.dispose();
    controller.dispose();
    firstSubscription.dispose();
  });

  testWidgets('motion controllers forward their debug label', (tester) async {
    final observer = _RecordingObserver();
    final subscription = MotorInspectionRegistry.attach(observer);
    final controller = SingleMotionController(
      motion: const Motion.linear(Duration(milliseconds: 100)),
      vsync: tester,
      debugLabel: 'Primary CTA',
    );

    expect(observer.registered.single.debugLabel, 'Primary CTA');
    expect(
      observer.registered.single.inspectPlayback().tracks,
      isEmpty,
    );

    controller.dispose();
    subscription.dispose();
  });

  testWidgets('attached tooling captures stable finite duration estimates', (
    tester,
  ) async {
    final observer = _RecordingObserver();
    final subscription = MotorInspectionRegistry.attach(observer);
    final controller = TrackController(vsync: tester);
    final track = Track<double>(MotionConverter.single, initial: 0);

    unawaited(
      controller.animate([
        track([
          const TrackStep.to(
            1,
            motion: Motion.linear(Duration(milliseconds: 120)),
          ),
          const TrackStep.hold(Duration(milliseconds: 40)),
          const TrackStep.to(
            0,
            motion: Motion.linear(Duration(milliseconds: 80)),
          ),
        ]),
      ]),
    );
    await tester.pump();

    final initial =
        controller.inspectPlayback().tracks.single.estimatedStepDurations;
    expect(initial, const [
      Duration(milliseconds: 120),
      Duration(milliseconds: 40),
      Duration(milliseconds: 80),
    ]);

    await tester.pump(const Duration(milliseconds: 150));
    expect(
      controller.inspectPlayback().tracks.single.estimatedStepDurations,
      initial,
    );

    controller.dispose();
    subscription.dispose();
  });

  testWidgets('estimates match actual durations across a barrier', (
    tester,
  ) async {
    final subscription = MotorInspectionRegistry.attach(_RecordingObserver());
    final controller = TrackController(vsync: tester);
    final fast = Track<double>(MotionConverter.single, initial: 0);
    final slow = Track<double>(MotionConverter.single, initial: 0);

    unawaited(
      controller.animate([
        fast([
          const TrackStep.to(1, motion: Motion.snappySpring()),
          const TrackStep.sync(token: #meet),
          const TrackStep.to(0, motion: Motion.bouncySpring()),
        ]),
        slow([
          const TrackStep.to(1, motion: Motion.smoothSpring()),
          const TrackStep.sync(token: #meet),
          const TrackStep.to(0, motion: Motion.linear(Duration(seconds: 1))),
        ]),
      ]),
    );
    await tester.pump();
    List<TrackPlayback> tracks() => controller.inspectPlayback().tracks;
    final estimates = [for (final t in tracks()) t.estimatedStepDurations];

    await tester.pumpAndSettle(const Duration(milliseconds: 1));
    final actual = [for (final t in tracks()) t.stepDurations];

    for (var track = 0; track < 2; track++) {
      for (var step = 0; step < 3; step++) {
        expect(
          (estimates[track][step]! - actual[track][step]!).inMicroseconds.abs(),
          lessThan(Duration.microsecondsPerMillisecond),
          reason: 'track $track step $step',
        );
      }
    }

    controller.dispose();
    subscription.dispose();
  });

  testWidgets('estimates simulated durations to the millisecond', (
    tester,
  ) async {
    final subscription = MotorInspectionRegistry.attach(_RecordingObserver());
    final controller = TrackController(vsync: tester);
    final track = Track<double>(MotionConverter.single, initial: 0);

    unawaited(
      controller.animate([
        track.free(const FrictionMotion(), withVelocity: 1000),
      ]),
    );
    await tester.pump();
    final estimate = controller
        .inspectPlayback()
        .tracks
        .single
        .estimatedStepDurations
        .single;

    await tester.pumpAndSettle(const Duration(milliseconds: 1));
    final actual =
        controller.inspectPlayback().tracks.single.stepDurations.single;

    expect(estimate, isNotNull);
    expect(
      (estimate! - actual!).inMicroseconds.abs(),
      lessThan(Duration.microsecondsPerMillisecond),
    );

    controller.dispose();
    subscription.dispose();
  });

  testWidgets('builders pass their debug labels to their controllers', (
    tester,
  ) async {
    final observer = _RecordingObserver();
    final subscription = MotorInspectionRegistry.attach(observer);
    final track = Track<double>(MotionConverter.single, initial: 0);
    const motion = Motion.linear(Duration(milliseconds: 100));
    Widget build(BuildContext context, Object value, Widget? child) =>
        const SizedBox();

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Overlay(
          initialEntries: [
            OverlayEntry(
              builder: (context) => Column(
                children: [
                  TrackBuilder(
                    debugLabel: 'Tracks',
                    animations: [track.to(1, motion: motion)],
                    builder: (context, value, child) => const SizedBox(),
                  ),
                  PhaseTrackBuilder<int>(
                    debugLabel: 'Phases',
                    timeline: TrackPhaseTimeline({
                      0: [track.to(1, motion: motion)],
                    }),
                    builder: (context, value, phase, child) => const SizedBox(),
                  ),
                  SingleMotionBuilder(
                    debugLabel: 'Single value',
                    value: 1,
                    motion: motion,
                    builder: build,
                  ),
                  const MotionDraggable(
                    debugLabel: 'Draggable',
                    data: 1,
                    child: SizedBox(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    expect(
      [for (final controller in observer.registered) controller.debugLabel],
      containsAll(['Tracks', 'Phases', 'Single value', 'Draggable']),
    );

    await tester.pumpWidget(const SizedBox());
    subscription.dispose();
  });
}

class _RecordingObserver implements MotorInspectionObserver {
  final registered = <TrackController>[];
  final unregistered = <TrackController>[];

  @override
  void didRegisterController(TrackController controller) {
    registered.add(controller);
  }

  @override
  void didUnregisterController(TrackController controller) {
    unregistered.add(controller);
  }
}
