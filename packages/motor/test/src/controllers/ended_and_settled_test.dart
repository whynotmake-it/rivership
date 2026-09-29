// ignore_for_file: cascade_invocations, unawaited_futures

import 'dart:async';

import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

const _bouncy = CupertinoMotion.bouncy();
const _linear300 = Motion.linear(Duration(milliseconds: 300));

/// A spring without damping: it oscillates forever.
const _undamped = SpringMotion(
  SpringDescription(mass: 1, stiffness: 100, damping: 0),
  snapToEnd: false,
);

/// A motion with no duration that never settles.
class _Drift extends Motion {
  const _Drift();

  @override
  bool get needsSettle => false;

  @override
  Simulation createSimulation({
    double start = 0,
    double end = 1,
    double velocity = 0,
  }) =>
      _DriftSimulation(start);

  @override
  bool operator ==(Object other) => other is _Drift;

  @override
  int get hashCode => (_Drift).hashCode;
}

class _DriftSimulation extends Simulation with SettlingSimulation {
  _DriftSimulation(this.start);

  final double start;

  @override
  Duration? get settlesAt => null;

  @override
  double x(double time) => start + time;

  @override
  double dx(double time) => 1;

  @override
  bool isDone(double time) => false;
}

/// When a run ended and settled, in seconds on 10 ms frames from the first
/// frame, or null if it didn't.
final class _Moments {
  double? ended;
  double? settled;
  bool canceled = false;
}

const _frame = Duration(milliseconds: 10);

/// Pumps 10 ms frames until [run] settles or [until] seconds pass.
Future<_Moments> _watch(
  WidgetTester tester,
  MotionFuture run, {
  double until = 5,
}) async {
  final moments = _Moments();
  var frames = 0;
  double now() => frames / 100;
  unawaited(run.ended.then((_) => moments.ended ??= now()));
  unawaited(
    run.orCancel.then(
      (_) => moments.settled ??= now(),
      onError: (Object _) => moments.canceled = true,
    ),
  );
  await tester.pump();
  while (frames < until * 100 && moments.settled == null && !moments.canceled) {
    frames++;
    await tester.pump(_frame);
  }
  return moments;
}

/// The first 10 ms frame at or after [seconds].
double _frameAfter(double seconds) => (seconds * 100 - 1e-6).ceil() / 100;

double _settleSeconds(Motion motion, {double start = 0, double end = 1}) =>
    motion
        .createSimulation(start: start, end: end)
        .estimateSettle()!
        .inMicroseconds /
    1e6;

/// [track] to [value] with [motion], ending at the motion's duration.
TrackAnimation<double> _toByDuration(
  Track<double> track,
  double value, {
  Motion motion = _bouncy,
}) =>
    track([TrackStep.to(value, motion: motion, until: WaitUntil.duration)]);

void main() {
  final a = Track<double>(MotionConverter.single, initial: 0);
  final b = Track<double>(MotionConverter.single, initial: 0);
  final settle = _settleSeconds(_bouncy);

  group('one step', () {
    testWidgets('a spring ends after its duration and settles later',
        (tester) async {
      final controller = TrackController(vsync: tester);
      addTearDown(controller.dispose);
      for (final animation in [a.to(1, motion: _bouncy), _toByDuration(a, 1)]) {
        controller.set([a.value(0)]);
        final moments = await _watch(tester, controller.animate([animation]));
        expect(moments.ended, 0.5, reason: '$animation');
        expect(moments.settled, _frameAfter(settle), reason: '$animation');
        expect(moments.settled, greaterThan(0.9), reason: '$animation');
      }
    });

    testWidgets('a curve ends at its duration and settles right after',
        (tester) async {
      final controller = TrackController(vsync: tester);
      addTearDown(controller.dispose);
      final moments = await _watch(
        tester,
        controller.animate([a.to(1, motion: _linear300)]),
      );
      expect(moments.ended, 0.3);
      // Its simulation is done just after its duration, so on a frame that
      // lands exactly on it, it settles one frame later.
      expect(moments.settled, 0.31);
    });

    testWidgets('a spring already on its target ends and settles at once',
        (tester) async {
      final controller = TrackController(vsync: tester);
      addTearDown(controller.dispose);
      for (final animation in [a.to(0, motion: _bouncy), _toByDuration(a, 0)]) {
        final moments = await _watch(tester, controller.animate([animation]));
        expect(moments.ended, 0);
        expect(moments.settled, 0);
      }
    });

    testWidgets('a call that starts nothing has ended and settled',
        (tester) async {
      final controller = TrackController(vsync: tester);
      addTearDown(controller.dispose);
      // Each would time out the test if it waited for a frame.
      for (final run in [MotionFuture.complete(), controller.animate([])]) {
        await run.ended;
        await run;
        await expectLater(run.orCancel, completes);
      }
      expect(controller.isAnimating, isFalse);
    });
  });

  group('each call', () {
    const linear100 = Motion.linear(Duration(milliseconds: 100));

    testWidgets('settles with its own tracks, not the others', (tester) async {
      final controller = TrackController(vsync: tester);
      addTearDown(controller.dispose);
      final first =
          controller.play(TrackTimeline([a.to(1, motion: linear100)]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      final second = controller.animate([
        b([
          const TrackStep.to(1, motion: linear100),
          const TrackStep.to(2, motion: linear100),
        ]),
      ]);
      expect(identical(first, second), isFalse);
      var firstDone = false;
      var secondDone = false;
      first.then((_) => firstDone = true);
      second.then((_) => secondDone = true);

      // The first track arrives ~100 ms in, while the second keeps running.
      await tester.pump(const Duration(milliseconds: 80));
      await tester.pump();
      expect(firstDone, isTrue);
      expect(secondDone, isFalse);
      expect(controller.isAnimating, isTrue);

      await tester.pumpAndSettle();
      expect(secondDone, isTrue);

      // A later, shorter call settles before an earlier, longer one.
      final long = controller.animate([
        a([
          const TrackStep.to(0, motion: linear100),
          const TrackStep.to(1, motion: linear100),
          const TrackStep.to(0, motion: linear100),
        ]),
      ]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      final short = controller.animate([b.to(0, motion: linear100)]);
      var shortDone = false;
      var longDone = false;
      short.then((_) => shortDone = true);
      long.then((_) => longDone = true);

      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      expect(controller.value(b), closeTo(0, 1e-4));
      expect(controller.isAnimating, isTrue);
      expect(shortDone, isTrue);
      expect(longDone, isFalse);

      await tester.pumpAndSettle();
      expect(longDone, isTrue);
    });

    testWidgets('is canceled when another call restarts one of its tracks',
        (tester) async {
      final controller = TrackController(vsync: tester);
      addTearDown(controller.dispose);
      final first = controller.animate([
        a.to(1, motion: linear100),
        b.to(1, motion: linear100),
      ]);
      var firstDone = false;
      var firstCanceled = false;
      first.then((_) => firstDone = true);
      first.orCancel.catchError((Object error) {
        firstCanceled = error is TickerCanceled;
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));

      final second = controller.animate([b.to(2, motion: linear100)]);
      var secondDone = false;
      second.then((_) => secondDone = true);

      await tester.pumpAndSettle();
      expect(firstDone, isFalse);
      expect(firstCanceled, isTrue);
      expect(secondDone, isTrue);
    });

    testWidgets('runs whenCompleteOrCancel once for either outcome',
        (tester) async {
      final controller = TrackController(vsync: tester);
      addTearDown(controller.dispose);
      var calls = 0;

      final completing = controller.animate([a.to(1, motion: linear100)]);
      completing.whenCompleteOrCancel(() => calls++);
      await tester.pumpAndSettle();
      expect(calls, 1);

      final canceling = controller.animate([a.to(0, motion: linear100)]);
      canceling.whenCompleteOrCancel(() => calls++);
      await tester.pump();
      controller.stop(canceled: true);
      await tester.pump();
      expect(calls, 2);
    });

    testWidgets('is canceled when the controller is disposed', (tester) async {
      final controller = TrackController(vsync: tester);
      var completed = false;
      var canceled = false;
      final future = controller.animate([a.to(1, motion: linear100)]);
      future.then((_) => completed = true);
      future.orCancel.catchError((Object error) {
        canceled = error is TickerCanceled;
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      expect(controller.isAnimating, isTrue);

      // If dispose left a ticker or timer pending, the binding would fail
      // this test.
      controller.dispose();
      await tester.pump();

      expect(completed, isFalse);
      expect(canceled, isTrue);
    });
  });

  group('a plan', () {
    testWidgets('ends when its last step does', (tester) async {
      final controller = TrackController(vsync: tester);
      addTearDown(controller.dispose);
      final moments = await _watch(
        tester,
        controller.animate([
          a([
            const TrackStep.to(1, motion: _bouncy, until: WaitUntil.duration),
            const TrackStep.to(0, motion: _bouncy, until: WaitUntil.duration),
          ]),
        ]),
      );
      expect(moments.ended, 1.0);
      expect(moments.settled, greaterThan(1.5));
    });

    testWidgets('ends at the last duration, whatever the last until',
        (tester) async {
      final controller = TrackController(vsync: tester);
      addTearDown(controller.dispose);
      for (final until in WaitUntil.values) {
        controller.set([a.value(0)]);
        final moments = await _watch(
          tester,
          controller.animate([
            a([
              const TrackStep.to(1, motion: _bouncy),
              TrackStep.to(0, motion: _bouncy, until: until),
            ]),
          ]),
        );
        // The first step waits until settled, then the last one ends after
        // its duration and settles later.
        expect(moments.ended, _frameAfter(settle + 0.5), reason: '$until');
        expect(moments.settled, closeTo(2 * settle, 0.011), reason: '$until');
      }
    });

    testWidgets('of several tracks ends when the last track ends',
        (tester) async {
      final controller = TrackController(vsync: tester);
      addTearDown(controller.dispose);
      final moments = await _watch(
        tester,
        controller.animate([
          a.to(1, motion: _bouncy),
          b([
            const TrackStep.hold(Duration(milliseconds: 200)),
            const TrackStep.to(1, motion: _bouncy),
          ]),
        ]),
      );
      expect(moments.ended, 0.7);
      expect(moments.settled, _frameAfter(0.2 + settle));
    });

    testWidgets('ending in a hold or a keyframe ends at its time',
        (tester) async {
      final controller = TrackController(vsync: tester);
      addTearDown(controller.dispose);
      final held = await _watch(
        tester,
        controller.animate([
          a([
            const TrackStep.to(1, motion: _linear300),
            const TrackStep.hold(Duration(milliseconds: 200)),
          ]),
        ]),
      );
      expect(held.ended, _frameAfter(0.5));

      final keyed = await _watch(
        tester,
        controller.animate([
          b([
            const TrackStep.at(
              Duration(milliseconds: 400),
              1,
              motion: _bouncy,
            ),
          ]),
        ]),
      );
      expect(keyed.ended, _frameAfter(0.4));
      expect(keyed.settled, keyed.ended);
    });

    testWidgets('that loops never ends or settles', (tester) async {
      final controller = TrackController(vsync: tester);
      addTearDown(controller.dispose);
      for (final until in WaitUntil.values) {
        final moments = await _watch(
          tester,
          controller.animate(
            [
              a([
                TrackStep.to(1, motion: _bouncy, until: until),
                TrackStep.to(0, motion: _bouncy, until: until),
              ]),
            ],
            loop: LoopMode.loop,
          ),
          until: 3,
        );
        expect(moments.ended, isNull, reason: '$until');
        expect(moments.settled, isNull, reason: '$until');
      }
      await controller.stop(canceled: true);
    });
  });

  group('never settling', () {
    testWidgets('with a duration, ends but never settles', (tester) async {
      final controller = TrackController(vsync: tester);
      addTearDown(controller.dispose);
      final run = controller.animate([a.to(1, motion: _undamped)]);
      final moments = await _watch(tester, run, until: 60);
      expect(moments.ended, _frameAfter(0.628));
      expect(moments.settled, isNull);
      expect(controller.isAnimating, isTrue);
      await controller.stop(canceled: true);
      await expectLater(run.orCancel, throwsA(isA<TickerCanceled>()));
    });

    testWidgets('without a duration, neither ends nor settles', (tester) async {
      final controller = TrackController(vsync: tester);
      addTearDown(controller.dispose);
      for (final animation in [
        a.to(1, motion: const _Drift()),
        _toByDuration(a, 1, motion: const _Drift()),
      ]) {
        final moments = await _watch(
          tester,
          controller.animate([animation]),
          until: 60,
        );
        expect(moments.ended, isNull);
        expect(moments.settled, isNull);
      }
      await controller.stop(canceled: true);
    });
  });

  group('interruptions', () {
    testWidgets('a retarget before the end cancels both', (tester) async {
      final controller = TrackController(vsync: tester);
      addTearDown(controller.dispose);
      final first = controller.animate([a.to(1, motion: _bouncy)]);
      var ended = false;
      unawaited(first.ended.then((_) => ended = true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final second = controller.animate([a.to(-1, motion: _bouncy)]);
      await expectLater(first.orCancel, throwsA(isA<TickerCanceled>()));
      final moments = await _watch(tester, second);
      expect(ended, isFalse);
      expect(moments.ended, 0.5);
      expect(moments.settled, isNotNull);
    });

    testWidgets('a retarget after the end keeps it ended, cancels settling',
        (tester) async {
      final controller = TrackController(vsync: tester);
      addTearDown(controller.dispose);
      final first = controller.animate([a.to(1, motion: _bouncy)]);
      var ended = false;
      unawaited(first.ended.then((_) => ended = true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(ended, isTrue);
      controller.animate([a.to(0, motion: _bouncy)]);
      await expectLater(first.orCancel, throwsA(isA<TickerCanceled>()));
      await tester.pumpAndSettle();
    });

    testWidgets('reading ended only after the end completes it at once',
        (tester) async {
      final controller = TrackController(vsync: tester);
      addTearDown(controller.dispose);
      final run = controller.animate([a.to(1, motion: _bouncy)]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      var ended = false;
      unawaited(run.ended.then((_) => ended = true));
      await tester.pump();
      expect(ended, isTrue);
      expect(controller.isAnimating, isTrue);
      await tester.pumpAndSettle();
    });

    testWidgets('a retarget after the end, before ended is read, keeps it',
        (tester) async {
      final controller = TrackController(vsync: tester);
      addTearDown(controller.dispose);
      final first = controller.animate([a.to(1, motion: _bouncy)]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      controller.animate([a.to(0, motion: _bouncy)]);
      await expectLater(first.orCancel, throwsA(isA<TickerCanceled>()));
      var ended = false;
      unawaited(first.ended.then((_) => ended = true));
      await tester.pump();
      expect(ended, isTrue);
      await tester.pumpAndSettle();
    });

    testWidgets('reading ended after a canceling stop before the end', (
      tester,
    ) async {
      final controller = TrackController(vsync: tester);
      addTearDown(controller.dispose);
      final run = controller.animate([a.to(1, motion: _bouncy)]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      controller.stop(canceled: true);
      var ended = false;
      unawaited(run.ended.then((_) => ended = true));
      await tester.pump(const Duration(seconds: 2));
      expect(ended, isFalse);
    });

    testWidgets('a retarget of another track leaves the run alone',
        (tester) async {
      final controller = TrackController(vsync: tester);
      addTearDown(controller.dispose);
      final run = controller.animate([a.to(1, motion: _linear300)]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      controller.animate([b.to(1, motion: _bouncy)]);
      final moments = await _watch(tester, run);
      expect(moments.ended, isNotNull);
      expect(moments.settled, isNotNull);
      await tester.pumpAndSettle();
    });

    testWidgets('a graceful stop ends it at once and cancels it',
        (tester) async {
      final controller = TrackController(vsync: tester);
      addTearDown(controller.dispose);
      final run = controller.animate([a.to(1, motion: _bouncy)]);
      var ended = false;
      var settled = false;
      unawaited(run.ended.then((_) => ended = true));
      unawaited(run.then((_) => settled = true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final stop = controller.stop();
      var stopEnded = false;
      unawaited(stop.ended.then((_) => stopEnded = true));
      await tester.pump();
      expect(ended, isTrue);
      expect(stopEnded, isTrue, reason: "the stop's own future has ended");
      await expectLater(run.orCancel, throwsA(isA<TickerCanceled>()));
      await tester.pumpAndSettle();
      expect(settled, isFalse);
      await stop;
    });

    testWidgets('a graceful stop that halts at once completes it',
        (tester) async {
      final controller = TrackController(vsync: tester);
      addTearDown(controller.dispose);
      final run = controller.animate([a.to(1, motion: _linear300)]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      controller.stop();
      await run.ended;
      await run.orCancel;
    });

    testWidgets('a canceling stop cancels both', (tester) async {
      final controller = TrackController(vsync: tester);
      addTearDown(controller.dispose);
      final run = controller.animate([a.to(1, motion: _bouncy)]);
      var ended = false;
      unawaited(run.ended.then((_) => ended = true));
      await tester.pump();
      controller.stop(canceled: true);
      await expectLater(run.orCancel, throwsA(isA<TickerCanceled>()));
      await tester.pump(const Duration(seconds: 2));
      expect(ended, isFalse);
    });
  });

  group('chaining', () {
    testWidgets('awaiting ended hands over the way until: .duration does',
        (tester) async {
      final chained = TrackController(vsync: tester);
      final planned = TrackController(vsync: tester);
      addTearDown(chained.dispose);
      addTearDown(planned.dispose);
      final c = Track<double>(MotionConverter.single, initial: 0);
      final p = Track<double>(MotionConverter.single, initial: 0);

      planned.animate([
        p([
          const TrackStep.to(1, motion: _bouncy, until: WaitUntil.duration),
          const TrackStep.to(0, motion: _bouncy),
        ]),
      ]);
      unawaited(
        chained
            .animate([c.to(1, motion: _bouncy)])
            .ended
            .then((_) => chained.animate([c.to(0, motion: _bouncy)])),
      );
      await tester.pump();
      for (var frame = 1; frame <= 150; frame++) {
        await tester.pump(_frame);
        expect(
          chained.value(c),
          closeTo(planned.value(p), 1e-6),
          reason: 'at ${frame * 10} ms',
        );
      }
      await tester.pumpAndSettle();
    });

    testWidgets('awaiting the future chains the way a plan does by default',
        (tester) async {
      final chained = TrackController(vsync: tester);
      final planned = TrackController(vsync: tester);
      addTearDown(chained.dispose);
      addTearDown(planned.dispose);
      final c = Track<double>(MotionConverter.single, initial: 0);
      final p = Track<double>(MotionConverter.single, initial: 0);

      planned.animate([
        p([
          const TrackStep.to(1, motion: _linear300),
          const TrackStep.to(0, motion: _linear300),
        ]),
      ]);
      unawaited(
        chained.animate([c.to(1, motion: _linear300)]).then(
          (_) => chained.animate([c.to(0, motion: _linear300)]),
        ),
      );
      await tester.pump();
      for (var frame = 1; frame <= 70; frame++) {
        await tester.pump(_frame);
      }
      expect(chained.value(c), planned.value(p));
      await tester.pumpAndSettle();
    });
  });

  group('MotionController', () {
    testWidgets('animateTo ends after the duration and settles later',
        (tester) async {
      final controller = BoundedMotionController<double>(
        motion: _bouncy,
        vsync: tester,
        converter: MotionConverter.single,
        initialValue: 0,
        lowerBound: 0,
        upperBound: 1,
      );
      addTearDown(controller.dispose);
      final moments = await _watch(tester, controller.forward());
      expect(moments.ended, 0.5);
      expect(moments.settled, _frameAfter(settle));
      expect(controller.status, AnimationStatus.completed);
    });

    testWidgets('play ends after the duration, whatever its until',
        (tester) async {
      final controller = MotionController<double>(
        motion: _bouncy,
        vsync: tester,
        converter: MotionConverter.single,
        initialValue: 0,
      );
      addTearDown(controller.dispose);
      for (final until in WaitUntil.values) {
        controller.value = 0;
        final moments = await _watch(
          tester,
          controller.play([TrackStep.to(1, until: until)]),
        );
        expect(moments.ended, 0.5, reason: '$until');
        expect(moments.settled, _frameAfter(settle), reason: '$until');
      }
    });

    testWidgets('setting the value ends and settles it', (tester) async {
      final controller = MotionController<double>(
        motion: _bouncy,
        vsync: tester,
        converter: MotionConverter.single,
        initialValue: 0,
      );
      addTearDown(controller.dispose);
      final run = controller.animateTo(1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      controller.value = 0.5;
      await run.ended;
      await run;
    });

    for (final bounded in [false, true]) {
      testWidgets(
          'a graceful stop ends the run and cancels it '
          '(bounded: $bounded)', (tester) async {
        final controller = bounded
            ? BoundedMotionController<double>(
                motion: _bouncy,
                vsync: tester,
                converter: MotionConverter.single,
                initialValue: 0,
                lowerBound: 0,
                upperBound: 1,
              )
            : MotionController<double>(
                motion: _bouncy,
                vsync: tester,
                converter: MotionConverter.single,
                initialValue: 0,
              );
        addTearDown(controller.dispose);
        final run = controller.animateTo(1);
        var ended = false;
        unawaited(run.ended.then((_) => ended = true));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final stop = controller.stop();
        await tester.pump();
        expect(ended, isTrue);
        await expectLater(run.orCancel, throwsA(isA<TickerCanceled>()));
        await tester.pumpAndSettle();
        await stop;
      });
    }

    testWidgets('a graceful stop of a curve completes the run', (tester) async {
      final controller = MotionController<double>(
        motion: _linear300,
        vsync: tester,
        converter: MotionConverter.single,
        initialValue: 0,
      );
      addTearDown(controller.dispose);
      final run = controller.animateTo(1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      controller.stop();
      await run.ended;
      await run.orCancel;
    });

    testWidgets('a new animateTo cancels the previous run', (tester) async {
      final controller = MotionController<double>(
        motion: _bouncy,
        vsync: tester,
        converter: MotionConverter.single,
        initialValue: 0,
      );
      addTearDown(controller.dispose);
      final first = controller.animateTo(1);
      await tester.pump();
      controller.animateTo(0);
      await expectLater(first.orCancel, throwsA(isA<TickerCanceled>()));
      await tester.pumpAndSettle();
    });
  });

  group('PhaseTrackController', () {
    testWidgets('ends with the last phase and settles before PhaseSettled',
        (tester) async {
      final controller = PhaseTrackController<int>(vsync: tester);
      addTearDown(controller.dispose);
      final events = <String>[];
      final run = controller.playPhases(
        TrackPhaseTimeline<int>({
          0: [a.to(0, motion: _bouncy)],
          1: [a.to(1, motion: _bouncy)],
          2: [a.to(0, motion: _bouncy)],
        }),
        onTransition: (transition) => events.add('$transition'),
      );
      final moments = await _watch(tester, run);
      // Each phase waits until its step has settled; the first is already on
      // its target. The last one ends after its duration, and settles later.
      expect(moments.ended, closeTo(settle + 0.5, 0.011));
      expect(moments.settled, greaterThan(moments.ended!));
      expect(controller.value(a), 0);
      expect(events.last, 'PhaseSettled(2)');
      expect(events.where((e) => e.startsWith('PhaseTransitioning')), [
        'PhaseTransitioning(from: 0, to: 1)',
        'PhaseTransitioning(from: 1, to: 2)',
      ]);
    });

    testWidgets('goToPhase settles on its phase', (tester) async {
      final controller = PhaseTrackController<int>(vsync: tester);
      addTearDown(controller.dispose);
      controller.setTimeline(
        TrackPhaseTimeline<int>({
          0: [a.to(1, motion: _linear300)],
          1: [a.to(2, motion: _linear300)],
        }),
      );
      final moments = await _watch(tester, controller.goToPhase(1));
      expect(moments.ended, 0.3);
      expect(moments.settled, 0.31);
      expect(controller.value(a), 2);
    });

    for (final loop in [LoopMode.loop, LoopMode.pingPong, LoopMode.seamless]) {
      testWidgets('a looping timeline never ends or settles ($loop)',
          (tester) async {
        final controller = PhaseTrackController<int>(vsync: tester);
        addTearDown(controller.dispose);
        final run = controller.playPhases(
          TrackPhaseTimeline<int>(
            {
              0: [a.to(0, motion: _linear300)],
              1: [a.to(1, motion: _linear300)],
              2: [a.to(0, motion: _linear300)],
            },
            phaseLoop: loop,
          ),
        );
        final moments = await _watch(tester, run, until: 3);
        expect(controller.isAnimating, isTrue);
        expect(moments.ended, isNull);
        expect(moments.settled, isNull);
        expect(moments.canceled, isFalse);

        controller.stop(canceled: true);
        await expectLater(run.orCancel, throwsA(isA<TickerCanceled>()));
      });
    }

    testWidgets('a graceful stop ends a looping timeline', (tester) async {
      final controller = PhaseTrackController<int>(vsync: tester);
      addTearDown(controller.dispose);
      final run = controller.playPhases(
        TrackPhaseTimeline<int>(
          {
            0: [a.to(0, motion: _linear300)],
            1: [a.to(1, motion: _linear300)],
          },
          phaseLoop: LoopMode.loop,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));
      controller.stop();
      await run.ended;
      await run.orCancel;
      expect(controller.isAnimating, isFalse);
    });
  });

  group('until: .duration before a barrier', () {
    testWidgets('a trailing barrier is reached once the step has ended',
        (tester) async {
      final controller = TrackController(vsync: tester);
      addTearDown(controller.dispose);
      controller.animate([
        a([
          const TrackStep.to(1, motion: _bouncy, until: WaitUntil.duration),
          const TrackStep.sync(token: #meet),
        ]),
        b([
          const TrackStep.sync(token: #meet),
          const TrackStep.to(1, motion: _linear300),
        ]),
      ]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(controller.value(b), 0);
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.value(b), closeTo(1 / 3, 1e-6));
      expect(controller.value(a), isNot(1), reason: 'the spring still moves');
      await tester.pumpAndSettle();
      expect(controller.value(a), 1, reason: 'it settles on its target');
      expect(controller.value(b), 1);
    });

    testWidgets('a track that sits out the last phase moves on once ended',
        (tester) async {
      final controller = PhaseTrackController<int>(vsync: tester);
      addTearDown(controller.dispose);
      final started = <double>[];
      var frames = 0;
      controller.playPhases(
        TrackPhaseTimeline<int>({
          0: [
            a([
              const TrackStep.to(1, motion: _bouncy, until: WaitUntil.duration),
            ]),
            b.to(1, motion: _linear300),
          ],
          1: [b.to(0, motion: _linear300)],
        }),
        onTransition: (transition) {
          if (transition is PhaseTransitioning<int>) started.add(frames / 100);
        },
      );
      await tester.pump();
      while (frames < 300) {
        frames++;
        await tester.pump(_frame);
      }
      expect(started, [0.5]);
      expect(controller.value(a), 1);
      expect(controller.isAnimating, isFalse);
    });
  });
}
