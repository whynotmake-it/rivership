// ignore_for_file: cascade_invocations, unawaited_futures

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

import '../util.dart';

void main() {
  const spring = CupertinoMotion.smooth();
  const linear100 = Motion.linear(Duration(milliseconds: 100));

  group('TrackController.stop', () {
    late TrackController controller;

    final springTrack =
        Track<double>(MotionConverter.single, initial: 0, motion: spring);
    final linearTrack =
        Track<double>(MotionConverter.single, initial: 0, motion: linear100);
    final noDefault = Track<double>(MotionConverter.single, initial: 0);
    final offset = Track<Offset>(MotionConverter.offset, initial: Offset.zero);

    tearDown(() {
      controller.dispose();
    });

    for (final (name, animation, settlesWhereStopped) in [
      (
        'the track default spring',
        springTrack([const TrackStep.to(1)]),
        springTrack
      ),
      (
        'the spring of the running step',
        noDefault([const TrackStep.to(1, motion: spring)]),
        noDefault
      ),
      (
        'the track default motion for a free step',
        springTrack(
          [const TrackStep.free(motion: FrictionMotion())],
          withVelocity: 5,
        ),
        null,
      ),
      (
        'the running motion of each dimension',
        offset([
          const TrackStep.to(
            Offset(1, 1),
            motionPerDimension: [linear100, spring],
          ),
        ]),
        null,
      ),
    ]) {
      testWidgets('a graceful stop settles with $name instead of freezing',
          (tester) async {
        controller = TrackController(vsync: tester);

        controller.animate([animation]);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 30));
        final valueAtStop = settlesWhereStopped == null
            ? null
            : controller.value(settlesWhereStopped);
        expect(controller.isAnimating, isTrue);

        controller.stop();
        await tester.pump();
        expect(controller.isAnimating, isTrue);

        await tester.pumpAndSettle();
        expect(controller.isAnimating, isFalse);
        if (settlesWhereStopped != null) {
          // It settles back at the value where it was stopped (carrying its
          // momentum), not the original target of 1.
          expect(valueAtStop, lessThan(1));
          expect(
            controller.value(settlesWhereStopped),
            closeTo(valueAtStop!, 1e-2),
          );
          expect(controller.value(settlesWhereStopped), lessThan(1));
        }
      });
    }

    for (final (name, animation) in [
      ('a linear track', linearTrack([const TrackStep.to(1)])),
      (
        'a curve step on a spring track',
        springTrack([const TrackStep.to(1, motion: linear100)])
      ),
    ]) {
      testWidgets('a graceful stop halts $name at once', (tester) async {
        controller = TrackController(vsync: tester);

        controller.animate([animation]);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 30));
        expect(controller.isAnimating, isTrue);

        controller.stop();
        await tester.pump();
        expect(controller.isAnimating, isFalse);
      });
    }

    testWidgets(
        'a canceling stop freezes the track at once and returns a complete '
        'future', (tester) async {
      controller = TrackController(vsync: tester);

      controller.animate([
        springTrack([const TrackStep.to(1)]),
      ]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));

      final valueAtStop = controller.value(springTrack);

      // Would time out if the future waited for a frame.
      await controller.stop(canceled: true);
      await tester.pump();

      expect(controller.isAnimating, isFalse);
      expect(controller.value(springTrack), closeTo(valueAtStop, 1e-9));
      expect(controller.velocity(springTrack), 0);
    });

    testWidgets(
        'a partial graceful stop settles one track, completes its call once '
        'both rest, and leaves the other running', (tester) async {
      controller = TrackController(vsync: tester);

      final call = controller.animate([
        springTrack([const TrackStep.to(1)]),
      ]);
      controller.animate([
        linearTrack([const TrackStep.to(1)]),
      ]);
      var callDone = false;
      call.then((_) => callDone = true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));

      final springAtStop = controller.value(springTrack);
      final linearAtStop = controller.value(linearTrack);
      expect(springAtStop, lessThan(1));
      expect(linearAtStop, lessThan(1));

      final future = controller.stop(tracks: [springTrack]);
      var completed = false;
      future.then((_) => completed = true);

      // The stopped spring keeps moving (it settles, it does not freeze).
      await tester.pump(const Duration(milliseconds: 16));
      expect(controller.isAnimating, isTrue);
      expect(
        controller.value(springTrack),
        isNot(closeTo(springAtStop, 1e-6)),
        reason: 'a graceful stop lets the spring settle, not freeze',
      );
      // The linear track was not targeted and keeps going to its target.
      expect(controller.value(linearTrack), greaterThan(linearAtStop));
      expect(callDone, isFalse);

      await tester.pump();
      expect(completed, isFalse);

      await tester.pumpAndSettle();
      expect(completed, isTrue);
      expect(callDone, isTrue);
      expect(controller.isAnimating, isFalse);

      // The linear track finished its animation; the spring came to rest near
      // where it was stopped instead of its original target.
      expect(controller.value(linearTrack), closeTo(1, 1e-4));
      expect(controller.value(springTrack), closeTo(springAtStop, 1e-1));
      expect(controller.value(springTrack), lessThan(1));
    });

    testWidgets('a partial canceling stop freezes only the listed tracks',
        (tester) async {
      controller = TrackController(vsync: tester);
      final opacity = Track<double>(MotionConverter.single, initial: 0.0);
      final scale = Track<double>(MotionConverter.single, initial: 1.0);
      const motion = Motion.linear(Duration(milliseconds: 200));

      controller.animate([
        opacity([const TrackStep.to(1, motion: motion)]),
        scale([const TrackStep.to(2, motion: motion)]),
      ]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final scaleWhenStopped = controller.value(scale);
      controller.stop(tracks: [scale], canceled: true);

      // The controller is still animating opacity.
      expect(controller.isAnimating, isTrue);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Scale froze where it was stopped; opacity continued.
      expect(controller.value(scale), closeTo(scaleWhenStopped, error));
      expect(controller.value(opacity), greaterThan(0));

      await tester.pumpAndSettle();
      expect(controller.value(opacity), closeTo(1, error));
      expect(controller.value(scale), closeTo(scaleWhenStopped, error));

      // Stopping the only running track stops the controller.
      controller.animate([
        opacity([const TrackStep.to(0, motion: motion)]),
      ]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(controller.value(opacity), lessThan(1));
      controller.stop(tracks: [opacity], canceled: true);
      await tester.pump();
      expect(controller.isAnimating, isFalse);
    });
  });

  group('TrackController.stop futures', () {
    late TrackController controller;
    final track = Track<double>(MotionConverter.single, initial: 0);

    tearDown(() {
      controller.dispose();
    });

    for (final (name, motion) in [
      ('curve', linear100),
      ('spring', spring),
    ]) {
      testWidgets('a graceful stop of a running $name ends its future',
          (tester) async {
        controller = TrackController(vsync: tester);

        final future = controller.animate([
          track([TrackStep.to(1, motion: motion)]),
        ]);
        var ended = false;
        future.ended.then((_) => ended = true);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 30));
        expect(ended, isFalse);

        controller.stop();
        await tester.pump();

        expect(ended, isTrue);

        // A spring still settles after it ended.
        await tester.pumpAndSettle();
      });

      testWidgets('a canceling stop of a running $name cancels its future',
          (tester) async {
        controller = TrackController(vsync: tester);

        final future = controller.animate([
          track([TrackStep.to(1, motion: motion)]),
        ]);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 30));

        controller.stop(canceled: true);
        await tester.pump();

        await expectLater(future.orCancel, throwsA(isA<TickerCanceled>()));
      });
    }
  });

  group('calls that change no value', () {
    late TrackController controller;
    final linearTrack = Track<double>(
      MotionConverter.single,
      initial: 0,
      motion: const Motion.linear(Duration(milliseconds: 100)),
    );

    tearDown(() => controller.dispose());

    // A render object may stop its controller during layout, where a value
    // notification would mark it dirty mid-layout.
    for (final canceled in [true, false]) {
      testWidgets(
          'a stop with canceled: $canceled notifies no value listener and '
          'keeps the value', (tester) async {
        controller = TrackController(vsync: tester)
          ..animate([
            linearTrack([const TrackStep.to(1)]),
          ]);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        var notified = 0;
        final statuses = <AnimationStatus>[];
        controller
          ..addListener(() => notified++)
          ..addStatusListener(statuses.add);
        final value = controller.value(linearTrack);

        controller.stop(canceled: canceled);

        expect(notified, 0);
        expect(controller.value(linearTrack), value);
        expect(controller.isAnimating, isFalse);
        expect(statuses, isEmpty, reason: 'a stop keeps the direction');
      });
    }

    testWidgets('pause and resume notify no value listener', (tester) async {
      controller = TrackController(vsync: tester)
        ..animate([
          linearTrack([const TrackStep.to(1)]),
        ]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      var notified = 0;
      controller.addListener(() => notified++);

      controller.pause();
      expect(controller.isAnimating, isFalse);
      controller.resume();
      expect(controller.isAnimating, isTrue);

      expect(notified, 0);
      controller.stop(canceled: true);
    });

    testWidgets('stopping an idle controller notifies nothing', (tester) async {
      controller = TrackController(vsync: tester)..set([linearTrack.value(1)]);
      var notified = 0;
      controller
        ..addListener(() => notified++)
        ..addStatusListener((_) => notified++);

      controller.stop(canceled: true);
      controller.stop();

      expect(notified, 0);
    });

    testWidgets('a stop that releases a barrier notifies', (tester) async {
      final waiting = Track<double>(
        MotionConverter.single,
        initial: 0,
        motion: const Motion.linear(Duration(milliseconds: 100)),
      );
      const token = #meet;
      controller = TrackController(vsync: tester)
        ..animate([
          waiting([
            const TrackStep.to(1),
            const TrackStep.sync(token: token),
            const TrackStep.to(2),
          ]),
          linearTrack([
            const TrackStep.to(1, motion: Motion.linear(Duration(seconds: 1))),
            const TrackStep.sync(token: token),
          ]),
        ]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(controller.value(waiting), 1);
      var notified = 0;
      controller.addListener(() => notified++);

      controller.stop(tracks: [linearTrack], canceled: true);

      expect(notified, 1);
      await tester.pump(const Duration(milliseconds: 50));
      expect(controller.value(waiting), greaterThan(1));
      controller.stop(canceled: true);
    });

    testWidgets('MotionController.stop notifies no value listener',
        (tester) async {
      final motion = SingleMotionController(
        motion: const Motion.linear(Duration(milliseconds: 100)),
        vsync: tester,
      )..animateTo(1);
      controller = TrackController(vsync: tester);
      addTearDown(motion.dispose);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      var notified = 0;
      motion.addListener(() => notified++);

      motion.stop(canceled: true);

      expect(notified, 0);
      expect(motion.isAnimating, isFalse);
    });
  });
}
