import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:motor_benchmark/src/allocations.dart';
import 'package:motor_benchmark/src/driver.dart';

/// Something measured per scenario and side.
enum Metric {
  total('Frame + reads', 'µs/frame'),
  frame('Frame (engine)', 'µs/frame'),
  read('Value read', 'ns/value'),
  start('Start from rest', 'µs/op'),
  retarget('Retarget mid-flight', 'µs/op'),
  allocated('Allocated', 'B/frame'),
  retained('Retained', 'KB');

  const Metric(this.label, this.unit);

  final String label;
  final String unit;
}

/// Shared knobs for every scenario.
@immutable
class BenchConfig {
  const BenchConfig({
    this.warmupFrames = 60,
    this.frames = 240,
    this.operations = 30,
    this.runs = 7,
  });

  /// Smoke configuration for CI: seconds, not minutes.
  const BenchConfig.quick()
      : warmupFrames = 10,
        frames = 30,
        operations = 5,
        runs = 2;

  /// Reads `BENCH_QUICK`, `BENCH_RUNS` and `BENCH_FRAMES`.
  factory BenchConfig.fromEnvironment(Map<String, String> env) {
    final base = env['BENCH_QUICK'] == '1'
        ? const BenchConfig.quick()
        : const BenchConfig();
    return BenchConfig(
      warmupFrames: base.warmupFrames,
      frames: int.tryParse(env['BENCH_FRAMES'] ?? '') ?? base.frames,
      operations: base.operations,
      runs: int.tryParse(env['BENCH_RUNS'] ?? '') ?? base.runs,
    );
  }

  /// Untimed frames after starting, before measuring.
  final int warmupFrames;

  /// Timed frames per run.
  final int frames;

  /// Timed starts and retargets per run.
  final int operations;

  /// Measured runs per side. One extra warm-up run is discarded.
  final int runs;

  Map<String, Object?> toJson() => {
        'warmupFrames': warmupFrames,
        'frames': frames,
        'operations': operations,
        'runs': runs,
      };
}

/// One side of a comparison: a set of animated values and the controllers
/// driving them.
abstract class BenchSide {
  /// Animates every value from its current state toward the high target
  /// ([forward]) or the low one.
  void start({required bool forward});

  /// Reads every value once and folds them into a number, so reads can't be
  /// optimized away. Both sides fold equal values to equal numbers.
  double read();

  bool get isAnimating;

  void stop();

  void dispose();
}

/// Creates a [BenchSide]. [steady] asks for motions long enough to stay in
/// flight for the whole measured window; otherwise realistic short motions.
typedef SideFactory = BenchSide Function(
  TickerProvider vsync, {
  required bool steady,
});

/// A motor setup and its equivalent built from Flutter's
/// `AnimationController`.
@immutable
class BenchScenario {
  const BenchScenario({
    required this.id,
    required this.group,
    required this.values,
    required this.motorSetup,
    required this.flutterSetup,
    required this.motor,
    required this.flutter,
    this.retargets = false,
  });

  final String id;

  /// Rows sharing a group are printed together, e.g. `spring 1D`.
  final String group;

  /// How many animated values the scenario has.
  final int values;
  final String motorSetup;
  final String flutterSetup;
  final SideFactory motor;
  final SideFactory flutter;

  /// Whether mid-flight retargets are measured (springs only: they keep
  /// velocity; a retargeted curve has no equivalent on the Flutter side).
  final bool retargets;
}

/// Per-run samples for one side of one scenario.
class SideResult {
  final Map<Metric, List<double>> samples = {};

  /// The value [BenchSide.read] returned after warmup, for the equivalence
  /// check between sides.
  double? checkValue;

  void add(Metric metric, double value) => (samples[metric] ??= []).add(value);

  Stats? stats(Metric metric) {
    final values = samples[metric];
    return values == null || values.isEmpty ? null : Stats.from(values);
  }

  Map<String, Object?> toJson() => {
        for (final MapEntry(:key, :value) in samples.entries)
          key.name: {...Stats.from(value).toJson(), 'runs': value},
        'checkValue': checkValue,
      };
}

/// Median and spread over runs.
@immutable
class Stats {
  const Stats({required this.median, required this.min, required this.max});

  factory Stats.from(List<double> values) {
    final sorted = [...values]..sort();
    final mid = sorted.length ~/ 2;
    final median =
        sorted.length.isOdd ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
    return Stats(median: median, min: sorted.first, max: sorted.last);
  }

  final double median;
  final double min;
  final double max;

  /// Half the range, relative to the median.
  double get spread => median == 0 ? 0 : (max - min) / 2 / median.abs();

  Map<String, Object?> toJson() => {'median': median, 'min': min, 'max': max};
}

class ScenarioResult {
  ScenarioResult(this.scenario);

  final BenchScenario scenario;
  final motor = SideResult();
  final flutter = SideResult();

  /// Motor's median divided by Flutter's.
  double? ratio(Metric metric) {
    final m = motor.stats(metric)?.median;
    final f = flutter.stats(metric)?.median;
    if (m == null || f == null || f == 0) return null;
    return m / f;
  }

  /// Whether both sides produced the same values after warmup.
  bool get equivalent {
    final m = motor.checkValue;
    final f = flutter.checkValue;
    if (m == null || f == null) return false;
    return (m - f).abs() <= 1e-3 * math.max(1, f.abs());
  }

  Map<String, Object?> toJson() => {
        'id': scenario.id,
        'group': scenario.group,
        'values': scenario.values,
        'motorSetup': scenario.motorSetup,
        'flutterSetup': scenario.flutterSetup,
        'equivalent': equivalent,
        'motor': motor.toJson(),
        'flutter': flutter.toJson(),
      };
}

/// Runs [scenarios] and returns their results.
///
/// Each scenario gets `config.runs + 1` runs per side, alternating which side
/// goes first; the first run warms up the code and is discarded. When
/// [profiler] is given, allocations are measured in a separate untimed pass.
Future<List<ScenarioResult>> runSuite({
  required SchedulerBinding binding,
  required BenchConfig config,
  required List<BenchScenario> scenarios,
  AllocationProfiler? profiler,
  void Function(String message)? log,
}) async {
  final driver = FrameDriver(binding);
  final results = <ScenarioResult>[];
  final allocationBaseline =
      profiler == null ? 0.0 : await _idleAllocations(driver, profiler);

  for (final scenario in scenarios) {
    log?.call('→ ${scenario.id}: ${scenario.motorSetup} vs '
        '${scenario.flutterSetup}');
    final result = ScenarioResult(scenario);
    for (var run = 0; run <= config.runs; run++) {
      final sides = [
        (scenario.motor, result.motor),
        (scenario.flutter, result.flutter),
      ];
      for (final (factory, side) in run.isEven ? sides : sides.reversed) {
        final into = run == 0 ? SideResult() : side;
        _measureSteady(driver, config, factory, into, scenario.values);
        _measureOperations(driver, config, factory, into, scenario);
        if (run == 0) side.checkValue = into.checkValue;
      }
      // Let pending microtasks (ticker futures) run between runs.
      await Future<void>.delayed(Duration.zero);
    }
    if (profiler != null) {
      for (final (factory, side) in [
        (scenario.motor, result.motor),
        (scenario.flutter, result.flutter),
      ]) {
        await _measureAllocations(
          driver,
          config,
          profiler,
          factory,
          side,
          allocationBaseline,
        );
      }
    }
    results.add(result);
  }
  return results;
}

/// Read passes per timed frame, so every timed read block covers enough
/// reads to dwarf the stopwatch's own cost.
int _readPasses(int values) => math.max(1, 256 ~/ math.max(1, values));

void _measureSteady(
  FrameDriver driver,
  BenchConfig config,
  SideFactory factory,
  SideResult into,
  int values,
) {
  final side = factory(const BenchVsync(), steady: true);
  side.start(forward: true);
  for (var i = 0; i < config.warmupFrames; i++) {
    driver.frame();
    _expectAnimating(side, 'warmup frame $i');
  }
  into.checkValue = side.read();

  final frameTimer = Stopwatch();
  final readTimer = Stopwatch();
  var sink = 0.0;
  var reads = 0;
  final passes = _readPasses(values);
  for (var i = 0; i < config.frames; i++) {
    driver.frame(frameTimer);
    _expectAnimating(side, 'measured frame $i');
    readTimer.start();
    for (var p = 0; p < passes; p++) {
      sink += side.read();
    }
    readTimer.stop();
    reads += passes;
  }
  _expectFinite(sink);
  side
    ..stop()
    ..dispose();

  final frameMicros = _micros(frameTimer) / config.frames;
  final readMicrosPerPass = _micros(readTimer) / reads;
  into
    ..add(Metric.frame, frameMicros)
    ..add(Metric.read, readMicrosPerPass * 1000 / values)
    ..add(Metric.total, frameMicros + readMicrosPerPass);
}

void _measureOperations(
  FrameDriver driver,
  BenchConfig config,
  SideFactory factory,
  SideResult into,
  BenchScenario scenario,
) {
  final side = factory(const BenchVsync(), steady: false);
  final timer = Stopwatch();

  // Start from rest: the call plus the frame that follows it, since engines
  // may defer work to their first tick.
  for (var i = 0; i < config.operations; i++) {
    side.stop();
    timer.start();
    side.start(forward: i.isEven);
    timer.stop();
    driver.frame(timer);
    _expectAnimating(side, 'start $i');
    driver
      ..frame()
      ..frame();
  }
  into.add(Metric.start, _micros(timer) / config.operations);

  if (scenario.retargets) {
    side
      ..stop()
      ..start(forward: true);
    for (var i = 0; i < 3; i++) {
      driver.frame();
    }
    timer.reset();
    for (var i = 0; i < config.operations; i++) {
      timer.start();
      side.start(forward: i.isOdd);
      timer.stop();
      driver.frame(timer);
      _expectAnimating(side, 'retarget $i');
      for (var f = 0; f < 3; f++) {
        driver.frame();
      }
    }
    into.add(Metric.retarget, _micros(timer) / config.operations);
  }

  _expectFinite(side.read());
  side
    ..stop()
    ..dispose();
}

Future<double> _idleAllocations(
  FrameDriver driver,
  AllocationProfiler profiler,
) =>
    profiler.allocatedPerCall(driver.frame);

Future<void> _measureAllocations(
  FrameDriver driver,
  BenchConfig config,
  AllocationProfiler profiler,
  SideFactory factory,
  SideResult into,
  double idleFrameBytes,
) async {
  final before = await profiler.liveBytes();
  final side = factory(const BenchVsync(), steady: true)..start(forward: true);
  for (var i = 0; i < config.warmupFrames; i++) {
    driver.frame();
  }
  final after = await profiler.liveBytes();
  into.add(Metric.retained, (after - before) / 1024);

  var sink = 0.0;
  final perFrame = await profiler.allocatedPerCall(() {
    driver.frame();
    sink += side.read();
  });
  _expectFinite(sink);
  _expectAnimating(side, 'allocation pass');
  side
    ..stop()
    ..dispose();
  into.add(Metric.allocated, math.max(0, perFrame - idleFrameBytes));
}

double _micros(Stopwatch timer) => timer.elapsedTicks * 1e6 / timer.frequency;

void _expectAnimating(BenchSide side, String when) {
  if (!side.isAnimating) {
    throw StateError('Animation stopped before the end of the window ($when).');
  }
}

void _expectFinite(double sink) {
  if (!sink.isFinite) throw StateError('Non-finite read sink: $sink');
}

/// Formats [results] as one markdown table per metric.
String formatResults(List<ScenarioResult> results, BenchConfig config) {
  final buf = StringBuffer();
  for (final metric in Metric.values) {
    final rows = results.where((r) => r.motor.stats(metric) != null).toList();
    if (rows.isEmpty) continue;
    buf
      ..writeln()
      ..writeln('### ${metric.label} (${metric.unit})')
      ..writeln()
      ..writeln('| Scenario | Values | Flutter setup | Flutter | Motor | '
          'Motor / Flutter |')
      ..writeln('|---|---:|---|---:|---:|---:|');
    for (final r in rows) {
      final ratio = r.ratio(metric);
      buf.writeln('| ${r.scenario.group} | ${r.scenario.values} | '
          '${r.scenario.flutterSetup} | '
          '${_cell(r.flutter.stats(metric))} | '
          '${_cell(r.motor.stats(metric))} | '
          '${ratio == null ? '–' : '${ratio.toStringAsFixed(2)}×'} |');
    }
  }
  final allocationRuns =
      results.any((r) => r.motor.stats(Metric.allocated) != null);
  buf
    ..writeln()
    ..writeln('_Median of ${config.runs} runs (± half the range, relative); '
        '${config.frames} frames and ${config.operations} operations per run'
        '${allocationRuns ? '; allocations from one untimed pass' : ''}. '
        'Mode: ${_buildMode()}._');
  final mismatched = [
    for (final r in results)
      if (!r.equivalent) r.scenario.id,
  ];
  if (mismatched.isNotEmpty) {
    buf.writeln('\n**Not equivalent:** ${mismatched.join(', ')}');
  }
  return buf.toString();
}

String _cell(Stats? stats) {
  if (stats == null) return '–';
  final digits = stats.median.abs() >= 100 ? 0 : 1;
  return '${stats.median.toStringAsFixed(digits)} '
      '±${(stats.spread * 100).toStringAsFixed(0)}%';
}

String _buildMode() => kReleaseMode
    ? 'release (AOT)'
    : kProfileMode
        ? 'profile (AOT)'
        : 'debug (JIT, asserts on)';

/// Writes [results] as JSON to [path] and returns the file.
File writeResultsJson(
  List<ScenarioResult> results,
  BenchConfig config,
  String path,
) {
  final file = File(path)..parent.createSync(recursive: true);
  file.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'generatedAt': DateTime.now().toIso8601String(),
      'mode': _buildMode(),
      'dart': Platform.version,
      'config': config.toJson(),
      'results': [for (final r in results) r.toJson()],
    }),
  );
  return file;
}
