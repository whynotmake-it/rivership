// ignore_for_file: unawaited_futures

import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

void main() {
  const fast = Motion.linear(Duration(milliseconds: 100));
  const slow = Motion.linear(Duration(milliseconds: 1000));

  Future<double> run(
    WidgetTester tester,
    void Function(TrackController c, Track<double> b) interrupt,
  ) async {
    final a = Track<double>(MotionConverter.single, initial: 0);
    final b = Track<double>(MotionConverter.single, initial: 0);
    final c = TrackController(vsync: tester);
    addTearDown(c.dispose);
    c.play(
      TrackTimeline([
        a([
          const TrackStep.to(1, motion: fast),
          const TrackStep.sync(token: #meet),
          const TrackStep.to(2, motion: slow),
        ]),
        b([
          const TrackStep.to(1, motion: slow),
          const TrackStep.sync(token: #meet),
        ]),
      ]),
    );
    await tester.pump();
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    // A has waited at the barrier since 100 ms; now (300 ms) B leaves.
    expect(c.value(a), 1);
    interrupt(c, b);
    await tester.pump(const Duration(milliseconds: 10));
    final shown = c.value(a);
    c.stop(canceled: true);
    return shown;
  }

  testWidgets(
      'set() on a barrier participant releases the waiters no earlier than '
      'the set, like a canceling stop', (tester) async {
    final afterStop =
        await run(tester, (c, b) => c.stop(tracks: [b], canceled: true));
    final afterSet = await run(tester, (c, b) => c.set([b.value(5)]));
    // After a canceling stop, A is released at 300 ms: 10 ms into its
    // 1000 ms move.
    expect(afterStop, closeTo(1.01, 1e-6));
    // set() is documented to act like a canceling stop.
    // Actual: 1.21, A plays as if released at 100 ms and jumps 200 ms ahead.
    expect(afterSet, closeTo(1.01, 1e-6));
  });
}
