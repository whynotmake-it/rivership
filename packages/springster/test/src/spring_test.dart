// ignore_for_file: deprecated_member_use_from_same_package

import 'package:flutter_test/flutter_test.dart';
import 'package:springster/src/simple_spring.dart';

void main() {
  group('Spring', () {
    test('creates with default parameters', () {
      const spring = SimpleSpring();
      expect(spring.durationSeconds, equals(0.5));
      expect(spring.bounce, equals(0));
      expect(spring.dampingFraction, equals(1.0));
    });

    test('creates with custom parameters', () {
      const spring = SimpleSpring(
        durationSeconds: 0.3,
        bounce: 0.5,
      );
      expect(spring.durationSeconds, equals(0.3));
      expect(spring.bounce, equals(0.5));
      expect(spring.dampingFraction, equals(0.5));
    });

    test('creates with damping fraction', () {
      const spring = SimpleSpring.withDamping(
        dampingFraction: 0.7,
        durationSeconds: 0.4,
      );
      expect(spring.durationSeconds, equals(0.4));
      expect(spring.bounce, closeTo(0.3, 0.0001));
      expect(spring.dampingFraction, equals(0.7));
    });

    test('copyWith modifies bounce correctly', () {
      const spring = SimpleSpring(bounce: 0.2);
      final bouncier = spring.copyWith(bounce: 0.5);
      expect(bouncier.bounce, equals(0.5));
      expect(bouncier.durationSeconds, equals(spring.durationSeconds));
    });

    test('copyWith with duration modifies both parameters', () {
      const spring = SimpleSpring(bounce: 0.2);
      final modified = spring.copyWith(bounce: 0.5, durationSeconds: 0.7);
      expect(modified.bounce, equals(0.5));
      expect(modified.durationSeconds, equals(0.7));
    });

    test('bounce is clamped between -1 and 1', () {
      expect(
        () => SimpleSpring(bounce: 1.5),
        throwsAssertionError,
      );
      expect(
        () => SimpleSpring(bounce: -1.5),
        throwsAssertionError,
      );
    });
  });
}
