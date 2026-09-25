// ignore_for_file: cascade_invocations, unawaited_futures

import 'package:clock/clock.dart';
import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

import '../util.dart';

void main() {
  group('TrackController.set', () {
    late TrackController controller;
    final position = Track<double>(MotionConverter.single, initial: 0.0);

    tearDown(() {
      controller.dispose();
    });

    testWidgets('updates track values immediately', (tester) async {
      controller = TrackController(vsync: tester);

      controller.set([position.value(5.0)]);

      expect(controller.value(position), equals(5.0));
    });

    testWidgets('does not start the ticker', (tester) async {
      controller = TrackController(vsync: tester);

      controller.set([position.value(5.0)]);

      expect(controller.isAnimating, isFalse);
    });

    testWidgets('stores an explicit velocity', (tester) async {
      controller = TrackController(vsync: tester);

      controller.set(
        [position.value(5.0)],
        withVelocity: [position.velocity(100.0)],
      );

      expect(controller.value(position), equals(5.0));
      expect(controller.velocity(position), equals(100.0));
    });

    testWidgets('estimates velocity from position samples when none is given',
        (tester) async {
      controller = TrackController(vsync: tester);

      // Feed several samples with increasing values to build velocity.
      // MotionVelocityTracker needs time-stamped samples.
      controller.set([position.value(0.0)]);
      await tester.pump(const Duration(milliseconds: 16));
      controller.set([position.value(1.0)]);
      await tester.pump(const Duration(milliseconds: 16));
      controller.set([position.value(2.0)]);
      await tester.pump(const Duration(milliseconds: 16));
      controller.set([position.value(3.0)]);

      // The tracked velocity should be non-zero and positive.
      expect(controller.velocity(position), greaterThan(0));
    });

    testWidgets('feeds its tracked velocity into the next play',
        (tester) async {
      controller = TrackController(vsync: tester);
      const spring = Motion.smoothSpring(duration: Duration(milliseconds: 500));

      // Build up velocity by setting values rapidly.
      controller.set([position.value(0.0)]);
      await tester.pump(const Duration(milliseconds: 16));
      controller.set([position.value(1.0)]);
      await tester.pump(const Duration(milliseconds: 16));
      controller.set([position.value(2.0)]);

      final velocityBeforePlay = controller.velocity(position);
      expect(velocityBeforePlay, greaterThan(0));

      // Play an animation. The spring should inherit the tracked velocity,
      // causing overshoot past the target.
      controller.play(
        TrackTimeline([
          position.to(2.0, motion: spring),
        ]),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      // With positive velocity toward 2.0 and already at 2.0, a spring
      // should overshoot past the target.
      expect(controller.value(position), greaterThan(2.0));

      controller.stop(canceled: true);
    });

    testWidgets('stops estimating once velocity tracking is turned off',
        (tester) async {
      controller = TrackController(vsync: tester);
      controller.set([position.value(0.0)]);
      await tester.pump(const Duration(milliseconds: 16));
      controller.set([position.value(1.0)]);
      final tracked = controller.velocity(position);
      expect(tracked, greaterThan(0));

      controller.velocityTracking = const VelocityTracking.off();
      expect(controller.velocity(position), tracked);

      await tester.pump(const Duration(milliseconds: 16));
      controller.set([position.value(2.0)]);
      await tester.pump(const Duration(milliseconds: 16));
      controller.set([position.value(3.0)]);
      expect(controller.velocity(position), 0.0);
    });

    testWidgets('keeps its tracked velocity when play starts in a later frame',
        (tester) async {
      controller = TrackController(vsync: tester);
      const spring = Motion.smoothSpring(duration: Duration(milliseconds: 500));

      controller.set([position.value(0.0)]);
      await tester.pump(const Duration(milliseconds: 16));
      controller.set([position.value(1.0)]);
      await tester.pump(const Duration(milliseconds: 16));
      controller.set([position.value(2.0)]);
      // Within the 40 ms after which a still pointer counts as stopped.
      await tester.pump(const Duration(milliseconds: 16));

      controller.play(TrackTimeline([position.to(2.0, motion: spring)]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      expect(controller.value(position), greaterThan(2.0));
      controller.stop(canceled: true);
    });

    testWidgets('stop discards velocity tracked from earlier samples',
        (tester) async {
      controller = TrackController(vsync: tester);

      controller.set([position.value(0.0)]);
      await tester.pump(const Duration(milliseconds: 16));
      controller.set([position.value(1.0)]);
      controller.stop(canceled: true);

      expect(controller.velocity(position), 0.0);
    });

    testWidgets(
        'ignores position samples but accepts explicit velocity when '
        'VelocityTracking is off', (tester) async {
      controller = TrackController(
        vsync: tester,
        velocityTracking: const VelocityTracking.off(),
      );

      // Auto-tracking disabled: velocity should stay zero even with samples.
      controller.set([position.value(0.0)]);
      await tester.pump(const Duration(milliseconds: 16));
      controller.set([position.value(1.0)]);
      await tester.pump(const Duration(milliseconds: 16));
      controller.set([position.value(2.0)]);

      expect(controller.velocity(position), equals(0.0));

      // Explicit velocity still works.
      controller.set(
        [position.value(3.0)],
        withVelocity: [position.velocity(50.0)],
      );
      expect(controller.velocity(position), equals(50.0));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // withVelocity: parameter
  // ─────────────────────────────────────────────────────────────────────────

  group('TrackAnimation withVelocity', () {
    late TrackController controller;
    final position = Track<double>(MotionConverter.single, initial: 0.0);

    tearDown(() {
      controller.dispose();
    });

    testWidgets('is used as the initial playback velocity', (tester) async {
      controller = TrackController(vsync: tester);
      const spring = Motion.smoothSpring(duration: Duration(milliseconds: 500));

      // Start from 2.0 with positive velocity — should overshoot target.
      controller.play(
        TrackTimeline(
          [position.to(2.0, motion: spring, from: 2.0, withVelocity: 100.0)],
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      // Spring starts at target with positive velocity => overshoots.
      expect(controller.value(position), greaterThan(2.0));

      controller.stop(canceled: true);
    });

    testWidgets('defaults to a zero initial velocity when omitted',
        (tester) async {
      controller = TrackController(vsync: tester);
      const spring = Motion.smoothSpring(duration: Duration(milliseconds: 500));

      // Start at the target with no velocity — should settle immediately
      // without overshooting.
      controller.play(
        TrackTimeline(
          [position.to(1.0, motion: spring, from: 1.0)],
        ),
      );

      await tester.pump();
      // At target with zero velocity: spring should not overshoot.
      expect(controller.value(position), closeTo(1.0, 0.01));

      await tester.pumpAndSettle();
      expect(controller.value(position), closeTo(1.0, error));
    });

    testWidgets('overrides the tracked velocity', (tester) async {
      controller = TrackController(vsync: tester);
      const spring = Motion.smoothSpring(duration: Duration(milliseconds: 500));

      // Build up negative tracked velocity.
      controller.set([position.value(3.0)]);
      await tester.pump(const Duration(milliseconds: 16));
      controller.set([position.value(2.0)]);
      await tester.pump(const Duration(milliseconds: 16));
      controller.set([position.value(1.0)]);

      // Tracked velocity should be negative.
      expect(controller.velocity(position), lessThan(0));

      // Play with explicit positive velocity — should override tracked.
      controller.play(
        TrackTimeline(
          [position.to(1.0, motion: spring, from: 1.0, withVelocity: 100.0)],
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      // Positive velocity should cause overshoot past 1.0, not undershoot.
      expect(controller.value(position), greaterThan(1.0));

      controller.stop(canceled: true);
    });
  });

  group('TrackController.animate with withVelocity', () {
    late TrackController controller;
    final position = Track<double>(MotionConverter.single, initial: 0.0);

    tearDown(() {
      controller.dispose();
    });

    testWidgets('starts from current value without jumping', (tester) async {
      controller = TrackController(
        vsync: tester,
        velocityTracking: const VelocityTracking.off(),
      );
      const spring = Motion.smoothSpring(duration: Duration(milliseconds: 500));

      controller.set([position.value(2.0)]);

      controller.animate(
        [position.to(2.0, motion: spring, withVelocity: 150.0)],
      );

      await tester.pump();
      // No jump: value stays at the current value on the first frame.
      expect(controller.value(position), closeTo(2.0, error));
      // The provided velocity is applied as the initial playback velocity.
      expect(controller.velocity(position), closeTo(150.0, 1));

      // Positive velocity at the target overshoots.
      await tester.pump(const Duration(milliseconds: 16));
      expect(controller.value(position), greaterThan(2.0));

      controller.stop(canceled: true);
    });

    testWidgets('overrides auto-tracked velocity', (tester) async {
      controller = TrackController(vsync: tester);
      const spring = Motion.smoothSpring(duration: Duration(milliseconds: 500));

      // Build up negative tracked velocity.
      controller.set([position.value(3.0)]);
      await tester.pump(const Duration(milliseconds: 16));
      controller.set([position.value(2.0)]);
      await tester.pump(const Duration(milliseconds: 16));
      controller.set([position.value(1.0)]);
      expect(controller.velocity(position), lessThan(0));

      // Explicit positive velocity should win and cause overshoot past 1.0.
      controller.animate(
        [position.to(1.0, motion: spring, withVelocity: 100.0)],
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(controller.value(position), greaterThan(1.0));

      controller.stop(canceled: true);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Integration
  // ─────────────────────────────────────────────────────────────────────────

  group('TrackController velocity', () {
    late TrackController controller;
    final position = Track<double>(MotionConverter.single, initial: 0.0);
    final scale = Track<double>(MotionConverter.single, initial: 1.0);

    tearDown(() {
      controller.dispose();
    });

    testWidgets('set followed by animate carries velocity over',
        (tester) async {
      controller = TrackController(vsync: tester);
      const spring = Motion.smoothSpring(duration: Duration(milliseconds: 500));

      controller.set(
        [position.value(5.0)],
        withVelocity: [position.velocity(200.0)],
      );

      controller.animate([position.to(5.0, motion: spring)]);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      // Spring at target with high velocity => overshoot.
      expect(controller.value(position), greaterThan(5.0));

      controller.stop(canceled: true);
    });

    testWidgets('stop resets velocity to zero', (tester) async {
      controller = TrackController(vsync: tester);

      controller.set(
        [position.value(5.0)],
        withVelocity: [position.velocity(200.0)],
      );
      expect(controller.velocity(position), equals(200.0));

      controller.stop();
      expect(controller.velocity(position), equals(0.0));
    });

    testWidgets('set on one track leaves other tracks untouched',
        (tester) async {
      controller = TrackController(vsync: tester);

      controller.set(
        [position.value(5.0)],
        withVelocity: [position.velocity(100.0)],
      );

      expect(controller.value(position), equals(5.0));
      expect(controller.velocity(position), equals(100.0));

      // Scale should still be at its initial value with zero velocity.
      expect(controller.value(scale), equals(1.0));
      expect(controller.velocity(scale), equals(0.0));
    });

    testWidgets('per-animation from is applied before playing', (tester) async {
      controller = TrackController(vsync: tester);
      const linear = Motion.linear(Duration(milliseconds: 100));

      controller.play(
        TrackTimeline(
          [position.to(10.0, motion: linear, from: 5.0)],
        ),
      );

      await tester.pump();
      expect(controller.value(position), equals(5.0));

      await tester.pumpAndSettle();
      expect(controller.value(position), closeTo(10.0, error));
    });
  });

  testWidgets('asserts when a value changes its number of dimensions',
      (tester) async {
    final values = Track<List<double>>(
      MotionConverter.custom(
        normalize: (value) => value,
        denormalize: (values) => values,
      ),
      initial: const [0, 0, 0],
    );
    final controller = TrackController(vsync: tester);
    addTearDown(controller.dispose);
    final three = values.value(const [1, 2, 3]);
    final one = values.value(const [5]);

    controller.set([three]);
    expect(controller.value(values), [1, 2, 3]);
    expect(() => controller.set([one]), throwsAssertionError);
  });

  group('tracked velocity decays when the value holds still', () {
    testWidgets('before it is read', (tester) async {
      final controller = SingleMotionController(
        motion: const CupertinoMotion(),
        vsync: tester,
      );
      addTearDown(controller.dispose);
      for (var i = 0; i < 10; i++) {
        controller.value = i * 10.0;
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pump(const Duration(seconds: 2));

      expect(controller.velocity, 0);
    });

    testWidgets('after it was read while moving', (tester) async {
      final controller = SingleMotionController(
        motion: const CupertinoMotion(),
        vsync: tester,
      );
      addTearDown(controller.dispose);
      for (var i = 0; i < 10; i++) {
        controller.value = i * 10.0;
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(controller.velocity, greaterThan(0));
      await tester.pump(const Duration(seconds: 2));

      // Releasing now starts from rest, without a fling.
      controller.animateTo(90);
      expect(controller.velocity, 0);
      await tester.pumpAndSettle();
    });
  });

  testWidgets('a custom velocity tracker receives every sample',
      (tester) async {
    final position = Track<double>(MotionConverter.single, initial: 0.0);
    final samples = <Object?>[];
    final controller = TrackController(
      vsync: tester,
      velocityTracking: VelocityTracking.on(
        velocityTrackerBuilder: <T>(converter) =>
            _RecordingTracker<T>(converter, samples),
      ),
    );
    addTearDown(controller.dispose);

    controller
      ..set([position.value(1)])
      ..set([position.value(2)]);

    expect(samples, [1.0, 2.0]);
  });

  testWidgets('custom velocity trackers take the default path',
      (tester) async {
    final position = Track<double>(MotionConverter.single, initial: 0.0);
    int clockReads(VelocityTracking tracking) {
      final controller = TrackController(
        vsync: tester,
        velocityTracking: tracking,
      );
      var reads = 0;
      final start = DateTime.utc(2026);
      withClock(Clock(() => start.add(Duration(milliseconds: 16 * reads++))),
          () {
        controller
          ..set([position.value(1)])
          ..set([position.value(2)]);
      });
      controller.dispose();
      return reads;
    }

    expect(clockReads(const VelocityTracking.on()), 2);
    expect(
      clockReads(
        VelocityTracking.on(
          velocityTrackerBuilder: <T>(converter) =>
              MotionVelocityTracker<T>(converter),
        ),
      ),
      2,
    );
    expect(
      clockReads(
        VelocityTracking.on(
          velocityTrackerBuilder: <T>(converter) =>
              _RecordingTracker<T>(converter, []),
        ),
      ),
      2,
    );
  });

  testWidgets('a finished curve rests, so the next motion starts from rest',
      (tester) async {
    final position = Track<double>(MotionConverter.single, initial: 0.0);
    final controller = TrackController(vsync: tester);
    addTearDown(controller.dispose);
    final motionController = SingleMotionController(
      motion: const Motion.curved(Duration(milliseconds: 300), Curves.easeIn),
      vsync: tester,
    );
    addTearDown(motionController.dispose);

    controller.animate([
      position.to(1, motion: const Motion.linear(Duration(milliseconds: 300))),
    ]);
    motionController.animateTo(1);
    await tester.pumpAndSettle();
    expect(controller.velocity(position), 0);
    expect(motionController.velocity, 0);

    controller.animate([position.to(1, motion: const Motion.smoothSpring())]);
    motionController
      ..motion = const Motion.smoothSpring()
      ..animateTo(1);
    await tester.pump();
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(controller.value(position), 1);
      expect(motionController.value, 1);
    }
  });

  testWidgets('a spring taking over a curve starts with its velocity',
      (tester) async {
    final position = Track<double>(MotionConverter.single, initial: 0.0);
    final controller = TrackController(vsync: tester);
    addTearDown(controller.dispose);

    controller.animate([
      position.to(10, motion: const Motion.linear(Duration(seconds: 1))),
    ]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(controller.velocity(position), closeTo(10, 1e-6));

    controller.animate([position.to(10, motion: const Motion.smoothSpring())]);
    expect(controller.velocity(position), closeTo(10, 1e-6));
    controller.stop(canceled: true);
  });
}

class _RecordingTracker<T> extends MotionVelocityTracker<T> {
  _RecordingTracker(super.converter, this.samples);

  final List<Object?> samples;

  @override
  void addPosition(Duration time, T value) {
    samples.add(value);
    super.addPosition(time, value);
  }
}
