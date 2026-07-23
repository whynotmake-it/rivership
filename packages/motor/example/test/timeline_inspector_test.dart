// ignore_for_file: cascade_invocations, unawaited_futures

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/widgets/timeline_inspector.dart';

Track<double> _track() => Track(.single, initial: 0);

const _linear50 = Motion.linear(Duration(milliseconds: 50));
const _linear100 = Motion.linear(Duration(milliseconds: 100));

void main() {
  testWidgets('layout refines estimates with recorded engine timing', (
    tester,
  ) async {
    final controller = TrackController(vsync: tester);
    addTearDown(controller.dispose);
    final quick = _track();
    final slow = _track();
    controller.animate([
      quick.to(1, motion: _linear50),
      slow.to(1, motion: _linear100),
    ]);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    final layout = layoutPlayback(
      controller.inspectPlayback(),
      pixelsPerMillisecond: 1,
    );

    expect(layout.lanes, hasLength(2));
    expect(
      layout.lanes.first.segments.single.provenance,
      TimelineTimingProvenance.recorded,
    );
    expect(
      layout.lanes.last.segments.single.provenance,
      TimelineTimingProvenance.estimated,
    );
    controller.stop(canceled: true);
  });

  testWidgets('spring span refines to its recorded settle duration', (
    tester,
  ) async {
    final controller = TrackController(vsync: tester);
    addTearDown(controller.dispose);
    final track = _track();
    const spring = CupertinoMotion(
      duration: Duration(milliseconds: 250),
      snapToEnd: false,
    );
    controller.animate([track.to(1, motion: spring)]);

    await tester.pump();
    await tester.pumpAndSettle();
    final snapshot = controller.inspectPlayback();
    final layout = layoutPlayback(snapshot, pixelsPerMillisecond: 1);
    final actual = snapshot.tracks.single.stepDurations.single!;

    expect(layout.lanes.single.segments.single.end, actual);
    expect(
      layout.lanes.single.segments.single.provenance,
      TimelineTimingProvenance.recorded,
    );
  });

  testWidgets('barrier uses the recorded release moment', (tester) async {
    final controller = TrackController(vsync: tester);
    addTearDown(controller.dispose);
    final fast = _track();
    final slow = _track();
    controller.animate([
      fast([
        const TrackStep.to(1, motion: _linear50),
        const TrackStep.sync(token: #meet),
        const TrackStep.to(2, motion: _linear100),
      ]),
      slow([
        const TrackStep.to(1, motion: _linear100),
        const TrackStep.sync(token: #meet),
        const TrackStep.to(2, motion: _linear100),
      ]),
    ]);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    final snapshot = controller.inspectPlayback();
    final layout = layoutPlayback(snapshot, pixelsPerMillisecond: 1);
    final release = snapshot.tracks.first.stepStarts[2]!;
    final barrier = layout.lanes.first.segments.firstWhere(
      (segment) => segment.kind == TimelineSegmentKind.barrier,
    );

    expect(barrier.start, release);
    expect(barrier.provenance, TimelineTimingProvenance.recorded);
    controller.stop(canceled: true);
  });

  testWidgets('rebuilds from an interrupted controller plan', (tester) async {
    final controller = TrackController(vsync: tester);
    addTearDown(controller.dispose);
    final first = _track();
    final second = _track();
    controller.animate([first.to(1, motion: _linear100)]);

    await tester.pumpWidget(
      CupertinoApp(
        home: SizedBox(
          width: 600,
          child: TimelineInspector(
            controller: controller,
            laneLabels: {first: 'first', second: 'second'},
          ),
        ),
      ),
    );
    await tester.pump();
    controller.animate([second.to(1, motion: _linear100)]);
    await tester.pump();

    expect(find.byType(TimelineInspector), findsOneWidget);
    expect(tester.takeException(), isNull);
    controller.stop(canceled: true);
  });

  testWidgets('lane groups collapse related tracks into one lane', (
    tester,
  ) async {
    final controller = TrackController(vsync: tester);
    addTearDown(controller.dispose);
    final tracks = [for (var i = 0; i < 10; i++) _track()];
    controller.animate([
      for (final track in tracks) track.to(1, motion: _linear100),
    ]);
    await tester.pump();

    final grouped = layoutPlayback(
      controller.inspectPlayback(),
      pixelsPerMillisecond: 1,
      laneGroups: [
        {...tracks},
      ],
    );
    expect(grouped.lanes, hasLength(1));
    expect(grouped.lanes.single.tracks, hasLength(10));

    expect(
      () =>
          layoutPlayback(controller.inspectPlayback(), pixelsPerMillisecond: 1),
      throwsAssertionError,
    );
    controller.stop(canceled: true);
  });

  testWidgets('drag pauses, scrubs, and resumes from the selected value', (
    tester,
  ) async {
    final controller = TrackController(vsync: tester);
    addTearDown(controller.dispose);
    final track = _track();
    controller.animate([
      track.to(1, motion: const Motion.linear(Duration(milliseconds: 600))),
    ]);
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: SizedBox(
            width: 500,
            child: TimelineInspector(controller: controller),
          ),
        ),
      ),
    );
    await tester.pump();

    final canvas = find.byKey(const ValueKey('timeline-inspector-canvas'));
    final rect = tester.getRect(canvas);
    final gesture = await tester.startGesture(
      Offset(rect.left + rect.width * .25, rect.center.dy),
    );
    await gesture.moveTo(Offset(rect.left + rect.width * .7, rect.center.dy));
    await tester.pump();

    expect(controller.isAnimating, isFalse);
    final scrubbed = controller.value(track);
    expect(scrubbed, greaterThan(.4));

    await gesture.up();
    await tester.pump();
    expect(controller.isAnimating, isTrue);
    await tester.pump(const Duration(milliseconds: 40));
    expect(controller.value(track), greaterThanOrEqualTo(scrubbed));
    controller.stop(canceled: true);
  });

  testWidgets('loop playhead stays inside the current rendered leg', (
    tester,
  ) async {
    final controller = TrackController(vsync: tester);
    addTearDown(controller.dispose);
    final track = _track();
    controller.play(
      TrackTimeline([track.to(1, motion: _linear50)], loop: LoopMode.pingPong),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    final layout = layoutPlayback(
      controller.inspectPlayback(),
      pixelsPerMillisecond: 1,
    );
    expect(layout.lanes.single.playhead, greaterThanOrEqualTo(Duration.zero));
    expect(
      layout.lanes.single.playhead,
      lessThanOrEqualTo(layout.lanes.single.end),
    );
    controller.stop(canceled: true);
  });
}
