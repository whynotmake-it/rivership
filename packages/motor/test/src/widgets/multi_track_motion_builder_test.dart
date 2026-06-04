import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

import '../util.dart';

enum _Phase { idle, pressed }

void main() {
  group('MultiTrackMotionBuilder', () {
    final opacity = Track<double>(MotionConverter.single, origin: 0.0);
    final scale = Track<double>(MotionConverter.single, origin: 1.0);

    testWidgets('builds with track values', (tester) async {
      double? capturedOpacity;
      double? capturedScale;

      await tester.pumpWidget(
        MultiTrackMotionBuilder(
          timeline: TrackTimeline([
            opacity.to(
              1.0,
              motion: const Motion.linear(Duration(milliseconds: 100)),
            ),
            scale.to(
              2,
              motion: const Motion.linear(Duration(milliseconds: 100)),
            ),
          ]),
          builder: (context, value, child) {
            capturedOpacity = value<double>(opacity);
            capturedScale = value<double>(scale);
            return const SizedBox();
          },
        ),
      );

      expect(capturedOpacity, equals(0));
      expect(capturedScale, equals(1));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(capturedOpacity, greaterThan(0));
      expect(capturedScale, greaterThan(1));

      await tester.pumpAndSettle();
      expect(capturedOpacity, closeTo(1, error));
      expect(capturedScale, closeTo(2, error));
    });

    testWidgets('restarts when restartTrigger changes', (tester) async {
      final steps = <int>[];

      Widget build(int trigger) {
        return MultiTrackMotionBuilder(
          timeline: TrackTimeline([
            opacity([
              const Step.to(
                1,
                motion: Motion.linear(Duration(milliseconds: 100)),
              ),
            ]),
          ]),
          restartTrigger: trigger,
          onStep: (track, stepIndex) => steps.add(stepIndex),
          builder: (context, value, child) => const SizedBox(),
        );
      }

      await tester.pumpWidget(build(0));
      await tester.pumpAndSettle();
      await tester.pumpWidget(build(1));
      await tester.pumpAndSettle();

      expect(steps, equals([0, 0]));
    });

    testWidgets('restartTrigger starts from the start, not animate back',
        (tester) async {
      double? captured;

      Widget build(int trigger) {
        return MultiTrackMotionBuilder(
          timeline: TrackTimeline([
            opacity.to(
              1,
              motion: const Motion.linear(Duration(milliseconds: 100)),
            ),
          ]),
          restartTrigger: trigger,
          builder: (context, value, child) {
            captured = value<double>(opacity);
            return const SizedBox();
          },
        );
      }

      await tester.pumpWidget(build(0));
      await tester.pumpAndSettle();
      // Settled at the end of the timeline.
      expect(captured, closeTo(1, error));

      // Changing the trigger must jump back to the start (origin 0) and replay
      // forward — not animate from 1 back toward the first value.
      await tester.pumpWidget(build(1));
      await tester.pump();
      expect(captured, closeTo(0, error));

      await tester.pump(const Duration(milliseconds: 50));
      expect(captured, greaterThan(0));
      expect(captured, lessThan(1));
    });

    testWidgets('honors active false', (tester) async {
      double? captured;

      await tester.pumpWidget(
        MultiTrackMotionBuilder(
          timeline: TrackTimeline([
            opacity.to(
              1,
              motion: const Motion.linear(Duration(milliseconds: 100)),
            ),
          ]),
          active: false,
          builder: (context, value, child) {
            captured = value<double>(opacity);
            return const SizedBox();
          },
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      expect(captured, equals(0));
    });
  });

  group('PhaseTrackBuilder', () {
    final scale = Track<double>(
      MotionConverter.single,
      origin: 1.0,
      motion: const Motion.linear(Duration(milliseconds: 100)),
    );

    testWidgets('animates when phase changes', (tester) async {
      double? captured;

      Widget build(_Phase phase) {
        return PhaseTrackBuilder<_Phase>(
          currentPhase: phase,
          timeline: TrackPhaseTimeline({
            _Phase.idle: [scale.to(1.0)],
            _Phase.pressed: [scale.to(0.5)],
          }),
          builder: (context, value, phase, child) {
            captured = value<double>(scale);
            return const SizedBox();
          },
        );
      }

      await tester.pumpWidget(build(_Phase.idle));
      await tester.pumpAndSettle();
      expect(captured, closeTo(1, error));

      await tester.pumpWidget(build(_Phase.pressed));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(captured, lessThan(1));
      expect(captured, greaterThan(0.5));

      await tester.pumpAndSettle();
      expect(captured, closeTo(0.5, error));
    });

    testWidgets('restartTrigger starts from the start, not animate back',
        (tester) async {
      double? captured;

      Widget build(int trigger) {
        return PhaseTrackBuilder<_Phase>(
          playing: true,
          restartTrigger: trigger,
          timeline: TrackPhaseTimeline({
            _Phase.idle: [scale.to(2.0)],
            _Phase.pressed: [scale.to(3.0)],
          }),
          builder: (context, value, phase, child) {
            captured = value<double>(scale);
            return const SizedBox();
          },
        );
      }

      await tester.pumpWidget(build(0));
      await tester.pumpAndSettle();
      // Settled at the last phase.
      expect(captured, closeTo(3, error));

      // Changing the trigger must jump back to the start (origin 1.0) and
      // replay forward — not animate from 3 back toward the first phase.
      await tester.pumpWidget(build(1));
      await tester.pump();
      expect(captured, closeTo(1, error));
    });
  });
}
