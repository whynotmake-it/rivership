// ignore_for_file: cascade_invocations, unawaited_futures

import 'package:flutter_test/flutter_test.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';
import 'package:motor_devtools/motor_devtools.dart';

void main() {
  testWidgets('lays out estimated, recorded, held, and synchronized segments', (
    tester,
  ) async {
    final track = Track<double>(
      MotionConverter.single,
      initial: 0,
      debugLabel: 'Scale',
    );
    final controller = TrackController(vsync: tester);
    controller.animate([
      track(
        const [
          TrackStep.to(
            1,
            motion: Motion.linear(Duration(milliseconds: 300)),
          ),
          TrackStep.hold(Duration(milliseconds: 100)),
          TrackStep.sync(token: 'ready'),
        ],
      ),
    ]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    final snapshot = controller.inspectPlayback();

    final layout = layoutMotorTimeline(
      snapshot,
      pixelsPerMillisecond: 1,
    );

    expect(layout.lanes, hasLength(1));
    expect(
      layout.totalDuration,
      greaterThanOrEqualTo(const Duration(milliseconds: 400)),
    );
    expect(
      layout.lanes.single.segments.map((segment) => segment.kind),
      [
        MotorTimelineSegmentKind.motion,
        MotorTimelineSegmentKind.hold,
        MotorTimelineSegmentKind.barrier,
      ],
    );
    expect(
      layout.lanes.single.segments.first.provenance,
      MotorTimelineProvenance.recorded,
    );
    expect(
      layout.lanes.single.segments[1].provenance,
      MotorTimelineProvenance.estimated,
    );
    controller.dispose();
  });
}
