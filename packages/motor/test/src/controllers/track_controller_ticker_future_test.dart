// ignore_for_file: cascade_invocations, unawaited_futures

import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

void main() {
  const linear100 = Motion.linear(Duration(milliseconds: 100));

  group('TrackController TickerFuture', () {
    late TrackController controller;
    final opacity = Track<double>(MotionConverter.single, origin: 0.0);
    final scale = Track<double>(MotionConverter.single, origin: 0.0);

    tearDown(() {
      controller.dispose();
    });

    testWidgets('play returns a TickerFuture that completes on settle',
        (tester) async {
      controller = TrackController(vsync: tester);

      final future = controller.play(
        TrackTimeline([opacity.to(1, motion: linear100)]),
      );
      expect(future, isA<TickerFuture>());

      var completed = false;
      future.then((_) => completed = true);

      await tester.pump();
      expect(completed, isFalse, reason: 'should not complete while animating');

      await tester.pumpAndSettle();
      expect(completed, isTrue, reason: 'should complete once settled');
    });

    testWidgets('animate returns a TickerFuture that completes on settle',
        (tester) async {
      controller = TrackController(vsync: tester);

      final future = controller.animate([opacity.to(1, motion: linear100)]);
      expect(future, isA<TickerFuture>());

      var completed = false;
      future.then((_) => completed = true);

      await tester.pump();
      expect(completed, isFalse);

      await tester.pumpAndSettle();
      expect(completed, isTrue);
    });

    testWidgets('animate with an empty list returns an already-complete future',
        (tester) async {
      controller = TrackController(vsync: tester);

      final future = controller.animate([]);

      expect(controller.isAnimating, isFalse);
      // Would hang / time out the test if the future never completed.
      await future;
    });

    testWidgets('stop(canceled: true) cancels the in-flight future',
        (tester) async {
      controller = TrackController(vsync: tester);

      final future = controller.play(
        TrackTimeline([opacity.to(1, motion: linear100)]),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      controller.stop(canceled: true);
      await tester.pump();

      await expectLater(future.orCancel, throwsA(isA<TickerCanceled>()));
    });

    testWidgets(
        'returns one whole-controller future shared across in-flight calls',
        (tester) async {
      controller = TrackController(vsync: tester);

      final first = controller.play(
        TrackTimeline([opacity.to(1, motion: linear100)]),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));

      // Start a second, longer track while the first is still running. The
      // in-flight future is shared, reflecting the whole controller settling.
      final second = controller.animate([
        scale([
          const Step.to(1, motion: linear100),
          const Step.to(2, motion: linear100),
        ]),
      ]);
      expect(identical(first, second), isTrue);

      var completed = false;
      first.then((_) => completed = true);

      // The opacity track finishes ~100ms in, but the controller-wide future
      // must wait for the longer scale track to settle too.
      await tester.pump(const Duration(milliseconds: 120));
      expect(completed, isFalse);
      expect(controller.isAnimating, isTrue);

      await tester.pumpAndSettle();
      expect(completed, isTrue);
    });

    testWidgets(
        'animate future outlives its own track while another track still runs',
        (tester) async {
      controller = TrackController(vsync: tester);

      // Start a long-running track first.
      controller.play(
        TrackTimeline([
          opacity([
            const Step.to(1, motion: linear100),
            const Step.to(0, motion: linear100),
            const Step.to(1, motion: linear100),
          ]),
        ]),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));

      // Animate a short track while the long one is still running.
      final shortFuture =
          controller.animate([scale.to(1, motion: linear100)]);

      var completed = false;
      shortFuture.then((_) => completed = true);

      // Pump well past the short track's own ~100ms duration. Its future must
      // not complete yet because the long opacity track is still animating.
      await tester.pump(const Duration(milliseconds: 150));
      expect(
        controller.value(scale),
        closeTo(1, 1e-4),
        reason: 'short track should have finished its own animation',
      );
      expect(controller.isAnimating, isTrue);
      expect(
        completed,
        isFalse,
        reason: 'whole-controller future waits for the long track',
      );

      await tester.pumpAndSettle();
      expect(completed, isTrue);
    });

    testWidgets('looping playback never completes the future', (tester) async {
      controller = TrackController(vsync: tester);

      final future = controller.play(
        TrackTimeline(
          [opacity.to(1, motion: linear100)],
          loop: LoopMode.loop,
        ),
      );

      var completed = false;
      future.then((_) => completed = true);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(completed, isFalse);
      expect(controller.isAnimating, isTrue);

      controller.stop(canceled: true);
      await tester.pump();
    });
  });

  group('PhaseTrackController TickerFuture', () {
    late PhaseTrackController<String> controller;

    tearDown(() {
      controller.dispose();
    });

    testWidgets('playPhases completes when a non-looping sequence settles',
        (tester) async {
      controller = PhaseTrackController<String>(vsync: tester);
      final size = Track<double>(MotionConverter.single, origin: 0);

      final future = controller.playPhases(
        TrackPhaseTimeline({
          'a': [size.to(1, motion: linear100)],
          'b': [size.to(2, motion: linear100)],
        }),
      );
      expect(future, isA<TickerFuture>());

      var completed = false;
      future.then((_) => completed = true);

      await tester.pump();
      expect(completed, isFalse);

      await tester.pumpAndSettle();
      expect(completed, isTrue);
      expect(controller.value(size), closeTo(2, 1e-4));
    });

    testWidgets('goToPhase returns a TickerFuture that completes on settle',
        (tester) async {
      controller = PhaseTrackController<String>(vsync: tester);
      final size = Track<double>(MotionConverter.single, origin: 0);

      final timeline = TrackPhaseTimeline({
        'a': [size.to(1, motion: linear100)],
        'b': [size.to(2, motion: linear100)],
      });
      controller.setTimeline(timeline);

      final future = controller.goToPhase('b');
      expect(future, isA<TickerFuture>());

      var completed = false;
      future.then((_) => completed = true);

      await tester.pump();
      expect(completed, isFalse);

      await tester.pumpAndSettle();
      expect(completed, isTrue);
      expect(controller.value(size), closeTo(2, 1e-4));
    });
  });
}
