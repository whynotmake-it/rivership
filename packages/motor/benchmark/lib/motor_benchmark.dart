import 'dart:io';

import 'package:flutter/scheduler.dart';
import 'package:motor_benchmark/src/allocations.dart';
import 'package:motor_benchmark/src/harness.dart';
import 'package:motor_benchmark/src/scenarios.dart';

export 'package:motor_benchmark/src/allocations.dart';
export 'package:motor_benchmark/src/driver.dart';
export 'package:motor_benchmark/src/harness.dart';
export 'package:motor_benchmark/src/scenarios.dart';

/// Runs the scenarios selected by the environment, prints markdown tables and
/// writes JSON.
///
/// Environment: `BENCH_QUICK=1`, `BENCH_FILTER=<id prefixes>`,
/// `BENCH_RUNS`, `BENCH_FRAMES`, `BENCH_JSON=<path>` (default
/// `results/latest.json`), `BENCH_ALLOC=0` to skip allocation profiling.
Future<List<ScenarioResult>> runFromEnvironment(
  SchedulerBinding binding,
) async {
  final env = Platform.environment;
  final config = BenchConfig.fromEnvironment(env);
  final scenarios = scenariosMatching(env['BENCH_FILTER']);
  if (scenarios.isEmpty) {
    throw ArgumentError(
      'No scenario matches BENCH_FILTER=${env['BENCH_FILTER']}. Known ids: '
      '${allScenarios().map((s) => s.id).join(', ')}',
    );
  }
  final profiler =
      env['BENCH_ALLOC'] == '0' ? null : await AllocationProfiler.connect();
  final results = await runSuite(
    binding: binding,
    config: config,
    scenarios: scenarios,
    profiler: profiler,
    log: _print,
  );
  await profiler?.dispose();
  _print(formatResults(results, config));
  final file = writeResultsJson(
    results,
    config,
    env['BENCH_JSON'] ?? 'results/latest.json',
  );
  _print('Wrote ${file.absolute.path}');
  return results;
}

// ignore: avoid_print
void _print(String message) => print(message);
