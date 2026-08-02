import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

/// Which cost to measure.
enum BenchMode {
  /// Time only inside the animation listener (notify + value read).
  /// Simulation advance happens before notify; prefer [pump] for full tick cost.
  tick,

  /// Wall time of `tester.pump` + work (includes framework scheduling).
  pump,

  /// Record both [tick] and [pump] samples per run.
  both,
}

/// Shared knobs for every scenario.
class BenchConfig {
  const BenchConfig({
    this.warmupFrames = 60,
    this.measuredFrames = 240,
    this.frameStep = const Duration(milliseconds: 16),
    this.repeats = 7,
    this.mode = BenchMode.both,
  });

  /// Quick smoke configuration.
  const BenchConfig.quick()
      : warmupFrames = 15,
        measuredFrames = 60,
        frameStep = const Duration(milliseconds: 16),
        repeats = 3,
        mode = BenchMode.both;

  final int warmupFrames;
  final int measuredFrames;
  final Duration frameStep;
  final int repeats;
  final BenchMode mode;

  bool get measuresTick => mode == BenchMode.tick || mode == BenchMode.both;
  bool get measuresPump => mode == BenchMode.pump || mode == BenchMode.both;

  BenchConfig copyWith({
    int? warmupFrames,
    int? measuredFrames,
    Duration? frameStep,
    int? repeats,
    BenchMode? mode,
  }) {
    return BenchConfig(
      warmupFrames: warmupFrames ?? this.warmupFrames,
      measuredFrames: measuredFrames ?? this.measuredFrames,
      frameStep: frameStep ?? this.frameStep,
      repeats: repeats ?? this.repeats,
      mode: mode ?? this.mode,
    );
  }
}

/// One measured sample for one side and one layer.
class SideSample {
  const SideSample({
    required this.side,
    required this.layer,
    required this.elapsed,
    required this.frames,
    required this.sink,
  });

  final String side;
  final BenchMode layer;
  final Duration elapsed;
  final int frames;
  final double sink;

  double get microsPerFrame =>
      frames == 0 ? 0 : elapsed.inMicroseconds / frames;

  Map<String, Object?> toJson() => {
        'side': side,
        'layer': layer.name,
        'elapsedMicros': elapsed.inMicroseconds,
        'frames': frames,
        'microsPerFrame': microsPerFrame,
        'sink': sink,
      };
}

/// Distribution over repeated [SideSample]s for one side/layer.
class SideStats {
  const SideStats({
    required this.p50,
    required this.p90,
    required this.mean,
    required this.stddev,
    required this.n,
  });

  final double p50;
  final double p90;
  final double mean;
  final double stddev;
  final int n;

  factory SideStats.from(List<SideSample> samples) {
    assert(samples.isNotEmpty, 'SideStats requires samples');
    final values = [
      for (final s in samples) s.microsPerFrame,
    ]..sort();
    final n = values.length;
    final mean = values.reduce((a, b) => a + b) / n;
    final variance =
        values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / n;
    return SideStats(
      p50: _percentile(values, 0.50),
      p90: _percentile(values, 0.90),
      mean: mean,
      stddev: math.sqrt(variance),
      n: n,
    );
  }

  static double _percentile(List<double> sorted, double p) {
    if (sorted.length == 1) return sorted.first;
    final rank = p * (sorted.length - 1);
    final lo = rank.floor();
    final hi = rank.ceil();
    if (lo == hi) return sorted[lo];
    final t = rank - lo;
    return sorted[lo] * (1 - t) + sorted[hi] * t;
  }

  Map<String, Object?> toJson() => {
        'p50': p50,
        'p90': p90,
        'mean': mean,
        'stddev': stddev,
        'n': n,
      };
}

/// Aggregated outcome for one scenario.
class ScenarioResult {
  const ScenarioResult({
    required this.id,
    required this.name,
    required this.description,
    required this.params,
    required this.motor,
    required this.flutter,
    this.primaryLabel = 'Motor',
    this.baselineLabel = 'Flutter',
  });

  final String id;
  final String name;
  final String description;
  final Map<String, Object?> params;
  final List<SideSample> motor;
  final List<SideSample> flutter;
  final String primaryLabel;
  final String baselineLabel;

  List<SideSample> motorLayer(BenchMode layer) =>
      motor.where((s) => s.layer == layer).toList();

  List<SideSample> flutterLayer(BenchMode layer) =>
      flutter.where((s) => s.layer == layer).toList();

  SideStats motorStats(BenchMode layer) => SideStats.from(motorLayer(layer));

  SideStats flutterStats(BenchMode layer) =>
      SideStats.from(flutterLayer(layer));

  /// Positive => primary (Motor) slower.
  double deltaPercent(BenchMode layer) {
    final baseline = flutterStats(layer).p50;
    if (baseline == 0) return 0;
    return (motorStats(layer).p50 - baseline) / baseline * 100;
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'params': params,
        'primaryLabel': primaryLabel,
        'baselineLabel': baselineLabel,
        'layers': {
          for (final layer in {
            for (final s in [...motor, ...flutter]) s.layer
          })
            layer.name: {
              'primary': motorStats(layer).toJson(),
              'baseline': flutterStats(layer).toJson(),
              'deltaPercentP50': deltaPercent(layer),
            },
        },
        'samples': {
          'primary': [for (final s in motor) s.toJson()],
          'baseline': [for (final s in flutter) s.toJson()],
        },
      };
}

/// Contract implemented by every benchmark scenario.
abstract class BenchScenario {
  String get id;
  String get name;
  String get description;
  Map<String, Object?> get params => const {};

  Future<ScenarioResult> run(WidgetTester tester, BenchConfig config);
}

/// Measures animation work for [config.mode].
///
/// - `tick`: stopwatch only inside the animation listener while
///   frames are pumped (notify + value read; sim advance is just before notify).
/// - `pump`: wall clock around the measured pump loop.
/// - Asserts [isAnimating] stays true through warmup and measure.
Future<List<SideSample>> measureSide({
  required WidgetTester tester,
  required BenchConfig config,
  required String side,
  required Listenable listenable,
  required void Function() start,
  required double Function() read,
  required void Function() dispose,
  required bool Function() isAnimating,
}) async {
  var sink = 0.0;
  var notifyCount = 0;
  final tickSw = Stopwatch();
  var accumulateTicks = false;

  void listener() {
    notifyCount++;
    if (accumulateTicks) {
      tickSw.start();
      sink += read();
      tickSw.stop();
    } else {
      sink += read();
    }
  }

  listenable.addListener(listener);
  start();
  listener();

  for (var i = 0; i < config.warmupFrames; i++) {
    await tester.pump(config.frameStep);
    expect(
      isAnimating(),
      isTrue,
      reason: '$side stopped animating during warmup frame $i',
    );
  }

  final notifiesBefore = notifyCount;
  tickSw
    ..stop()
    ..reset();
  accumulateTicks = config.measuresTick;

  final pumpSw = Stopwatch();
  if (config.measuresPump) pumpSw.start();

  var stayedAnimating = true;
  for (var i = 0; i < config.measuredFrames; i++) {
    await tester.pump(config.frameStep);
    if (!isAnimating()) stayedAnimating = false;
  }

  if (config.measuresPump) pumpSw.stop();
  accumulateTicks = false;
  listenable.removeListener(listener);

  expect(
    stayedAnimating,
    isTrue,
    reason: '$side stopped animating during measured window',
  );
  expect(
    notifyCount,
    greaterThan(notifiesBefore),
    reason: '$side produced no animation notifications during measure',
  );
  expect(sink.isFinite, isTrue);

  dispose();

  return [
    if (config.measuresTick)
      SideSample(
        side: side,
        layer: BenchMode.tick,
        elapsed: tickSw.elapsed,
        frames: config.measuredFrames,
        sink: sink,
      ),
    if (config.measuresPump)
      SideSample(
        side: side,
        layer: BenchMode.pump,
        elapsed: pumpSw.elapsed,
        frames: config.measuredFrames,
        sink: sink,
      ),
  ];
}

/// Times a pure synchronous loop (no ticker).
SideSample measureSyncLoop({
  required String side,
  required int iterations,
  required void Function(int i) body,
  required double Function() read,
}) {
  var sink = 0.0;
  final warmup = math.max(1, iterations ~/ 10);
  for (var i = 0; i < warmup; i++) {
    body(i);
    sink += read();
  }

  final sinkBefore = sink;
  final sw = Stopwatch()..start();
  for (var i = 0; i < iterations; i++) {
    body(i);
    sink += read();
  }
  sw.stop();

  expect(sink.isFinite, isTrue);
  expect(sink, isNot(equals(sinkBefore)));
  return SideSample(
    side: side,
    layer: BenchMode.tick,
    elapsed: sw.elapsed,
    frames: iterations,
    sink: sink,
  );
}

/// Runs both sides [BenchConfig.repeats] times, alternating order.
Future<ScenarioResult> runPaired({
  required WidgetTester tester,
  required BenchConfig config,
  required BenchScenario scenario,
  required Future<List<SideSample>> Function() motorOnce,
  required Future<List<SideSample>> Function() flutterOnce,
  String primaryLabel = 'Motor',
  String baselineLabel = 'Flutter',
}) async {
  final motor = <SideSample>[];
  final flutter = <SideSample>[];

  for (var i = 0; i < config.repeats; i++) {
    if (i.isEven) {
      motor.addAll(await motorOnce());
      flutter.addAll(await flutterOnce());
    } else {
      flutter.addAll(await flutterOnce());
      motor.addAll(await motorOnce());
    }
  }

  return ScenarioResult(
    id: scenario.id,
    name: scenario.name,
    description: scenario.description,
    params: scenario.params,
    motor: motor,
    flutter: flutter,
    primaryLabel: primaryLabel,
    baselineLabel: baselineLabel,
  );
}

/// Pretty-prints results as markdown tables (one per measured layer).
void printResults(List<ScenarioResult> results, BenchConfig config) {
  if (results.isEmpty) {
    // ignore: avoid_print
    print('No benchmark results.');
    return;
  }

  final layers = <BenchMode>[
    if (config.measuresTick) BenchMode.tick,
    if (config.measuresPump) BenchMode.pump,
  ];

  final buf = StringBuffer()..writeln();

  for (final layer in layers) {
    buf
      ..writeln('## Motor vs AnimationController — `${layer.name}` layer')
      ..writeln()
      ..writeln(
        '| Scenario | Params | ${results.first.baselineLabel} p50 | '
        '${results.first.primaryLabel} p50 | Δ p50 | p90 Δ |',
      )
      ..writeln('|---|---|---:|---:|---:|---:|');

    for (final r in results) {
      if (r.motorLayer(layer).isEmpty) continue;
      final params =
          r.params.entries.map((e) => '${e.key}=${e.value}').join(', ');
      final delta = r.deltaPercent(layer);
      final sign = delta > 0 ? '+' : '';
      final base = r.flutterStats(layer);
      final prim = r.motorStats(layer);
      final p90Delta =
          base.p90 == 0 ? 0.0 : (prim.p90 - base.p90) / base.p90 * 100;
      final p90Sign = p90Delta > 0 ? '+' : '';
      buf.writeln(
        '| ${r.name} | $params | '
        '${base.p50.toStringAsFixed(1)} | '
        '${prim.p50.toStringAsFixed(1)} | '
        '$sign${delta.toStringAsFixed(1)}% | '
        '$p90Sign${p90Delta.toStringAsFixed(1)}% |',
      );
    }

    buf
      ..writeln()
      ..writeln(
        '_µs/frame (or µs/op for sync). Positive Δ = ${results.first.primaryLabel} '
        'slower. p50/p90 over ${results.first.motorLayer(layer).length} runs. '
        '`${layer.name}`: ${switch (layer) {
          BenchMode.tick => 'listener notify + value read only',
          BenchMode.pump => 'full tester.pump wall time',
          BenchMode.both => '',
        }}_',
      )
      ..writeln();
  }

  // ignore: avoid_print
  print(buf);
}

/// Writes [results] as JSON. Returns the path written.
File writeResultsJson(
  List<ScenarioResult> results,
  BenchConfig config, {
  String? path,
}) {
  final relative =
      path ?? 'results/bench_${DateTime.now().millisecondsSinceEpoch}.json';
  final file = File(relative);
  file.parent.createSync(recursive: true);
  final payload = <String, Object?>{
    'generatedAt': DateTime.now().toIso8601String(),
    'config': <String, Object?>{
      'warmupFrames': config.warmupFrames,
      'measuredFrames': config.measuredFrames,
      'frameStepMs': config.frameStep.inMilliseconds,
      'repeats': config.repeats,
      'mode': config.mode.name,
    },
    'results': [
      for (final r in results) r.toJson(),
    ],
  };
  final encoded = const JsonEncoder.withIndent('  ').convert(payload);
  file.writeAsStringSync(encoded);
  File('${file.parent.path}/latest.json').writeAsStringSync(encoded);
  return file;
}

double hashDoubles(Iterable<double> values) {
  var acc = 0.0;
  var i = 0;
  for (final v in values) {
    acc += v * (1 + (i++ % 7));
  }
  return math.sin(acc);
}

/// Status-driven spring ping-pong for [AnimationController] (matches Motor).
VoidCallback attachFlutterSpringPingPong(
  AnimationController controller,
  SpringDescription description, {
  double low = 0,
  double high = 1,
}) {
  var target = high;
  void kick() {
    controller.animateWith(
      SpringSimulation(
        description,
        controller.value,
        target,
        controller.velocity,
      ),
    );
  }

  void onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    target = target == low ? high : low;
    kick();
  }

  controller.addStatusListener(onStatus);
  kick();
  return () => controller.removeStatusListener(onStatus);
}

/// Status-driven spring ping-pong for [MotionController] (matches Flutter).
///
/// Motor reports [AnimationStatus.dismissed] when settling at the controller's
/// initial value and [AnimationStatus.completed] otherwise — so both must
/// retarget, or long windows (full suite) stop after the first return trip.
VoidCallback attachMotorSpringPingPong<T extends Object>(
  MotionController<T> controller, {
  required T low,
  required T high,
}) {
  var target = high;
  void kick() => controller.animateTo(target);

  void onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed &&
        status != AnimationStatus.dismissed) {
      return;
    }
    target = target == low ? high : low;
    kick();
  }

  controller.addStatusListener(onStatus);
  kick();
  return () => controller.removeStatusListener(onStatus);
}
