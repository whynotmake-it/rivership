// ignore_for_file: deprecated_member_use_from_same_package

import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

import 'util.dart';

void main() {
  test('MotionCurve samples its motion from the start velocity', () {
    final motion = SpringMotion(SpringDescription.withDurationAndBounce());
    final curve = MotionCurve(motion: motion);
    expect(curve.transform(0), equals(0.0));
    expect(curve.transform(1), closeTo(1.0, error));
    expect(curve.transform(0.5), inInclusiveRange(0.0, 1.0));

    expect(
      MotionCurve(motion: motion, velocity: 2).simulation.dx(0),
      equals(2.0),
    );
    expect(motion.toCurve.motion, equals(motion));
    expect(motion.toCurve.transform(0.5), curve.transform(0.5));
  });
}
