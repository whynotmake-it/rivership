import 'package:flutter_test/flutter_test.dart';
import 'package:springster/springster.dart';

void main() {
  group('SimpleSpring', () {
    test('creates with default parameters', () {
      const spring = SimpleSpring.smooth;
      expect(spring.duration, equals(0.5));
      expect(spring.bounce, equals(0));
      expect(spring.dampingFraction, equals(1.0));
    });

    test('creates with custom parameters', () {
      const spring = SimpleSpring(
        duration: 0.3,
        bounce: 0.5,
      );
      expect(spring.duration, equals(0.3));
      expect(spring.bounce, equals(0.5));
      expect(spring.dampingFraction, equals(0.5));
    });

    test('creates with damping fraction', () {
      const spring = SimpleSpring.withDamping(
        dampingFraction: 0.7,
        duration: 0.4,
      );
      expect(spring.duration, equals(0.4));
      expect(spring.bounce, closeTo(0.3, 0.0001));
      expect(spring.dampingFraction, equals(0.7));
    });

    test('extraBounce modifies bounce correctly', () {
      const spring = SimpleSpring(bounce: 0.2);
      final bouncier = spring.extraBounce(0.3);
      expect(bouncier.bounce, equals(0.5));
      expect(bouncier.duration, equals(spring.duration));
    });

    test('extraBounce with duration modifies both parameters', () {
      const spring = SimpleSpring(bounce: 0.2);
      final modified = spring.extraBounce(0.3, 0.7);
      expect(modified.bounce, equals(0.5));
      expect(modified.duration, equals(0.7));
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

    test('predefined springs have correct values', () {
      expect(SimpleSpring.instant.duration, equals(0));
      expect(SimpleSpring.bouncy.dampingFraction, equals(0.7));
      expect(SimpleSpring.smooth.dampingFraction, equals(1));
      expect(SimpleSpring.snappy.dampingFraction, equals(0.85));
      expect(SimpleSpring.interactive.duration, equals(0.15));
      expect(SimpleSpring.interactive.dampingFraction, equals(0.86));
    });
  });
}
