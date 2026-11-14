// ignore_for_file: unawaited_futures
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

void main() {
  testWidgets(
      'a graceful stop of one track while paused does not resume the others',
      (tester) async {
    final a = Track<double>(MotionConverter.single, initial: 0);
    final b = Track<double>(MotionConverter.single, initial: 0);
    final c = TrackController(vsync: tester);
    addTearDown(c.dispose);
    c.animate([
      a([const TrackStep.to(1, motion: CupertinoMotion.smooth())]),
      b([const TrackStep.to(1, motion: Motion.linear(Duration(seconds: 1)))]),
    ]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    c.pause();
    final bPaused = c.value(b);
    c.stop(tracks: [a]); // graceful: the spring settles
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    // b was paused and nobody resumed or replayed it.
    expect(c.value(b), bPaused);
    c.stop(canceled: true);
  });
}
