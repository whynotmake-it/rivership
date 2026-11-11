import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

import '../util.dart';

const _linear100 = Motion.linear(Duration(milliseconds: 100));

/// Builds a [TrackBuilder] either inline or from a [TrackTimeline].
final _constructors = <String,
    Widget Function(
  List<TrackAnimation> animations, {
  required TrackWidgetBuilder builder,
  void Function(Track track, int stepIndex)? onStep,
  Object? restartTrigger,
})>{
  'inline': (animations, {required builder, onStep, restartTrigger}) =>
      TrackBuilder(
        animations: animations,
        onStep: onStep,
        restartTrigger: restartTrigger,
        builder: builder,
      ),
  'timeline': (animations, {required builder, onStep, restartTrigger}) =>
      TrackBuilder.timeline(
        TrackTimeline(animations),
        onStep: onStep,
        restartTrigger: restartTrigger,
        builder: builder,
      ),
};

void main() {
  group('TrackBuilder', () {
    final opacity = Track<double>(MotionConverter.single, initial: 0.0);
    final scale = Track<double>(MotionConverter.single, initial: 1.0);

    group('initialValues', () {
      final width = Track<double>(MotionConverter.single);
      final heights = <double>[];

      testWidgets('a restart applies them again', (tester) async {
        final offset = Track<double>(MotionConverter.single, initial: 0);
        var highest = 0.0;
        Widget build(int trigger) => TrackBuilder(
              initialValues: [offset.velocity(200)],
              restartTrigger: trigger,
              animations: [
                offset([const TrackStep.to(0, motion: CupertinoMotion())]),
              ],
              builder: (context, value, child) {
                if (value(offset) > highest) highest = value(offset);
                return const SizedBox();
              },
            );

        await tester.pumpWidget(build(0));
        await tester.pumpAndSettle();
        expect(highest, greaterThan(0.5));

        highest = 0;
        await tester.pumpWidget(build(1));
        await tester.pumpAndSettle();
        expect(highest, greaterThan(0.5), reason: 'the restart keeps velocity');
      });

      Widget build(double target, List<double> seen) => TrackBuilder(
            initialValues: [width.value(40)],
            animations: [
              width([TrackStep.to(target, motion: _linear100)]),
            ],
            builder: (context, value, child) {
              seen.add(value(width));
              return const SizedBox();
            },
          );

      testWidgets('a track mounts at rest on its initial value',
          (tester) async {
        final seen = <double>[];
        await tester.pumpWidget(build(40, seen));

        await tester.pumpAndSettle();
        expect(seen, everyElement(40));
      });

      testWidgets('later changes animate from it, and rebuilds keep going',
          (tester) async {
        final seen = <double>[];
        await tester.pumpWidget(build(40, seen));
        await tester.pumpWidget(build(80, seen));
        await tester.pump(const Duration(milliseconds: 50));

        expect(seen.last, closeTo(60, 1));

        // A rebuild doesn't put the track back on its initial value.
        await tester.pumpWidget(build(80, seen));
        expect(seen.last, closeTo(60, 1));
        await tester.pumpAndSettle();
        expect(seen.last, 80);
      });

      group('for a track that appears after mount', () {
        final height = Track<double>(MotionConverter.single, initial: 0);

        Widget build({
          required bool withHeight,
          double initial = 40,
          double? from,
        }) =>
            TrackBuilder(
              initialValues: [if (withHeight) height.value(initial)],
              animations: [
                width([const TrackStep.to(10, motion: _linear100)]),
                if (withHeight)
                  height(
                    [const TrackStep.to(40, motion: _linear100)],
                    from: from,
                  ),
              ],
              builder: (context, value, child) {
                if (withHeight) heights.add(value(height));
                return const SizedBox();
              },
            );

        setUp(heights.clear);

        testWidgets('it starts at rest on its initial value', (tester) async {
          await tester.pumpWidget(build(withHeight: false));
          await tester.pumpAndSettle();

          await tester.pumpWidget(build(withHeight: true));
          await tester.pumpAndSettle();
          expect(heights, isNotEmpty);
          expect(heights, everyElement(40));
        });

        testWidgets('it does so again when dropped and added back',
            (tester) async {
          await tester.pumpWidget(build(withHeight: true, initial: 0));
          await tester.pump(const Duration(milliseconds: 50));
          expect(heights.last, closeTo(20, 1));

          await tester.pumpWidget(build(withHeight: false));
          await tester.pumpAndSettle();
          heights.clear();

          await tester.pumpWidget(build(withHeight: true));
          await tester.pumpAndSettle();
          expect(heights, everyElement(40));
        });

        testWidgets("the animation's own from wins", (tester) async {
          await tester.pumpWidget(build(withHeight: false));
          await tester.pumpAndSettle();

          await tester.pumpWidget(build(withHeight: true, from: 0));
          await tester.pump(const Duration(milliseconds: 50));
          expect(heights.first, 0);
          expect(heights.last, closeTo(20, 1));
        });

        testWidgets('a track already seen ignores a new entry', (tester) async {
          await tester.pumpWidget(build(withHeight: true, initial: 0));
          await tester.pump(const Duration(milliseconds: 50));
          await tester.pumpWidget(build(withHeight: true, initial: 100));
          expect(heights.last, closeTo(20, 1));
          await tester.pumpAndSettle();
          expect(heights.last, 40);
        });
      });
    });

    group('a track that starts at its target', () {
      Widget build(
        List<TrackAnimation> animations,
        List<AnimationStatus> statuses,
      ) =>
          TrackBuilder(
            animations: animations,
            onAnimationStatusChanged: statuses.add,
            builder: (context, value, child) => const SizedBox(),
          );

      testWidgets('neither ticks nor reports a status on mount',
          (tester) async {
        final statuses = <AnimationStatus>[];
        await tester.pumpWidget(
          build(
            [
              opacity([const TrackStep.to(0.0, motion: _linear100)]),
              scale([const TrackStep.to(2.0, motion: _linear100)], from: 2.0),
            ],
            statuses,
          ),
        );

        expect(tester.binding.hasScheduledFrame, isFalse);
        await tester.pump(const Duration(milliseconds: 200));
        expect(statuses, isEmpty);
      });

      testWidgets('neither ticks nor reports a status when it appears',
          (tester) async {
        final statuses = <AnimationStatus>[];
        await tester.pumpWidget(
          build(
            [
              opacity([const TrackStep.to(0.0, motion: _linear100)]),
            ],
            statuses,
          ),
        );
        await tester.pumpWidget(
          build(
            [
              opacity([const TrackStep.to(0.0, motion: _linear100)]),
              scale([const TrackStep.to(3.0, motion: _linear100)], from: 3.0),
            ],
            statuses,
          ),
        );

        expect(tester.binding.hasScheduledFrame, isFalse);
        expect(statuses, isEmpty);
      });

      testWidgets('plays while another track moves', (tester) async {
        final statuses = <AnimationStatus>[];
        late TrackValueReader read;
        await tester.pumpWidget(
          TrackBuilder(
            animations: [
              opacity([const TrackStep.to(1.0, motion: _linear100)]),
              scale([const TrackStep.to(2.0, motion: _linear100)], from: 2.0),
            ],
            onAnimationStatusChanged: statuses.add,
            builder: (context, value, child) {
              read = value;
              return const SizedBox();
            },
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));

        expect(read(opacity), closeTo(0.5, 1e-9));
        expect(read(scale), 2.0);
        await tester.pumpAndSettle();
        expect(statuses, [AnimationStatus.forward, AnimationStatus.completed]);
      });
    });

    testWidgets('builds with inline animations', (tester) async {
      final noInitial = Track<double>(MotionConverter.single);
      double? capturedOpacity;
      double? capturedScale;
      double? capturedNoInitial;

      await tester.pumpWidget(
        TrackBuilder(
          animations: [
            opacity([const TrackStep.to(1, motion: _linear100)]),
            scale([const TrackStep.to(2, motion: _linear100)]),
            noInitial([const TrackStep.to(1, motion: _linear100)]),
          ],
          builder: (context, value, child) {
            capturedOpacity = value(opacity);
            capturedScale = value(scale);
            capturedNoInitial = value(noInitial);
            return const SizedBox();
          },
        ),
      );

      expect(capturedOpacity, equals(0));
      expect(capturedScale, equals(1));
      expect(
        capturedNoInitial,
        equals(0),
        reason: 'falls back to a zero start when initial is omitted',
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(capturedOpacity, greaterThan(0));
      expect(capturedScale, greaterThan(1));

      await tester.pumpAndSettle();
      expect(capturedOpacity, closeTo(1, error));
      expect(capturedScale, closeTo(2, error));
      expect(capturedNoInitial, closeTo(1, error));
    });

    for (final MapEntry(key: name, value: build) in _constructors.entries) {
      group(name, () {
        testWidgets('rebuild with equal animations does not restart',
            (tester) async {
          final steps = <int>[];
          double? captured;

          Widget widget() => build(
                [
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

          await tester.pumpWidget(widget());
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          final midway = captured!;
          expect(midway, greaterThan(0));
          expect(midway, lessThan(1));

          // Rebuild with fresh-but-equal animations. Playback must continue
          // from the current value rather than restarting from the start.
          await tester.pumpWidget(widget());
          await tester.pump(const Duration(milliseconds: 16));

          expect(captured, greaterThanOrEqualTo(midway));
          expect(steps, equals([0]));

          await tester.pumpAndSettle();
        });

        testWidgets(
            'retargeting one track every frame leaves keyframes on another '
            'track running', (tester) async {
          final starts = <Track>[];
          double? keyframed;
          double? driven;

          Widget widget(double input) => build(
                [
                  opacity([
                    const TrackStep.at(
                      Duration(milliseconds: 300),
                      1,
                      motion: Motion.linear(Duration(milliseconds: 300)),
                    ),
                  ]),
                  scale([
                    TrackStep.to(
                      input,
                      motion: const Motion.linear(Duration(milliseconds: 50)),
                    ),
                  ]),
                ],
                onStep: (track, stepIndex) => starts.add(track),
                builder: (context, value, child) {
                  keyframed = value(opacity);
                  driven = value(scale);
                  return const SizedBox();
                },
              );

          await tester.pumpWidget(widget(1));
          for (var frame = 1; frame <= 25; frame++) {
            await tester.pumpWidget(widget(1 + frame / 10));
            await tester.pump(const Duration(milliseconds: 16));
          }

          expect(keyframed, 1);
          expect(starts.where((track) => track == opacity), hasLength(1));
          expect(driven, greaterThan(3));

          await tester.pumpAndSettle();
          expect(driven, closeTo(3.5, error));
        });

        testWidgets('restartTrigger replays from the start values',
            (tester) async {
          final steps = <int>[];
          double? captured;

          Widget widget(int trigger) => build(
                [
                  opacity([const TrackStep.to(1, motion: _linear100)]),
                ],
                restartTrigger: trigger,
                onStep: (track, stepIndex) => steps.add(stepIndex),
                builder: (context, value, child) {
                  captured = value(opacity);
                  return const SizedBox();
                },
              );

          await tester.pumpWidget(widget(0));
          expect(captured, equals(0));
          await tester.pumpAndSettle();
          expect(captured, closeTo(1, error));

          // Restarting starts over from the start rather than animating back.
          await tester.pumpWidget(widget(1));
          expect(captured, closeTo(0, error));
          await tester.pump();
          expect(captured, closeTo(0, error));
          await tester.pump(const Duration(milliseconds: 50));
          expect(captured, closeTo(0.5, error));

          await tester.pumpAndSettle();
          expect(steps, equals([0, 0]));
        });
      });
    }

    testWidgets('inline rebuild with a different animation restarts',
        (tester) async {
      final steps = <int>[];

      Widget build(double target) => TrackBuilder(
            animations: [
              opacity([TrackStep.to(target, motion: _linear100)]),
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

    testWidgets('a changed loop still replays every track', (tester) async {
      final starts = <Track>[];

      Widget build(LoopMode loop) => TrackBuilder(
            animations: [
              opacity([const TrackStep.to(1, motion: _linear100)]),
              scale([const TrackStep.to(2, motion: _linear100)]),
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

    testWidgets('loops when loop is set', (tester) async {
      final steps = <int>[];

      await tester.pumpWidget(
        TrackBuilder(
          loop: LoopMode.loop,
          animations: [
            opacity(const [
              TrackStep.to(1, motion: _linear100),
              TrackStep.to(0, motion: _linear100),
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

    group('active', () {
      double? captured;

      Widget build({required bool active}) => TrackBuilder(
            animations: [
              opacity([const TrackStep.to(1, motion: _linear100)]),
            ],
            active: active,
            builder: (context, value, child) {
              captured = value(opacity);
              return const SizedBox();
            },
          );

      testWidgets('false holds still and turning true starts playback',
          (tester) async {
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

    testWidgets('swapping onAnimationStatusChanged moves the listener',
        (tester) async {
      final first = <AnimationStatus>[];
      final second = <AnimationStatus>[];

      Widget build(ValueChanged<AnimationStatus> onStatus, double target) =>
          TrackBuilder(
            animations: [
              opacity([TrackStep.to(target, motion: _linear100)]),
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
  });
}
