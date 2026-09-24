import 'package:flutter/animation.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/src/simulations/curve_simulation.dart';

void main() {
  group('CurveSimulation.dx', () {
    CurveSimulation simulation(Curve curve) => CurveSimulation(
          duration: const Duration(milliseconds: 500),
          curve: curve,
          start: 2,
          end: 12,
          tolerance: Tolerance.defaultTolerance,
        );

    test('matches the derivative of a linear curve', () {
      final linear = simulation(Curves.linear);
      for (final t in [0.05, 0.2, 0.25, 0.4, 0.45]) {
        expect(linear.dx(t), closeTo(20, 1e-6));
      }
    });

    test('matches the derivative of an eased curve', () {
      // u² eases in; its derivative is 2u.
      final eased = simulation(const _Squared());
      for (final t in [0.05, 0.2, 0.25, 0.4, 0.45]) {
        final expected = 10 / 0.5 * 2 * (t / 0.5);
        expect(eased.dx(t), closeTo(expected, 1e-6));
      }
    });
  });
}

class _Squared extends Curve {
  const _Squared();

  @override
  double transformInternal(double t) => t * t;
}
