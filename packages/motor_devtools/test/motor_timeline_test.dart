// ignore_for_file: cascade_invocations, unawaited_futures

import 'package:flutter/animation.dart';
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

  test('authored geometry stays fixed as measurements arrive', () {
    final track = Track<double>(
      MotionConverter.single,
      initial: 0,
      debugLabel: 'Scale',
    );
    const steps = <TrackStep<Object>>[
      TrackStep.to(
        1.0,
        motion: Motion.linear(Duration(milliseconds: 300)),
      ),
      TrackStep.hold(Duration(milliseconds: 100)),
    ];

    PlaybackSnapshot snapshot({
      required List<Duration?> starts,
      required List<Duration?> durations,
    }) => PlaybackSnapshot(
      revision: 1,
      tickerElapsed: Duration.zero,
      status: AnimationStatus.forward,
      tracks: [
        TrackPlayback(
          track: track,
          steps: steps,
          hasSyntheticReturnStep: false,
          loop: LoopMode.none,
          currentStepIndex: 0,
          direction: 1,
          cycle: 0,
          isWaitingForSync: false,
          syncToken: null,
          startOffset: Duration.zero,
          playhead: Duration.zero,
          cycleStart: Duration.zero,
          stepStarts: starts,
          stepDurations: durations,
          estimatedStepDurations: const [null, null],
        ),
      ],
    );

    final estimated = layoutMotorTimeline(
      snapshot(starts: [Duration.zero, null], durations: [null, null]),
    );
    final measured = layoutMotorTimeline(
      snapshot(
        starts: [
          Duration.zero,
          const Duration(milliseconds: 700),
        ],
        durations: [
          const Duration(milliseconds: 700),
          const Duration(milliseconds: 100),
        ],
      ),
    );

    expect(measured.totalDuration, estimated.totalDuration);
    expect(
      measured.lanes.single.segments.map(
        (segment) => (segment.start, segment.end),
      ),
      estimated.lanes.single.segments.map(
        (segment) => (segment.start, segment.end),
      ),
    );
  });

  test('reverse legs render their playhead from right to left', () {
    final track = Track<double>(
      MotionConverter.single,
      initial: 0,
      debugLabel: 'Scale',
    );
    final snapshot = PlaybackSnapshot(
      revision: 1,
      tickerElapsed: const Duration(milliseconds: 1250),
      status: AnimationStatus.forward,
      tracks: [
        TrackPlayback(
          track: track,
          steps: const [
            TrackStep.to(
              1.0,
              motion: Motion.linear(Duration(seconds: 1)),
            ),
          ],
          hasSyntheticReturnStep: false,
          loop: LoopMode.pingPong,
          currentStepIndex: 0,
          direction: -1,
          cycle: 1,
          isWaitingForSync: false,
          syncToken: null,
          startOffset: Duration.zero,
          playhead: const Duration(milliseconds: 1250),
          cycleStart: const Duration(seconds: 1),
          stepStarts: const [Duration.zero],
          stepDurations: const [Duration(seconds: 1)],
          estimatedStepDurations: const [Duration(seconds: 1)],
        ),
      ],
    );

    final layout = layoutMotorTimeline(snapshot);

    expect(
      layout.lanes.single.playhead,
      const Duration(milliseconds: 750),
    );
  });
}
