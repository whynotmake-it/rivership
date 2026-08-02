import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:motor_benchmark/src/harness.dart';

/// Synchronous writes: Motor `set` (velocity off) vs `AnimationController.value=`.
class ManualSetScenario implements BenchScenario {
  const ManualSetScenario({this.iterations = 8000});

  final int iterations;

  @override
  String get id => 'manual_set';

  @override
  String get name => 'Manual set';

  @override
  String get description =>
      'TrackController.set (velocity off) vs AnimationController.value=.';

  @override
  Map<String, Object?> get params => {
        'iterations': iterations,
        'velocityTracking': false,
      };

  @override
  Future<ScenarioResult> run(WidgetTester tester, BenchConfig config) async {
    final track = Track<double>(
      const SingleMotionConverter(),
      initial: 0.0,
      debugLabel: 'set',
    );

    final motor = <SideSample>[];
    final flutter = <SideSample>[];

    for (var r = 0; r < config.repeats; r++) {
      SideSample motorOnce() {
        final c = TrackController(
          vsync: tester,
          velocityTracking: const VelocityTracking.off(),
        )..set([track.value(0.0)]);
        final sample = measureSyncLoop(
          side: 'motor',
          iterations: iterations,
          body: (i) => c.set([track.value(i / iterations)]),
          read: () => c.value<double>(track),
        );
        c.dispose();
        return sample;
      }

      SideSample flutterOnce() {
        final c = AnimationController.unbounded(vsync: tester);
        final sample = measureSyncLoop(
          side: 'flutter',
          iterations: iterations,
          body: (i) => c.value = i / iterations,
          read: () => c.value,
        );
        c.dispose();
        return sample;
      }

      if (r.isEven) {
        motor.add(motorOnce());
        flutter.add(flutterOnce());
      } else {
        flutter.add(flutterOnce());
        motor.add(motorOnce());
      }
    }

    return ScenarioResult(
      id: id,
      name: name,
      description: description,
      params: params,
      motor: motor,
      flutter: flutter,
    );
  }
}

/// Motor-only: cost of [VelocityTracking.on] vs off on `set`.
class VelocityTrackingOverheadScenario implements BenchScenario {
  const VelocityTrackingOverheadScenario({this.iterations = 8000});

  final int iterations;

  @override
  String get id => 'velocity_tracking_overhead';

  @override
  String get name => 'Velocity tracking overhead';

  @override
  String get description =>
      'Motor TrackController.set with VelocityTracking.on vs off.';

  @override
  Map<String, Object?> get params => {'iterations': iterations};

  @override
  Future<ScenarioResult> run(WidgetTester tester, BenchConfig config) async {
    final track = Track<double>(
      const SingleMotionConverter(),
      initial: 0.0,
      debugLabel: 'vt',
    );

    final onSamples = <SideSample>[];
    final offSamples = <SideSample>[];

    SideSample once({required bool tracking}) {
      final c = TrackController(
        vsync: tester,
        velocityTracking: tracking
            ? const VelocityTracking.on()
            : const VelocityTracking.off(),
      )..set([track.value(0.0)]);
      final sample = measureSyncLoop(
        side: tracking ? 'on' : 'off',
        iterations: iterations,
        body: (i) => c.set([track.value(i / iterations)]),
        read: () => c.value<double>(track),
      );
      c.dispose();
      return sample;
    }

    for (var r = 0; r < config.repeats; r++) {
      if (r.isEven) {
        onSamples.add(once(tracking: true));
        offSamples.add(once(tracking: false));
      } else {
        offSamples.add(once(tracking: false));
        onSamples.add(once(tracking: true));
      }
    }

    return ScenarioResult(
      id: id,
      name: name,
      description: description,
      params: params,
      motor: onSamples,
      flutter: offSamples,
      primaryLabel: 'tracking on',
      baselineLabel: 'tracking off',
    );
  }
}
