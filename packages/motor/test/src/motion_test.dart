// ignore_for_file: avoid_redundant_argument_values
// ignore_for_file: deprecated_member_use_from_same_package

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

import 'util.dart';

class _ConstantVelocityMotion extends FreeMotion {
  const _ConstantVelocityMotion();

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

/// Implements [Motion] with only the members 2.0 requires of implementers.
class _ImplementedMotion implements Motion {
  const _ImplementedMotion();

  @override
  Tolerance get tolerance => Tolerance.defaultTolerance;

  @override
  bool get needsSettle => false;

  @override
  bool get unboundedWillSettle => true;

  @override
  Duration? get duration => const Duration(seconds: 1);

  @override
  Motion scaleTo(Duration duration) => Motion.linear(duration);

  @override
  Simulation createSimulation({
    double start = 0,
    double end = 1,
    double velocity = 0,
  }) =>
      const Motion.linear(Duration(seconds: 1))
          .createSimulation(start: start, end: end);
}

void main() {
  group('Motion hierarchy', () {
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

    test('paces a CupertinoMotion like the retimed spring', () {
      const spring = CupertinoMotion.bouncy(snapToEnd: false);
      const target = Duration(milliseconds: 250);
      final scaled = spring.scaleTo(target);
      expect(scaled, isA<FixedDurationMotion>());

      final simulation = scaled.createSimulation(end: 10, velocity: 30);
      final retimed = spring
          .copyWith(duration: target)
          .createSimulation(end: 10, velocity: 30);
      expect(scaled.duration, target);
      expect(simulation.dx(0), closeTo(30, 1e-9));
      for (var t = 0.0; t < 2; t += 0.01) {
        expect(simulation.x(t), closeTo(retimed.x(t), 1e-6));
      }
      // It keeps settling after its step.
      expect(simulation.isDone(0.25), isFalse);
    });

    test('paces other springs, keeping the start velocity', () {
      final description = SpringDescription.withDampingRatio(
        mass: 1,
        stiffness: 380,
        ratio: 0.8,
      );
      final spring = SpringMotion(description, snapToEnd: false);
      const target = Duration(milliseconds: 200);
      final scaled = spring.scaleTo(target);
      expect(scaled, isA<FixedDurationMotion>());
      expect(scaled.needsSettle, isTrue);

      final simulation = scaled.createSimulation(end: 300, velocity: -900)
          as SettlingSimulation;
      expect(scaled.duration, target);
      expect(simulation.dx(0), closeTo(-900, 1e-6));

      // The same as the spring retimed by hand.
      final factor = description.duration.inMicroseconds / 200000;
      final retimed = SpringSimulation(
        SpringDescription(
          mass: 1,
          stiffness: description.stiffness * factor * factor,
          damping: description.damping * factor,
        ),
        0,
        300,
        -900,
      );
      for (var t = 0.0; t < 1; t += 0.01) {
        expect(simulation.x(t), closeTo(retimed.x(t), 1e-6));
      }
      expect(simulation.settlesAt, isNotNull);
      expect(
        simulation.isDone(simulation.settlesAt!.inMicroseconds / 1e6),
        isTrue,
      );
    });

    test('implementing Motion needs duration and scaleTo only', () {
      const motion = _ImplementedMotion();

      final scaled = motion.scaleTo(const Duration(seconds: 2));
      expect(scaled.settlingDuration(), const Duration(seconds: 2));
      expect(scaled.duration, const Duration(seconds: 2));
      expect(motion.createSimulation().x(0.5), closeTo(0.5, error));
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

  group('spring snapToEnd', () {
    double restingValue(SpringMotion motion) {
      final simulation = motion.createSimulation(start: 0, end: 1);
      var t = 0.0;
      while (!simulation.isDone(t) && t < 10) {
        t += 1 / 60;
      }
      expect(simulation.isDone(t), isTrue, reason: '$motion');
      return simulation.x(t);
    }

    test('every spring factory settles exactly on the target by default', () {
      const description =
          SpringDescription(mass: 1, stiffness: 100, damping: 10);
      final springs = [
        const SpringMotion(description),
        const Motion.customSpring(description) as SpringMotion,
        const CupertinoMotion(),
        const CupertinoMotion.bouncy(),
        const CupertinoMotion.snappy(),
        const CupertinoMotion.smooth(),
        const CupertinoMotion.interactive(),
      ];
      // snapToEnd guarantees the resting value is exactly the target, not just
      // within tolerance, so value-based conditionals stay reliable.
      for (final spring in springs) {
        expect(restingValue(spring), equals(1.0), reason: '$spring');
      }
    });

    test('snapToEnd: false can settle off-target within tolerance', () {
      const snapping = CupertinoMotion.bouncy();
      const notSnapping = CupertinoMotion.bouncy(snapToEnd: false);

      // Without snapping the resting value lands within tolerance but is not
      // guaranteed to be exactly the target.
      expect(restingValue(notSnapping), isNot(equals(1.0)));
      expect(
        restingValue(notSnapping),
        closeTo(1.0, snapping.tolerance.distance),
      );
      expect(
        restingValue(snapping.copyWith(snapToEnd: false)),
        restingValue(notSnapping),
      );
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

  group('TrimmedMotion', () {
    test('trims a linear motion to the kept extent', () {
      const parent = LinearMotion(Duration(seconds: 1));
      const untrimmed = TrimmedMotion(parent: parent, fromStart: 0, fromEnd: 0);
      final parentSim = parent.createSimulation(start: 0, end: 100);
      final untrimmedSim = untrimmed.createSimulation(start: 0, end: 100);
      for (double t = 0; t <= 1.0; t += 0.2) {
        expect(untrimmedSim.x(t), closeTo(parentSim.x(t), error));
      }

      const trimmed = TrimmedMotion(
        parent: parent,
        fromStart: 0.2,
        fromEnd: 0.2,
      );
      final simulation = trimmed.createSimulation();
      expect(simulation.x(0), closeTo(0, error));
      expect(simulation.x(0.3), closeTo(.5, error));
      expect(simulation.x(.6), closeTo(1, error));
      expect(simulation.isDone(.6), isTrue);
      final velocity = trimmed.createSimulation(start: 0, end: 100).dx(0.5);
      expect(velocity, greaterThan(0));
      expect(velocity.isFinite, isTrue);
    });

    test('segment trims to a sub-extent', () {
      const parent = LinearMotion(Duration(seconds: 1));
      final trimmed = parent.segment(length: 0.5, start: 0.2);

      expect(trimmed.fromStart, equals(0.2));
      expect(trimmed.fromEnd, closeTo(0.3, error)); // 1.0 - (0.2 + 0.5)
    });

    test('preserves curved parent samples', () {
      final simulation = const CurvedMotion(
        Duration(seconds: 1),
        Curves.easeInOut,
      ).trimmed(fromStart: 0.2, fromEnd: 0.1).createSimulation();

      const samples = [
        (0.0, 0.0, 0.0),
        (0.1, 0.11830247917850757, 1.3046286549398545),
        (0.35, 0.5597513652865835, 1.609224776492224),
        (0.7, 1.0, 0.0),
      ];
      for (final (time, position, velocity) in samples) {
        expect(simulation.x(time), closeTo(position, 1e-9));
        expect(simulation.dx(time), closeTo(velocity, 1e-9));
      }
    });

    test('preserves spring parent samples', () {
      final simulation =
          const CupertinoMotion(duration: Duration(milliseconds: 550))
              .trimmed(fromStart: 0.2, fromEnd: 0.1)
              .createSimulation();

      // 1e-7 tolerance: these positions were sampled with a probed parent
      // length, about 3e-8 s from its exact settle time.
      const samples = [
        (0.0, 0.0),
        (0.1, 0.5743175672500058),
        (0.35, 0.9608466277078888),
        (0.7, 0.9996420550842717),
      ];
      for (final (time, position) in samples) {
        expect(simulation.x(time), closeTo(position, 1e-7));
      }
    });
  });
}
