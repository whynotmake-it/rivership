import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

import '../util.dart';

enum _Phase { idle, pressed }

void main() {
  group('PhaseMotionBuilder', () {
    const linear100 = Motion.linear(Duration(milliseconds: 100));

    testWidgets('builder receives the current phase', (tester) async {
      final scale = Track<double>(
        MotionConverter.single,
        zero: 1,
        motion: linear100,
      );

      _Phase? capturedPhase;

      Widget build(_Phase phase) {
        return PhaseMotionBuilder<_Phase>(
          currentPhase: phase,
          timeline: TrackPhaseTimeline({
            _Phase.idle: [scale.to(1)],
            _Phase.pressed: [scale.to(2)],
          }),
          builder: (context, value, phase, child) {
            capturedPhase = phase;
            return const SizedBox();
          },
        );
      }

      await tester.pumpWidget(build(_Phase.idle));
      await tester.pumpAndSettle();
      expect(capturedPhase, _Phase.idle);

      await tester.pumpWidget(build(_Phase.pressed));
      await tester.pumpAndSettle();
      expect(capturedPhase, _Phase.pressed);
    });

    testWidgets('onTransition emits transitioning then settled',
        (tester) async {
      final scale = Track<double>(
        MotionConverter.single,
        zero: 0,
        motion: linear100,
      );

      final transitions = <PhaseTransition<_Phase>>[];

      await tester.pumpWidget(
        PhaseMotionBuilder<_Phase>(
          playing: true,
          timeline: TrackPhaseTimeline({
            _Phase.idle: [scale.to(1)],
            _Phase.pressed: [scale.to(2)],
          }),
          onTransition: transitions.add,
          builder: (context, value, phase, child) => const SizedBox(),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        transitions,
        equals([
          const PhaseTransitioning(from: _Phase.idle, to: _Phase.pressed),
          const PhaseSettled(_Phase.pressed),
        ]),
      );
    });

    testWidgets('restartTrigger replays the timeline', (tester) async {
      final scale = Track<double>(
        MotionConverter.single,
        zero: 0,
        motion: linear100,
      );

      var settleCount = 0;

      Widget build(int trigger) {
        return PhaseMotionBuilder<_Phase>(
          playing: true,
          restartTrigger: trigger,
          timeline: TrackPhaseTimeline({
            _Phase.idle: [scale.to(2)],
          }),
          onTransition: (transition) {
            if (transition is PhaseSettled<_Phase>) settleCount++;
          },
          builder: (context, value, phase, child) => const SizedBox(),
        );
      }

      await tester.pumpWidget(build(0));
      await tester.pumpAndSettle();
      expect(settleCount, 1);

      await tester.pumpWidget(build(1));
      await tester.pumpAndSettle();
      expect(settleCount, 2);
    });

    testWidgets('manual phase change does not re-apply timeline.from',
        (tester) async {
      final scale = Track<double>(
        MotionConverter.single,
        zero: 0,
        motion: linear100,
      );

      double? captured;

      Widget build(_Phase phase) {
        return PhaseMotionBuilder<_Phase>(
          currentPhase: phase,
          timeline: TrackPhaseTimeline(
            {
              _Phase.idle: [scale.to(1)],
              _Phase.pressed: [scale.to(2)],
            },
            from: [scale.value(5)],
          ),
          builder: (context, value, phase, child) {
            captured = value<double>(scale);
            return const SizedBox();
          },
        );
      }

      // `from` is applied once: idle animates down from 5 toward its target.
      await tester.pumpWidget(build(_Phase.idle));
      await tester.pump();
      expect(captured, closeTo(5, 0.5));

      await tester.pumpAndSettle();
      expect(captured, closeTo(1, error));

      // Switching phases must NOT snap back to `from` (5) - it should ramp
      // from the current value (1) toward 2.
      await tester.pumpWidget(build(_Phase.pressed));
      var maxSeen = captured!;
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 15));
        if (captured! > maxSeen) maxSeen = captured!;
      }

      await tester.pumpAndSettle();
      expect(captured, closeTo(2, error));
      expect(
        maxSeen,
        lessThan(2.5),
        reason: 'value should ramp 1 -> 2, not snap back to from (5.0)',
      );
    });
  });
}
