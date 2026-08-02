import 'package:motor_benchmark/src/harness.dart';
import 'package:motor_benchmark/src/scenarios/interrupt_retarget.dart';
import 'package:motor_benchmark/src/scenarios/manual_set.dart';
import 'package:motor_benchmark/src/scenarios/multi_track_scale.dart';
import 'package:motor_benchmark/src/scenarios/offset_spring.dart';
import 'package:motor_benchmark/src/scenarios/single_curve.dart';
import 'package:motor_benchmark/src/scenarios/single_spring.dart';
import 'package:motor_benchmark/src/scenarios/widget_rebuild.dart';

export 'package:motor_benchmark/src/harness.dart';
export 'package:motor_benchmark/src/scenarios/interrupt_retarget.dart';
export 'package:motor_benchmark/src/scenarios/manual_set.dart';
export 'package:motor_benchmark/src/scenarios/multi_track_scale.dart';
export 'package:motor_benchmark/src/scenarios/offset_spring.dart';
export 'package:motor_benchmark/src/scenarios/single_curve.dart';
export 'package:motor_benchmark/src/scenarios/single_spring.dart';
export 'package:motor_benchmark/src/scenarios/widget_rebuild.dart';

/// All built-in Motor vs AnimationController scenarios.
List<BenchScenario> allScenarios() => [
      const SingleCurveScenario(),
      const SingleSpringScenario(),
      const OffsetSpringScenario(),
      const MultiTrackScaleScenario(1),
      const MultiTrackScaleScenario(10),
      const MultiTrackScaleScenario(50),
      const MultiTrackScaleScenario(100),
      const MultiTrackScaleScenario(250),
      const MultiTrackScaleScenario(500),
      const InterruptRetargetScenario(),
      const WidgetRebuildScenario(),
      const ManualSetScenario(),
      const VelocityTrackingOverheadScenario(),
    ];

/// Filters [allScenarios] by comma-separated ids (exact or prefix match).
List<BenchScenario> scenariosMatching(String? filter) {
  final all = allScenarios();
  if (filter == null || filter.trim().isEmpty) return all;
  final ids = filter
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  return [
    for (final id in ids)
      ...all.where(
        (s) => s.id == id || s.id.startsWith('${id}_'),
      ),
  ];
}

/// Parses `BENCH_MODE` (`tick` | `pump` | `both`).
BenchMode parseBenchMode(String? raw) {
  switch (raw?.trim().toLowerCase()) {
    case 'tick':
      return BenchMode.tick;
    case 'pump':
      return BenchMode.pump;
    case 'both':
    case null:
    case '':
      return BenchMode.both;
    default:
      throw ArgumentError(
        'Unknown BENCH_MODE="$raw". Use tick, pump, or both.',
      );
  }
}
