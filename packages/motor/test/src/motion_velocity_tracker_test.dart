import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

void main() {
  group('MotionVelocityTracker', () {
    test('tracks single double value velocity', () {
      final tracker = MotionVelocityTracker<double>(MotionConverter.single)

        // t=0, v=0
        ..addPosition(Duration.zero, 0.0)

        // t=10ms, v=10. Velocity = 10 / 0.01 = 1000
        ..addPosition(const Duration(milliseconds: 10), 10.0);

      final estimate = tracker.getVelocityEstimate();
      expect(estimate, isNotNull);
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
      expect(estimate!.perSecond, closeTo(1000.0, 0.1));
    });

    test('tracks Offset velocity', () {
      final tracker = MotionVelocityTracker<Offset>(MotionConverter.offset)
        ..addPosition(Duration.zero, Offset.zero)
        ..addPosition(const Duration(milliseconds: 10), const Offset(10, 20))
        ..addPosition(const Duration(milliseconds: 20), const Offset(20, 40))
        ..addPosition(const Duration(milliseconds: 30), const Offset(30, 60));

      final estimate = tracker.getVelocityEstimate();
      expect(estimate!.perSecond.dx, closeTo(1000.0, 0.1));
      expect(estimate.perSecond.dy, closeTo(2000.0, 0.1));
    });

    test('returns zero if stopped for too long', () async {
      final tracker = MotionVelocityTracker<double>(MotionConverter.single)
        ..addPosition(Duration.zero, 0.0)
        ..addPosition(const Duration(milliseconds: 10), 10.0);

      // Wait 50ms (threshold is 40ms)
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final estimate = tracker.getVelocityEstimate();
      expect(estimate!.perSecond, 0.0);
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
      expect(estimate!.perSecond, closeTo(950.0, 0.1));
    });
  });
}
