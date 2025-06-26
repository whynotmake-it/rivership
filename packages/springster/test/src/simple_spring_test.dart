import 'package:flutter_test/flutter_test.dart';
import 'package:springster/springster.dart';

void main() {
  group('Spring', () {
    test('creates with default parameters', () {
      const spring = Spring();
      expect(spring.durationSeconds, equals(0.5));
      expect(spring.bounce, equals(0));
      expect(spring.dampingFraction, equals(1.0));
    });

    test('creates with custom parameters', () {
      const spring = Spring(
        durationSeconds: 0.3,
        bounce: 0.5,
      );
      expect(spring.durationSeconds, equals(0.3));
      expect(spring.bounce, equals(0.5));
      expect(spring.dampingFraction, equals(0.5));
    });

    test('creates with damping fraction', () {
      const spring = Spring.withDamping(
        dampingFraction: 0.7,
        durationSeconds: 0.4,
      );
      expect(spring.durationSeconds, equals(0.4));
      expect(spring.bounce, closeTo(0.3, 0.0001));
      expect(spring.dampingFraction, equals(0.7));
    });

    test('copyWith modifies bounce correctly', () {
      const spring = Spring(bounce: 0.2);
      final bouncier = spring.copyWith(bounce: 0.5);
      expect(bouncier.bounce, equals(0.5));
      expect(bouncier.durationSeconds, equals(spring.durationSeconds));
    });

    test('copyWith with duration modifies both parameters', () {
      const spring = Spring(bounce: 0.2);
      final modified = spring.copyWith(bounce: 0.5, durationSeconds: 0.7);
      expect(modified.bounce, equals(0.5));
      expect(modified.durationSeconds, equals(0.7));
    });

    test('bounce is clamped between -1 and 1', () {
      expect(
        () => Spring(bounce: 1.5),
        throwsAssertionError,
      );
      expect(
        () => Spring(bounce: -1.5),
        throwsAssertionError,
      );
    });

    test('predefined springs have correct values', () {
      expect(Spring.instant.durationSeconds, equals(0));
      expect(Spring.bouncy.dampingFraction, equals(0.7));
      expect(const Spring().dampingFraction, equals(1));
      expect(Spring.snappy.dampingFraction, equals(0.85));
      expect(Spring.interactive.durationSeconds, equals(0.15));
      expect(Spring.interactive.dampingFraction, equals(0.86));
    });
  });
}
