// ignore_for_file: deprecated_member_use_from_same_package

import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:motor/src/extensions/spring_description_extension.dart';

import 'util.dart';

void main() {
  group('MotionCurve', () {
    test('creates with spring description', () {
      final spring = SpringDescriptionExtension.withDurationAndBounce();
      final curve = MotionCurve(motion: SpringMotion(spring));
      expect(curve.motion, equals(SpringMotion(spring)));
    });

    test('creates with initial velocity', () {
      final spring = SpringDescriptionExtension.withDurationAndBounce();
      final curve = MotionCurve(motion: SpringMotion(spring), velocity: 2);
      expect(curve.motion, equals(SpringMotion(spring)));
      expect(curve.simulation.dx(0), equals(2.0));
    });

    test('transform returns values between 0 and 1', () {
      final curve = MotionCurve(
        motion:
            SpringMotion(SpringDescriptionExtension.withDurationAndBounce()),
      );
      expect(curve.transform(0), equals(0.0));
      expect(curve.transform(1), closeTo(1.0, 0.1));
      expect(curve.transform(0.5), inInclusiveRange(0.0, 1.0));
    });

    test('toCurve extension creates correct MotionCurve', () {
      final spring = SpringDescriptionExtension.withDurationAndBounce();
      final curve = SpringMotion(spring).toCurve;
      expect(curve, isA<MotionCurve>());

      final springMotion = curve.motion as SpringMotion;
      expect(springMotion.description, equalsSpring(spring));
    });
  });
}
