// ignore_for_file: cascade_invocations, unawaited_futures

import 'package:flutter_test/flutter_test.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';
import 'package:motor_devtools/src/timeline.dart';

class _Observer implements MotorInspectionObserver {
  @override
  void didRegisterController(TrackController controller) {}

  @override
  void didUnregisterController(TrackController controller) {}
}

const _ms = Duration(milliseconds: 1);

void main() {
  late MotorInspectionSubscription subscription;
  setUp(() => subscription = MotorInspectionRegistry.attach(_Observer()));
  tearDown(() => subscription.dispose());

  final a = Track<double>(MotionConverter.single, initial: 0, debugLabel: 'a');
  final b = Track<double>(MotionConverter.single, initial: 0, debugLabel: 'b');

  testWidgets('lays out resolved and estimated steps on the playback clock', (
    tester,
  ) async {
    final controller = TrackController(vsync: tester);
    controller.animate([
      a(const [
        TrackStep.to(1, motion: Motion.linear(Duration(milliseconds: 300))),
        TrackStep.hold(Duration(milliseconds: 100)),
        TrackStep.sync(token: 'x'),
        TrackStep.to(0, motion: Motion.linear(Duration(milliseconds: 200))),
      ]),
      b(const [
        TrackStep.to(1, motion: Motion.linear(Duration(milliseconds: 600))),
        TrackStep.sync(token: 'x'),
      ]),
    ]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final layout = layoutTimeline(controller.inspectPlayback());

    expect(layout.position, _ms * 100);
    expect(layout.window, TimelineWindow(Duration.zero, _ms * 800));
    final lane = layout.lanes.first;
    expect(lane.segments.map((segment) => segment.kind), [
      SegmentKind.motion,
      SegmentKind.hold,
      SegmentKind.sync,
      SegmentKind.motion,
    ]);
    expect(lane.segments.map((segment) => segment.start), [
      Duration.zero,
      _ms * 300,
      _ms * 400,
      _ms * 600,
    ]);
    expect(lane.end, _ms * 800);
    expect(layout.window.fractionOf(layout.position), closeTo(0.125, 1e-9));
    expect(layout.window.timeAt(0.5), _ms * 400);

    controller.dispose();
  });

  testWidgets('starts the window at the latest run', (tester) async {
    final controller = TrackController(vsync: tester);
    controller.animate([
      a.to(1, motion: const Motion.linear(Duration(milliseconds: 200))),
      b.to(1, motion: const Motion.linear(Duration(milliseconds: 200))),
    ]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final restart = controller.inspectPlayback().position;
    controller.animate([
      a.to(0, motion: const Motion.linear(Duration(milliseconds: 400))),
    ]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final layout = layoutTimeline(controller.inspectPlayback());

    expect(layout.window.start, restart);
    expect(layout.window.end, restart + _ms * 400);
    expect(layout.lanes, hasLength(2));

    controller.dispose();
  });

  testWidgets('pages through a folded loop one cycle at a time', (
    tester,
  ) async {
    final controller = TrackController(vsync: tester);
    controller.play(
      TrackTimeline(
        [
          a(const [
            TrackStep.to(1, motion: Motion.linear(Duration(milliseconds: 300))),
            TrackStep.to(0, motion: Motion.linear(Duration(milliseconds: 200))),
          ]),
        ],
        loop: LoopMode.loop,
      ),
    );
    await tester.pump();
    for (var i = 0; i < 21; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final snapshot = controller.inspectPlayback();
    expect(snapshot.tracks.single.loopPeriod, isNotNull);

    final layout = layoutTimeline(snapshot);

    final cycle = snapshot.tracks.single.loopPeriod!;
    expect(layout.window.length, cycle);
    expect(layout.window.start, cycle * 2);
    final visible = layout.lanes.single.segments.where(
      (segment) =>
          segment.end! > layout.window.start &&
          segment.start < layout.window.end,
    );
    expect(visible.first.start, layout.window.start);
    expect(visible.last.end, layout.window.end);

    controller.stop(canceled: true);
    controller.dispose();
  });

  testWidgets('keeps a given window, as while scrubbing', (tester) async {
    final controller = TrackController(vsync: tester);
    controller.animate([
      a.to(1, motion: const Motion.linear(Duration(milliseconds: 200))),
    ]);
    await tester.pump();
    const window = TimelineWindow(Duration.zero, Duration(seconds: 2));

    final layout = layoutTimeline(controller.inspectPlayback(), window: window);

    expect(layout.window, window);
    controller.dispose();
  });
}
