// ignore_for_file: cascade_invocations, unawaited_futures
// ignore_for_file: deprecated_member_use_from_same_package

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:motor/src/simulations/step_playback.dart';

import 'fuzz_support.dart';

const _linear100 = Motion.linear(Duration(milliseconds: 100));
const _frame = Duration(milliseconds: 16);

StepPlayback<double> _playback(
  List<TrackStep<double>> steps, {
  LoopMode loop = LoopMode.none,
  double start = 0,
  double? velocity,
  Motion? fallback,
}) =>
    StepPlayback<double>(
      steps: steps,
      converter: MotionConverter.single,
      start: start,
      velocity: velocity,
      loop: loop,
      fallbackMotion: fallback,
    );

/// Records how a [MotionFuture] resolved.
List<String> _watch(MotionFuture future) {
  final events = <String>[];
  future.ended.then((_) => events.add('ended'));
  future.orCancel.then(
    (_) => events.add('settled'),
    onError: (Object _) => events.add('canceled'),
  );
  return events;
}

void main() {
  final a = Track<double>(MotionConverter.single, initial: 0);
  final b = Track<double>(MotionConverter.single, initial: 0);

  group('durations', () {
    test('zero, one microsecond and a century all end on time', () {
      final playback = _playback(const [
        TrackStep.hold(Duration.zero),
        TrackStep.to(1, motion: Motion.linear(Duration(microseconds: 1))),
        TrackStep.hold(Duration(microseconds: 1)),
        TrackStep.to(2, motion: Motion.linear(Duration(days: 36500))),
        TrackStep.to(3, motion: Motion.linear(Duration.zero)),
      ]);
      const century = 36500 * 86400.0;

      playback.advanceTo(1e-5);
      expect(playback.values.single, closeTo(1, 1e-9));
      playback.advanceTo(century / 2);
      expect(playback.values.single, closeTo(1.5, 1e-6));
      expect(playback.isDone, isFalse);
      playback.advanceTo(century + 1);
      expect(playback.values.single, 3);
      expect(playback.isDone, isTrue);
    });

    test('a negative hold asserts instead of going back in time', () {
      expect(
        () => _playback(const [
          TrackStep.to(1, motion: _linear100),
          TrackStep.hold(Duration(milliseconds: -50)),
          TrackStep.to(2, motion: _linear100),
        ]),
        throwsA(
          isA<AssertionError>().having(
            (error) => error.message,
            'message',
            contains('negative duration'),
          ),
        ),
      );
    });

    test('a motion with a negative duration asserts', () {
      for (final steps in [
        const [
          TrackStep<double>.to(
            1,
            motion: Motion.linear(Duration(microseconds: -100)),
          ),
        ],
        const [
          TrackStep<double>.to(1, motion: NoMotion(Duration(seconds: -1))),
        ],
        [
          TrackStep<double>.free(
            motion: const FrictionMotion().scaleTo(const Duration(seconds: -1)),
          ),
        ],
      ]) {
        expect(() => _playback(steps), throwsAssertionError, reason: '$steps');
      }
      expect(
        () => _playback(
          const [TrackStep.to(1)],
          fallback: const Motion.linear(Duration(seconds: -1)),
        ),
        throwsAssertionError,
      );
    });

    test('a spring scaled to nothing arrives at once', () {
      final playback = _playback([
        TrackStep.to(
          1,
          motion: const Motion.bouncySpring().scaleTo(Duration.zero),
        ),
      ])
        ..advanceTo(0);
      expect(playback.values.single, 1);
      playback.advanceTo(1e-6);
      expect(playback.isDone, isTrue);
    });
  });

  group('velocities and values', () {
    test('a huge velocity still settles on target', () {
      final playback = _playback(
        const [TrackStep.to(1, motion: Motion.bouncySpring())],
        velocity: 1e12,
      );
      for (var t = 0.0; t < 30 && !playback.isDone; t += 0.1) {
        playback.advanceTo(t);
        expect(playback.values.single.isFinite, isTrue, reason: 't=$t');
      }
      expect(playback.isDone, isTrue);
      expect(playback.values.single, 1);
    });

    test('a non-finite velocity or target never settles, and does not throw',
        () {
      for (final (velocity, target) in [
        (double.nan, 1.0),
        (double.infinity, 1.0),
        (1e300, 1.0),
        (0.0, double.nan),
        (0.0, double.infinity),
      ]) {
        for (final motion in const [
          Motion.bouncySpring(),
          Motion.smoothSpring(),
          CupertinoMotion(bounce: -0.5),
        ]) {
          final watch = Stopwatch()..start();
          final playback = _playback(
            [TrackStep.to(target, motion: motion)],
            velocity: velocity,
          );
          // Past the day playback looks ahead before asking the spring.
          for (final t in [0.1, 10.0, 1e6]) {
            playback.advanceTo(t);
          }
          final reason = 'velocity $velocity to $target, $motion';
          expect(watch.elapsed, lessThan(const Duration(seconds: 1)));
          expect(playback.hasEnded, isTrue, reason: reason);
        }
      }
    });

    testWidgets('a track moved to NaN can be set back', (tester) async {
      final controller = TrackController(vsync: tester);
      addTearDown(controller.dispose);
      controller.animate([
        a.to(1, motion: const Motion.bouncySpring(), withVelocity: double.nan),
      ]);
      await tester.pump();
      await tester.pump(_frame);
      expect(controller.value(a).isNaN, isTrue);

      controller.set([a.value(0)]);
      final events = _watch(controller.animate([a.to(1, motion: _linear100)]));
      await tester.pumpAndSettle();
      expect(controller.value(a), 1);
      expect(events, ['ended', 'settled']);
    });

    testWidgets('a move to where the track is ends and settles at once',
        (tester) async {
      final controller = TrackController(vsync: tester);
      addTearDown(controller.dispose);
      final events = _watch(
        controller.animate([a.to(0, motion: const Motion.bouncySpring())]),
      );
      await tester.pump();
      await tester.pump(_frame);
      expect(events, ['ended', 'settled']);
      expect(controller.value(a), 0);
    });

    testWidgets('a move to where the track is, with velocity, comes back',
        (tester) async {
      final controller = TrackController(vsync: tester);
      addTearDown(controller.dispose);
      controller.animate([
        a.to(0, motion: const Motion.bouncySpring(), withVelocity: 20),
      ]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(controller.value(a), greaterThan(0.1));
      await tester.pumpAndSettle();
      expect(controller.value(a), 0);
    });
  });

  group('bounce', () {
    test('above 1 asserts and 1 never settles', () {
      expect(
        () => const CupertinoMotion(bounce: 1.5).createSimulation(),
        throwsAssertionError,
      );
      final playback = _playback(
        const [TrackStep.to(1, motion: CupertinoMotion(bounce: 1))],
      )..advanceTo(1e4);
      expect(playback.isDone, isFalse);
      expect(playback.hasEnded, isTrue);
      expect(playback.values.single, inInclusiveRange(-0.01, 2.01));
    });

    test('-1 or below asserts instead of blowing up', () {
      for (final bounce in [-1.0, -5.0]) {
        expect(
          () => CupertinoMotion(bounce: bounce).createSimulation(),
          throwsAssertionError,
          reason: 'bounce $bounce',
        );
      }
    });

    test('just above -1 is heavily damped and settles finite', () {
      final playback = _playback(
        const [TrackStep.to(1, motion: CupertinoMotion(bounce: -0.99))],
      );
      for (var t = 0.0; t < 600 && !playback.isDone; t += 1) {
        playback.advanceTo(t);
        expect(playback.values.single, inInclusiveRange(0, 1), reason: '$t');
      }
      expect(playback.isDone, isTrue);
    });
  });

  group('plans', () {
    testWidgets('an empty plan asserts and leaves the controller usable',
        (tester) async {
      final controller = TrackController(vsync: tester);
      addTearDown(controller.dispose);
      expect(() => controller.animate([a([])]), throwsAssertionError);

      final events = _watch(controller.animate([a.to(1, motion: _linear100)]));
      await tester.pumpAndSettle();
      expect(controller.value(a), 1);
      expect(events, ['ended', 'settled']);
    });

    testWidgets('a barrier with one participant releases at once',
        (tester) async {
      final controller = TrackController(vsync: tester);
      addTearDown(controller.dispose);
      controller.animate([
        a([
          const TrackStep.to(1, motion: _linear100),
          const TrackStep.sync(token: #alone),
          const TrackStep.to(2, motion: _linear100),
        ]),
      ]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(controller.value(a), closeTo(1.5, 1e-9));
      await tester.pumpAndSettle();
    });

    testWidgets('a barrier nobody else reaches holds until they stop',
        (tester) async {
      final controller = TrackController(vsync: tester);
      addTearDown(controller.dispose);
      final events = _watch(
        controller.animate([
          a([
            const TrackStep.to(1, motion: _linear100),
            const TrackStep.sync(token: #never),
            const TrackStep.to(2, motion: _linear100),
          ]),
          b(
            [
              const TrackStep.free(motion: FreeDrift()),
              const TrackStep.sync(token: #never),
            ],
            withVelocity: 1,
          ),
        ]),
      );
      await tester.pump();
      for (var i = 0; i < 60; i++) {
        await tester.pump(_frame);
      }
      expect(controller.value(a), 1);
      expect(controller.value(b), closeTo(0.96, 1e-9));

      // Once `b` is stopped, `a` goes on from that moment, not earlier.
      controller.stop(tracks: [b], canceled: true);
      await tester.pump(const Duration(milliseconds: 50));
      expect(controller.value(a), closeTo(1.5, 1e-9));
      await tester.pumpAndSettle();
      expect(controller.value(a), 2);
      expect(events, ['canceled']);
    });

    testWidgets('a barrier releases when the other plan is replaced',
        (tester) async {
      final controller = TrackController(vsync: tester);
      addTearDown(controller.dispose);
      controller.animate([
        a([
          const TrackStep.to(1, motion: _linear100),
          const TrackStep.sync(token: #meet),
          const TrackStep.to(2, motion: _linear100),
        ]),
        b([
          const TrackStep.to(1, motion: Motion.linear(Duration(seconds: 5))),
          const TrackStep.sync(token: #meet),
        ]),
      ]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(controller.value(a), 1);
      controller.animate([b.to(0, motion: _linear100)]);
      await tester.pump(const Duration(milliseconds: 50));
      expect(controller.value(a), closeTo(1.5, 1e-9));
      await tester.pumpAndSettle();
    });

    testWidgets('zero-length loops neither hang nor flood onStep',
        (tester) async {
      for (final loop in [
        LoopMode.loop,
        LoopMode.pingPong,
        LoopMode.seamless,
      ]) {
        final controller = TrackController(vsync: tester);
        var steps = 0;
        final events = _watch(
          controller.animate(
            [
              a([
                const TrackStep.to(1, motion: Motion.linear(Duration.zero)),
                const TrackStep.hold(Duration.zero),
              ]),
              b([const TrackStep.hold(Duration.zero)]),
            ],
            loop: loop,
            onStep: (_, __) => steps++,
          ),
        );
        final watch = Stopwatch()..start();
        await tester.pump();
        for (var i = 0; i < 30; i++) {
          await tester.pump(_frame);
        }
        expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
        expect(steps, lessThan(30 * 5000), reason: '$loop');
        expect(controller.value(a).isFinite, isTrue);
        controller.stop(canceled: true);
        await tester.pump();
        expect(events, ['canceled'], reason: '$loop');
        controller.dispose();
      }
    });

    test('a keyframe whose time passed while the step before ran skips it', () {
      final playback = _playback(const [
        TrackStep.to(1, motion: Motion.linear(Duration(milliseconds: 500))),
        TrackStep.at(Duration(milliseconds: 100), 2, motion: _linear100),
      ]);
      playback.advanceTo(0.05);
      expect(playback.values.single, closeTo(1, 1e-9));
      playback.advanceTo(0.1);
      expect(playback.values.single, closeTo(2, 1e-9));
    });

    test('a keyframe at zero arrives at once', () {
      final playback = _playback(
        const [
          TrackStep.at(Duration.zero, 5, motion: Motion.bouncySpring()),
          TrackStep.to(0, motion: _linear100),
        ],
        start: 1,
      )..advanceTo(0);
      expect(playback.values.single, 5);
      playback.advanceTo(0.05);
      expect(playback.values.single, closeTo(2.5, 1e-9));
    });

    test('a keyframe before the holds before it asserts', () {
      expect(
        () => _playback(const [
          TrackStep.hold(Duration(milliseconds: 200)),
          TrackStep.at(Duration(milliseconds: 100), 1, motion: _linear100),
        ]),
        throwsAssertionError,
      );
    });
  });

  group('lying simulations', () {
    test('one that says it settles but is never done never ends its step', () {
      final playback = _playback(const [
        TrackStep.to(1, motion: _NeverDoneMotion()),
        TrackStep.to(2, motion: _linear100),
      ]);
      for (final t in [0.5, 10.0, 1000.0]) {
        playback.advanceTo(t);
        expect(playback.currentStepIndex, 0, reason: 't=$t');
      }
    });

    test('one that is never done hands over at its duration', () {
      final playback = _playback(const [
        TrackStep.to(
          1,
          motion: _NeverDoneMotion(duration: Duration(milliseconds: 200)),
          until: WaitUntil.duration,
        ),
        TrackStep.to(2, motion: _linear100),
      ])
        ..advanceTo(0.25);
      expect(playback.currentStepIndex, 1);
      playback.advanceTo(10);
      expect(playback.isDone, isTrue);
      expect(playback.values.single, 2);
    });

    test('one that is never done can not loop and says why', () {
      expect(
        () => _playback(
          const [TrackStep.to(1, motion: _NeverDoneMotion())],
          loop: LoopMode.loop,
        ),
        throwsA(
          isA<AssertionError>().having(
            (error) => '${error.message}',
            'message',
            contains('never ends'),
          ),
        ),
      );
    });

    test('one that says it settles late holds its step that long', () {
      final playback = _playback(const [
        TrackStep.to(1, motion: LateReportingMotion()),
        TrackStep.to(2, motion: _linear100),
      ])
        ..advanceTo(0.39);
      expect(playback.currentStepIndex, 0);
      expect(playback.values.single, 1);
      playback.advanceTo(0.45);
      expect(playback.currentStepIndex, 1);
      expect(playback.values.single, closeTo(1.5, 1e-9));
    });

    test('one whose value turns NaN keeps playback running, finite elsewhere',
        () {
      final playback = StepPlayback<Offset>(
        steps: const [
          TrackStep.to(
            Offset(1, 1),
            motionPerDimension: [_NaNMotion(), _linear100],
          ),
        ],
        converter: MotionConverter.offset,
        start: Offset.zero,
      )..advanceTo(10);
      expect(playback.values[0].isNaN, isTrue);
      expect(playback.values[1], 1);
      expect(playback.isDone, isFalse);
    });

    test('one that throws surfaces the error from advanceTo', () {
      final playback = _playback(const [TrackStep.to(1, motion: _Throws())]);
      expect(() => playback.advanceTo(0.2), throwsStateError);
    });
  });
}

/// Moves linearly to its end over 0.1 s, says it settles then, but is never
/// done.
class _NeverDoneMotion extends Motion {
  const _NeverDoneMotion({this.duration});

  @override
  final Duration? duration;

  @override
  bool get needsSettle => false;

  @override
  Simulation createSimulation({
    double start = 0,
    double end = 1,
    double velocity = 0,
  }) =>
      _NeverDone(start, end);

  @override
  bool operator ==(Object other) =>
      other is _NeverDoneMotion && other.duration == duration;

  @override
  int get hashCode => duration.hashCode;
}

class _NeverDone extends Simulation with SettlingSimulation {
  _NeverDone(this.start, this.end);

  final double start;
  final double end;

  @override
  Duration get settlesAt => const Duration(milliseconds: 100);

  @override
  double x(double time) => start + (end - start) * (time / 0.1).clamp(0, 1);

  @override
  double dx(double time) => time < 0.1 ? (end - start) / 0.1 : 0;

  @override
  bool isDone(double time) => false;
}

/// Turns NaN after 50 ms and is never done.
class _NaNMotion extends Motion {
  const _NaNMotion();

  @override
  bool get needsSettle => false;

  @override
  Simulation createSimulation({
    double start = 0,
    double end = 1,
    double velocity = 0,
  }) =>
      _NaN(start);

  @override
  bool operator ==(Object other) => other is _NaNMotion;

  @override
  int get hashCode => (_NaNMotion).hashCode;
}

class _NaN extends Simulation {
  _NaN(this.start);

  final double start;

  @override
  double x(double time) => time < 0.05 ? start : double.nan;

  @override
  double dx(double time) => time < 0.05 ? 0 : double.nan;

  @override
  bool isDone(double time) => !x(time).isNaN && time > 1e9;
}

class _Throws extends Motion {
  const _Throws();

  @override
  bool get needsSettle => false;

  @override
  Simulation createSimulation({
    double start = 0,
    double end = 1,
    double velocity = 0,
  }) =>
      _Throwing();

  @override
  bool operator ==(Object other) => other is _Throws;

  @override
  int get hashCode => (_Throws).hashCode;
}

class _Throwing extends Simulation {
  @override
  double x(double time) => time > 0.1 ? throw StateError('x') : 0;

  @override
  double dx(double time) => time > 0.1 ? throw StateError('dx') : 0;

  @override
  bool isDone(double time) => false;
}
