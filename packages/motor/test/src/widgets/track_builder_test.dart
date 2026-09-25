import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

import '../util.dart';

enum _Phase { idle, pressed }

const _linear100 = Motion.linear(Duration(milliseconds: 100));

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
            capturedOpacity = value(opacity);
            capturedScale = value(scale);
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
            captured = value(opacity);
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
              captured = value(opacity);
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

    testWidgets(
        'retargeting one track every frame leaves keyframes on another '
        'track running', (tester) async {
      final starts = <Track>[];
      double? keyframed;
      double? driven;

      Widget build(double input) => TrackBuilder(
            animations: [
              opacity([
                const TrackStep.at(
                  Duration(milliseconds: 300),
                  1,
                  motion: Motion.linear(Duration(milliseconds: 300)),
                ),
              ]),
              scale.to(
                input,
                motion: const Motion.linear(Duration(milliseconds: 50)),
              ),
            ],
            onStep: (track, stepIndex) => starts.add(track),
            builder: (context, value, child) {
              keyframed = value(opacity);
              driven = value(scale);
              return const SizedBox();
            },
          );

      await tester.pumpWidget(build(1));
      for (var frame = 1; frame <= 25; frame++) {
        await tester.pumpWidget(build(1 + frame / 10));
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(keyframed, 1);
      expect(starts.where((track) => track == opacity), hasLength(1));
      expect(driven, greaterThan(3));

      await tester.pumpAndSettle();
      expect(driven, closeTo(3.5, error));
    });

    testWidgets('calls the latest onStep', (tester) async {
      final calls = <String>[];

      Widget build(String name) => TrackBuilder(
            animations: [
              opacity(const [
                TrackStep.to(1, motion: _linear100),
                TrackStep.to(0, motion: _linear100),
              ]),
            ],
            onStep: (track, stepIndex) => calls.add('$name $stepIndex'),
            builder: (context, value, child) => const SizedBox(),
          );

      await tester.pumpWidget(build('first'));
      await tester.pump();
      await tester.pumpWidget(build('second'));
      await tester.pumpAndSettle();

      expect(calls, ['first 0', 'second 1']);
    });

    testWidgets(
        'retargeting one track of a timeline leaves the other tracks running',
        (tester) async {
      double? keyframed;

      Widget build(double input) => TrackBuilder.timeline(
            TrackTimeline([
              opacity([
                const TrackStep.at(
                  Duration(milliseconds: 300),
                  1,
                  motion: Motion.linear(Duration(milliseconds: 300)),
                ),
              ]),
              scale.to(
                input,
                motion: const Motion.linear(Duration(milliseconds: 50)),
              ),
            ]),
            builder: (context, value, child) {
              keyframed = value(opacity);
              return const SizedBox();
            },
          );

      await tester.pumpWidget(build(1));
      for (var frame = 1; frame <= 25; frame++) {
        await tester.pumpWidget(build(1 + frame / 10));
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(keyframed, 1);
      await tester.pumpAndSettle();
    });

    testWidgets('a changed loop still replays every track', (tester) async {
      final starts = <Track>[];

      Widget build(LoopMode loop) => TrackBuilder(
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
            loop: loop,
            onStep: (track, stepIndex) => starts.add(track),
            builder: (context, value, child) => const SizedBox(),
          );

      await tester.pumpWidget(build(LoopMode.none));
      await tester.pumpAndSettle();
      await tester.pumpWidget(build(LoopMode.pingPong));
      await tester.pump();

      expect(starts, [opacity, scale, opacity, scale]);
      await tester.pumpWidget(const SizedBox());
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
            captured = value(opacity);
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
            captured = value(opacity);
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
              captured = value(opacity);
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

      testWidgets('turning false jumps to where the animations end',
          (tester) async {
        await tester.pumpWidget(build(active: true));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        await tester.pumpWidget(build(active: false));
        await tester.pump();
        expect(captured, 1);
        expect(tester.hasRunningAnimations, isFalse);
      });

      testWidgets('changes while inactive jump to the new end', (tester) async {
        double? value;
        Widget build(double target) => TrackBuilder.timeline(
              TrackTimeline([
                opacity([
                  TrackStep.to(target, motion: _linear100),
                  const TrackStep.hold(Duration(milliseconds: 50)),
                ]),
                scale([const TrackStep.hold(Duration(milliseconds: 50))]),
              ]),
              active: false,
              builder: (context, read, child) {
                value = read(opacity);
                captured = read(scale);
                return const SizedBox();
              },
            );

        await tester.pumpWidget(build(1));
        expect(value, 0);
        await tester.pumpWidget(build(0.4));
        await tester.pump();
        expect(value, 0.4);
        expect(captured, 1, reason: 'a track without a target keeps its value');
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
              captured = value(opacity);
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
            captured = value(noInitial);
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
            captured = value(scale);
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
            captured = value(scale);
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

    testWidgets('a phase change while playing keeps auto-advancing',
        (tester) async {
      final phases = <_Phase>[];
      double? captured;

      Widget build(_Phase phase) => PhaseTrackBuilder<_Phase>(
            playing: true,
            currentPhase: phase,
            timeline: TrackPhaseTimeline({
              _Phase.idle: [scale.to(2.0)],
              _Phase.pressed: [scale.to(3.0)],
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
