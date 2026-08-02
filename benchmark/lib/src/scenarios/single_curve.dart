import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:motor_benchmark/src/harness.dart';

/// 1D duration/curve: Motor [TrackController] vs [AnimationController].
class SingleCurveScenario implements BenchScenario {
  const SingleCurveScenario();

  static const _duration = Duration(milliseconds: 800);
  static const _motion = CurvedMotion(_duration, Curves.easeInOut);

  @override
  String get id => 'single_curve';

  @override
  String get name => 'Single curve (1D)';

  @override
  String get description =>
      'CurvedMotion vs AnimationController — looping easeInOut.';

  @override
  Map<String, Object?> get params => const {'dims': 1, 'motion': 'curve'};

  @override
  Future<ScenarioResult> run(WidgetTester tester, BenchConfig config) {
    return runPaired(
      tester: tester,
      config: config,
      scenario: this,
      motorOnce: () async {
        final track = Track<double>(
          const SingleMotionConverter(),
          initial: 0.0,
          motion: _motion,
        );
        final c = TrackController(
          vsync: tester,
          velocityTracking: const VelocityTracking.off(),
        );
        return measureSide(
          tester: tester,
          config: config,
          side: 'motor',
          listenable: c,
          start: () {
            c.animate(
              [
                track([
                  const TrackStep.to(1.0),
                  const TrackStep.to(0.0),
                ]),
              ],
              loop: LoopMode.loop,
            );
          },
          read: () => c.value(track),
          isAnimating: () => c.isAnimating,
          dispose: () {
            c.stop(canceled: true);
            c.dispose();
          },
        );
      },
      flutterOnce: () async {
        final c = AnimationController(
          vsync: tester,
          duration: _duration,
        );
        return measureSide(
          tester: tester,
          config: config,
          side: 'flutter',
          listenable: c,
          start: () => c.repeat(reverse: true),
          read: () => c.value,
          isAnimating: () => c.isAnimating,
          dispose: () {
            c
              ..stop()
              ..dispose();
          },
        );
      },
    );
  }
}
