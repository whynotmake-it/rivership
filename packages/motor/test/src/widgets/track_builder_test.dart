import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

import '../util.dart';

enum _Phase { idle, pressed }

void main() {
  group('TrackBuilder', () {
    final opacity = Track<double>(MotionConverter.single, initial: 0.0);
    final scale = Track<double>(MotionConverter.single, initial: 1.0);

    testWidgets('builds with inline animations', (tester) async {
      double? capturedOpacity;
      double? capturedScale;

      await tester.pumpWidget(
        TrackBuilder(
          animations: [
            opacity.to(
              1,
              motion: const Motion.linear(Duration(milliseconds: 100)),
            ),
            scale.to(
              2,
              motion: const Motion.linear(Duration(milliseconds: 100)),
            ),
          ],
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

    testWidgets('builds with a reusable timeline', (tester) async {
      double? captured;

      await tester.pumpWidget(
        TrackBuilder.timeline(
          TrackTimeline([
            opacity.to(
              1,
              motion: const Motion.linear(Duration(milliseconds: 100)),
            ),
          ]),
          builder: (context, value, child) {
            captured = value<double>(opacity);
            return const SizedBox();
          },
        ),
      );

      expect(captured, equals(0));
      await tester.pumpAndSettle();
      expect(captured, closeTo(1, error));
    });

    testWidgets('inline rebuild with an equal list does not restart',
        (tester) async {
      final steps = <int>[];
      double? captured;

      Widget build() => TrackBuilder(
            animations: [
              opacity([
                const TrackStep.to(
                  1,
                  motion: Motion.linear(Duration(milliseconds: 200)),
                ),
              ]),
            ],
            onStep: (track, stepIndex) => steps.add(stepIndex),
            builder: (context, value, child) {
              captured = value<double>(opacity);
              return const SizedBox();
            },
          );

      await tester.pumpWidget(build());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final midway = captured!;
      expect(midway, greaterThan(0));
      expect(midway, lessThan(1));

      // Rebuild with a fresh-but-equal animations list. Playback must continue
      // from the current value rather than restarting from the start.
      await tester.pumpWidget(build());
      await tester.pump(const Duration(milliseconds: 16));

      expect(captured, greaterThanOrEqualTo(midway));
      expect(steps, equals([0]));

      await tester.pumpAndSettle();
    });

    testWidgets('inline rebuild with a different animation restarts',
        (tester) async {
      final steps = <int>[];

      Widget build(double target) => TrackBuilder(
            animations: [
              opacity([
                TrackStep.to(
                  target,
                  motion: const Motion.linear(Duration(milliseconds: 100)),
                ),
              ]),
            ],
            onStep: (track, stepIndex) => steps.add(stepIndex),
            builder: (context, value, child) => const SizedBox(),
          );

      await tester.pumpWidget(build(1));
      await tester.pumpAndSettle();
      await tester.pumpWidget(build(2));
      await tester.pumpAndSettle();

      expect(steps, equals([0, 0]));
    });

    testWidgets('timeline rebuild with an equal timeline does not restart',
        (tester) async {
      final steps = <int>[];

      Widget build() => TrackBuilder.timeline(
            TrackTimeline([
              opacity([
                const TrackStep.to(
                  1,
                  motion: Motion.linear(Duration(milliseconds: 200)),
                ),
              ]),
            ]),
            onStep: (track, stepIndex) => steps.add(stepIndex),
            builder: (context, value, child) => const SizedBox(),
          );

      await tester.pumpWidget(build());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(build());
      await tester.pump(const Duration(milliseconds: 16));

      expect(steps, equals([0]));
      await tester.pumpAndSettle();
    });

    testWidgets('restartTrigger replays from the start', (tester) async {
      final steps = <int>[];

      Widget build(int trigger) {
        return TrackBuilder(
          animations: [
            opacity([
              const TrackStep.to(
                1,
                motion: Motion.linear(Duration(milliseconds: 100)),
              ),
            ]),
          ],
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
        return TrackBuilder(
          animations: [
            opacity.to(
              1,
              motion: const Motion.linear(Duration(milliseconds: 100)),
            ),
          ],
          restartTrigger: trigger,
          builder: (context, value, child) {
            captured = value<double>(opacity);
            return const SizedBox();
          },
        );
      }

      await tester.pumpWidget(build(0));
      await tester.pumpAndSettle();
      expect(captured, closeTo(1, error));

      await tester.pumpWidget(build(1));
      await tester.pump();
      expect(captured, closeTo(0, error));

      await tester.pump(const Duration(milliseconds: 50));
      expect(captured, greaterThan(0));
      expect(captured, lessThan(1));
    });

    testWidgets('loops when loop is set', (tester) async {
      final steps = <int>[];

      await tester.pumpWidget(
        TrackBuilder(
          loop: LoopMode.loop,
          animations: [
            opacity([
              const TrackStep.to(
                1,
                motion: Motion.linear(Duration(milliseconds: 100)),
              ),
              const TrackStep.to(
                0,
                motion: Motion.linear(Duration(milliseconds: 100)),
              ),
            ]),
          ],
          onStep: (track, stepIndex) => steps.add(stepIndex),
          builder: (context, value, child) => const SizedBox(),
        ),
      );

      await tester.pump();
      // Pump across multiple step boundaries and past one full cycle so the
      // loop re-enters step 0.
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 40));
      }
      // A looping animation never settles and cycles through its steps again.
      expect(steps.length, greaterThan(2));

      // Dispose the builder to stop the looping ticker.
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('honors active false', (tester) async {
      double? captured;

      await tester.pumpWidget(
        TrackBuilder(
          animations: [
            opacity.to(
              1,
              motion: const Motion.linear(Duration(milliseconds: 100)),
            ),
          ],
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

    group('active', () {
      double? captured;

      Widget build({required bool active}) => TrackBuilder(
            animations: [
              opacity.to(
                1,
                motion: const Motion.linear(Duration(milliseconds: 100)),
              ),
            ],
            active: active,
            builder: (context, value, child) {
              captured = value<double>(opacity);
              return const SizedBox();
            },
          );

      testWidgets('turning true starts playback', (tester) async {
        await tester.pumpWidget(build(active: false));
        await tester.pump(const Duration(milliseconds: 100));
        expect(captured, equals(0));

        await tester.pumpWidget(build(active: true));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(captured, closeTo(0.5, error));
        await tester.pumpAndSettle();
        expect(captured, closeTo(1, error));
      });

      testWidgets('turning false freezes the current values', (tester) async {
        await tester.pumpWidget(build(active: true));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        await tester.pumpWidget(build(active: false));
        await tester.pump(const Duration(milliseconds: 100));
        expect(captured, closeTo(0.5, error));
        expect(tester.hasRunningAnimations, isFalse);
      });
    });

    testWidgets('restartTrigger replays a timeline from its start values',
        (tester) async {
      double? captured;
      final timeline = TrackTimeline([
        opacity.to(1, motion: const Motion.linear(Duration(milliseconds: 100))),
      ]);

      Widget build(int trigger) => TrackBuilder.timeline(
            timeline,
            restartTrigger: trigger,
            builder: (context, value, child) {
              captured = value<double>(opacity);
              return const SizedBox();
            },
          );

      await tester.pumpWidget(build(0));
      await tester.pumpAndSettle();
      expect(captured, closeTo(1, error));

      await tester.pumpWidget(build(1));
      expect(captured, closeTo(0, error));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(captured, closeTo(0.5, error));
    });

    testWidgets('swapping onAnimationStatusChanged moves the listener',
        (tester) async {
      final first = <AnimationStatus>[];
      final second = <AnimationStatus>[];

      Widget build(ValueChanged<AnimationStatus> onStatus, double target) =>
          TrackBuilder(
            animations: [
              opacity.to(
                target,
                motion: const Motion.linear(Duration(milliseconds: 100)),
              ),
            ],
            onAnimationStatusChanged: onStatus,
            builder: (context, value, child) => const SizedBox(),
          );

      await tester.pumpWidget(build(first.add, 1));
      await tester.pumpAndSettle();
      await tester.pumpWidget(build(second.add, 0));
      await tester.pumpAndSettle();

      expect(first, [AnimationStatus.forward, AnimationStatus.completed]);
      expect(second, [AnimationStatus.reverse, AnimationStatus.dismissed]);
    });

    testWidgets('falls back to a zero start when initial is omitted',
        (tester) async {
      final noInitial = Track<double>(MotionConverter.single);
      double? captured;

      await tester.pumpWidget(
        TrackBuilder(
          animations: [
            noInitial.to(
              1,
              motion: const Motion.linear(Duration(milliseconds: 100)),
            ),
          ],
          builder: (context, value, child) {
            captured = value<double>(noInitial);
            return const SizedBox();
          },
        ),
      );

      expect(captured, equals(0));
      await tester.pumpAndSettle();
      expect(captured, closeTo(1, error));
    });
  });

  group('PhaseTrackBuilder', () {
    final scale = Track<double>(
      MotionConverter.single,
      initial: 1.0,
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
      expect(captured, closeTo(3, error));

      await tester.pumpWidget(build(1));
      await tester.pump();
      expect(captured, closeTo(1, error));
    });
  });
}
