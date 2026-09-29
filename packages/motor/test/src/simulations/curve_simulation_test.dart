import 'package:flutter/animation.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/src/simulations/curve_simulation.dart';

void main() {
  test('CurveSimulation.dx matches the derivative of its curve', () {
    for (final (curve, derivative) in <(Curve, double Function(double))>[
      (Curves.linear, (_) => 20),
      // u² eases in; its derivative is 2u.
      (const _Squared(), (t) => 10 / 0.5 * 2 * (t / 0.5)),
    ]) {
      final simulation = CurveSimulation(
        duration: const Duration(milliseconds: 500),
        curve: curve,
        start: 2,
        end: 12,
        tolerance: Tolerance.defaultTolerance,
      );
      for (final t in [0.05, 0.2, 0.25, 0.4, 0.45]) {
        expect(
          simulation.dx(t),
          closeTo(derivative(t), 1e-6),
          reason: '$curve at $t',
        );
      }
    }
  });
}

class _Squared extends Curve {
  const _Squared();

  @override
  double transformInternal(double t) => t * t;
}
