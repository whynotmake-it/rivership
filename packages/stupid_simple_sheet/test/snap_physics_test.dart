import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';

void main() {
  group('FlingSnapPhysics', () {
    const physics = FlingSnapPhysics();
    final snapPoints = [0.0, 0.3, 0.6, 1.0];

    test('low velocity snaps to closest point', () {
      // Position is 0.4 — closest to 0.3
      final result = physics.findTargetSnapPoint(
        position: 0.4,
        absoluteVelocity: 0, // no velocity
        snapPoints: snapPoints,
      );
      expect(result, 0.3);
    });

    test('low velocity at midpoint between snaps picks closer one', () {
      // Position is 0.5 — equidistant between 0.3 and 0.6,
      // but 0.6 should NOT win; first-found-closest wins (0.3)
      // Actually let's pick a clear case: 0.55 is closer to 0.6
      final result = physics.findTargetSnapPoint(
        position: 0.55,
        absoluteVelocity: 0,
        snapPoints: snapPoints,
      );
      expect(result, 0.6);
    });

    test('positive velocity (fling down/open) goes to next higher snap', () {
      // At 0.4, flinging upward (positive velocity = opening)
      // should go to 0.6 (next point above 0.4)
      final result = physics.findTargetSnapPoint(
        position: 0.4,
        absoluteVelocity: 1000,
        snapPoints: snapPoints,
      );
      expect(result, 0.6);
    });

    test('negative velocity (fling up/close) goes to next lower snap', () {
      // At 0.4, flinging downward (negative velocity = closing)
      // should go to 0.3 (next point below 0.4)
      final result = physics.findTargetSnapPoint(
        position: 0.4,
        absoluteVelocity: -1000,
        snapPoints: snapPoints,
      );
      expect(result, 0.3);
    });

    test('fling never overshoots — stops at adjacent snap point', () {
      // Even a very strong fling from 0.4 upward should only go to 0.6,
      // not skip to 1.0
      final result = physics.findTargetSnapPoint(
        position: 0.4,
        absoluteVelocity: 99999,
        snapPoints: snapPoints,
      );
      expect(result, 0.6);
    });

    test('fling at top boundary with positive velocity snaps to closest', () {
      // At 1.0, flinging upward — no snap point above, falls back to closest
      final result = physics.findTargetSnapPoint(
        position: 1,
        absoluteVelocity: 1000,
        snapPoints: snapPoints,
      );
      expect(result, 1.0);
    });

    test('fling at bottom boundary with negative velocity snaps to closest',
        () {
      // At 0.0, flinging downward — no snap point below, falls back to closest
      final result = physics.findTargetSnapPoint(
        position: 0,
        absoluteVelocity: -1000,
        snapPoints: snapPoints,
      );
      expect(result, 0.0);
    });

    test('respects custom minFlingVelocity', () {
      const customPhysics = FlingSnapPhysics(minFlingVelocity: 2000);

      // Velocity of 1000 is below custom threshold — should snap to closest
      final result = customPhysics.findTargetSnapPoint(
        position: 0.4,
        absoluteVelocity: 1000,
        snapPoints: snapPoints,
      );
      expect(result, 0.3); // closest to 0.4

      // Velocity of 3000 is above custom threshold — should fling to next
      final flingResult = customPhysics.findTargetSnapPoint(
        position: 0.4,
        absoluteVelocity: 3000,
        snapPoints: snapPoints,
      );
      expect(flingResult, 0.6);
    });

    test('defaults to kMinFlingVelocity', () {
      expect(physics.minFlingVelocity, kMinFlingVelocity);
    });
  });

  group('FrictionSnapPhysics', () {
    const physics = FrictionSnapPhysics();
    final snapPoints = [0.0, 0.3, 0.6, 1.0];

    test('zero velocity snaps to closest point', () {
      final result = physics.findTargetSnapPoint(
        position: 0.4,
        velocity: 0,
        snapPoints: snapPoints,
      );
      expect(result, 0.3);
    });

    test('strong positive velocity projects forward past intermediate snaps',
        () {
      // At 0.1 with a very strong upward velocity, the friction simulation
      // should project far enough to land near 1.0
      final result = physics.findTargetSnapPoint(
        position: 0.1,
        velocity: 5, // strong relative velocity
        snapPoints: snapPoints,
      );
      // Should skip 0.3 and land at 0.6 or 1.0
      expect(result, greaterThanOrEqualTo(0.6));
    });

    test('moderate velocity lands at intermediate snap', () {
      // At 0.0 with moderate velocity, should project to an intermediate
      // point rather than all the way to 1.0
      final result = physics.findTargetSnapPoint(
        position: 0,
        velocity: 0.5,
        snapPoints: snapPoints,
      );
      // Should land somewhere in the middle, not at 0.0
      expect(result, greaterThan(0.0));
    });

    test('negative velocity projects backward', () {
      // At 0.8 with negative (downward) velocity
      final result = physics.findTargetSnapPoint(
        position: 0.8,
        velocity: -5,
        snapPoints: snapPoints,
      );
      // Should project down toward 0.0 or 0.3
      expect(result, lessThan(0.6));
    });

    test('projected position is clamped to 0..1 range', () {
      // Even with extreme velocity, result should be a valid snap point
      final result = physics.findTargetSnapPoint(
        position: 0.9,
        velocity: 100, // absurdly high
        snapPoints: snapPoints,
      );
      expect(snapPoints.contains(result), isTrue);

      final resultNeg = physics.findTargetSnapPoint(
        position: 0.1,
        velocity: -100,
        snapPoints: snapPoints,
      );
      expect(snapPoints.contains(resultNeg), isTrue);
    });

    test('custom drag coefficient changes projection distance', () {
      // Higher drag coefficient = more friction = shorter projection
      const highFriction = FrictionSnapPhysics(dragCoefficient: 0.5);
      const lowFriction = FrictionSnapPhysics(dragCoefficient: 0.05);

      final highResult = highFriction.findTargetSnapPoint(
        position: 0.3,
        velocity: 2,
        snapPoints: snapPoints,
      );

      final lowResult = lowFriction.findTargetSnapPoint(
        position: 0.3,
        velocity: 2,
        snapPoints: snapPoints,
      );

      // Lower friction should project further (higher or equal snap point)
      expect(lowResult, greaterThanOrEqualTo(highResult));
    });
  });

  group('SheetSnappingConfig', () {
    group('findClosestSnapPoint', () {
      test('finds closest point ignoring velocity', () {
        const config = SheetSnappingConfig([0.3, 0.6, 1.0]);
        expect(config.findClosestSnapPoint(0.4), 0.3);
        expect(config.findClosestSnapPoint(0.55), 0.6);
        expect(config.findClosestSnapPoint(0.9), 1.0);
        expect(config.findClosestSnapPoint(0.1), 0.0);
      });
    });

    group('findTargetSnapPoint', () {
      test('excludes closed (0.0) when includeClosed is false', () {
        const config = SheetSnappingConfig([0.5, 1.0]);
        // At 0.1, closest point is 0.0 — but with includeClosed: false,
        // should pick 0.5 instead
        final result = config.findTargetSnapPoint(
          position: 0.1,
          relativeVelocity: 0,
          absoluteVelocity: 0,
          includeClosed: false,
        );
        expect(result, 0.5);
      });

      test('includes closed (0.0) by default', () {
        const config = SheetSnappingConfig([0.5, 1.0]);
        final result = config.findTargetSnapPoint(
          position: 0.1,
          relativeVelocity: 0,
          absoluteVelocity: 0,
        );
        expect(result, 0.0);
      });
    });

    group('physics parameter', () {
      test('defaults to FlingSnapPhysics', () {
        const config = SheetSnappingConfig.full;
        expect(config.physics, isA<FlingSnapPhysics>());
      });

      test('can be configured with FrictionSnapPhysics', () {
        const config = SheetSnappingConfig(
          [0.5, 1.0],
          physics: FrictionSnapPhysics(),
        );
        expect(config.physics, isA<FrictionSnapPhysics>());

        // And it actually uses the friction physics for target finding
        final result = config.findTargetSnapPoint(
          position: 0.3,
          relativeVelocity: 2,
          absoluteVelocity: 2000,
        );
        // Result should be a valid snap point
        expect(config.getAllPoints().contains(result), isTrue);
      });

      test('FlingSnapPhysics uses absoluteVelocity for fling detection', () {
        const config = SheetSnappingConfig([0.3, 0.6, 1.0]);

        // With low absolute velocity (drag), should snap to closest
        final dragResult = config.findTargetSnapPoint(
          position: 0.4,
          relativeVelocity: 999, // high relative, but absolute matters
          absoluteVelocity: 10, // below kMinFlingVelocity
        );
        expect(dragResult, 0.3); // closest to 0.4

        // With high absolute velocity (fling upward), should go to next
        final flingResult = config.findTargetSnapPoint(
          position: 0.4,
          relativeVelocity: 0, // doesn't matter for FlingSnapPhysics
          absoluteVelocity: 1000, // above kMinFlingVelocity
        );
        expect(flingResult, 0.6); // next snap above 0.4
      });

      test('FrictionSnapPhysics uses relativeVelocity for projection', () {
        const config = SheetSnappingConfig(
          [0.3, 0.6, 1.0],
          physics: FrictionSnapPhysics(),
        );

        // With zero relative velocity, should snap to closest regardless
        // of absolute velocity
        final result = config.findTargetSnapPoint(
          position: 0.4,
          relativeVelocity: 0,
          absoluteVelocity: 99999, // doesn't matter for FrictionSnapPhysics
        );
        expect(result, 0.3); // closest to 0.4
      });
    });

    test('SheetSnappingConfig.full uses default FlingSnapPhysics', () {
      expect(SheetSnappingConfig.full.physics, isA<FlingSnapPhysics>());
    });
  });
}
