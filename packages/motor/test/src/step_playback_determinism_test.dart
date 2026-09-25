// ignore_for_file: cascade_invocations, unawaited_futures

import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:motor/src/simulations/step_playback.dart';

/// Playback must be a function of time alone: ticking live and seeking
/// straight to a time have to produce the same values, including for bouncy
/// springs whose `isDone` flickers before they settle.
void main() {
  const plans = <String, List<TrackStep<double>>>{
    'free then springs': [
      TrackStep.free(motion: FreeMotion.friction()),
      TrackStep.to(0, motion: Motion.bouncySpring()),
      TrackStep.to(1, motion: Motion.smoothSpring()),
    ],
    'bouncy springs': [
      TrackStep.to(1, motion: Motion.bouncySpring()),
      TrackStep.to(0, motion: Motion.bouncySpring(extraBounce: 0.2)),
    ],
  };
  const frame = 1 / 60;
  const length = 12.0;

  for (final MapEntry(key: name, value: steps) in plans.entries) {
    for (final loop in LoopMode.values) {
      for (final velocity in [0.0, 5.0]) {
        test('$name, $loop, velocity $velocity: live matches a fresh seek', () {
          StepPlayback<double> playback() => StepPlayback<double>(
                steps: steps,
                converter: MotionConverter.single,
                start: 0,
                velocity: velocity,
                loop: loop,
              );

          final live = playback();
          final liveValues = <double>[];
          for (var i = 0; i * frame <= length; i++) {
            live.advanceTo(i * frame);
            liveValues.add(live.values.single);
          }

          final farSeek = playback()..advanceTo(length);
          for (var i = liveValues.length - 1; i >= 0; i -= 7) {
            farSeek.advanceTo(i * frame);
            expect(
              farSeek.values.single,
              closeTo(liveValues[i], 1e-9),
              reason: 'after a far seek, at ${i * frame}s',
            );

            final fresh = playback()..advanceTo(i * frame);
            expect(
              fresh.values.single,
              closeTo(liveValues[i], 1e-9),
              reason: 'fresh seek to ${i * frame}s',
            );
          }
        });
      }
    }
  }

  testWidgets('scrubbing a fresh controller matches live playback',
      (tester) async {
    final track = Track<double>(MotionConverter.single, initial: 0);
    TrackTimeline timeline() => TrackTimeline([
          track(plans['free then springs']!, withVelocity: 5),
        ]);

    final live = TrackController(vsync: tester)..play(timeline());
    await tester.pump();
    final values = <double>[];
    for (var i = 1; i <= 480; i++) {
      await tester.pump(const Duration(microseconds: 16667));
      values.add(live.value(track));
    }
    live.stop(canceled: true);

    final scrubbed = TrackController(vsync: tester)..play(timeline());
    scrubbed
      ..pause()
      ..scrubTo(const Duration(microseconds: 16667 * 480));
    for (var i = values.length - 1; i >= 0; i -= 5) {
      scrubbed.scrubTo(Duration(microseconds: 16667 * (i + 1)));
      expect(scrubbed.value(track), closeTo(values[i], 1e-9));
    }
    scrubbed.stop(canceled: true);

    live.dispose();
    scrubbed.dispose();
  });
}
