import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:motor_benchmark/motor_benchmark.dart';

/// Runs the Motor vs AnimationController microbenchmark suite.
///
/// ```sh
/// cd benchmark
/// flutter test --profile test/run_benchmarks_test.dart --reporter expanded
///
/// BENCH_MODE=tick|pump|both
/// BENCH_FILTER=single_curve,multi_track
/// BENCH_QUICK=1
/// BENCH_JSON=results/run.json
/// ```
void main() {
  final filter = Platform.environment['BENCH_FILTER'];
  final quick = Platform.environment['BENCH_QUICK'] == '1';
  final mode = parseBenchMode(Platform.environment['BENCH_MODE']);
  final jsonPath = Platform.environment['BENCH_JSON'];

  final config = (quick ? const BenchConfig.quick() : const BenchConfig())
      .copyWith(mode: mode);

  final scenarios = scenariosMatching(filter);
  assert(
    scenarios.isNotEmpty,
    'No scenarios matched BENCH_FILTER=$filter. '
    'Known ids: ${allScenarios().map((s) => s.id).join(', ')}',
  );

  testWidgets(
    'Motor vs AnimationController benchmarks',
    (tester) async {
      final results = <ScenarioResult>[];
      for (final scenario in scenarios) {
        // ignore: avoid_print
        print('→ ${scenario.id}: ${scenario.description}');
        results.add(await scenario.run(tester, config));
      }
      printResults(results, config);

      final file = writeResultsJson(results, config, path: jsonPath);
      // ignore: avoid_print
      print('Wrote ${file.path}');

      for (final result in results) {
        for (final layer in [
          if (config.measuresTick) BenchMode.tick,
          if (config.measuresPump) BenchMode.pump,
        ]) {
          if (result.motorLayer(layer).isEmpty) continue;
          expect(result.motorStats(layer).p50, greaterThan(0));
          expect(result.flutterStats(layer).p50, greaterThan(0));
        }
      }
    },
    timeout: Timeout(Duration(minutes: quick ? 3 : 20)),
  );
}
