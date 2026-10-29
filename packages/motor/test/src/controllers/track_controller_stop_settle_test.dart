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
      ('the track default spring', springTrack.to(1), springTrack),
      (
        'the spring of the running step',
        noDefault.to(1, motion: spring),
        noDefault
      ),
      (
        'the track default motion for a free step',
        springTrack.free(const FrictionMotion(), withVelocity: 5),
        null,
      ),
      (
        'the running motion of each dimension',
        offset.to(
          const Offset(1, 1),
          motionPerDimension: const [linear100, spring],
        ),
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
      ('a linear track', linearTrack.to(1)),
      ('a curve step on a spring track', springTrack.to(1, motion: linear100)),
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

      controller.animate([springTrack.to(1)]);
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
        'a partial graceful stop settles one track, cancels its call, and '
        'leaves the other running', (tester) async {
      controller = TrackController(vsync: tester);

      final call = controller.animate([springTrack.to(1)]);
      controller.animate([linearTrack.to(1)]);
      var callDone = false;
      var callCanceled = false;
      call.then((_) => callDone = true);
      call.orCancel.catchError((Object error) {
        callCanceled = error is TickerCanceled;
      });
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
      expect(callDone, isFalse);
      expect(callCanceled, isTrue);
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
        opacity.to(1, motion: motion),
        scale.to(2, motion: motion),
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
      controller.animate([opacity.to(0, motion: motion)]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(controller.value(opacity), lessThan(1));
      controller.stop(tracks: [opacity], canceled: true);
      await tester.pump();
      expect(controller.isAnimating, isFalse);
    });
  });
}
