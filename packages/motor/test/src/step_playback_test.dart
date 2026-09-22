// ignore_for_file: cascade_invocations

import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:motor/src/simulations/step_playback.dart';

import 'util.dart';

void main() {
  const linear100 = Motion.linear(Duration(milliseconds: 100));
  const linear200 = Motion.linear(Duration(milliseconds: 200));

  group('StepPlayback timeline construction', () {
    test('hold then to plays sequentially', () {
      final playback = StepPlayback<double>(
        steps: [
          const Step.hold(Duration(milliseconds: 200)),
          const Step.to(1.0, motion: linear100),
        ],
        converter: MotionConverter.single,
        start: 0.0,
      );

      // During the hold, value stays at 0.
      playback.advanceTo(0.1);
      expect(playback.values.first, closeTo(0.0, error));
      expect(playback.isDone, isFalse);

      // After hold completes (200ms), the to-step begins.
      playback.advanceTo(0.25);
      expect(playback.values.first, greaterThan(0.0));
      expect(playback.values.first, lessThan(1.0));

      // After both complete.
      playback.advanceTo(0.5);
      expect(playback.values.first, closeTo(1.0, error));
      expect(playback.isDone, isTrue);
    });

    test('Step.at with valid future time plays correctly', () {
      final playback = StepPlayback<double>(
        steps: [
          const Step.at(
            Duration(milliseconds: 200),
            1.0,
            motion: linear200,
          ),
        ],
        converter: MotionConverter.single,
        start: 0.0,
      );

      playback.advanceTo(0.1);
      expect(playback.values.first, greaterThan(0.0));
      expect(playback.values.first, lessThan(1.0));

      playback.advanceTo(0.3);
      expect(playback.values.first, closeTo(1.0, error));
      expect(playback.isDone, isTrue);
    });

    test('Step.at after a shorter hold plays correctly', () {
      final playback = StepPlayback<double>(
        steps: [
          const Step.hold(Duration(milliseconds: 100)),
          const Step.at(
            Duration(milliseconds: 300),
            1.0,
            motion: linear200,
          ),
        ],
        converter: MotionConverter.single,
        start: 0.0,
      );

      // During hold.
      playback.advanceTo(0.05);
      expect(playback.values.first, closeTo(0.0, error));

      // After hold, at-step should be animating.
      playback.advanceTo(0.2);
      expect(playback.values.first, greaterThan(0.0));
      expect(playback.values.first, lessThan(1.0));

      playback.advanceTo(0.5);
      expect(playback.values.first, closeTo(1.0, error));
      expect(playback.isDone, isTrue);
    });

    test('hold(1s) then at(0.5s) asserts because at is in the past', () {
      expect(
        () => StepPlayback<double>(
          steps: [
            const Step.hold(Duration(seconds: 1)),
            const Step.at(
              Duration(milliseconds: 500),
              1.0,
              motion: linear100,
            ),
          ],
          converter: MotionConverter.single,
          start: 0.0,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('multiple holds then at in the past asserts', () {
      expect(
        () => StepPlayback<double>(
          steps: [
            const Step.hold(Duration(milliseconds: 400)),
            const Step.hold(Duration(milliseconds: 400)),
            const Step.at(
              Duration(milliseconds: 500),
              1.0,
              motion: linear100,
            ),
          ],
          converter: MotionConverter.single,
          start: 0.0,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('at times must not go backwards', () {
      expect(
        () => StepPlayback<double>(
          steps: [
            const Step.at(
              Duration(milliseconds: 300),
              1.0,
              motion: linear100,
            ),
            const Step.at(
              Duration(milliseconds: 100),
              2.0,
              motion: linear100,
            ),
          ],
          converter: MotionConverter.single,
          start: 0.0,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('sequential to steps play in order', () {
      final playback = StepPlayback<double>(
        steps: [
          const Step.to(1.0, motion: linear100),
          const Step.to(2.0, motion: linear100),
          const Step.to(3.0, motion: linear100),
        ],
        converter: MotionConverter.single,
        start: 0.0,
      );

      playback.advanceTo(0.05);
      expect(playback.values.first, greaterThan(0.0));
      expect(playback.values.first, lessThan(1.0));

      playback.advanceTo(0.15);
      expect(playback.values.first, greaterThan(1.0));
      expect(playback.values.first, lessThan(2.0));

      playback.advanceTo(0.5);
      expect(playback.values.first, closeTo(3.0, error));
      expect(playback.isDone, isTrue);
    });

    test('hold of zero duration advances immediately', () {
      final playback = StepPlayback<double>(
        steps: [
          const Step.hold(Duration.zero),
          const Step.to(1.0, motion: linear100),
        ],
        converter: MotionConverter.single,
        start: 0.0,
      );

      playback.advanceTo(0.05);
      expect(playback.values.first, greaterThan(0.0));
      expect(playback.values.first, lessThan(1.0));

      playback.advanceTo(0.2);
      expect(playback.values.first, closeTo(1.0, error));
      expect(playback.isDone, isTrue);
    });

    test('Step.at at exactly the cumulative time is valid (gap == 0)', () {
      // hold(100ms) then at(100ms) => gap is exactly 0, which is allowed.
      final playback = StepPlayback<double>(
        steps: [
          const Step.hold(Duration(milliseconds: 100)),
          const Step.at(
            Duration(milliseconds: 100),
            1.0,
            motion: linear100,
          ),
        ],
        converter: MotionConverter.single,
        start: 0.0,
      );

      // Should not throw — gap is exactly 0.
      playback.advanceTo(0.3);
      expect(playback.values.first, closeTo(1.0, error));
      expect(playback.isDone, isTrue);
    });

    test('empty steps list asserts', () {
      expect(
        () => StepPlayback<double>(
          steps: [],
          converter: MotionConverter.single,
          start: 0.0,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('single hold step completes after its duration', () {
      final playback = StepPlayback<double>(
        steps: [
          const Step.hold(Duration(milliseconds: 300)),
        ],
        converter: MotionConverter.single,
        start: 5.0,
      );

      playback.advanceTo(0.15);
      expect(playback.values.first, closeTo(5.0, error));
      expect(playback.isDone, isFalse);

      playback.advanceTo(0.5);
      expect(playback.values.first, closeTo(5.0, error));
      expect(playback.isDone, isTrue);
    });
  });
}
