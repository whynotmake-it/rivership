// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:motor/src/controllers/motion_controller.dart'
    show motionsEqual;

import 'util.dart';

class _ConstantVelocityMotion extends FreeMotion {
  const _ConstantVelocityMotion();

  @override
  bool get needsSettle => false;

  @override
  bool get unboundedWillSettle => true;

  @override
  Simulation createSimulation({
    double start = 0,
    double velocity = 0,
  }) {
    return _ConstantVelocitySimulation(start: start, velocity: velocity);
  }
}

class _ConstantVelocitySimulation extends Simulation {
  _ConstantVelocitySimulation({
    required this.start,
    required this.velocity,
  });

  final double start;
  final double velocity;

  @override
  double x(double time) => start + velocity * time;

  @override
  double dx(double time) => velocity;

  @override
  bool isDone(double time) => time >= 1;
}

void main() {
  group('Motion hierarchy', () {
    test('keeps targeted Motion factory source compatibility', () {
      const curved = Motion.curved(Duration(milliseconds: 300));
      const spring = Motion.smoothSpring();

      expect(curved, isA<Motion>());
      expect(curved, isA<MotionBase>());
      expect(spring, isA<Motion>());
      expect(spring, isA<MotionBase>());
    });

    test('scales fixed-duration motions natively', () {
      const curved = Motion.curved(Duration(milliseconds: 300));
      const linear = Motion.linear(Duration(milliseconds: 300));
      const none = Motion.none(Duration(milliseconds: 300));

      expect(
        curved.scaleTo(const Duration(seconds: 1)),
        equals(const Motion.curved(Duration(seconds: 1))),
      );
      expect(
        linear.scaleTo(const Duration(seconds: 1)),
        equals(const Motion.linear(Duration(seconds: 1))),
      );
      expect(none.scaleTo(const Duration(seconds: 1)), isA<NoMotion>());
      expect(
        (none.scaleTo(const Duration(seconds: 1)) as NoMotion).duration,
        equals(const Duration(seconds: 1)),
      );
    });

    test('wraps target-based physics in a fixed-duration motion', () {
      const spring = Motion.smoothSpring();
      final scaled = spring.scaleTo(const Duration(milliseconds: 250));

      expect(scaled, isA<FixedDurationMotion>());

      final simulation = scaled.createSimulation(start: 0, end: 10);
      expect(simulation.x(0), equals(0));
      expect(simulation.isDone(0.2), isFalse);
      expect(simulation.x(0.25), equals(10));
      expect(simulation.isDone(0.25), isTrue);
    });

    test('wraps free motions in a fixed-duration motion', () {
      const motion = _ConstantVelocityMotion();
      final scaled = motion.scaleTo(const Duration(milliseconds: 500));

      expect(scaled, isA<FixedDurationFreeMotion>());

      final simulation = scaled.createSimulation(start: 2, velocity: 4);
      expect(simulation.x(0), equals(2));
      expect(simulation.x(0.25), closeTo(4, error));
      expect(simulation.x(0.5), closeTo(6, error));
      expect(simulation.isDone(0.5), isTrue);
    });
  });

  group('spring snapToEnd default', () {
    test('all spring factories default snapToEnd to true', () {
      expect(
        const SpringMotion(SpringDescription(mass: 1, stiffness: 1, damping: 1))
            .snapToEnd,
        isTrue,
      );
      expect(
        (const Motion.customSpring(
          SpringDescription(mass: 1, stiffness: 1, damping: 1),
        ) as SpringMotion)
            .snapToEnd,
        isTrue,
      );
      expect(const CupertinoMotion().snapToEnd, isTrue);
      expect(const CupertinoMotion.bouncy().snapToEnd, isTrue);
      expect(const CupertinoMotion.snappy().snapToEnd, isTrue);
      expect(const CupertinoMotion.smooth().snapToEnd, isTrue);
      expect(const CupertinoMotion.interactive().snapToEnd, isTrue);
    });

    test('snapToEnd: false is respected', () {
      expect(const CupertinoMotion.bouncy(snapToEnd: false).snapToEnd, isFalse);
      expect(
        const SpringMotion(
          SpringDescription(mass: 1, stiffness: 1, damping: 1),
          snapToEnd: false,
        ).snapToEnd,
        isFalse,
      );
    });

    test('default spring settles exactly on the target value', () {
      const motion = CupertinoMotion.bouncy();
      final simulation = motion.createSimulation(start: 0, end: 1);

      var t = 0.0;
      while (!simulation.isDone(t) && t < 10) {
        t += 1 / 60;
      }

      expect(simulation.isDone(t), isTrue);
      // snapToEnd guarantees the resting value is exactly the target, not just
      // within tolerance, so value-based conditionals stay reliable.
      expect(simulation.x(t), equals(1.0));
    });

    test('snapToEnd: false can settle off-target within tolerance', () {
      const snapping = CupertinoMotion.bouncy();
      const notSnapping = CupertinoMotion.bouncy(snapToEnd: false);

      double restingValue(SpringMotion motion) {
        final simulation = motion.createSimulation(start: 0, end: 1);
        var t = 0.0;
        while (!simulation.isDone(t) && t < 10) {
          t += 1 / 60;
        }
        return simulation.x(t);
      }

      expect(restingValue(snapping), equals(1.0));
      // Without snapping the resting value lands within tolerance but is not
      // guaranteed to be exactly the target.
      expect(restingValue(notSnapping), isNot(equals(1.0)));
      expect(
        restingValue(notSnapping),
        closeTo(1.0, snapping.tolerance.distance),
      );
    });
  });

  group('SpringMotion equality', () {
    const description = SpringDescription(mass: 1, stiffness: 100, damping: 10);

    test('motions differing only in snapToEnd are unequal', () {
      const snapping = SpringMotion(description);
      const notSnapping = SpringMotion(description, snapToEnd: false);

      expect(snapping == notSnapping, isFalse);
      expect(snapping.hashCode, isNot(equals(notSnapping.hashCode)));
    });

    test('subtypes with identical physics and snapToEnd compare equal', () {
      const motion = CupertinoMotion(
        duration: Duration(milliseconds: 500),
        bounce: 0.1,
      );
      const smooth = CupertinoMotion.smooth(extraBounce: 0.1);

      expect(motion == smooth, isTrue);
      expect(motion.hashCode, equals(smooth.hashCode));
    });

    test('copyWith preserves duration and bounce exactly', () {
      const motion = CupertinoMotion(
        duration: Duration(milliseconds: 320),
        bounce: 0.2,
      );
      final copy = motion.copyWith(snapToEnd: false);

      expect(copy.duration, equals(const Duration(milliseconds: 320)));
      expect(copy.bounce, equals(0.2));
      expect(copy.snapToEnd, isFalse);
    });

    test('motionsEqual detects snapToEnd differences', () {
      const snapping = SpringMotion(description);
      const notSnapping = SpringMotion(description, snapToEnd: false);

      expect(motionsEqual([snapping], [notSnapping]), isFalse);
      expect(motionsEqual([snapping], [snapping]), isTrue);
    });
  });

  group('NoMotion', () {
    test('creates a simulation that holds the target value', () {
      const motion = Motion.none(Duration(seconds: 1));
      final simulation = motion.createSimulation(start: 0, end: 100);

      // Should hold the target value immediately
      expect(simulation.x(0), equals(0));
      expect(simulation.x(0.5), equals(0));
      expect(simulation.x(1), equals(0));
      expect(simulation.x(2), equals(0));

      expect(simulation.isDone(1), isFalse);
      expect(simulation.isDone(1.000001), isTrue);
      expect(simulation.isDone(2), isTrue);
    });
  });

  group('TrimmedMotion - Basic Tests', () {
    group('Linear Motion Trimming', () {
      test('no trimming = original behavior', () {
        const parent = LinearMotion(Duration(seconds: 1));
        const trimmed = TrimmedMotion(parent: parent, fromStart: 0, fromEnd: 0);

        final parentSim = parent.createSimulation(start: 0, end: 100);
        final trimmedSim = trimmed.createSimulation(start: 0, end: 100);

        // Should behave identically at several time points
        for (double t = 0; t <= 1.0; t += 0.2) {
          expect(trimmedSim.x(t), closeTo(parentSim.x(t), error));
        }
      });

      test('symmetric trimming (0.2, 0.2)', () {
        const parent = LinearMotion(Duration(seconds: 1));
        const trimmed = TrimmedMotion(
          parent: parent,
          fromStart: 0.2,
          fromEnd: 0.2,
        );

        final simulation = trimmed.createSimulation();

        // Should start at 0
        expect(simulation.x(0), closeTo(0, error));

        // Should end at 1
        expect(simulation.x(.6), closeTo(1, error));

        // Middle should be 50 (linear interpolation)
        expect(simulation.x(0.3), closeTo(.5, error));

        // Should be done at t=1
        expect(simulation.isDone(.6), isTrue);
      });
    });

    group('Extension Methods', () {
      test('trimmed() extension works', () {
        const parent = LinearMotion(Duration(seconds: 1));
        final trimmed = parent.trimmed(fromStart: 0.1, fromEnd: 0.2);

        expect(trimmed, isA<TrimmedMotion>());
        expect(trimmed.parent, equals(parent));
        expect(trimmed.fromStart, equals(0.1));
        expect(trimmed.fromEnd, equals(0.2));
      });

      test('subExtent() extension works', () {
        const parent = LinearMotion(Duration(seconds: 1));
        final trimmed = parent.segment(length: 0.5, start: 0.2);

        expect(trimmed.fromStart, equals(0.2));
        expect(trimmed.fromEnd, closeTo(0.3, error)); // 1.0 - (0.2 + 0.5)
      });
    });

    test('velocity calculation works', () {
      const parent = LinearMotion(Duration(seconds: 1));
      const trimmed =
          TrimmedMotion(parent: parent, fromStart: 0.2, fromEnd: 0.2);

      final simulation = trimmed.createSimulation(start: 0, end: 100);

      // Linear motion should have constant velocity when active
      final velocity = simulation.dx(0.5);
      expect(velocity, greaterThan(0));

      // For linear motion, velocity should be positive and finite
      expect(velocity, greaterThan(0));
      expect(velocity.isFinite, isTrue);
    });
  });
}
