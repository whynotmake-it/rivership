import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

import 'util.dart';

void main() {
  group('MotionVelocityTracker', () {
    test('weights the most recent pair least', () {
      // Pair velocities are weighted 0.6, 0.35 and 0.05 from oldest to newest.
      // A single pair only fills the newest slot, so its estimate is
      // deliberately conservative until there is more history.
      for (final (name, positions, expected) in [
        ('a single pair', [0.0, 10.0], 1000 * 0.05),
        ('constant velocity', [0.0, 10.0, 20.0, 30.0], 1000.0),
        ('a stop in the newest pair', [0.0, 10.0, 20.0, 20.0], 950.0),
      ]) {
        final tracker = MotionVelocityTracker<double>(MotionConverter.single);
        for (final (i, position) in positions.indexed) {
          tracker.addPosition(Duration(milliseconds: 10 * i), position);
        }
        expect(
          tracker.getVelocityEstimate()!.perSecond,
          closeTo(expected, error),
          reason: name,
        );
      }
    });

    test('returns zero if stopped for too long', () {
      // fakeAsync controls package:clock, which the tracker uses for its
      // "pointer stopped" detection, so this is deterministic (no real wait).
      fakeAsync((async) {
        final tracker = MotionVelocityTracker<double>(MotionConverter.single)
          ..addPosition(Duration.zero, 0.0)
          ..addPosition(const Duration(milliseconds: 10), 10.0);

        // Just under the 40ms threshold: still reports a velocity.
        async.elapse(const Duration(milliseconds: 39));
        expect(tracker.getVelocityEstimate()!.perSecond, isNot(0.0));

        // Past the threshold: movement is considered stopped -> zero velocity.
        async.elapse(const Duration(milliseconds: 2));
        expect(tracker.getVelocityEstimate()!.perSecond, 0.0);
      });
    });

    test('keeps the latest 20 samples as the buffer wraps around', () {
      for (final count in [4, 19, 20, 21, 57]) {
        final tracker = MotionVelocityTracker<Offset>(MotionConverter.offset);
        for (var i = 0; i < count; i++) {
          tracker.addPosition(
            Duration(milliseconds: 16 * i),
            Offset(i * 8.0, i * -4.0),
          );
        }

        final kept = count < 20 ? count : 20;
        final estimate = tracker.getVelocityEstimate()!;
        expect(estimate.perSecond.dx, closeTo(500, error), reason: '$count');
        expect(estimate.perSecond.dy, closeTo(-250, error), reason: '$count');
        expect(estimate.duration, Duration(milliseconds: 16 * (kept - 1)));
        expect(estimate.offset, Offset(8.0 * (kept - 1), -4.0 * (kept - 1)));
      }
    });
  });
}
