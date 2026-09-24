// ignore_for_file: unawaited_futures

import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

import '../util.dart';

void main() {
  group('PhaseTrackController.playPhases(atPhase:)', () {
    const linear100 = Motion.linear(Duration(milliseconds: 100));

    late PhaseTrackController<String> controller;

    tearDown(() {
      controller.dispose();
    });

    testWidgets('starts playback from the given phase, not phase 0',
        (tester) async {
      controller = PhaseTrackController<String>(vsync: tester);
      final size = Track<double>(MotionConverter.single, initial: 0);

      controller.playPhases(
        TrackPhaseTimeline({
          'a': [size.to(1, motion: linear100)],
          'b': [size.to(2, motion: linear100)],
          'c': [size.to(3, motion: linear100)],
        }),
        atPhase: 'c',
      );

      expect(controller.currentPhase, 'c');

      await tester.pump();
      // Halfway through a single 100ms phase, size should ramp 0 -> 3 and be
      // clearly past 1.0. If playback wrongly starts at phase 'a' (0 -> 1),
      // the value here is only ~0.5.
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        controller.value(size),
        greaterThan(1),
        reason: 'playPhases(atPhase: c) should animate 0 -> 3 directly, '
            'not start at phase a',
      );

      await tester.pumpAndSettle();
      expect(controller.value(size), closeTo(3, error));
    });

    testWidgets('skips earlier phases but still continues to the end',
        (tester) async {
      controller = PhaseTrackController<String>(vsync: tester);
      final size = Track<double>(MotionConverter.single, initial: 0);

      final entered = <String>[];

      controller.playPhases(
        TrackPhaseTimeline({
          'a': [size.to(1, motion: linear100)],
          'b': [size.to(2, motion: linear100)],
          'c': [size.to(3, motion: linear100)],
        }),
        atPhase: 'b',
        onTransition: (transition) {
          if (transition is PhaseTransitioning<String>) {
            entered.add(transition.to);
          }
        },
      );

      expect(controller.currentPhase, 'b');

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      // Past the halfway point of phase 'b' (0 -> 2) the value is > 1.0.
      // With the bug it is still in phase 'a' (0 -> 1) at ~0.6.
      expect(
        controller.value(size),
        greaterThan(1),
        reason: 'playback should start at phase b, not a',
      );

      await tester.pumpAndSettle();
      expect(controller.value(size), closeTo(3, error));

      // Phase 'a' must never be entered; only 'c' is reached via transition.
      expect(entered, equals(['c']));
    });
  });
}
