import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

import '../util.dart';

class _LyingDurationMotion extends Motion {
  const _LyingDurationMotion();

  @override
  Duration get duration => const Duration(milliseconds: 100);

  @override
  bool get needsSettle => false;

  @override
  bool get unboundedWillSettle => true;

  @override
  Simulation createSimulation({
    double start = 0,
    double end = 1,
    double velocity = 0,
  }) {
    return _TimedLinearSimulation(
      start: start,
      end: end,
      doneAtSeconds: 1,
    );
  }

  @override
  bool operator ==(Object other) => other is _LyingDurationMotion;

  @override
  int get hashCode => Object.hash(_LyingDurationMotion, duration);
}

class _FiniteFreeMotion extends FreeMotion {
  const _FiniteFreeMotion();

  @override
  bool get needsSettle => false;

  @override
  bool get unboundedWillSettle => true;

  @override
  Simulation createSimulation({
    double start = 0,
    double velocity = 0,
  }) {
    return _TimedLinearSimulation(
      start: start,
      end: start + 10,
      doneAtSeconds: 0.2,
    );
  }
}

class _TimedLinearSimulation extends Simulation {
  _TimedLinearSimulation({
    required this.start,
    required this.end,
    required this.doneAtSeconds,
  });

  final double start;
  final double end;
  final double doneAtSeconds;

  @override
  double x(double time) {
    if (time >= doneAtSeconds) return end;
    return start + (end - start) * (time / doneAtSeconds);
  }

  @override
  double dx(double time) {
    if (time < 0 || time >= doneAtSeconds) return 0;
    return (end - start) / doneAtSeconds;
  }

  @override
  bool isDone(double time) => time >= doneAtSeconds;
}

void main() {
  group('MotionController.play', () {
    late MotionController<double> controller;

    tearDown(() {
      controller.dispose();
    });

    testWidgets('plays a list of steps', (tester) async {
      controller = MotionController<double>(
        motion: const Motion.linear(Duration(milliseconds: 100)),
        vsync: tester,
        converter: MotionConverter.single,
        initialValue: 0,
      );

      final future = controller.play([
        const Step.to(10.0, motion: Motion.linear(Duration(milliseconds: 100))),
        const Step.hold(Duration(milliseconds: 100)),
        const Step.to(0.0, motion: Motion.linear(Duration(milliseconds: 100))),
      ]);

      expect(future, isA<TickerFuture>());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(controller.value, greaterThan(0));
      expect(controller.value, lessThan(10));

      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.value, closeTo(10, error));

      await tester.pumpAndSettle();
      expect(controller.value, closeTo(0, error));
      expect(controller.isAnimating, isFalse);
    });

    testWidgets('waits for the active simulation to finish each step',
        (tester) async {
      final steps = <int>[];
      controller = MotionController<double>(
        motion: const Motion.linear(Duration(milliseconds: 100)),
        vsync: tester,
        converter: MotionConverter.single,
        initialValue: 0,
      );

      unawaited(
        controller.play(
          [
            const Step.to(10, motion: _LyingDurationMotion()),
            const Step.to(
              20,
              motion: Motion.linear(Duration(milliseconds: 100)),
            ),
          ],
          onStep: steps.add,
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(controller.value, lessThan(10));
      expect(steps, equals([0]));

      await tester.pumpAndSettle();

      expect(controller.value, closeTo(20, error));
      expect(steps, containsAllInOrder([0, 1]));
    });

    testWidgets('plays non-terminal free steps until their simulation finishes',
        (tester) async {
      controller = MotionController<double>(
        motion: const Motion.linear(Duration(milliseconds: 100)),
        vsync: tester,
        converter: MotionConverter.single,
        initialValue: 0,
      );

      unawaited(
        controller.play([
          const Step.free(motion: _FiniteFreeMotion()),
          const Step.to(0, motion: Motion.linear(Duration(milliseconds: 100))),
        ]),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.value, greaterThan(0));

      await tester.pumpAndSettle();

      expect(controller.value, closeTo(0, error));
      expect(controller.isAnimating, isFalse);
    });

    testWidgets(
        'Step.at interrupts an unfinished segment at its scheduled time',
        (tester) async {
      final steps = <int>[];
      controller = MotionController<double>(
        motion: const Motion.linear(Duration(milliseconds: 100)),
        vsync: tester,
        converter: MotionConverter.single,
        initialValue: 0,
      );

      unawaited(
        controller.play(
          [
            const Step.to(10, motion: _LyingDurationMotion()),
            const Step.at(
              Duration(milliseconds: 120),
              0,
              motion: Motion.linear(Duration(milliseconds: 100)),
            ),
          ],
          onStep: steps.add,
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(steps, containsAllInOrder([0, 1]));
      expect(controller.value, lessThan(1.2));

      await tester.pumpAndSettle();
      expect(controller.value, closeTo(0, error));
    });

    testWidgets('calls onStep when the active step changes', (tester) async {
      final steps = <int>[];
      controller = MotionController<double>(
        motion: const Motion.linear(Duration(milliseconds: 100)),
        vsync: tester,
        converter: MotionConverter.single,
        initialValue: 0,
      );

      unawaited(
        controller.play(
          [
            const Step.to(
              10,
              motion: Motion.linear(Duration(milliseconds: 100)),
            ),
            const Step.to(
              20,
              motion: Motion.linear(Duration(milliseconds: 100)),
            ),
          ],
          onStep: steps.add,
        ),
      );

      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      expect(steps, containsAllInOrder([0, 1]));
    });

    testWidgets('looping playback runs until stopped', (tester) async {
      controller = MotionController<double>(
        motion: const Motion.linear(Duration(milliseconds: 100)),
        vsync: tester,
        converter: MotionConverter.single,
        initialValue: 0,
      );

      unawaited(
        controller.play(
          [
            const Step.to(
              10,
              motion: Motion.linear(Duration(milliseconds: 100)),
            ),
          ],
          loop: LoopMode.loop,
        ),
      );

      await tester.pump(const Duration(seconds: 1));
      expect(controller.isAnimating, isTrue);

      unawaited(controller.stop(canceled: true));
      await tester.pump();
      expect(controller.isAnimating, isFalse);
    });

    testWidgets('animateTo interrupts playback', (tester) async {
      final steps = <int>[];
      controller = MotionController<double>(
        motion: const Motion.linear(Duration(milliseconds: 100)),
        vsync: tester,
        converter: MotionConverter.single,
        initialValue: 0,
      );

      unawaited(
        controller.play(
          [
            const Step.to(
              10,
              motion: Motion.linear(Duration(milliseconds: 100)),
            ),
            const Step.to(
              20,
              motion: Motion.linear(Duration(milliseconds: 100)),
            ),
          ],
          onStep: steps.add,
        ),
      );

      await tester.pump(const Duration(milliseconds: 50));
      unawaited(controller.animateTo(5));
      await tester.pumpAndSettle();

      expect(controller.value, closeTo(5, error));
      expect(steps, equals([0]));
    });
  });
}
