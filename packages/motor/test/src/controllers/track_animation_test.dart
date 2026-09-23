// ignore_for_file: cascade_invocations, unawaited_futures

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

import '../util.dart';

void main() {
  group('TrackController.animationOf', () {
    const linear100 = Motion.linear(Duration(milliseconds: 100));
    late TrackController controller;
    final opacity = Track<double>(MotionConverter.single, initial: 0);
    final scale = Track<double>(MotionConverter.single, initial: 1);

    tearDown(() {
      controller.dispose();
    });

    testWidgets('composes with tweens and curves', (tester) async {
      controller = TrackController(vsync: tester);
      final animation = controller.animationOf(opacity);
      final tweened = Tween<double>(begin: 10, end: 20).animate(animation);
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeIn);

      controller.animate([opacity.to(1, motion: linear100)]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(animation.value, closeTo(0.5, error));
      expect(tweened.value, closeTo(15, error));
      expect(curved.value, closeTo(Curves.easeIn.transform(0.5), error));
      controller.stop(canceled: true);
    });

    testWidgets('drives a FadeTransition', (tester) async {
      controller = TrackController(vsync: tester);
      await tester.pumpWidget(
        FadeTransition(
          opacity: controller.animationOf(opacity),
          child: const SizedBox(),
        ),
      );

      controller.animate([opacity.to(1, motion: linear100)]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));

      final fade = tester.widget<FadeTransition>(find.byType(FadeTransition));
      expect(fade.opacity.value, closeTo(0.3, error));
      controller.stop(canceled: true);
    });

    testWidgets('returns the same animation for the same track',
        (tester) async {
      controller = TrackController(vsync: tester);

      expect(
        identical(
          controller.animationOf(opacity),
          controller.animationOf(opacity),
        ),
        isTrue,
      );
      expect(
        identical(
          controller.animationOf(opacity),
          controller.animationOf(scale),
        ),
        isFalse,
      );
    });

    testWidgets('stays quiet while its track is idle', (tester) async {
      controller = TrackController(vsync: tester);
      var notifications = 0;
      controller.animationOf(opacity).addListener(() => notifications++);

      controller.animate([scale.to(2, motion: linear100)]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(notifications, 0);

      controller.animate([opacity.to(1, motion: linear100)]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(notifications, greaterThan(0));
      controller.stop(canceled: true);
    });

    testWidgets('reports its own track status', (tester) async {
      controller = TrackController(vsync: tester);
      final animation = controller.animationOf(opacity);
      final statuses = <AnimationStatus>[];
      animation.addStatusListener(statuses.add);
      expect(animation.status, AnimationStatus.dismissed);

      controller.animate([opacity.to(1, motion: linear100)]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(animation.status, AnimationStatus.forward);

      controller.pause();
      expect(animation.status, AnimationStatus.forward);
      controller.resume();

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(animation.status, AnimationStatus.completed);

      controller.animate([opacity.to(0, motion: linear100)]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(animation.status, AnimationStatus.reverse);

      await tester.pump(const Duration(milliseconds: 100));
      expect(statuses, [
        AnimationStatus.forward,
        AnimationStatus.completed,
        AnimationStatus.reverse,
        AnimationStatus.completed,
      ]);
    });

    testWidgets('stops listening to the controller without listeners',
        (tester) async {
      controller = TrackController(vsync: tester);
      var notifications = 0;
      void listener() => notifications++;
      final animation = controller.animationOf(opacity)..addListener(listener);
      animation.removeListener(listener);

      controller.animate([opacity.to(1, motion: linear100)]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(notifications, 0);
      expect(animation.value, closeTo(0.5, error));
      controller.stop(canceled: true);
    });
  });
}
