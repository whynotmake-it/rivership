// ignore_for_file: cascade_invocations, unawaited_futures

import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

const _ms = Duration(milliseconds: 1);
const _spring = CupertinoMotion.smooth();
const _linear1s = Motion.linear(Duration(seconds: 1));

Duration _t(int milliseconds) => Duration(milliseconds: milliseconds);

void main() {
  final tracks = [
    for (var i = 0; i < 3; i++) Track<double>(MotionConverter.single),
  ];
  final solo = Track<double>(MotionConverter.single, initial: 0);

  late TrackController controller;
  Future<void> setUpController(WidgetTester tester) async {
    controller = TrackController(vsync: tester);
    addTearDown(controller.dispose);
  }

  group('redirect hands over', () {
    testWidgets(
        'a delayed redirect keeps moving during its delay, then heads '
        'back', (tester) async {
      await setUpController(tester);
      controller.set([for (final t in tracks) t.value(0)]);
      controller.animate([
        for (final t in tracks) t([const TrackStep.to(1, motion: _spring)]),
      ]);
      await tester.pump();
      await tester.pump(_t(100));

      final before = [for (final t in tracks) controller.value(t)];
      final velocity = controller.velocity(tracks.first);
      expect(velocity, greaterThan(0));

      controller.animate([
        for (final (i, t) in tracks.indexed)
          t([const TrackStep.to(0, motion: _spring)], delay: _ms * (i * 40)),
      ]);
      // Right after the redirect nothing stopped.
      await tester.pump(_ms);
      for (final (i, t) in tracks.indexed) {
        expect(controller.value(t), greaterThan(before[i]), reason: 'track $i');
        expect(
          controller.velocity(t),
          closeTo(velocity, velocity * 0.2),
          reason: 'velocity is continuous on track $i',
        );
      }
      // The last track, 80 ms delayed, still keeps moving up meanwhile.
      var last = controller.value(tracks.last);
      for (var i = 0; i < 6; i++) {
        await tester.pump(_t(10));
        expect(controller.value(tracks.last), greaterThan(last));
        last = controller.value(tracks.last);
      }
      // The first one, not delayed, already turned around.
      expect(controller.velocity(tracks.first), lessThan(0));

      await tester.pump(const Duration(seconds: 3));
      for (final t in tracks) {
        expect(controller.value(t), closeTo(0, 1e-3));
      }
    });

    testWidgets('a hold first, as before, no longer freezes a moving track',
        (tester) async {
      await setUpController(tester);
      controller.set([solo.value(0)]);
      controller.animate([
        solo([const TrackStep.to(1, motion: _linear1s)]),
      ]);
      await tester.pump();
      await tester.pump(_t(200));
      expect(controller.value(solo), closeTo(0.2, 1e-6));

      controller.animate([
        solo([
          const TrackStep.hold(Duration(milliseconds: 100)),
          const TrackStep.to(0, motion: _linear1s),
        ]),
      ]);
      await tester.pump();
      await tester.pump(_t(50));
      expect(controller.value(solo), closeTo(0.25, 1e-6));
      await tester.pump(_t(50));
      expect(controller.value(solo), closeTo(0.3, 1e-6));
      // Then the new step takes over from there.
      await tester.pump(_t(100));
      expect(controller.value(solo), closeTo(0.27, 1e-6));
      controller.stop(canceled: true);
    });

    testWidgets('from: and set() rest during the delay', (tester) async {
      await setUpController(tester);
      controller.set([solo.value(0)]);
      controller.animate([
        solo([const TrackStep.to(1, motion: _linear1s)]),
      ]);
      await tester.pump();
      await tester.pump(_t(200));

      controller.animate([
        solo(
          [const TrackStep.to(0, motion: _linear1s)],
          from: 0.5,
          delay: _t(300),
        ),
      ]);
      await tester.pump();
      await tester.pump(_t(100));
      expect(controller.value(solo), 0.5);
      expect(controller.velocity(solo), 0);
      await tester.pump(_t(300));
      expect(controller.value(solo), closeTo(0.45, 1e-6));
      controller.stop(canceled: true);
    });

    testWidgets('a redirect during a delay does not chain old motion',
        (tester) async {
      await setUpController(tester);
      controller.set([solo.value(0)]);
      controller.animate([
        solo([const TrackStep.to(1, motion: _linear1s)]),
      ]);
      await tester.pump();
      await tester.pump(_t(200));
      controller.animate([
        solo([const TrackStep.to(0, motion: _linear1s)], delay: _t(300)),
      ]);
      await tester.pump();
      await tester.pump(_t(100));
      expect(controller.value(solo), closeTo(0.3, 1e-6));
      // Redirected again while the first redirect waits.
      controller.animate([
        solo([const TrackStep.to(0.3, motion: _linear1s)], delay: _t(100)),
      ]);
      await tester.pump();
      await tester.pump(_t(50));
      expect(controller.value(solo), closeTo(0.35, 1e-6));
      await tester.pump(_t(50));
      expect(controller.value(solo), closeTo(0.4, 1e-6));
      controller.stop(canceled: true);
    });
  });

  group('delay', () {
    testWidgets('shifts .at keyframes', (tester) async {
      await setUpController(tester);
      controller.set([solo.value(0)]);
      controller.animate([
        solo(
          const [TrackStep.at(Duration(seconds: 1), 1, motion: _linear1s)],
          delay: _t(200),
        ),
      ]);
      await tester.pump();
      await tester.pump(_t(190));
      expect(controller.value(solo), 0);
      await tester.pump(_t(1000));
      expect(controller.value(solo), closeTo(0.99, 1e-6), reason: 'at 1.19 s');
      expect(controller.isAnimating, isTrue);
      await tester.pump(_t(10));
      expect(controller.value(solo), 1, reason: 'lands at 1.2 s');
      await tester.pump(_t(20));
      expect(controller.isAnimating, isFalse);
    });

    testWidgets('applies once with LoopMode.loop', (tester) async {
      await setUpController(tester);
      controller.set([solo.value(0)]);
      controller.animate(
        [
          solo(
            const [TrackStep.to(1, motion: Motion.linear(_second100))],
            delay: _t(200),
          ),
        ],
        loop: LoopMode.loop,
      );
      await tester.pump();
      await tester.pump(_t(100));
      expect(controller.value(solo), 0);
      // 200 ms delay, 100 ms up, 100 ms down: next cycle starts at 400 ms.
      await tester.pump(_t(200));
      expect(controller.value(solo), closeTo(1, 1e-6), reason: '300 ms');
      await tester.pump(_t(100));
      expect(controller.value(solo), closeTo(0, 1e-6), reason: '400 ms');
      await tester.pump(_t(50));
      expect(controller.value(solo), closeTo(0.5, 1e-6), reason: '450 ms');
      await tester.pump(_t(1000 + 50));
      expect(controller.value(solo), closeTo(1, 1e-6), reason: '1.5 s');
      controller.stop(canceled: true);
    });

    testWidgets('a looped redirect does not replay the old motion',
        (tester) async {
      for (final loop in [LoopMode.seamless, LoopMode.loop]) {
        await setUpController(tester);
        controller.set([solo.value(0)]);
        controller.animate([
          solo([const TrackStep.to(1, motion: _linear1s)]),
        ]);
        await tester.pump();
        await tester.pump(_t(500));
        expect(controller.value(solo), closeTo(0.5, 1e-6));

        // Cycle 0 is 100 ms of the old motion, then 100 ms to the target.
        controller.animate(
          [
            solo([
              const TrackStep.hold(_second100),
              const TrackStep.to(0.5, motion: Motion.linear(_second100)),
            ]),
          ],
          loop: loop,
        );
        await tester.pump();
        await tester.pump(_t(50));
        expect(controller.value(solo), closeTo(0.55, 1e-6), reason: '$loop');
        // Later cycles hold at rest at 0.5: the old motion is not replayed.
        // The second cycle starts at 200 ms, or 300 ms after a return step.
        final second = loop == LoopMode.loop ? 300 : 200;
        await tester.pump(_t(second + 50 - 50));
        for (var i = 0; i < 3; i++) {
          await tester.pump(_t(30));
          expect(controller.value(solo), 0.5, reason: '$loop $i');
        }
        await tester.pump(_t(300));
        await tester.pump(_t(30));
        expect(controller.value(solo), 0.5, reason: '$loop later');
        controller.stop(canceled: true);
      }
    });
  });

  group('parity', () {
    Future<List<double>> ticked(WidgetTester tester, List<int> at) async {
      await setUpController(tester);
      controller.set([solo.value(0)]);
      controller.animate([
        solo([const TrackStep.to(1, motion: _spring)]),
      ]);
      await tester.pump();
      await tester.pump(_t(100));
      controller.animate([
        solo([const TrackStep.to(0, motion: _spring)], delay: _t(120)),
      ]);
      await tester.pump();
      final values = <double>[];
      var now = 0;
      for (final time in at) {
        await tester.pump(_t(time - now));
        now = time;
        values.add(controller.value(solo));
      }
      controller.stop(canceled: true);
      return values;
    }

    testWidgets('scrubTo matches ticking for a delayed redirect',
        (tester) async {
      const at = [10, 60, 119, 120, 121, 200, 500];
      final expected = await ticked(tester, at);

      await setUpController(tester);
      controller.set([solo.value(0)]);
      controller.animate([
        solo([const TrackStep.to(1, motion: _spring)]),
      ]);
      await tester.pump();
      await tester.pump(_t(100));
      controller.animate([
        solo([const TrackStep.to(0, motion: _spring)], delay: _t(120)),
      ]);
      await tester.pump();
      final scrubbed = <double>[];
      for (final time in at.reversed) {
        controller.scrubTo(_t(100 + time));
        scrubbed.insert(0, controller.value(solo));
      }
      for (var i = 0; i < at.length; i++) {
        expect(scrubbed[i], closeTo(expected[i], 1e-6), reason: '${at[i]} ms');
      }
      controller.stop(canceled: true);
    });
  });

  group('futures', () {
    testWidgets('ended and settled include the delay', (tester) async {
      await setUpController(tester);
      controller.set([solo.value(0)]);
      final moments = <String, int>{};
      var elapsed = 0;
      final future = controller.animate([
        solo([const TrackStep.to(1, motion: _linear1s)], delay: _t(200)),
      ]);
      future.ended.then((_) => moments['ended'] = elapsed);
      future.then((_) => moments['settled'] = elapsed);
      await tester.pump();
      while (elapsed < 2000 && !moments.containsKey('settled')) {
        elapsed += 10;
        await tester.pump(_t(10));
      }
      expect(moments['ended'], 1200);
      expect(moments['settled'], inInclusiveRange(1200, 1220));
    });
  });
}

const _second100 = Duration(milliseconds: 100);
