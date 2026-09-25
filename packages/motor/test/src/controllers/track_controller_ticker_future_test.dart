// ignore_for_file: cascade_invocations, unawaited_futures

import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

void main() {
  const linear100 = Motion.linear(Duration(milliseconds: 100));

  group('TrackController TickerFuture', () {
    late TrackController controller;
    final opacity = Track<double>(MotionConverter.single, initial: 0.0);
    final scale = Track<double>(MotionConverter.single, initial: 0.0);

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

    testWidgets('each call gets its own future for its own tracks',
        (tester) async {
      controller = TrackController(vsync: tester);

      final first = controller.play(
        TrackTimeline([opacity.to(1, motion: linear100)]),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));

      final second = controller.animate([
        scale([
          const TrackStep.to(1, motion: linear100),
          const TrackStep.to(2, motion: linear100),
        ]),
      ]);
      expect(identical(first, second), isFalse);

      var firstDone = false;
      var secondDone = false;
      first.then((_) => firstDone = true);
      second.then((_) => secondDone = true);

      // Opacity finishes ~100ms in, while scale keeps running.
      await tester.pump(const Duration(milliseconds: 80));
      await tester.pump();
      expect(firstDone, isTrue);
      expect(secondDone, isFalse);
      expect(controller.isAnimating, isTrue);

      await tester.pumpAndSettle();
      expect(secondDone, isTrue);
    });

    testWidgets('a call completes when its tracks finish, not the others',
        (tester) async {
      controller = TrackController(vsync: tester);

      final longFuture = controller.play(
        TrackTimeline([
          opacity([
            const TrackStep.to(1, motion: linear100),
            const TrackStep.to(0, motion: linear100),
            const TrackStep.to(1, motion: linear100),
          ]),
        ]),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));

      final shortFuture = controller.animate([scale.to(1, motion: linear100)]);

      var shortDone = false;
      var longDone = false;
      shortFuture.then((_) => shortDone = true);
      longFuture.then((_) => longDone = true);

      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      expect(controller.value(scale), closeTo(1, 1e-4));
      expect(controller.isAnimating, isTrue);
      expect(shortDone, isTrue);
      expect(longDone, isFalse);

      await tester.pumpAndSettle();
      expect(longDone, isTrue);
    });

    testWidgets('restarting a track cancels the earlier call', (tester) async {
      controller = TrackController(vsync: tester);

      final first = controller.animate([
        opacity.to(1, motion: linear100),
        scale.to(1, motion: linear100),
      ]);
      var firstDone = false;
      var firstCanceled = false;
      first.then((_) => firstDone = true);
      first.orCancel.catchError((Object error) {
        firstCanceled = error is TickerCanceled;
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));

      final second = controller.animate([scale.to(2, motion: linear100)]);
      var secondDone = false;
      second.then((_) => secondDone = true);

      await tester.pumpAndSettle();
      expect(firstDone, isFalse);
      expect(firstCanceled, isTrue);
      expect(secondDone, isTrue);
    });

    testWidgets('a graceful stop completes earlier calls once at rest',
        (tester) async {
      controller = TrackController(vsync: tester);
      const spring = Motion.smoothSpring();

      final future = controller.animate([opacity.to(1, motion: spring)]);
      var done = false;
      var canceled = false;
      future.then((_) => done = true);
      future.orCancel.catchError((Object error) {
        canceled = true;
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final stopFuture = controller.stop(tracks: [opacity]);
      var stopDone = false;
      stopFuture.then((_) => stopDone = true);

      await tester.pump(const Duration(milliseconds: 16));
      expect(controller.isAnimating, isTrue, reason: 'the spring settles');
      expect(done, isFalse);

      await tester.pumpAndSettle();
      expect(done, isTrue);
      expect(stopDone, isTrue);
      expect(canceled, isFalse);
    });

    testWidgets('whenCompleteOrCancel runs for either outcome', (tester) async {
      controller = TrackController(vsync: tester);
      var calls = 0;

      final completing = controller.animate([
        opacity.to(1, motion: linear100),
      ]);
      completing.whenCompleteOrCancel(() => calls++);
      await tester.pumpAndSettle();
      expect(calls, 1);

      final canceling = controller.animate([
        opacity.to(0, motion: linear100),
      ]);
      canceling.whenCompleteOrCancel(() => calls++);
      await tester.pump();
      controller.stop(canceled: true);
      await tester.pump();
      expect(calls, 2);
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
      final size = Track<double>(MotionConverter.single, initial: 0);

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
      final size = Track<double>(MotionConverter.single, initial: 0);

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

  testWidgets('dispose cancels the pending future', (tester) async {
    final track = Track<double>(MotionConverter.single, initial: 0);
    final controller = TrackController(vsync: tester);
    var completed = false;
    var canceled = false;
    final future = controller.animate([track.to(1, motion: linear100)]);
    future.then((_) => completed = true);
    future.orCancel.catchError((Object error) {
      canceled = error is TickerCanceled;
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));

    controller.dispose();
    await tester.pump();

    expect(completed, isFalse);
    expect(canceled, isTrue);
  });
}
