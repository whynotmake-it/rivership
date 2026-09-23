import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/src/simulations/settling_spring_simulation.dart';

void main() {
  group('SettlingSpringSimulation', () {
    const tolerance = Tolerance.defaultTolerance;
    final springs = {
      'underdamped': SpringDescription.withDampingRatio(
        mass: 1,
        stiffness: 200,
        ratio: 0.3,
      ),
      'critically damped': SpringDescription.withDampingRatio(
        mass: 1,
        stiffness: 200,
      ),
      'overdamped': SpringDescription.withDampingRatio(
        mass: 1,
        stiffness: 200,
        ratio: 2,
      ),
    };

    for (final MapEntry(key: name, value: spring) in springs.entries) {
      group(name, () {
        final random = math.Random(name.length);
        final cases = [
          for (var i = 0; i < 20; i++)
            (
              start: random.nextDouble() * 400 - 200,
              end: random.nextDouble() * 400 - 200,
              velocity: random.nextDouble() * 4000 - 2000,
            ),
        ];

        test('moves like a Flutter spring until it settles', () {
          for (final (:start, :end, :velocity) in cases) {
            final settling = SettlingSpringSimulation(
              spring,
              start,
              end,
              velocity,
              snapToEnd: true,
            );
            final flutter = SpringSimulation(spring, start, end, velocity);
            final finish = settling.finishSeconds!;
            for (var t = 0.0; t < finish; t += 0.01) {
              expect(settling.x(t), flutter.x(t));
              expect(settling.dx(t), flutter.dx(t));
            }
          }
        });

        test('stays within tolerance of its target once settled', () {
          for (final (:start, :end, :velocity) in cases) {
            final settling = SettlingSpringSimulation(
              spring,
              start,
              end,
              velocity,
              snapToEnd: false,
            );
            final finish = settling.finishSeconds!;
            expect(settling.isDone(finish), isTrue);
            for (var t = finish; t < finish + 3; t += 0.001) {
              expect((settling.x(t) - end).abs(), lessThan(tolerance.distance));
            }
          }
        });

        test('settles close to when Flutter first reports done', () {
          for (final (:start, :end, :velocity) in cases) {
            final settling = SettlingSpringSimulation(
              spring,
              start,
              end,
              velocity,
              snapToEnd: true,
            );
            final flutter = SpringSimulation(spring, start, end, velocity);
            var firstDone = 0.0;
            while (!flutter.isDone(firstDone)) {
              firstDone += 0.001;
            }
            final period = 2 * math.pi / math.sqrt(spring.stiffness);
            expect(settling.finishSeconds, closeTo(firstDone, period / 2));
            expect(settling.x(settling.finishSeconds!), end);
          }
        });
      });
    }

    test('is done right away when already at rest on its target', () {
      final settling = SettlingSpringSimulation(
        springs['underdamped']!,
        1,
        1.0005,
        0,
        snapToEnd: true,
      );
      expect(settling.finishSeconds, 0);
      expect(settling.x(0), 1.0005);
    });
  });
}
