import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heroine/heroine.dart';

void main() {
  group('DuplicateHeroinePolicy export', () {
    test('can be imported from package:heroine/heroine.dart', () {
      expect(
        DuplicateHeroinePolicy.values,
        containsAll([
          DuplicateHeroinePolicy.forbidden,
          DuplicateHeroinePolicy.first,
          DuplicateHeroinePolicy.last,
        ]),
      );
    });
  });

  group('HeroineVelocity export', () {
    test('HeroineVelocity can be imported from package:heroine/heroine.dart',
        () {
      // This test verifies that HeroineVelocity is properly exported
      // and can be instantiated without needing to import from src/
      const velocity = Velocity(pixelsPerSecond: Offset(100, 100));
      const widget = HeroineVelocity(
        velocity: velocity,
        child: SizedBox(),
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
