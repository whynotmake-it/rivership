// ignore_for_file: avoid_redundant_argument_values

import 'dart:ui';

import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

import 'util.dart';

void main() {
  group('FrictionMotion', () {
    test('creates a FrictionSimulation', () {
      const motion = FrictionMotion();
      final simulation = motion.createSimulation(start: 100, velocity: 500);

      expect(simulation, isA<FrictionSimulation>());
      expect(simulation.x(0), equals(100));
      expect(simulation.dx(0), closeTo(500, error));
    });

    test('decelerates to a stop', () {
      const motion = FrictionMotion();
      final simulation = motion.createSimulation(start: 0, velocity: 1000);

      var previous = simulation.dx(0).abs();
      for (var t = 0.1; t <= 2.0; t += 0.1) {
        final current = simulation.dx(t).abs();
        expect(current, lessThanOrEqualTo(previous + error));
        previous = current;
      }
    });

    test('eventually isDone', () {
      const motion = FrictionMotion();
      final simulation = motion.createSimulation(start: 0, velocity: 1000);

      expect(simulation.isDone(0), isFalse);
      expect(simulation.isDone(100), isTrue);
    });

    test('uses custom drag coefficient', () {
      const fast = FrictionMotion(drag: 0.01);
      const slow = FrictionMotion(drag: 0.5);

      final fastSim = fast.createSimulation(start: 0, velocity: 1000);
      final slowSim = slow.createSimulation(start: 0, velocity: 1000);

      // Lower drag = faster deceleration, so at time 1 the fast-drag sim
      // should have less velocity remaining.
      expect(fastSim.dx(1).abs(), lessThan(slowSim.dx(1).abs()));
    });

    test('applies constant deceleration', () {
      const withDecel = FrictionMotion(constantDeceleration: 100);
      const without = FrictionMotion();

      final withSim = withDecel.createSimulation(start: 0, velocity: 1000);
      final withoutSim = without.createSimulation(start: 0, velocity: 1000);

      // Constant deceleration should slow it down faster.
      expect(withSim.dx(1).abs(), lessThan(withoutSim.dx(1).abs()));
    });

    group('finalValue', () {
      test('returns physics-computed resting position', () {
        const motion = FrictionMotion();
        final fv = motion.finalValue(start: 0, velocity: 1000);

        expect(fv, isNotNull);
        expect(fv, greaterThan(0));

        // Should match FrictionSimulation.finalX
        final simulation = FrictionSimulation(0.135, 0, 1000);
        expect(fv, closeTo(simulation.finalX, error));
      });

      test('returns negative resting position for negative velocity', () {
        const motion = FrictionMotion();
        final fv = motion.finalValue(start: 0, velocity: -1000);

        expect(fv, isNotNull);
        expect(fv, lessThan(0));
      });

      test('returns start when velocity is zero', () {
        const motion = FrictionMotion();
        final fv = motion.finalValue(start: 42, velocity: 0);

        expect(fv, isNotNull);
        expect(fv, closeTo(42, error));
      });
    });

    group('FreeMotion.friction factory', () {
      test('creates a FrictionMotion', () {
        const motion = FreeMotion.friction();

        expect(motion, isA<FrictionMotion>());
      });

      test('passes through parameters', () {
        const motion = FreeMotion.friction(
          drag: 0.5,
          constantDeceleration: 10,
        );

        expect(motion, isA<FrictionMotion>());
        const friction = motion as FrictionMotion;
        expect(friction.drag, equals(0.5));
        expect(friction.constantDeceleration, equals(10));
      });
    });

    group('scaleTo', () {
      test('wraps in FixedDurationFreeMotion', () {
        const motion = FrictionMotion();
        final scaled = motion.scaleTo(const Duration(milliseconds: 500));

        expect(scaled, isA<FixedDurationFreeMotion>());
      });

      test('preserves physics finalValue through FixedDurationFreeMotion', () {
        const motion = FrictionMotion();
        final scaled = motion.scaleTo(const Duration(milliseconds: 500));

        final original = motion.finalValue(start: 0, velocity: 1000);
        final wrapped = scaled.finalValue(start: 0, velocity: 1000);
        expect(wrapped, equals(original));
      });
    });

    group('properties', () {
      test('needsSettle is true', () {
        const motion = FrictionMotion();
        expect(motion.needsSettle, isTrue);
      });

      test('unboundedWillSettle is true', () {
        const motion = FrictionMotion();
        expect(motion.unboundedWillSettle, isTrue);
      });

      test('default drag is 0.135', () {
        const motion = FrictionMotion();
        expect(motion.drag, equals(0.135));
      });

      test('default constantDeceleration is 0', () {
        const motion = FrictionMotion();
        expect(motion.constantDeceleration, equals(0));
      });
    });

    group('equality', () {
      test('equal motions are equal', () {
        const a = FrictionMotion();
        const b = FrictionMotion();
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('different drag makes unequal', () {
        const a = FrictionMotion();
        const b = FrictionMotion(drag: 0.5);
        expect(a, isNot(equals(b)));
      });

      test('different constantDeceleration makes unequal', () {
        const a = FrictionMotion();
        const b = FrictionMotion(constantDeceleration: 10);
        expect(a, isNot(equals(b)));
      });
    });

    group('copyWith', () {
      test('copies with new drag', () {
        const original = FrictionMotion(drag: 0.1);
        final copy = original.copyWith(drag: 0.5);

        expect(copy.drag, equals(0.5));
        expect(copy.constantDeceleration, equals(0));
      });

      test('preserves fields when not specified', () {
        const original = FrictionMotion(
          drag: 0.2,
          constantDeceleration: 5,
        );
        final copy = original.copyWith();

        expect(copy.drag, equals(0.2));
        expect(copy.constantDeceleration, equals(5));
      });
    });

    test('works in a Step.free', () {
      const motion = FrictionMotion();
      const step = Step<double>.free(motion: motion);

      expect(step, isA<StepFree<double>>());
      expect((step as StepFree<double>).motion, equals(motion));
    });
  });

  group('FreeMotion.finalValue base', () {
    test('returns null by default', () {
      const motion = _NullFinalValueMotion();
      expect(motion.finalValue(), isNull);
    });
  });

  group('FreeMotion.project', () {
    test('projects a double through single converter', () {
      const friction = FrictionMotion();
      final result = friction.project(
        from: 100.0,
        velocity: 500.0,
        converter: MotionConverter.single,
      );

      expect(result, isNotNull);
      expect(result, equals(friction.finalValue(start: 100, velocity: 500)));
    });

    test('projects an Offset through offset converter', () {
      const friction = FrictionMotion();
      final result = friction.project(
        from: const Offset(100, 200),
        velocity: const Offset(500, -300),
        converter: MotionConverter.offset,
      );

      expect(result, isNotNull);
      final expectedDx = friction.finalValue(start: 100, velocity: 500);
      final expectedDy = friction.finalValue(start: 200, velocity: -300);
      expect(result.dx, closeTo(expectedDx, error));
      expect(result.dy, closeTo(expectedDy, error));
    });

    test('projects a Rect through rect converter', () {
      const friction = FrictionMotion();
      final result = friction.project(
        from: const Rect.fromLTRB(0, 0, 100, 100),
        velocity: const Rect.fromLTRB(10, 20, 30, 40),
        converter: MotionConverter.rect,
      );

      expect(result, isNotNull);
      expect(
        result.left,
        closeTo(friction.finalValue(start: 0, velocity: 10), error),
      );
      expect(
        result.top,
        closeTo(friction.finalValue(start: 0, velocity: 20), error),
      );
      expect(
        result.right,
        closeTo(friction.finalValue(start: 100, velocity: 30), error),
      );
      expect(
        result.bottom,
        closeTo(friction.finalValue(start: 100, velocity: 40), error),
      );
    });

    test('returns null when finalValue is unknown', () {
      const motion = _NullFinalValueMotion();
      final result = motion.project(
        from: Offset.zero,
        velocity: const Offset(100, 100),
        converter: MotionConverter.offset,
      );

      expect(result, isNull);
    });

    test('projects with zero velocity returns start position', () {
      const friction = FrictionMotion();
      final result = friction.project(
        from: const Offset(50, 75),
        velocity: Offset.zero,
        converter: MotionConverter.offset,
      );

      expect(result, isNotNull);
      expect(result.dx, closeTo(50, error));
      expect(result.dy, closeTo(75, error));
    });
  });
}

class _NullFinalValueMotion extends FreeMotion {
  const _NullFinalValueMotion();

  @override
  bool get needsSettle => false;

  @override
  bool get unboundedWillSettle => true;

  @override
  Simulation createSimulation({double start = 0, double velocity = 0}) {
    return FrictionSimulation(0.135, start, velocity);
  }
}
