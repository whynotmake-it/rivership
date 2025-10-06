import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heroine/heroine.dart';

void main() {
  group('HeroineVelocity export', () {
    test('HeroineVelocity can be imported from package:heroine/heroine.dart',
        () {
      // This test verifies that HeroineVelocity is properly exported
      // and can be instantiated without needing to import from src/
      const velocity = Velocity(pixelsPerSecond: Offset(100, 100));
      final widget = HeroineVelocity(
        velocity: velocity,
        child: const SizedBox(),
      );

      expect(widget, isA<HeroineVelocity>());
      expect(widget.velocity, equals(velocity));
    });

    test('HeroineVelocity.of() can be called', () {
      // Verify that the static method is accessible
      expect(HeroineVelocity.of, isA<Function>());
    });
  });
}
