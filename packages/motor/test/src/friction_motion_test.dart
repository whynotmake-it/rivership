// ignore_for_file: avoid_redundant_argument_values

import 'dart:ui';

import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

import 'util.dart';

void main() {
  group('FrictionMotion', () {
    test('simulates friction with its drag and deceleration', () {
      for (final motion in const [
        FrictionMotion(),
        FrictionMotion(drag: 0.5),
        FrictionMotion(constantDeceleration: 100),
      ]) {
        final simulation = motion.createSimulation(start: 100, velocity: 500);
        final flutter = FrictionSimulation(
          motion.drag,
          100,
          500,
          constantDeceleration: motion.constantDeceleration,
        );

        expect(simulation.x(0), equals(100));
        expect(simulation.dx(0), closeTo(500, error));
        for (final t in [0.1, 0.5, 1.0, 2.0]) {
          expect(
            simulation.x(t),
            closeTo(flutter.x(t), error),
            reason: '$motion at $t s',
          );
          expect(
            simulation.dx(t),
            closeTo(flutter.dx(t), error),
            reason: '$motion at $t s',
          );
        }
      }
    });

    test('finalValue is the resting position', () {
      const motion = FrictionMotion();
      for (final (start, velocity) in [(0.0, 1000.0), (0.0, -1000.0)]) {
        final resting = motion.finalValue(start: start, velocity: velocity);
        expect(
          resting,
          closeTo(FrictionSimulation(0.135, start, velocity).finalX, error),
        );
        expect(resting.sign, velocity.sign);
      }
      expect(motion.finalValue(start: 42, velocity: 0), closeTo(42, error));
    });

    group('scaleTo', () {
      test('preserves physics finalValue through FixedDurationFreeMotion', () {
        const motion = FrictionMotion();
        final scaled = motion.scaleTo(const Duration(milliseconds: 500));

        expect(scaled, isA<FixedDurationFreeMotion>());
        final original = motion.finalValue(start: 0, velocity: 1000);
        final wrapped = scaled.finalValue(start: 0, velocity: 1000);
        expect(wrapped, equals(original));
      });

      test('scales even a coast that lasts minutes', () {
        // Friction knows when it stops, here after about 995 s, so the
        // wrapper doesn't need to cut it off.
        const motion = FrictionMotion(drag: 0.99);
        final scaled = motion.scaleTo(const Duration(milliseconds: 400));
        final simulation = scaled.createSimulation(velocity: 1000);
        final coast =
            motion.createSimulation(velocity: 1000) as SettlingSimulation;

        expect(coast.settlesAt!.inSeconds, inInclusiveRange(990, 1000));
        expect(simulation.isDone(0.4), isTrue);
        expect(
          scaled.finalValue(velocity: 1000),
          closeTo(simulation.x(0.4), 1e-6),
        );
        expect(
          scaled.finalValue(velocity: 1000),
          motion.finalValue(velocity: 1000),
        );
      });
    });
  });

  group('FreeMotion.project', () {
    const friction = FrictionMotion();
    double rest(double start, double velocity) =>
        friction.finalValue(start: start, velocity: velocity);

    test('projects every dimension through the converter', () {
      expect(
        friction.project(
          from: 100.0,
          velocity: 500.0,
          converter: MotionConverter.single,
        ),
        equals(rest(100, 500)),
      );

      final offset = friction.project(
        from: const Offset(100, 200),
        velocity: const Offset(500, -300),
        converter: MotionConverter.offset,
      );
      expect(offset.dx, closeTo(rest(100, 500), error));
      expect(offset.dy, closeTo(rest(200, -300), error));

      final resting = friction.project(
        from: const Offset(50, 75),
        velocity: Offset.zero,
        converter: MotionConverter.offset,
      );
      expect(resting.dx, closeTo(50, error));
      expect(resting.dy, closeTo(75, error));

      final rect = friction.project(
        from: const Rect.fromLTRB(0, 0, 100, 100),
        velocity: const Rect.fromLTRB(10, 20, 30, 40),
        converter: MotionConverter.rect,
      );
      expect(rect.left, closeTo(rest(0, 10), error));
      expect(rect.top, closeTo(rest(0, 20), error));
      expect(rect.right, closeTo(rest(100, 30), error));
      expect(rect.bottom, closeTo(rest(100, 40), error));
    });

    test('returns null when finalValue is unknown', () {
      const motion = _NullFinalValueMotion();
      expect(motion.finalValue(), isNull);
      expect(
        motion.project(
          from: Offset.zero,
          velocity: const Offset(100, 100),
          converter: MotionConverter.offset,
        ),
        isNull,
      );
    });
  });
}

class _NullFinalValueMotion extends FreeMotion {
  const _NullFinalValueMotion();

  @override
  Simulation createSimulation({double start = 0, double velocity = 0}) {
    return FrictionSimulation(0.135, start, velocity);
  }
}
