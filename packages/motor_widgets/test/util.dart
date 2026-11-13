import 'package:flutter_test/flutter_test.dart';

/// A normal frame.
const frame = Duration(milliseconds: 16);

/// A short frame, so the change of velocity within one frame is small next to
/// the velocity itself.
const fineFrame = Duration(milliseconds: 2);

/// Expects the velocity across [samples], taken [fineFrame] apart, to be
/// continuous at [retargetAt], the first sample after a retarget.
///
/// The velocity before the retarget is the slope of the last frame before
/// it, the one after it the slope of the first frame after it. Keeping the
/// velocity, they differ only by the acceleration over a frame; restarting
/// from rest, the slope after would be near zero.
void expectContinuousVelocity(List<double> samples, {required int retargetAt}) {
  final dt = fineFrame.inMicroseconds / Duration.microsecondsPerSecond;
  double slope(int i) => (samples[i] - samples[i - 1]) / dt;

  final before = slope(retargetAt - 1);
  final after = slope(retargetAt);
  final beforeThat = slope(retargetAt - 2);
  // The change across the retarget is about as small as the change between
  // two frames of the old motion.
  final usualChange = (before - beforeThat).abs();
  expect(before.abs(), greaterThan(0.1), reason: 'should be moving');
  expect(
    (after - before).abs(),
    lessThan(usualChange * 4 + before.abs() * 0.05),
    reason:
        'velocity jumped from $before to $after at the retarget '
        '(samples: $samples)',
  );
}
