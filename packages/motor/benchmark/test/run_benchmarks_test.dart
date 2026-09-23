import 'package:flutter_test/flutter_test.dart';
import 'package:motor_benchmark/motor_benchmark.dart';

/// Runs the suite under `flutter test` (debug JIT, asserts on).
///
/// Good for smoke tests (`BENCH_QUICK=1`) and quick comparisons; use
/// `tool/run_aot.sh` for numbers to publish. Environment variables are
/// documented on [runFromEnvironment].
void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Motor vs AnimationController benchmarks',
    () async {
      final results = await runFromEnvironment(binding);
      for (final result in results) {
        expect(
          result.equivalent,
          isTrue,
          reason: '${result.scenario.id}: motor and Flutter read different '
              'values (${result.motor.checkValue} vs '
              '${result.flutter.checkValue})',
        );
        for (final metric in [Metric.frame, Metric.read, Metric.start]) {
          expect(result.motor.stats(metric)!.median, greaterThan(0));
          expect(result.flutter.stats(metric)!.median, greaterThan(0));
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 30)),
  );
}
