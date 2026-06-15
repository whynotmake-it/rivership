// ignore_for_file: cascade_invocations, unawaited_futures

import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

void main() {
  const spring = CupertinoMotion.smooth();
  const linear100 = Motion.linear(Duration(milliseconds: 100));

  group('TrackController.stop settle', () {
    late TrackController controller;

    final springTrack =
        Track<double>(MotionConverter.single, origin: 0, motion: spring);
    final linearTrack =
        Track<double>(MotionConverter.single, origin: 0, motion: linear100);

    tearDown(() {
      controller.dispose();
    });

    testWidgets('stop() settles a spring track instead of freezing',
        (tester) async {
      controller = TrackController(vsync: tester);

      controller.animate([springTrack.to(1)]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));

      final valueAtStop = controller.value(springTrack);
      expect(valueAtStop, lessThan(1));
      expect(controller.isAnimating, isTrue);

      controller.stop();
      await tester.pump();

      // The spring keeps animating after a graceful stop.
      expect(controller.isAnimating, isTrue);

      await tester.pumpAndSettle();
      expect(controller.isAnimating, isFalse);

      // It settles back at the value where it was stopped (carrying its
      // momentum), not the original target of 1.
      expect(controller.value(springTrack), closeTo(valueAtStop, 1e-2));
      expect(controller.value(springTrack), lessThan(1));
    });

    testWidgets('stop(canceled: true) freezes the track immediately',
        (tester) async {
      controller = TrackController(vsync: tester);

      controller.animate([springTrack.to(1)]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));

      final valueAtStop = controller.value(springTrack);

      controller.stop(canceled: true);
      await tester.pump();

      expect(controller.isAnimating, isFalse);
      expect(controller.value(springTrack), closeTo(valueAtStop, 1e-9));
      expect(controller.velocity(springTrack), 0);
    });

    testWidgets('stop() hard-stops a non-settling (linear) track',
        (tester) async {
      controller = TrackController(vsync: tester);

      controller.animate([linearTrack.to(1)]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      expect(controller.isAnimating, isTrue);

      // Linear motion does not need to settle, so a graceful stop still halts
      // immediately.
      controller.stop();
      await tester.pump();
      expect(controller.isAnimating, isFalse);
    });

    testWidgets('stop() hard-stops when the track has no default motion',
        (tester) async {
      controller = TrackController(vsync: tester);

      final noDefault = Track<double>(MotionConverter.single, origin: 0);
      // The spring lives on the step, not the track; settle uses the track
      // default, so there is nothing to settle with.
      controller.animate([noDefault.to(1, motion: spring)]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      expect(controller.isAnimating, isTrue);

      controller.stop();
      await tester.pump();
      expect(controller.isAnimating, isFalse);
    });

    testWidgets('stop() returns a future that completes when settling finishes',
        (tester) async {
      controller = TrackController(vsync: tester);

      controller.animate([springTrack.to(1)]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));

      final future = controller.stop();
      expect(future, isA<TickerFuture>());

      var completed = false;
      future.then((_) => completed = true);

      await tester.pump();
      expect(completed, isFalse);

      await tester.pumpAndSettle();
      expect(completed, isTrue);
    });

    testWidgets('stop(canceled: true) returns an already-complete future',
        (tester) async {
      controller = TrackController(vsync: tester);

      controller.animate([springTrack.to(1)]);
      await tester.pump();

      final future = controller.stop(canceled: true);
      await future;
    });
  });
}
