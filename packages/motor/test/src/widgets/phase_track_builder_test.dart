import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

import '../util.dart';

enum _Phase { idle, pressed }

void main() {
  group('PhaseTrackBuilder', () {
    const linear100 = Motion.linear(Duration(milliseconds: 100));

    testWidgets('builder receives the current phase', (tester) async {
      final scale = Track<double>(
        MotionConverter.single,
        initial: 1,
        motion: linear100,
      );

      _Phase? capturedPhase;

      Widget build(_Phase phase) {
        return PhaseTrackBuilder<_Phase>(
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
        initial: 0,
        motion: linear100,
      );

      final transitions = <PhaseTransition<_Phase>>[];

      await tester.pumpWidget(
        PhaseTrackBuilder<_Phase>(
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
        initial: 0,
        motion: linear100,
      );

      var settleCount = 0;

      Widget build(int trigger) {
        return PhaseTrackBuilder<_Phase>(
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
        initial: 0,
        motion: linear100,
      );

      double? captured;

      Widget build(_Phase phase) {
        return PhaseTrackBuilder<_Phase>(
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

    testWidgets('reactivating in playing mode resumes playback',
        (tester) async {
      final scale = Track<double>(
        MotionConverter.single,
        initial: 0,
        motion: linear100,
      );

      double? captured;

      Widget build({required bool active}) {
        return PhaseTrackBuilder<_Phase>(
          playing: true,
          active: active,
          timeline: TrackPhaseTimeline(
            {
              _Phase.idle: [scale.to(1)],
              _Phase.pressed: [scale.to(0)],
            },
            phaseLoop: LoopMode.loop,
          ),
          builder: (context, value, phase, child) {
            captured = value<double>(scale);
            return const SizedBox();
          },
        );
      }

      await tester.pumpWidget(build(active: true));
      await tester.pump(const Duration(milliseconds: 50));

      // Deactivate: values freeze.
      await tester.pumpWidget(build(active: false));
      final frozen = captured;
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(captured, equals(frozen));

      // Reactivate: values must start changing again on the next frame
      await tester.pumpWidget(build(active: true));

      await tester.pump(const Duration(milliseconds: 16));

      expect(captured, isNot(equals(frozen)));

      // Unmount to stop the looping timeline before the test ends.
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('reactivating in manual mode animates to currentPhase',
        (tester) async {
      final scale = Track<double>(
        MotionConverter.single,
        initial: 0,
        motion: linear100,
      );

      double? captured;

      Widget build({required bool active}) {
        return PhaseTrackBuilder<_Phase>(
          active: active,
          currentPhase: _Phase.pressed,
          timeline: TrackPhaseTimeline({
            _Phase.idle: [scale.to(1)],
            _Phase.pressed: [scale.to(2)],
          }),
          builder: (context, value, phase, child) {
            captured = value<double>(scale);
            return const SizedBox();
          },
        );
      }

      // Inactive: nothing plays, the track rests at its initial value.
      await tester.pumpWidget(build(active: false));
      await tester.pump(const Duration(milliseconds: 50));
      expect(captured, closeTo(0, error));

      // Reactivate: the controller animates to the current phase's values.
      await tester.pumpWidget(build(active: true));
      await tester.pumpAndSettle();
      expect(captured, closeTo(2, error));
    });

    testWidgets(
        'rebuilding with an equal timeline while active does not '
        'restart playback', (tester) async {
      final scale = Track<double>(MotionConverter.single, initial: 0);

      double? captured;

      Widget build() {
        return PhaseTrackBuilder<_Phase>(
          playing: true,
          timeline: TrackPhaseTimeline({
            _Phase.idle: [
              scale.to(
                1,
                motion: const Motion.linear(Duration(milliseconds: 200)),
              ),
            ],
          }),
          builder: (context, value, phase, child) {
            captured = value<double>(scale);
            return const SizedBox();
          },
        );
      }

      await tester.pumpWidget(build());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final midway = captured!;
      expect(midway, greaterThan(0));
      expect(midway, lessThan(1));

      // Rebuild with a fresh-but-equal timeline mid-animation. Playback must
      // continue from the current value rather than restarting.
      await tester.pumpWidget(build());
      await tester.pump(const Duration(milliseconds: 16));
      expect(captured, greaterThanOrEqualTo(midway));

      await tester.pumpAndSettle();
      expect(captured, closeTo(1, error));
    });

    testWidgets('changing velocityTracking recreates playback',
        (tester) async {
      final scale = Track<double>(MotionConverter.single, initial: 0);
      double? captured;

      Widget build(VelocityTracking velocityTracking) {
        return PhaseTrackBuilder<_Phase>(
          playing: true,
          velocityTracking: velocityTracking,
          timeline: TrackPhaseTimeline({
            _Phase.idle: [
              scale.to(
                1,
                motion: const Motion.linear(Duration(milliseconds: 200)),
              ),
            ],
          }),
          builder: (context, value, phase, child) {
            captured = value<double>(scale);
            return const SizedBox();
          },
        );
      }

      await tester.pumpWidget(build(const VelocityTracking.on()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final midway = captured!;
      expect(midway, closeTo(0.5, error));

      await tester.pumpWidget(build(const VelocityTracking.off()));
      await tester.pump(const Duration(milliseconds: 16));
      expect(captured, lessThan(midway));

      await tester.pumpAndSettle();
      expect(captured, closeTo(1, error));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('equal velocityTracking does not restart playback',
        (tester) async {
      final scale = Track<double>(MotionConverter.single, initial: 0);
      const velocityTracking = VelocityTracking.on();
      double? captured;

      Widget build() {
        return PhaseTrackBuilder<_Phase>(
          playing: true,
          // Explicitly exercise equality of two const `on` configurations.
          // ignore: avoid_redundant_argument_values
          velocityTracking: velocityTracking,
          timeline: TrackPhaseTimeline({
            _Phase.idle: [
              scale.to(
                1,
                motion: const Motion.linear(Duration(milliseconds: 200)),
              ),
            ],
          }),
          builder: (context, value, phase, child) {
            captured = value<double>(scale);
            return const SizedBox();
          },
        );
      }

      await tester.pumpWidget(build());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final midway = captured!;
      expect(midway, closeTo(0.5, error));

      await tester.pumpWidget(build());
      await tester.pump(const Duration(milliseconds: 16));
      expect(captured, greaterThan(midway));

      await tester.pumpAndSettle();
      expect(captured, closeTo(1, error));
    });
  });
}
