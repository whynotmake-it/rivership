// ignore_for_file: deprecated_member_use_from_same_package

import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

void main() {
  group('SpringCurve', () {
    test('creates with spring description', () {
      final spring = SpringDescription.withDurationAndBounce();
      final curve = SpringCurve(spring: spring);
      expect(curve.spring, equals(spring));
    });

    test('creates with initial velocity', () {
      final spring = SpringDescription.withDurationAndBounce();
      final curve = SpringCurve(spring: spring, velocity: 2);
      expect(curve.spring, equals(spring));
      expect(curve.simulation.dx(0), equals(2.0));
    });

    test('transform returns values between 0 and 1', () {
      final curve = SpringCurve(
        spring: SpringDescription.withDurationAndBounce(),
      );
      expect(curve.transform(0), equals(0.0));
      expect(curve.transform(1), closeTo(1.0, 0.1));
      expect(curve.transform(0.5), inInclusiveRange(0.0, 1.0));
    });

    test('simulation uses provided spring description', () {
      const spring = SpringDescription(
        mass: 1,
        stiffness: 100,
        damping: 10,
      );
      final curve = SpringCurve(spring: spring);
      expect(curve.spring.mass, equals(1.0));
      expect(curve.spring.stiffness, equals(100.0));
      expect(curve.spring.damping, equals(10.0));
    });

    test('toCurve extension creates correct SpringCurve', () {
      final spring = SpringDescription.withDurationAndBounce();
      final curve = spring.toCurve;
      expect(curve, isA<SpringCurve>());
      expect(curve.spring, equals(spring));
    });
  });
}
