// ignore_for_file: unawaited_futures
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

enum _P { a, b }

void main() {
  testWidgets(
      'set() on every track of a looping playPhases does not restart the loop',
      (tester) async {
    final x = Track<double>(
      MotionConverter.single,
      initial: 0,
      motion: const Motion.linear(Duration(milliseconds: 100)),
    );
    final c = PhaseTrackController<_P>(vsync: tester);
    addTearDown(c.dispose);
    final transitions = <PhaseTransition<_P>>[];
    final future = c.playPhases(
      TrackPhaseTimeline(
        {
          _P.a: [
            x([const TrackStep.to(0)]),
          ],
          _P.b: [
            x([const TrackStep.to(1)]),
          ],
        },
        loop: LoopMode.loop,
      ),
      onTransition: transitions.add,
    );
    var canceled = false;
    future.orCancel.catchError((_) => canceled = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Like a canceling stop: jump the track, start nothing.
    c.set([x.value(5)]);
    await tester.pump();
    expect(canceled, isTrue);
    transitions.clear();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    // Actual: the next frame finds nothing animating, calls
    // onPlaybackSettled, and the still-set _isPlayingPhases restarts the
    // loop from the first phase, animating x away from 5.
    expect(c.value(x), 5);
    expect(c.isAnimating, isFalse);
    expect(transitions, isEmpty);
    c.stop(canceled: true);
  });
}
