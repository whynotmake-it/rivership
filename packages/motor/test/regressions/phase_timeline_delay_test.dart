import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

void main() {
  test('a TrackPhaseTimeline rejects animations with a delay', () {
    final a = Track<double>(MotionConverter.single, initial: 0);
    expect(
      () => TrackPhaseTimeline<int>({
        0: [
          a(
            [
              const TrackStep.to(
                1,
                motion: Motion.linear(Duration(milliseconds: 100)),
              ),
            ],
            delay: const Duration(milliseconds: 50),
          ),
        ],
      }),
      throwsAssertionError,
    );
  });
}
