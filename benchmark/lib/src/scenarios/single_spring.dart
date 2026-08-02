import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:motor_benchmark/src/harness.dart';

/// 1D spring with matching status-driven ping-pong on both sides.
class SingleSpringScenario implements BenchScenario {
  const SingleSpringScenario();

  static const _motion = CupertinoMotion.smooth();

  @override
  String get id => 'single_spring';

  @override
  String get name => 'Single spring (1D)';

  @override
  String get description =>
      'Status-driven spring ping-pong (Motor animateTo vs AC animateWith).';

  @override
  Map<String, Object?> get params => const {'dims': 1, 'motion': 'spring'};

  @override
  Future<ScenarioResult> run(WidgetTester tester, BenchConfig config) {
    final description = _motion.description;

    return runPaired(
      tester: tester,
      config: config,
      scenario: this,
      motorOnce: () async {
        final c = SingleMotionController(
          motion: _motion,
          vsync: tester,
          velocityTracking: const VelocityTracking.off(),
        );
        late final VoidCallback detach;
        return measureSide(
          tester: tester,
          config: config,
          side: 'motor',
          listenable: c,
          start: () {
            detach = attachMotorSpringPingPong(c, low: 0.0, high: 1.0);
          },
          read: () => c.value,
          isAnimating: () => c.isAnimating,
          dispose: () {
            detach();
            c.stop(canceled: true);
            c.dispose();
          },
        );
      },
      flutterOnce: () async {
        final c = AnimationController.unbounded(vsync: tester);
        late final VoidCallback detach;
        return measureSide(
          tester: tester,
          config: config,
          side: 'flutter',
          listenable: c,
          start: () {
            detach = attachFlutterSpringPingPong(c, description);
          },
          read: () => c.value,
          isAnimating: () => c.isAnimating,
          dispose: () {
            detach();
            c
              ..stop()
              ..dispose();
          },
        );
      },
    );
  }
}
