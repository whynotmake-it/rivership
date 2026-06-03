// ignore_for_file: cascade_invocations, unawaited_futures

import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

import '../util.dart';

void main() {
  group('TrackController.set', () {
    late TrackController controller;
    final position = Track<double>(MotionConverter.single, zero: 0.0);

    tearDown(() {
      controller.dispose();
    });

    testWidgets('A1: set updates track values immediately', (tester) async {
      controller = TrackController(vsync: tester);

      controller.set([position.value(5.0)]);

      expect(controller.value(position), equals(5.0));
    });

    testWidgets('A2: set does not start the ticker', (tester) async {
      controller = TrackController(vsync: tester);

      controller.set([position.value(5.0)]);

      expect(controller.isAnimating, isFalse);
    });

    testWidgets('A3: set with explicit velocity stores that velocity',
        (tester) async {
      controller = TrackController(vsync: tester);

      controller.set(
        [position.value(5.0)],
        withVelocity: [position.velocity(100.0)],
      );

      expect(controller.value(position), equals(5.0));
      expect(controller.velocity(position), equals(100.0));
    });

    testWidgets(
        'A4: set without explicit velocity auto-tracks via position samples',
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

    testWidgets('A5: play after set uses tracked velocity', (tester) async {
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

    testWidgets(
        'A6: VelocityTracking.off disables auto-tracking but allows explicit',
        (tester) async {
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
  // B. withVelocity: parameter
  // ─────────────────────────────────────────────────────────────────────────

  group('withVelocity: parameter', () {
    late TrackController controller;
    final position = Track<double>(MotionConverter.single, zero: 0.0);

    tearDown(() {
      controller.dispose();
    });

    testWidgets('B7: TrackValue velocity is used as initial playback velocity',
        (tester) async {
      controller = TrackController(vsync: tester);
      const spring = Motion.smoothSpring(duration: Duration(milliseconds: 500));

      // Start from 2.0 with positive velocity — should overshoot target.
      controller.play(
        TrackTimeline(
          [position.to(2.0, motion: spring)],
          from: [position.value(2.0)],
          withVelocity: [position.velocity(100.0)],
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      // Spring starts at target with positive velocity => overshoots.
      expect(controller.value(position), greaterThan(2.0));

      controller.stop(canceled: true);
    });

    testWidgets('B8: TrackValue without velocity uses zero initial velocity',
        (tester) async {
      controller = TrackController(vsync: tester);
      const spring = Motion.smoothSpring(duration: Duration(milliseconds: 500));

      // Start at the target with no velocity — should settle immediately
      // without overshooting.
      controller.play(
        TrackTimeline(
          [position.to(1.0, motion: spring)],
          from: [position.value(1.0)],
        ),
      );

      await tester.pump();
      // At target with zero velocity: spring should not overshoot.
      expect(controller.value(position), closeTo(1.0, 0.01));

      await tester.pumpAndSettle();
      expect(controller.value(position), closeTo(1.0, error));
    });

    testWidgets('B9: from: velocity overrides tracked velocity',
        (tester) async {
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

      // Play with explicit positive velocity in from: — should override.
      controller.play(
        TrackTimeline(
          [position.to(1.0, motion: spring)],
          from: [position.value(1.0)],
          withVelocity: [position.velocity(100.0)],
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      // Positive velocity should cause overshoot past 1.0, not undershoot.
      expect(controller.value(position), greaterThan(1.0));

      controller.stop(canceled: true);
    });
  });

  group('withVelocity on animate', () {
    late TrackController controller;
    final position = Track<double>(MotionConverter.single, origin: 0.0);

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
        [position.to(2.0, motion: spring)],
        withVelocity: [position.velocity(150.0)],
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
        [position.to(1.0, motion: spring)],
        withVelocity: [position.velocity(100.0)],
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(controller.value(position), greaterThan(1.0));

      controller.stop(canceled: true);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // C. Integration
  // ─────────────────────────────────────────────────────────────────────────

  group('Integration', () {
    late TrackController controller;
    final position = Track<double>(MotionConverter.single, zero: 0.0);
    final scale = Track<double>(MotionConverter.single, zero: 1.0);

    tearDown(() {
      controller.dispose();
    });

    testWidgets('C10: set followed by animate carries velocity',
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

    testWidgets('C11: stop zeros velocity', (tester) async {
      controller = TrackController(vsync: tester);

      controller.set(
        [position.value(5.0)],
        withVelocity: [position.velocity(200.0)],
      );
      expect(controller.velocity(position), equals(200.0));

      controller.stop();
      expect(controller.velocity(position), equals(0.0));
    });

    testWidgets('C12: set on one track does not affect another',
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

    testWidgets('C13: Track.value() works in TrackTimeline from:',
        (tester) async {
      controller = TrackController(vsync: tester);
      const linear = Motion.linear(Duration(milliseconds: 100));

      controller.play(
        TrackTimeline(
          [position.to(10.0, motion: linear)],
          from: [position.value(5.0)],
        ),
      );

      await tester.pump();
      expect(controller.value(position), equals(5.0));

      await tester.pumpAndSettle();
      expect(controller.value(position), closeTo(10.0, error));
    });
  });
}
