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

    testWidgets('builds with inline animations', (tester) async {
      final noInitial = Track<double>(MotionConverter.single);
      double? capturedOpacity;
      double? capturedScale;
      double? capturedNoInitial;

      await tester.pumpWidget(
        TrackBuilder(
          animations: [
            opacity.to(1, motion: _linear100),
            scale.to(2, motion: _linear100),
            noInitial.to(1, motion: _linear100),
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
                [opacity.to(1, motion: _linear100)],
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
              opacity.to(1, motion: _linear100),
              scale.to(2, motion: _linear100),
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
            animations: [opacity.to(1, motion: _linear100)],
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
            animations: [opacity.to(target, motion: _linear100)],
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
