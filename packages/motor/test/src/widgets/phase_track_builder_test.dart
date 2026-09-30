import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

import '../util.dart';

enum _Phase { idle, pressed }

const _linear100 = Motion.linear(Duration(milliseconds: 100));
const _linear200 = Motion.linear(Duration(milliseconds: 200));

void main() {
  group('PhaseTrackBuilder', () {
    final scale = Track<double>(
      MotionConverter.single,
      initial: 0,
      motion: _linear100,
    );

    testWidgets(
        'manual phase changes animate from the current value and pass the '
        'phase to the builder', (tester) async {
      double? captured;
      _Phase? capturedPhase;

      Widget build(_Phase phase) {
        return PhaseTrackBuilder<_Phase>(
          currentPhase: phase,
          timeline: TrackPhaseTimeline(
            {
              _Phase.idle: [scale.to(1)],
              _Phase.pressed: [scale.to(2)],
            },
            initialValues: [scale.value(5)],
          ),
          builder: (context, value, phase, child) {
            captured = value(scale);
            capturedPhase = phase;
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
      expect(capturedPhase, _Phase.idle);

      // Switching phases must NOT snap back to `from` (5) - it should ramp
      // from the current value (1) toward 2.
      await tester.pumpWidget(build(_Phase.pressed));
      var maxSeen = captured!;
      await tester.pump();
      if (captured! > maxSeen) maxSeen = captured!;
      await tester.pump(const Duration(milliseconds: 50));
      expect(captured, greaterThan(1));
      expect(captured, lessThan(2));
      for (var i = 0; i < 7; i++) {
        await tester.pump(const Duration(milliseconds: 15));
        if (captured! > maxSeen) maxSeen = captured!;
      }

      await tester.pumpAndSettle();
      expect(captured, closeTo(2, error));
      expect(capturedPhase, _Phase.pressed);
      expect(
        maxSeen,
        lessThan(2.5),
        reason: 'value should ramp 1 -> 2, not snap back to from (5.0)',
      );
    });

    testWidgets('onTransition emits transitioning then settled',
        (tester) async {
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

    testWidgets('a phase change while playing keeps auto-advancing',
        (tester) async {
      final phases = <_Phase>[];
      double? captured;

      Widget build(_Phase phase) => PhaseTrackBuilder<_Phase>(
            playing: true,
            currentPhase: phase,
            timeline: TrackPhaseTimeline({
              _Phase.idle: [scale.to(2)],
              _Phase.pressed: [scale.to(3)],
            }),
            onTransition: (transition) {
              if (transition case PhaseSettled(:final phase)) phases.add(phase);
            },
            builder: (context, value, phase, child) {
              captured = value(scale);
              return const SizedBox();
            },
          );

      await tester.pumpWidget(build(_Phase.pressed));
      await tester.pumpAndSettle();
      await tester.pumpWidget(build(_Phase.idle));
      await tester.pumpAndSettle();

      expect(captured, closeTo(3, error));
      expect(phases.last, _Phase.pressed);
    });

    testWidgets('restartTrigger replays from the start, not animate back',
        (tester) async {
      var settleCount = 0;
      double? captured;

      Widget build(int trigger) {
        return PhaseTrackBuilder<_Phase>(
          playing: true,
          restartTrigger: trigger,
          timeline: TrackPhaseTimeline({
            _Phase.idle: [scale.to(2)],
            _Phase.pressed: [scale.to(3)],
          }),
          onTransition: (transition) {
            if (transition is PhaseSettled<_Phase>) settleCount++;
          },
          builder: (context, value, phase, child) {
            captured = value(scale);
            return const SizedBox();
          },
        );
      }

      await tester.pumpWidget(build(0));
      await tester.pumpAndSettle();
      expect(captured, closeTo(3, error));
      expect(settleCount, 1);

      await tester.pumpWidget(build(1));
      await tester.pump();
      expect(captured, closeTo(0, error));

      await tester.pumpAndSettle();
      expect(captured, closeTo(3, error));
      expect(settleCount, 2);
    });

    testWidgets('restartTrigger restores the timeline seed', (tester) async {
      double? captured;
      final timeline = TrackPhaseTimeline(
        {
          _Phase.idle: [scale.to(1)],
        },
        initialValues: [scale.value(5)],
      );

      Widget build(int trigger) => PhaseTrackBuilder<_Phase>(
            restartTrigger: trigger,
            timeline: timeline,
            builder: (context, value, phase, child) {
              captured = value(scale);
              return const SizedBox();
            },
          );

      await tester.pumpWidget(build(0));
      await tester.pumpAndSettle();
      expect(captured, closeTo(1, error));

      await tester.pumpWidget(build(1));
      expect(captured, closeTo(5, error));
      await tester.pumpAndSettle();
      expect(captured, closeTo(1, error));
    });

    testWidgets('calls the latest onTransition', (tester) async {
      final calls = <String>[];

      Widget build(String name, _Phase phase) => PhaseTrackBuilder<_Phase>(
            currentPhase: phase,
            timeline: TrackPhaseTimeline({
              _Phase.idle: [scale.to(1.0)],
              _Phase.pressed: [scale.to(0.5)],
            }),
            onTransition: (transition) => calls.add(name),
            builder: (context, value, phase, child) => const SizedBox(),
          );

      await tester.pumpWidget(build('first', _Phase.idle));
      await tester.pumpAndSettle();
      await tester.pumpWidget(build('first', _Phase.pressed));
      await tester.pump();
      await tester.pumpWidget(build('second', _Phase.pressed));
      calls.clear();
      await tester.pumpAndSettle();

      expect(calls, isNotEmpty);
      expect(calls, everyElement('second'));
    });

    testWidgets('reactivating in playing mode resumes playback',
        (tester) async {
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
            captured = value(scale);
            return const SizedBox();
          },
        );
      }

      await tester.pumpWidget(build(active: true));
      await tester.pump(const Duration(milliseconds: 50));

      // Deactivate: the tracks jump to where the current phase ends.
      await tester.pumpWidget(build(active: false));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(captured, 1);
      expect(tester.hasRunningAnimations, isFalse);

      // Reactivate: auto-advance continues from the current phase into the
      // next one.
      await tester.pumpWidget(build(active: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(captured, lessThan(1));

      // Unmount to stop the looping timeline before the test ends.
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('reactivating in manual mode animates to currentPhase',
        (tester) async {
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
            captured = value(scale);
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

    testWidgets('a phase change while inactive jumps and settles',
        (tester) async {
      final transitions = <PhaseTransition<_Phase>>[];
      double? captured;

      Widget build(_Phase phase) => PhaseTrackBuilder<_Phase>(
            active: false,
            currentPhase: phase,
            timeline: TrackPhaseTimeline({
              _Phase.idle: [scale.to(1)],
              _Phase.pressed: [scale.to(2)],
            }),
            onTransition: transitions.add,
            builder: (context, value, phase, child) {
              captured = value(scale);
              return const SizedBox();
            },
          );

      await tester.pumpWidget(build(_Phase.idle));
      await tester.pumpWidget(build(_Phase.pressed));
      await tester.pump();

      expect(captured, 2);
      expect(tester.hasRunningAnimations, isFalse);
      // Built inactive, no phase was entered before, so only the settle is
      // reported.
      expect(transitions, [const PhaseSettled(_Phase.pressed)]);
    });

    for (final (name, next) in [
      ('an equal velocityTracking', const VelocityTracking.on()),
      ('a changed velocityTracking', const VelocityTracking.off()),
    ]) {
      testWidgets('rebuilding with $name keeps playing without a restart',
          (tester) async {
        final linear = Track<double>(MotionConverter.single, initial: 0);
        double? captured;

        Widget build(VelocityTracking velocityTracking) {
          return PhaseTrackBuilder<_Phase>(
            playing: true,
            velocityTracking: velocityTracking,
            timeline: TrackPhaseTimeline({
              _Phase.idle: [linear.to(1, motion: _linear200)],
            }),
            builder: (context, value, phase, child) {
              captured = value(linear);
              return const SizedBox();
            },
          );
        }

        await tester.pumpWidget(build(const VelocityTracking.on()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(captured, closeTo(0.5, error));

        // A fresh-but-equal timeline and an equal or changed velocityTracking
        // must continue from the current value rather than restarting.
        await tester.pumpWidget(build(next));
        await tester.pump(const Duration(milliseconds: 20));
        expect(captured, closeTo(0.6, error));

        await tester.pumpAndSettle();
        expect(captured, closeTo(1, error));
      });
    }

    group('retargeting one track every frame', () {
      final opacity = Track<double>(MotionConverter.single, initial: 0.0);
      final driven = Track<double>(
        MotionConverter.single,
        initial: 0.0,
        motion: const Motion.linear(Duration(milliseconds: 50)),
      );
      const keyframe = TrackStep<double>.at(
        Duration(milliseconds: 300),
        1,
        motion: Motion.linear(Duration(milliseconds: 300)),
      );

      testWidgets('leaves the other tracks of the current phase running',
          (tester) async {
        double? keyframed;

        Widget build(double input) => PhaseTrackBuilder<_Phase>(
              currentPhase: _Phase.idle,
              timeline: TrackPhaseTimeline(
                {
                  _Phase.idle: [
                    opacity([keyframe]),
                    driven.to(input),
                  ],
                  _Phase.pressed: [opacity.to(0), driven.to(0)],
                },
                initialValues: [opacity.value(0.2)],
              ),
              builder: (context, value, phase, child) {
                keyframed = value(opacity);
                return const SizedBox();
              },
            );

        await tester.pumpWidget(build(0));
        await tester.pump(const Duration(milliseconds: 16));
        for (var frame = 1; frame <= 25; frame++) {
          await tester.pumpWidget(build(frame / 10));
          await tester.pump(const Duration(milliseconds: 16));
        }

        expect(keyframed, 1);
        await tester.pumpAndSettle();
      });

      testWidgets('keeps auto-playing through the phases', (tester) async {
        final phases = <_Phase>[];
        double? keyframed;

        Widget build(double input) => PhaseTrackBuilder<_Phase>(
              playing: true,
              // The driven track follows the input instantly, so it reaches
              // each phase barrier right away.
              timeline: TrackPhaseTimeline({
                _Phase.idle: [
                  opacity([keyframe]),
                  driven.to(input, motion: const Motion.linear(Duration.zero)),
                ],
                _Phase.pressed: [
                  opacity.to(0, motion: const Motion.linear(Duration.zero)),
                  driven.to(input, motion: const Motion.linear(Duration.zero)),
                ],
              }),
              onTransition: (transition) {
                if (transition case PhaseTransitioning(:final to)) {
                  phases.add(to);
                }
              },
              builder: (context, value, phase, child) {
                keyframed = value(opacity);
                return const SizedBox();
              },
            );

        await tester.pumpWidget(build(0));
        for (var frame = 1; frame <= 25; frame++) {
          await tester.pumpWidget(build(frame / 10));
          await tester.pump(const Duration(milliseconds: 16));
        }

        expect(phases, contains(_Phase.pressed));
        expect(keyframed, 0);
        await tester.pumpAndSettle();
      });
    });
  });
}
