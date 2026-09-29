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
  MotionRun run, {
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

void main() {
  final a = Track<double>(MotionConverter.single, initial: 0);
  final b = Track<double>(MotionConverter.single, initial: 0);

  group('one step', () {
    testWidgets('a spring ends after its duration and settles later',
        (tester) async {
      final controller = TrackController(vsync: tester);
      addTearDown(controller.dispose);
      final moments = await _watch(
        tester,
        controller.animate([a.to(1, motion: _bouncy)]),
      );
      expect(moments.ended, 0.5);
      expect(moments.settled, _frameAfter(_settleSeconds(_bouncy)));
      expect(moments.settled, greaterThan(0.9));
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
      final moments = await _watch(
        tester,
        controller.animate([a.to(0, motion: _bouncy)]),
      );
      expect(moments.ended, 0);
      expect(moments.settled, 0);
    });

    test('a call that starts nothing has ended and settled', () async {
      final run = MotionRun.complete();
      await run.ended;
      await run;
      await expectLater(run.orCancel, completes);
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
            const TrackStep.to(1, motion: _bouncy),
            const TrackStep.to(0, motion: _bouncy),
          ]),
        ]),
      );
      expect(moments.ended, 1.0);
      expect(moments.settled, greaterThan(1.5));
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
      expect(
        moments.settled,
        _frameAfter(0.2 + _settleSeconds(_bouncy)),
      );
    });

    testWidgets('with untilSettled last ends when it settles', (tester) async {
      final controller = TrackController(vsync: tester);
      addTearDown(controller.dispose);
      final moments = await _watch(
        tester,
        controller.animate([
          a([const TrackStep.to(1, motion: _bouncy, untilSettled: true)]),
        ]),
      );
      expect(moments.ended, moments.settled);
      expect(moments.settled, _frameAfter(_settleSeconds(_bouncy)));
    });

    testWidgets('with untilSettled in the middle ends a duration later',
        (tester) async {
      final controller = TrackController(vsync: tester);
      addTearDown(controller.dispose);
      final settle = _settleSeconds(_bouncy);
      final moments = await _watch(
        tester,
        controller.animate([
          a([
            const TrackStep.to(1, motion: _bouncy, untilSettled: true),
            const TrackStep.to(0, motion: _bouncy),
          ]),
        ]),
      );
      expect(moments.ended, _frameAfter(settle + 0.5));
      expect(moments.settled, greaterThan(moments.ended!));
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
      final moments = await _watch(
        tester,
        controller.animate(
          [
            a([
              const TrackStep.to(1, motion: _bouncy),
              const TrackStep.to(0, motion: _bouncy),
            ]),
          ],
          loop: LoopMode.loop,
        ),
        until: 3,
      );
      expect(moments.ended, isNull);
      expect(moments.settled, isNull);
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
      final moments = await _watch(
        tester,
        controller.animate([a.to(1, motion: const _Drift())]),
        until: 60,
      );
      expect(moments.ended, isNull);
      expect(moments.settled, isNull);
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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await first.ended;
      controller.animate([a.to(0, motion: _bouncy)]);
      await expectLater(first.orCancel, throwsA(isA<TickerCanceled>()));
      await tester.pumpAndSettle();
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

    testWidgets('a graceful stop ends it at once and settles it later',
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
      controller.stop();
      await tester.pump();
      expect(ended, isTrue);
      expect(settled, isFalse);
      await tester.pumpAndSettle();
      expect(settled, isTrue);
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
    testWidgets('awaiting ended hands over the way a plan does',
        (tester) async {
      final chained = TrackController(vsync: tester);
      final planned = TrackController(vsync: tester);
      addTearDown(chained.dispose);
      addTearDown(planned.dispose);
      final c = Track<double>(MotionConverter.single, initial: 0);
      final p = Track<double>(MotionConverter.single, initial: 0);

      planned.animate([
        p([
          const TrackStep.to(1, motion: _bouncy),
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

    testWidgets('awaiting the run hands over only once settled',
        (tester) async {
      final controller = MotionController<double>(
        motion: _bouncy,
        vsync: tester,
        converter: MotionConverter.single,
        initialValue: 0,
      );
      addTearDown(controller.dispose);
      final moments = await _watch(tester, controller.animateTo(1));
      expect(moments.ended, 0.5);
      expect(moments.settled, _frameAfter(_settleSeconds(_bouncy)));
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
      expect(moments.settled, greaterThan(0.9));
      expect(controller.status, AnimationStatus.completed);
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
      // Each phase's step ends after its duration, even the first, which is
      // already on its target.
      expect(moments.ended, 1.5);
      expect(moments.settled, greaterThan(moments.ended!));
      expect(events.last, 'PhaseSettled(2)');
      expect(events.where((e) => e.startsWith('PhaseTransitioning')), [
        'PhaseTransitioning(from: 0, to: 1)',
        'PhaseTransitioning(from: 1, to: 2)',
      ]);
    });
  });
}
