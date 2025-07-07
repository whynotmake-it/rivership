import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

import 'util.dart';

void main() {
  group('CupertinoMotion', () {
    test('generate constant SpringDescriptions', () async {
      expect(const CupertinoMotion().description, equalsSpring(standard));
      expect(const CupertinoMotion.bouncy().description, equalsSpring(bouncy));
      expect(const CupertinoMotion.snappy().description, equalsSpring(snappy));
      expect(const CupertinoMotion.smooth().description, equalsSpring(smooth));
      expect(
        const CupertinoMotion.interactive().description,
        equalsSpring(interactive),
      );
    });
  });

  group('EndVelocitySpringMotion', () {
    test('creates motion with correct properties', () {
      const motion = EndVelocitySpringMotion(
        SpringDescription(mass: 1, stiffness: 100, damping: 10),
        endVelocity: 50,
      );

      expect(motion.description.mass, 1);
      expect(motion.description.stiffness, 100);
      expect(motion.description.damping, 10);
      expect(motion.endVelocity, 50);
      expect(motion.needsSettle, true);
      expect(motion.unboundedWillSettle, false);
    });

    test('creates simulation with correct parameters', () {
      const motion = EndVelocitySpringMotion(
        SpringDescription(mass: 1, stiffness: 100, damping: 10),
        endVelocity: 25,
      );

      final simulation = motion.createSimulation(
        start: 0,
        end: 100,
        velocity: 10,
      );

      expect(simulation.x(0), 0);
      expect(simulation.dx(0), 10);
    });

    test('equality works correctly', () {
      const motion1 = EndVelocitySpringMotion(
        SpringDescription(mass: 1, stiffness: 100, damping: 10),
        endVelocity: 50,
      );
      const motion2 = EndVelocitySpringMotion(
        SpringDescription(mass: 1, stiffness: 100, damping: 10),
        endVelocity: 50,
      );
      const motion3 = EndVelocitySpringMotion(
        SpringDescription(mass: 1, stiffness: 100, damping: 10),
        endVelocity: 25,
      );

      expect(motion1, equals(motion2));
      expect(motion1, isNot(equals(motion3)));
    });

    test('copyWith works correctly', () {
      const original = EndVelocitySpringMotion(
        SpringDescription(mass: 1, stiffness: 100, damping: 10),
        endVelocity: 50,
      );

      final copied = original.copyWith(endVelocity: 75);

      expect(copied.description, equals(original.description));
      expect(copied.endVelocity, 75);
      expect(copied.snapToEnd, original.snapToEnd);
    });

    test('factory constructor works', () {
      const spring = SpringDescription(mass: 1, stiffness: 100, damping: 10);
      const motion = Motion.endVelocitySpring(spring, endVelocity: 30);

      expect(motion, isA<EndVelocitySpringMotion>());
      const endVelocityMotion = motion as EndVelocitySpringMotion;
      expect(endVelocityMotion.description, equals(spring));
      expect(endVelocityMotion.endVelocity, 30);
    });

    group('behavioral tests', () {
      test('simulation reaches target with correct end velocity', () {
        const spring = SpringDescription(mass: 1, stiffness: 100, damping: 10);
        const motion = EndVelocitySpringMotion(spring, endVelocity: 50);

        final simulation = motion.createSimulation(
          start: 0,
          end: 100,
          velocity: 0,
        );

        // Find when simulation is done
        double time = 0;
        const timeStep = 0.01;
        while (!simulation.isDone(time) && time < 10) {
          time += timeStep;
        }

        // Verify position is close to target
        final finalPosition = simulation.x(time);
        expect(finalPosition, closeTo(100, 0.1));

        // Verify velocity is close to desired end velocity
        final finalVelocity = simulation.dx(time);
        expect(finalVelocity, closeTo(50, 1.0));
      });

      test('approaches zero velocity when endVelocity is zero', () {
        const spring = SpringDescription(mass: 1, stiffness: 100, damping: 10);
        const endVelocityMotion = EndVelocitySpringMotion(spring, endVelocity: 0);

        final endVelocitySim = endVelocityMotion.createSimulation(
          start: 0,
          end: 100,
          velocity: 20,
        );

        // Find when simulation is done
        double time = 0;
        const timeStep = 0.01;
        while (!endVelocitySim.isDone(time) && time < 10) {
          time += timeStep;
        }

        // Verify position is close to target
        final finalPosition = endVelocitySim.x(time);
        expect(finalPosition, closeTo(100, 0.1));

        // Verify velocity is close to zero
        final finalVelocity = endVelocitySim.dx(time);
        expect(finalVelocity, closeTo(0, 1.0));
      });

      test('simulation starts with correct initial conditions', () {
        const spring = SpringDescription(mass: 1, stiffness: 100, damping: 10);
        const motion = EndVelocitySpringMotion(spring, endVelocity: 25);

        final simulation = motion.createSimulation(
          start: 10,
          end: 90,
          velocity: 15,
        );

        expect(simulation.x(0), 10);
        expect(simulation.dx(0), 15);
      });

      test('works with different spring configurations', () {
        // Test with underdamped spring
        const underdamped = SpringDescription(mass: 1, stiffness: 100, damping: 5);
        const underdampedMotion = EndVelocitySpringMotion(underdamped, endVelocity: 30);
        final underdampedSim = underdampedMotion.createSimulation(start: 0, end: 100);

        // Test with critically damped spring
        final criticalDamping = 2 * math.sqrt(100 * 1); // 2 * sqrt(k * m)
        final criticallyDamped = SpringDescription(mass: 1, stiffness: 100, damping: criticalDamping);
        final criticalMotion = EndVelocitySpringMotion(criticallyDamped, endVelocity: 30);
        final criticalSim = criticalMotion.createSimulation(start: 0, end: 100);

        // Test with overdamped spring
        const overdamped = SpringDescription(mass: 1, stiffness: 100, damping: 25);
        const overdampedMotion = EndVelocitySpringMotion(overdamped, endVelocity: 30);
        final overdampedSim = overdampedMotion.createSimulation(start: 0, end: 100);

        // All should start at the same position
        expect(underdampedSim.x(0), 0);
        expect(criticalSim.x(0), 0);
        expect(overdampedSim.x(0), 0);

        // All should have different behaviors but eventually reach target
        expect(underdampedSim.x(0), isNot(equals(underdampedSim.x(0.5))));
        expect(criticalSim.x(0), isNot(equals(criticalSim.x(0.5))));
        expect(overdampedSim.x(0), isNot(equals(overdampedSim.x(0.5))));
      });

      test('handles negative end velocities', () {
        const spring = SpringDescription(mass: 1, stiffness: 100, damping: 10);
        const motion = EndVelocitySpringMotion(spring, endVelocity: -25);

        final simulation = motion.createSimulation(
          start: 0,
          end: 100,
          velocity: 0,
        );

        // Find when simulation is done
        double time = 0;
        const timeStep = 0.01;
        while (!simulation.isDone(time) && time < 10) {
          time += timeStep;
        }

        // Verify position is close to target
        final finalPosition = simulation.x(time);
        expect(finalPosition, closeTo(100, 0.1));

        // Verify velocity is close to desired negative end velocity
        final finalVelocity = simulation.dx(time);
        expect(finalVelocity, closeTo(-25, 1.0));
      });

      test('simulation eventually terminates', () {
        const spring = SpringDescription(mass: 1, stiffness: 100, damping: 10);
        const motion = EndVelocitySpringMotion(spring, endVelocity: 20);

        final simulation = motion.createSimulation(
          start: 0,
          end: 100,
          velocity: 0,
        );

        // Check that simulation terminates within reasonable time
        bool foundEnd = false;
        for (double t = 0; t <= 10; t += 0.01) {
          if (simulation.isDone(t)) {
            foundEnd = true;
            break;
          }
        }

        expect(foundEnd, true, reason: 'Simulation should terminate within 10 seconds');
      });
    });
  });
}

/// A smooth spring with no bounce.
///
/// This uses the [default values for iOS](https://developer.apple.com/documentation/swiftui/animation/default).
final standard = SpringDescription.withDurationAndBounce(
  duration: const Duration(milliseconds: 550),
);

/// A spring with a predefined duration and higher amount of bounce.
final bouncy = SpringDescription.withDurationAndBounce(bounce: 0.3);

/// A snappy spring with a damping fraction of 0.85.
final snappy = SpringDescription.withDurationAndBounce(bounce: 0.15);

/// A smooth spring with a predefined duration and no bounce.
final smooth = SpringDescription.withDurationAndBounce();

/// A spring animation with a lower response value,
/// intended for driving interactive animations.
final interactive = SpringDescription.withDurationAndBounce(
  bounce: 0.14,
  duration: const Duration(milliseconds: 150),
);
