import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

void main() {
  group('MotionVelocityTracker', () {
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
  });
}
