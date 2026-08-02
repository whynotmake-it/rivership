import 'dart:async';

import 'package:flutter/animation.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:motor_benchmark/src/harness.dart';

/// Mid-flight retargeting cost (setup + following frame work).
class InterruptRetargetScenario implements BenchScenario {
  const InterruptRetargetScenario({this.retargets = 60});

  final int retargets;

  static const _motion = CupertinoMotion.smooth();

  @override
  String get id => 'interrupt_retarget';

  @override
  String get name => 'Interrupt / retarget';

  @override
  String get description =>
      'Re-target a spring $retargets times (Motor animateTo vs AC animateWith).';

  @override
  Map<String, Object?> get params => {'retargets': retargets};

  @override
  Future<ScenarioResult> run(WidgetTester tester, BenchConfig config) {
    final description = _motion.description;

    return runPaired(
      tester: tester,
      config: config,
      scenario: this,
      motorOnce: () => _runMotor(tester, config),
      flutterOnce: () => _runFlutter(tester, config, description),
    );
  }

  Future<List<SideSample>> _runMotor(
    WidgetTester tester,
    BenchConfig config,
  ) async {
    final c = SingleMotionController(
      motion: _motion,
      vsync: tester,
      velocityTracking: const VelocityTracking.off(),
    );
    var sink = 0.0;
    unawaited(c.animateTo(1.0));

    for (var i = 0; i < config.warmupFrames; i++) {
      await tester.pump(config.frameStep);
      sink += c.value;
    }

    final tickSw = Stopwatch();
    final pumpSw = Stopwatch();

    for (var i = 0; i < retargets; i++) {
      if (config.measuresPump) pumpSw.start();
      if (config.measuresTick) tickSw.start();
      unawaited(c.animateTo(i.isEven ? 1.0 : 0.0));
      if (config.measuresTick) {
        sink += c.value;
        tickSw.stop();
      }
      await tester.pump(config.frameStep);
      if (!config.measuresTick) sink += c.value;
      if (config.measuresPump) pumpSw.stop();
    }

    expect(sink.isFinite, isTrue);
    c.dispose();
    return _samples('motor', config, tickSw, pumpSw, sink);
  }

  Future<List<SideSample>> _runFlutter(
    WidgetTester tester,
    BenchConfig config,
    SpringDescription description,
  ) async {
    final c = AnimationController.unbounded(vsync: tester);
    var sink = 0.0;
    unawaited(c.animateWith(SpringSimulation(description, 0, 1, 0)));

    for (var i = 0; i < config.warmupFrames; i++) {
      await tester.pump(config.frameStep);
      sink += c.value;
    }

    final tickSw = Stopwatch();
    final pumpSw = Stopwatch();

    for (var i = 0; i < retargets; i++) {
      final target = i.isEven ? 1.0 : 0.0;
      if (config.measuresPump) pumpSw.start();
      if (config.measuresTick) tickSw.start();
      unawaited(
        c.animateWith(
          SpringSimulation(description, c.value, target, c.velocity),
        ),
      );
      if (config.measuresTick) {
        sink += c.value;
        tickSw.stop();
      }
      await tester.pump(config.frameStep);
      if (!config.measuresTick) sink += c.value;
      if (config.measuresPump) pumpSw.stop();
    }

    expect(sink.isFinite, isTrue);
    c.dispose();
    return _samples('flutter', config, tickSw, pumpSw, sink);
  }

  List<SideSample> _samples(
    String side,
    BenchConfig config,
    Stopwatch tickSw,
    Stopwatch pumpSw,
    double sink,
  ) {
    return [
      if (config.measuresTick)
        SideSample(
          side: side,
          layer: BenchMode.tick,
          elapsed: tickSw.elapsed,
          frames: retargets,
          sink: sink,
        ),
      if (config.measuresPump)
        SideSample(
          side: side,
          layer: BenchMode.pump,
          elapsed: pumpSw.elapsed,
          frames: retargets,
          sink: sink,
        ),
    ];
  }
}
