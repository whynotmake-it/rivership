// ignore_for_file: unawaited_futures
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

void main() {
  testWidgets(
      'set() on one track while paused keeps a looping playPhases advancing',
      (tester) async {
    const motion = Motion.linear(Duration(milliseconds: 500));
    final a = Track<double>(MotionConverter.single, initial: 0);
    final b = Track<double>(MotionConverter.single, initial: 0);
    final c = PhaseTrackController<int>(vsync: tester);
    addTearDown(c.dispose);
    c.playPhases(
      TrackPhaseTimeline<int>(
        {
          0: [
            a([const TrackStep.to(0, motion: motion)]),
            b([const TrackStep.to(0, motion: motion)]),
          ],
          1: [
            a([const TrackStep.to(1, motion: motion)]),
            b([const TrackStep.to(1, motion: motion)]),
          ],
        },
        loop: LoopMode.loop,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    c
      ..pause()
      ..set([a.value(0.5)])
      ..resume();
    final phases = <int?>{};
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      phases.add(c.currentPhase);
    }
    expect(phases, containsAll(<int?>[0, 1]));
    expect(c.isAnimating, isTrue);
    c.stop(canceled: true);
  });
}
