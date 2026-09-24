// ignore_for_file: deprecated_member_use_from_same_package

import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

void main() {
  const linear1s = Motion.linear(Duration(seconds: 1));

  test('two-keyframe seamless sequence uses a non-zero motion slice', () {
    final sequence = MotionSequence.spanning(
      {0.0: 'a', 1.0: 'b'},
      motion: linear1s,
      loop: LoopMode.seamless,
    );

    final motion = sequence.motionForPhase(toPhase: 0);

    expect(motion, isA<TrimmedMotion>());
    final trimmed = motion as TrimmedMotion;
    expect(trimmed.fromStart + trimmed.fromEnd, lessThan(1));
  });

  test('three-keyframe seamless sequence uses the penultimate slice', () {
    final sequence = MotionSequence.spanning(
      {0.0: 'a', 0.5: 'b', 1.0: 'c'},
      motion: linear1s,
      loop: LoopMode.seamless,
    );

    final motion = sequence.motionForPhase(toPhase: 0);

    expect(motion, isA<TrimmedMotion>());
    final trimmed = motion as TrimmedMotion;
    expect(trimmed.fromStart, 0);
    expect(trimmed.fromEnd, 0.5);
  });
}
