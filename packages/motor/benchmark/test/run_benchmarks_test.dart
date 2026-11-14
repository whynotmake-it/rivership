import 'package:flutter_test/flutter_test.dart';
import 'package:motor_benchmark/motor_benchmark.dart';

/// Runs the suite under `flutter test` (debug JIT, asserts on).
///
/// Good for smoke tests (`BENCH_QUICK=1`) and quick comparisons; use
/// `tool/run_aot.sh` for numbers to publish. Environment variables are
/// documented on [runFromEnvironment].
void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  // testWidgets because VelocityTracker reads the test binding's clock;
  // runAsync because the suite yields to real microtasks between runs.
  testWidgets(
    'Motor vs AnimationController benchmarks',
    (tester) async {
      final results = (await tester.runAsync(
        () => runFromEnvironment(binding),
      ))!;
      for (final result in results) {
        expect(
          result.equivalent,
          isTrue,
          reason: '${result.scenario.id}: motor and Flutter read different '
              'values (${result.motor.checkValue} vs '
              '${result.flutter.checkValue})',
        );
        for (final metric in result.motor.samples.keys) {
          expect(result.motor.stats(metric)!.median, greaterThan(0));
          expect(result.flutter.stats(metric)!.median, greaterThan(0));
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 30)),
  );
}
