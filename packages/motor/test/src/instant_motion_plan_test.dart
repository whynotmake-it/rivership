// ignore_for_file: unawaited_futures

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

const _instant = Motion.instant();
const _linear100 = Motion.linear(Duration(milliseconds: 100));

void main() {
  late Track<double> x;

  setUp(() => x = Track<double>(MotionConverter.single, initial: 0));

  group('Motion.instant as a step motion', () {
    testWidgets('jumps at the start of each step in a plan', (tester) async {
      final controller = TrackController(vsync: tester);
      addTearDown(controller.dispose);
      final statuses = <AnimationStatus>[];
      controller.addStatusListener(statuses.add);

      var settled = false;
      controller.animate([
        x([
          const TrackStep.to(1, motion: _instant),
          const TrackStep.hold(Duration(milliseconds: 100)),
          const TrackStep.to(2, motion: _instant),
        ]),
      ]).then((_) => settled = true);

      expect(controller.value(x), 1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(controller.value(x), 1);
      await tester.pump(const Duration(milliseconds: 60));
      expect(controller.value(x), 2);
      await tester.pumpAndSettle();

      expect(settled, isTrue);
      expect(statuses, [AnimationStatus.forward, AnimationStatus.completed]);
    });

    testWidgets('shows its target on the first build of a TrackBuilder',
        (tester) async {
      final built = <double>[];
      await tester.pumpWidget(
        TrackBuilder(
          animations: [
            x([const TrackStep.to(1, motion: _instant)]),
          ],
          builder: (context, value, child) {
            built.add(value(x));
            return const SizedBox();
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(built, everyElement(1));
    });

    testWidgets('ends at once and hands over with until: .ended',
        (tester) async {
      final controller = TrackController(vsync: tester);
      addTearDown(controller.dispose);

      var ended = false;
      final future = controller.animate([
        x([
          const TrackStep.to(1, motion: _instant, until: WaitUntil.ended),
          const TrackStep.to(2, motion: _linear100),
        ]),
      ]);
      future.ended.then((_) => ended = true);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(controller.value(x), closeTo(1.5, 1e-9));
      expect(ended, isFalse);
      await tester.pumpAndSettle();
      expect(ended, isTrue);
      expect(controller.value(x), 2);
    });

    testWidgets('completes its future on the first frame that advances time',
        (tester) async {
      final controller = TrackController(vsync: tester);
      addTearDown(controller.dispose);

      var ended = false;
      var settled = false;
      final future = controller.animate([
        x([const TrackStep.to(1, motion: _instant)]),
      ]);
      future.ended.then((_) => ended = true);
      future.then((_) => settled = true);

      expect(controller.value(x), 1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(ended, isTrue);
      expect(settled, isTrue);
      expect(controller.isAnimating, isFalse);
    });

    for (final loop in [LoopMode.loop, LoopMode.pingPong, LoopMode.seamless]) {
      testWidgets('alternates in a $loop loop with holds', (tester) async {
        final controller = TrackController(vsync: tester);
        addTearDown(controller.dispose);
        controller.animate(
          [
            x([
              const TrackStep.to(1, motion: _instant),
              const TrackStep.hold(Duration(milliseconds: 100)),
              const TrackStep.to(0, motion: _instant),
              const TrackStep.hold(Duration(milliseconds: 100)),
            ]),
          ],
          loop: loop,
        );

        final seen = <double>{};
        await tester.pump();
        for (var i = 0; i < 40; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          seen.add(controller.value(x));
        }

        expect(seen, {0.0, 1.0});
        expect(controller.isAnimating, isTrue);
        controller.stop(canceled: true);
      });
    }
  });
}
