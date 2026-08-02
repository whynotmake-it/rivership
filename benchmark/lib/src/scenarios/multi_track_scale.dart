import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:motor_benchmark/src/harness.dart';

/// N properties on one [TrackController] vs N [AnimationController]s.
class MultiTrackScaleScenario implements BenchScenario {
  const MultiTrackScaleScenario(this.trackCount);

  final int trackCount;

  static const _duration = Duration(milliseconds: 800);
  static const _motion = CurvedMotion(_duration, Curves.easeInOut);

  @override
  String get id => 'multi_track_$trackCount';

  @override
  String get name => 'Multi-track scale';

  @override
  String get description =>
      '$trackCount tracks / 1 ticker vs $trackCount AnimationControllers.';

  @override
  Map<String, Object?> get params => {'tracks': trackCount};

  @override
  Future<ScenarioResult> run(WidgetTester tester, BenchConfig config) {
    return runPaired(
      tester: tester,
      config: config,
      scenario: this,
      motorOnce: () async {
        final tracks = List<Track<double>>.generate(
          trackCount,
          (i) => Track(
            const SingleMotionConverter(),
            initial: 0.0,
            motion: _motion,
            debugLabel: 't$i',
          ),
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
                for (final track in tracks)
                  track([
                    const TrackStep.to(1.0),
                    const TrackStep.to(0.0),
                  ]),
              ],
              loop: LoopMode.loop,
            );
          },
          read: () => hashDoubles([
            for (final track in tracks) c.value(track),
          ]),
          isAnimating: () => c.isAnimating,
          dispose: () {
            c.stop(canceled: true);
            c.dispose();
          },
        );
      },
      flutterOnce: () async {
        final controllers = List<AnimationController>.generate(
          trackCount,
          (_) => AnimationController(vsync: tester, duration: _duration),
        );
        // Listen to the last controller so earlier tickers have already
        // advanced this frame before we sample all values once.
        return measureSide(
          tester: tester,
          config: config,
          side: 'flutter',
          listenable: controllers.last,
          start: () {
            for (final c in controllers) {
              c.repeat(reverse: true);
            }
          },
          read: () => hashDoubles([
            for (final c in controllers) c.value,
          ]),
          isAnimating: () => controllers.any((c) => c.isAnimating),
          dispose: () {
            for (final c in controllers) {
              c
                ..stop()
                ..dispose();
            }
          },
        );
      },
    );
  }
}
