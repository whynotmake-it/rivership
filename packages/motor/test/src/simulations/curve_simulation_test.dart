// ignore_for_file: unawaited_futures

import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

void main() {
  group('CurveSimulation.dx', () {
    CurveSimulation simulation(Curve curve) => CurveSimulation(
          duration: const Duration(milliseconds: 500),
          curve: curve,
          start: 2,
          end: 12,
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

  group('a custom motion returning CurveSimulation', () {
    Future<(Rect, int)> frame(WidgetTester tester, Motion motion) async {
      final rect = Track<Rect>(MotionConverter.rect, initial: Rect.zero);
      final controller = TrackController(vsync: tester)
        ..animate([
          rect.to(const Rect.fromLTRB(10, 20, 30, 40), motion: motion),
        ]);
      await tester.pump();
      _transforms = 0;
      await tester.pump(const Duration(milliseconds: 100));
      final result = (controller.value(rect), _transforms);
      controller.dispose();
      return result;
    }

    testWidgets('evaluates the curve once per frame, like CurvedMotion',
        (tester) async {
      final (curvedValue, curvedTransforms) = await frame(
        tester,
        const CurvedMotion(_duration, _countingCurve),
      );
      final (customValue, customTransforms) = await frame(
        tester,
        const _CurveSimulationMotion(),
      );

      expect(curvedTransforms, 1);
      expect(customTransforms, 1);
      expect(customValue, curvedValue);
    });
  });
}

const _duration = Duration(milliseconds: 300);
const _countingCurve = _CountingCurve();
var _transforms = 0;

class _CountingCurve extends Curve {
  const _CountingCurve();

  @override
  double transformInternal(double t) {
    _transforms++;
    return t * t;
  }
}

class _CurveSimulationMotion extends Motion {
  const _CurveSimulationMotion();

  @override
  bool get needsSettle => false;

  @override
  Simulation createSimulation({
    double start = 0,
    double end = 1,
    double velocity = 0,
  }) =>
      CurveSimulation(
        duration: _duration,
        curve: _countingCurve,
        start: start,
        end: end,
      );

  @override
  bool operator ==(Object other) => other is _CurveSimulationMotion;

  @override
  int get hashCode => (_CurveSimulationMotion).hashCode;
}

class _Squared extends Curve {
  const _Squared();

  @override
  double transformInternal(double t) => t * t;
}
