// ignore_for_file: unawaited_futures
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

void main() {
  testWidgets(
      'a graceful stop of one track does not complete a looping phase future '
      'while the loop keeps running', (tester) async {
    const motion = Motion.linear(Duration(milliseconds: 500));
    final a = Track<double>(MotionConverter.single, initial: 0);
    final b = Track<double>(MotionConverter.single, initial: 0);
    final c = PhaseTrackController<int>(vsync: tester);
    addTearDown(c.dispose);
    var done = false;
    c
        .playPhases(
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
        )
        .then((_) => done = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    c.stop(tracks: [a]);
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(done, isFalse, reason: 'the loop still plays track b');
    }
    expect(c.isAnimating, isTrue);
    c.stop(canceled: true);
  });
}
