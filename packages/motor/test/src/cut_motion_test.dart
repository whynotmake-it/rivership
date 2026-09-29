import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:motor/src/simulations/cut_motion.dart';

import 'util.dart';

double _seconds(Duration duration) => duration.inMicroseconds / 1e6;

void main() {
  group('CutMotion', () {
    const spring = CupertinoMotion.bouncy();
    final cut = CutMotion(spring, duration: spring.duration);
    final d = _seconds(spring.duration);

    test('ends at exactly its duration for every move', () {
      expect(cut.duration, spring.duration);
      for (final (end, velocity) in [
        (1.0, 0.0),
        (300.0, -5000.0),
        (0.0, 2000.0),
      ]) {
        expect(
          cut.settlingDuration(end: end, velocity: velocity),
          spring.duration,
        );
        final simulation = cut.createSimulation(end: end, velocity: velocity);
        expect(simulation.x(d), end);
        expect(simulation.isDone(d), isTrue);
        expect(simulation.isDone(d - 1e-9), isFalse);
      }
    });

    test('keeps the start value and velocity', () {
      final simulation =
          cut.createSimulation(start: 10, end: 300, velocity: 800);
      expect(simulation.x(0), 10);
      expect(simulation.dx(0), closeTo(800, 1e-9));
    });

    test('scales a move from rest so it lands on the target', () {
      final parent = spring.createSimulation(end: 300);
      final simulation = cut.createSimulation(end: 300);
      final scale = 300 / parent.x(d);
      for (var t = 0.0; t < d; t += 0.01) {
        expect(simulation.x(t), closeTo(parent.x(t) * scale, 1e-9));
      }
    });

    test('stays within the miss at the cut, also for a fling in place', () {
      for (final (end, velocity) in [
        (300.0, 0.0),
        (300.0, -5000.0),
        (0.0, 2000.0),
      ]) {
        final parent = spring.createSimulation(end: end, velocity: velocity);
        final simulation = cut.createSimulation(end: end, velocity: velocity);
        final miss = (parent.x(d) - end).abs();
        var deviation = 0.0;
        for (var t = 0.0; t <= d; t += 1e-3) {
          deviation =
              math.max(deviation, (simulation.x(t) - parent.x(t)).abs());
        }
        expect(deviation, lessThan(miss * 1.1), reason: '$end at $velocity');
      }
      // The fling still carries the value away from where it started.
      final fling = cut.createSimulation(end: 0, velocity: 2000);
      expect(fling.x(0.1), greaterThan(50));
    });

    test('hands on its velocity at the cut', () {
      final simulation = cut.createSimulation(end: 300);
      final parent = spring.createSimulation(end: 300);
      expect(simulation.dx(d), isNot(0));
      expect(
        simulation.dx(d),
        closeTo(parent.dx(d), parent.dx(d).abs() * 0.05),
      );
      expect(simulation.dx(d + 1), simulation.dx(d));
    });

    test('holds a parent that finishes before the cut', () {
      final curve = CutMotion(
        const Motion.linear(Duration(milliseconds: 200)),
        duration: const Duration(milliseconds: 500),
      );
      final simulation = curve.createSimulation();
      expect(simulation.x(0.1), closeTo(0.5, 1e-9));
      expect(simulation.x(0.3), 1);
      expect(simulation.isDone(0.3), isFalse);
      expect(simulation.isDone(0.5), isTrue);
    });

    test('compares by parent movement and duration', () {
      expect(cut, CutMotion(spring, duration: spring.duration));
      final same = CutMotion(spring, duration: spring.duration);
      expect(cut.hashCode, same.hashCode);
      const shorter = Duration(milliseconds: 400);
      expect(cut, isNot(CutMotion(spring, duration: shorter)));
      const other = CupertinoMotion();
      expect(cut, isNot(CutMotion(other, duration: spring.duration)));

      const duration = Duration(milliseconds: 300);
      const cutDuration = Duration(milliseconds: 200);
      expect(
        CutMotion(const Motion.linear(duration), duration: cutDuration),
        CutMotion(const Motion.curved(duration), duration: cutDuration),
      );
      expect(
        CutMotion(const Motion.linear(duration), duration: cutDuration)
            .hashCode,
        CutMotion(const Motion.curved(duration), duration: cutDuration)
            .hashCode,
      );
    });
  });
}
