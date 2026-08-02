import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:motor_benchmark/src/harness.dart';

/// 2D spring: one [MotionController]<[Offset]> vs two [AnimationController]s.
class OffsetSpringScenario implements BenchScenario {
  const OffsetSpringScenario();

  static const _motion = CupertinoMotion.smooth();
  static const _target = Offset(120, 80);

  @override
  String get id => 'offset_spring';

  @override
  String get name => 'Offset spring (2D)';

  @override
  String get description =>
      'Status-driven Offset spring vs 2× AnimationController.';

  @override
  Map<String, Object?> get params => const {'dims': 2, 'motion': 'spring'};

  @override
  Future<ScenarioResult> run(WidgetTester tester, BenchConfig config) {
    final description = _motion.description;

    return runPaired(
      tester: tester,
      config: config,
      scenario: this,
      motorOnce: () async {
        final c = MotionController<Offset>(
          motion: _motion,
          vsync: tester,
          converter: const OffsetMotionConverter(),
          initialValue: Offset.zero,
          velocityTracking: const VelocityTracking.off(),
        );
        late final VoidCallback detach;
        return measureSide(
          tester: tester,
          config: config,
          side: 'motor',
          listenable: c,
          start: () {
            detach = attachMotorSpringPingPong(
              c,
              low: Offset.zero,
              high: _target,
            );
          },
          read: () => c.value.dx + c.value.dy,
          isAnimating: () => c.isAnimating,
          dispose: () {
            detach();
            c.stop(canceled: true);
            c.dispose();
          },
        );
      },
      flutterOnce: () async {
        final x = AnimationController.unbounded(vsync: tester);
        final y = AnimationController.unbounded(vsync: tester);
        late final VoidCallback detachX;
        late final VoidCallback detachY;
        return measureSide(
          tester: tester,
          config: config,
          side: 'flutter',
          listenable: y,
          start: () {
            detachX = attachFlutterSpringPingPong(
              x,
              description,
              high: _target.dx,
            );
            detachY = attachFlutterSpringPingPong(
              y,
              description,
              high: _target.dy,
            );
          },
          read: () => x.value + y.value,
          isAnimating: () => x.isAnimating || y.isAnimating,
          dispose: () {
            detachX();
            detachY();
            x
              ..stop()
              ..dispose();
            y
              ..stop()
              ..dispose();
          },
        );
      },
    );
  }
}
