import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

import 'util.dart';

void main() {
  group('MotionVelocityTracker', () {
    test('a single pair yields a low-confidence (under-weighted) estimate', () {
      final tracker = MotionVelocityTracker<double>(MotionConverter.single)

        // t=0, v=0
        ..addPosition(Duration.zero, 0.0)

        // t=10ms, v=10. The instantaneous pair velocity is 10 / 0.01 = 1000.
        ..addPosition(const Duration(milliseconds: 10), 10.0);

      // With only one pair of samples available, just the most-recent slot is
      // populated, which carries the smallest weight (0.05). So the estimate is
      // deliberately conservative: 1000 * 0.05 = 50. Full confidence requires
      // more history (see the next test).
      final estimate = tracker.getVelocityEstimate();
      expect(estimate!.perSecond, closeTo(50.0, error));
    });

    test('tracks velocity with enough history', () {
      final tracker = MotionVelocityTracker<double>(MotionConverter.single)

        // Provide constant velocity 1000.
        // Samples at 0, 10, 20, 30.
        ..addPosition(Duration.zero, 0.0)
        ..addPosition(const Duration(milliseconds: 10), 10.0)
        ..addPosition(const Duration(milliseconds: 20), 20.0)
        ..addPosition(const Duration(milliseconds: 30), 30.0);

      // v0: 30-20 (1000)
      // v-1: 20-10 (1000)
      // v-2: 10-0 (1000)

      // sum = 1000 * (0.6 + 0.35 + 0.05) = 1000.

      final estimate = tracker.getVelocityEstimate();
      expect(estimate!.perSecond, closeTo(1000.0, error));
    });

    test('tracks Offset velocity', () {
      final tracker = MotionVelocityTracker<Offset>(MotionConverter.offset)
        ..addPosition(Duration.zero, Offset.zero)
        ..addPosition(const Duration(milliseconds: 10), const Offset(10, 20))
        ..addPosition(const Duration(milliseconds: 20), const Offset(20, 40))
        ..addPosition(const Duration(milliseconds: 30), const Offset(30, 60));

      final estimate = tracker.getVelocityEstimate();
      expect(estimate!.perSecond.dx, closeTo(1000.0, error));
      expect(estimate.perSecond.dy, closeTo(2000.0, error));
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

    test('weighted average check', () {
      final tracker = MotionVelocityTracker<double>(MotionConverter.single)

        // v(-2): t=0->10, x=0->10 (v=1000)
        ..addPosition(Duration.zero, 0.0)
        ..addPosition(const Duration(milliseconds: 10), 10.0)

        // v(-1): t=10->20, x=10->20 (v=1000)
        ..addPosition(const Duration(milliseconds: 20), 20.0)

        // v(0): t=20->30, x=20->20 (v=0)
        ..addPosition(const Duration(milliseconds: 30), 20.0);

      // Expected:
      // v(-2) = 1000 * 0.6 = 600
      // v(-1) = 1000 * 0.35 = 350
      // v(0) = 0 * 0.05 = 0
      // Total = 950

      final estimate = tracker.getVelocityEstimate();
      expect(estimate!.perSecond, closeTo(950.0, error));
    });
  });
}
