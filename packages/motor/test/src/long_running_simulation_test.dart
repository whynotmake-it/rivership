// ignore_for_file: cascade_invocations

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:motor/src/simulations/step_playback.dart';

double _seconds(Duration duration) => duration.inMicroseconds / 1e6;

Duration _duration(double seconds) =>
    Duration(microseconds: (seconds * 1e6).round());

StepPlayback<double> _playback(
  List<TrackStep<double>> steps, {
  LoopMode loop = LoopMode.none,
  double? velocity,
}) =>
    StepPlayback<double>(
      steps: steps,
      converter: MotionConverter.single,
      start: 0,
      velocity: velocity,
      loop: loop,
    );

/// About as many `isDone` calls as one sampled search makes: a 1/60 s grid
/// up to a minute, then doubling to two minutes.
const _searchCalls = 3610;

/// About as many `isDone` calls as playback's grid makes before it gives up:
/// 1/60 s steps up to a minute, then doubling up to a day.
const _gridCalls = 3620;

/// Counts `isDone` calls on every [_Scripted] simulation of one motion.
final class _Calls {
  int isDone = 0;
}

/// Ramps linearly from its start to its end over [arriveAt] seconds and
/// stays there. Whether it is done is scripted by [done], so it can finish
/// long after it arrives, never, or flicker.
class _Scripted extends Simulation {
  _Scripted(
    this.start,
    this.end, {
    required this.arriveAt,
    required this.done,
    required this.calls,
  });

  final double start;
  final double end;
  final double arriveAt;
  final bool Function(double time) done;
  final _Calls calls;

  @override
  double x(double time) => arriveAt <= 0
      ? end
      : start + (end - start) * (time / arriveAt).clamp(0.0, 1.0);

  @override
  double dx(double time) =>
      time < arriveAt && arriveAt > 0 ? (end - start) / arriveAt : 0;

  @override
  bool isDone(double time) {
    calls.isDone++;
    return done(time);
  }
}

/// A [_Scripted] simulation that reports [settlesAt], truthfully or not.
class _Reporting extends _Scripted with SettlingSimulation {
  _Reporting(
    super.start,
    super.end, {
    required super.arriveAt,
    required super.done,
    required super.calls,
    required this.settlesAt,
  });

  @override
  final Duration? settlesAt;
}

/// A motion whose simulations are [_Scripted], or [_Reporting] when
/// [reports] is true.
class _ScriptedMotion extends Motion {
  _ScriptedMotion({
    required this.done,
    this.reports = false,
    this.settlesAt,
  })  : arriveAt = 0.1,
        duration = null;

  /// Done from `seconds` on, and not before.
  _ScriptedMotion.doneAfter(
    double seconds, {
    this.reports = false,
    this.settlesAt,
  })  : done = ((time) => time >= seconds),
        arriveAt = 0.1,
        duration = null;

  /// Never done.
  _ScriptedMotion.never({
    this.arriveAt = 0.1,
    this.reports = false,
    this.duration,
  })  : done = ((_) => false),
        settlesAt = null;

  final bool Function(double time) done;
  final double arriveAt;
  final bool reports;
  final Duration? settlesAt;
  final calls = _Calls();

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
      reports
          ? _Reporting(
              start,
              end,
              arriveAt: arriveAt,
              done: done,
              calls: calls,
              settlesAt: settlesAt,
            )
          : _Scripted(start, end, arriveAt: arriveAt, done: done, calls: calls);

  @override
  bool operator ==(Object other) => identical(this, other);

  @override
  int get hashCode => identityHashCode(this);
}

/// A free motion that drifts at its start velocity forever and says so.
class _ReportedDrift extends FreeMotion {
  const _ReportedDrift({this.duration});

  @override
  final Duration? duration;

  @override
  Simulation createSimulation({double start = 0, double velocity = 0}) =>
      _DriftSimulation(start, velocity);

  @override
  bool operator ==(Object other) =>
      other is _ReportedDrift && other.duration == duration;

  @override
  int get hashCode => duration.hashCode;
}

class _DriftSimulation extends Simulation with SettlingSimulation {
  _DriftSimulation(this.start, this.velocity);

  final double start;
  final double velocity;

  @override
  Duration? get settlesAt => null;

  @override
  double x(double time) => start + velocity * time;

  @override
  double dx(double time) => velocity;

  @override
  bool isDone(double time) => false;
}

/// A spring without damping: it oscillates forever.
const _undamped = SpringMotion(
  SpringDescription(mass: 1, stiffness: 100, damping: 0),
  snapToEnd: false,
);

void main() {
  group('estimateSettle', () {
    test('finds a plain simulation that settles just inside two minutes', () {
      final motion = _ScriptedMotion.doneAfter(119.5);
      final settle = motion.createSimulation().estimateSettle();
      expect(_seconds(settle!), closeTo(119.5, 1e-6));
    });

    test('treats a plain simulation that settles later as never settling', () {
      for (final seconds in [120.001, 121.0, 3600.0]) {
        final motion = _ScriptedMotion.doneAfter(seconds);
        expect(
          motion.createSimulation().estimateSettle(),
          isNull,
          reason: '$seconds',
        );
      }
    });

    test('bounds the work for a plain simulation that never settles', () {
      final motion = _ScriptedMotion.never();
      expect(motion.createSimulation().estimateSettle(), isNull);
      expect(motion.calls.isDone, lessThanOrEqualTo(_searchCalls));
    });

    test('takes a reported time far past two minutes as it is', () {
      for (final settle in const [
        Duration(minutes: 3),
        Duration(hours: 1),
        Duration(days: 10),
        Duration(days: 365 * 1000),
      ]) {
        final motion = _ScriptedMotion.doneAfter(
          _seconds(settle),
          reports: true,
          settlesAt: settle,
        );
        expect(motion.createSimulation().estimateSettle(), settle);
        expect(motion.calls.isDone, lessThanOrEqualTo(3), reason: '$settle');
      }
    });

    test('trusts a reported never without asking isDone', () {
      // It even claims to be done all along.
      final motion = _ScriptedMotion(done: (_) => true, reports: true);
      expect(motion.createSimulation().estimateSettle(), isNull);
      expect(motion.calls.isDone, 0);
    });

    test('samples a simulation that reports too early', () {
      final motion = _ScriptedMotion.doneAfter(
        30,
        reports: true,
        settlesAt: const Duration(seconds: 1),
      );
      expect(
        _seconds(motion.createSimulation().estimateSettle()!),
        closeTo(30, 1e-6),
      );

      // Too early, and actually done only after the sampling gives up.
      final late = _ScriptedMotion.doneAfter(
        600,
        reports: true,
        settlesAt: const Duration(seconds: 1),
      );
      expect(late.createSimulation().estimateSettle(), isNull);
    });

    test('samples a simulation that reports a negative time', () {
      final motion = _ScriptedMotion.doneAfter(
        2,
        reports: true,
        settlesAt: const Duration(seconds: -5),
      );
      expect(
        _seconds(motion.createSimulation().estimateSettle()!),
        closeTo(2, 1e-6),
      );
    });

    test('keeps the reported end of a flickering simulation', () {
      // Done briefly at 0.5 s, then for good from 2 s.
      bool flickers(double t) => (t >= 0.5 && t < 0.6) || t >= 2;
      final reported = _ScriptedMotion(
        done: flickers,
        reports: true,
        settlesAt: const Duration(seconds: 2),
      );
      expect(
        reported.createSimulation().estimateSettle(),
        const Duration(seconds: 2),
      );
      // Sampling can only find the first time it is done.
      final sampled = _ScriptedMotion(done: flickers);
      expect(
        _seconds(sampled.createSimulation().estimateSettle()!),
        closeTo(0.5, 1e-6),
      );
    });
  });

  group('a step that settles late', () {
    test('ends exactly where a simulation settling after an hour says', () {
      const settle = Duration(hours: 1);
      final motion = _ScriptedMotion.doneAfter(
        3600,
        reports: true,
        settlesAt: settle,
      );
      final playback = _playback([TrackStep.to(1, motion: motion)]);
      for (var t = 0.0; t < 5; t += 1 / 60) {
        playback.advanceTo(t);
      }
      playback.advanceTo(3599.999);
      expect(playback.isDone, isFalse);
      playback.advanceTo(3600);
      expect(playback.isDone, isTrue);
      expect(playback.forwardSegmentSeconds.single, 3600);
      expect(playback.values.single, 1);
    });

    test('ends where a plain simulation settling after 100 s is done', () {
      final motion = _ScriptedMotion.doneAfter(100);
      final playback = _playback([
        TrackStep.to(1, motion: motion),
        const TrackStep.to(0, motion: Motion.linear(Duration(seconds: 1))),
      ]);
      for (var t = 0.0; t < 2; t += 1 / 60) {
        playback.advanceTo(t);
      }
      playback.advanceTo(99.9);
      expect(playback.currentStepIndex, 0);
      playback.advanceTo(100.5);
      expect(playback.currentStepIndex, 1);
      expect(playback.forwardSegmentSeconds.first, closeTo(100, 1e-6));
    });

    test('never ends for a plain simulation done only after two minutes', () {
      // Its isDone turns true at 150 s, but sampling gives up at 120 s, so
      // the step counts as never settling. Reporting settlesAt is the fix.
      final plain = _ScriptedMotion.doneAfter(150);
      final playback = _playback([TrackStep.to(1, motion: plain)]);
      for (final t in [1.0, 149.0, 151.0, 86400.0, 1e7]) {
        playback.advanceTo(t);
        expect(playback.isDone, isFalse, reason: '$t');
      }
      expect(playback.values.single, 1);

      final reported = _ScriptedMotion.doneAfter(
        150,
        reports: true,
        settlesAt: const Duration(seconds: 150),
      );
      final ends = _playback([TrackStep.to(1, motion: reported)])
        ..advanceTo(150);
      expect(ends.isDone, isTrue);
    });

    test('a hold of a year after it still ends on time', () {
      const year = Duration(days: 365);
      final playback = _playback([
        TrackStep.to(
          1,
          motion: _ScriptedMotion.doneAfter(
            10,
            reports: true,
            settlesAt: const Duration(seconds: 10),
          ),
        ),
        const TrackStep.hold(year),
        const TrackStep.to(0, motion: Motion.linear(Duration(seconds: 1))),
      ]);
      final holdEnds = 10 + _seconds(year);
      playback.advanceTo(holdEnds - 1);
      expect(playback.currentStepIndex, 1);
      playback.advanceTo(holdEnds + 0.5);
      expect(playback.currentStepIndex, 2);
      expect(playback.values.single, closeTo(0.5, 1e-6));
      // A curve is done just after its duration.
      playback.advanceTo(holdEnds + 1.001);
      expect(playback.isDone, isTrue);
    });
  });

  group('a step that never settles', () {
    test('asks a plain simulation a bounded number of times, ever', () {
      final motion = _ScriptedMotion.never();
      final playback = _playback([TrackStep.to(1, motion: motion)]);
      for (var t = 0.0; t < 70; t += 1 / 60) {
        playback.advanceTo(t);
      }
      for (final t in [1e3, 1e4, 86400.0, 1e6]) {
        playback.advanceTo(t);
      }
      // The grid up to a day, then one sampled search.
      expect(
        motion.calls.isDone,
        lessThanOrEqualTo(_gridCalls + _searchCalls),
      );
      final calls = motion.calls.isDone;
      for (final t in [2e6, 1e9, 1e12]) {
        playback.advanceTo(t);
      }
      expect(motion.calls.isDone, calls);
      expect(playback.isDone, isFalse);
      expect(playback.values.single, 1);
    });

    test('asks a simulation reporting never a bounded number of times', () {
      final motion = _ScriptedMotion.never(reports: true);
      final playback = _playback([TrackStep.to(1, motion: motion)]);
      for (var t = 0.0; t < 70; t += 1 / 60) {
        playback.advanceTo(t);
      }
      playback.advanceTo(1e6);
      expect(motion.calls.isDone, lessThanOrEqualTo(_gridCalls));
      final calls = motion.calls.isDone;
      playback.advanceTo(1e9);
      expect(motion.calls.isDone, calls);
    });

    test('keeps running when it reports never though isDone says done', () {
      final motion = _ScriptedMotion(done: (_) => true, reports: true);
      final playback = _playback([
        TrackStep.to(1, motion: motion),
        const TrackStep.to(0, motion: Motion.linear(Duration(seconds: 1))),
      ]);
      for (final t in [0.0, 0.05, 1.0, 1e5]) {
        playback.advanceTo(t);
      }
      expect(playback.currentStepIndex, 0);
      expect(playback.values.single, 1);
    });

    test('hands over at its duration however long it would run', () {
      final motion = _ScriptedMotion.never(
        reports: true,
        duration: const Duration(milliseconds: 300),
      );
      final playback = _playback([
        TrackStep.to(1, motion: motion, until: WaitUntil.duration),
        const TrackStep.to(0, motion: Motion.linear(Duration(seconds: 1))),
      ])
        ..advanceTo(2);
      expect(playback.forwardSegmentSeconds.first, 0.3);
      expect(playback.isDone, isTrue);
    });

    test('a free step with a duration hands over at it', () {
      final moving = _playback(
        const [
          TrackStep.free(
            motion: _ReportedDrift(duration: Duration(milliseconds: 500)),
            until: WaitUntil.duration,
          ),
          TrackStep.to(0, motion: Motion.linear(Duration(seconds: 1))),
        ],
        velocity: 2,
      )..advanceTo(0.5);
      expect(moving.currentStepIndex, 1);
      expect(moving.values.single, closeTo(1, 1e-9));
      // A curve is done just after its duration.
      moving.advanceTo(1.501);
      expect(moving.isDone, isTrue);
      expect(moving.values.single, 0);

      // Without a duration it coasts on, whatever follows.
      final coasting = _playback(
        const [
          TrackStep.free(motion: _ReportedDrift()),
          TrackStep.to(0, motion: Motion.linear(Duration(seconds: 1))),
        ],
        velocity: 2,
      )..advanceTo(1e6);
      expect(coasting.currentStepIndex, 0);
      expect(coasting.values.single, closeTo(2e6, 1e-3));
    });

    test('a keyframe after it still lands on time', () {
      for (final motion in [
        _ScriptedMotion.never(arriveAt: 5),
        _ScriptedMotion.never(arriveAt: 5, reports: true),
      ]) {
        final playback = _playback([
          TrackStep.to(10, motion: motion),
          const TrackStep.at(
            Duration(seconds: 2),
            -1,
            motion: Motion.linear(Duration(milliseconds: 500)),
          ),
        ])
          ..advanceTo(1.5);
        expect(playback.currentStepIndex, 1, reason: '${motion.reports}');
        playback.advanceTo(2);
        expect(playback.values.single, -1, reason: '${motion.reports}');
      }
    });

    test('as a keyframe motion, still lands on time', () {
      for (final motion in [
        _ScriptedMotion.never(arriveAt: 5),
        _ScriptedMotion.never(arriveAt: 5, reports: true),
      ]) {
        final playback = _playback([
          const TrackStep.to(1, motion: Motion.linear(Duration(seconds: 1))),
          TrackStep.at(const Duration(seconds: 3), -1, motion: motion),
        ])
          ..advanceTo(2.999);
        expect(playback.values.single, isNot(-1));
        playback.advanceTo(3);
        expect(playback.values.single, -1, reason: '${motion.reports}');
        expect(playback.isDone, isTrue);
      }
    });

    test('seeking far ahead matches the simulation, however far', () {
      final playback = _playback([const TrackStep.to(1, motion: _undamped)]);
      final simulation = _undamped.createSimulation();
      for (final t in [1e3, 1e5, 1e7]) {
        final sought = _playback([const TrackStep.to(1, motion: _undamped)])
          ..advanceTo(t);
        playback.advanceTo(t);
        expect(sought.values.single, playback.values.single, reason: '$t');
        expect(
          playback.values.single,
          closeTo(simulation.x(t), 1e-6),
          reason: '$t',
        );
      }
    });
  });

  group('a loop that never repeats exactly', () {
    // An undamped spring hands over mid-swing, so no two cycles start in the
    // same state and the loop can't fold into a period.
    final steps = [
      const TrackStep<double>.to(
        1,
        motion: _undamped,
        until: WaitUntil.duration,
      ),
      const TrackStep<double>.to(
        0,
        motion: _undamped,
        until: WaitUntil.duration,
      ),
    ];

    test('one jump far ahead shows what ticking there shows', () {
      const target = 3000.0;
      final jumped = _playback(steps, loop: LoopMode.loop)..advanceTo(target);
      final ticked = _playback(steps, loop: LoopMode.loop);
      for (var t = 0.0; t < target; t += 7.3) {
        ticked.advanceTo(t);
      }
      ticked.advanceTo(target);
      expect(jumped.loopPeriodSeconds, isNull);
      expect(jumped.values.single, closeTo(ticked.values.single, 1e-9));
      expect(jumped.currentStepIndex, ticked.currentStepIndex);
      expect(jumped.cycle, ticked.cycle);
    });

    test('keeps a bounded number of segments over a long run', () {
      // The first cycles are kept while it tries to fold. After that only
      // the last two are, however long it runs.
      final playback = _playback(steps, loop: LoopMode.loop);
      for (var t = 1.0; t < 1e5; t *= 1.37) {
        playback.advanceTo(t);
        expect(
          playback.debugSegmentCount,
          lessThanOrEqualTo(t < 100 ? 32 : 8),
          reason: '$t',
        );
      }
    });

    test('random schedules of ticks and jumps agree with one jump', () {
      final random = math.Random(7);
      for (var trial = 0; trial < 5; trial++) {
        final target = 50 + random.nextDouble() * 500;
        final scheduled = _playback(steps, loop: LoopMode.pingPong);
        var t = 0.0;
        while (t < target) {
          t = math.min(target, t + random.nextDouble() * 40);
          scheduled.advanceTo(t);
        }
        final jumped = _playback(steps, loop: LoopMode.pingPong)
          ..advanceTo(target);
        expect(
          scheduled.values.single,
          closeTo(jumped.values.single, 1e-9),
          reason: 'trial $trial at $target',
        );
      }
    });
  });

  group('wrappers around motions that never settle', () {
    test('create simulations with bounded work', () {
      final motion = _ScriptedMotion.never();
      final wrapped = <Motion>[
        motion.scaleTo(const Duration(seconds: 1)),
        motion.trimmed(fromStart: 0.2, fromEnd: 0.2),
        motion.scaleTo(const Duration(seconds: 1)).trimmed(fromEnd: 0.5),
        motion.trimmed(fromEnd: 0.5).scaleTo(const Duration(seconds: 1)),
      ];
      for (final wrapper in wrapped) {
        final before = motion.calls.isDone;
        final simulation = wrapper.createSimulation(end: 10);
        // Each wrapper level samples its parent at most once.
        expect(
          motion.calls.isDone - before,
          lessThanOrEqualTo(2 * _searchCalls),
          reason: '$wrapper',
        );
        // And the result is usable at any time.
        for (final t in [0.0, 0.5, 1.0, 1e6]) {
          expect(simulation.x(t).isFinite, isTrue, reason: '$wrapper at $t');
        }
      }
    });

    test('reported nevers pass through without sampling', () {
      final motion = _ScriptedMotion.never(
        reports: true,
        duration: const Duration(milliseconds: 400),
      );
      final scaled = motion.scaleTo(const Duration(milliseconds: 200));
      final simulation = scaled.createSimulation(end: 10) as SettlingSimulation;
      expect(simulation.settlesAt, isNull);
      expect(motion.calls.isDone, 0);
    });

    test('a scaled never-settling step still hands over at its duration', () {
      final scaled = _undamped.scaleTo(const Duration(milliseconds: 250));
      final playback = _playback([
        TrackStep.to(1, motion: scaled, until: WaitUntil.duration),
        const TrackStep.to(0, motion: Motion.linear(Duration(seconds: 1))),
      ])
        // A curve is done just after its duration.
        ..advanceTo(1.251);
      expect(playback.forwardSegmentSeconds.first, 0.25);
      expect(playback.isDone, isTrue);
    });
  });

  group('controllers', () {
    testWidgets('a future completes when a slow simulation settles',
        (tester) async {
      final track = Track<double>(MotionConverter.single, initial: 0);
      final controller = TrackController(vsync: tester);
      addTearDown(controller.dispose);
      final motion = _ScriptedMotion.doneAfter(
        90,
        reports: true,
        settlesAt: const Duration(seconds: 90),
      );
      var completed = false;
      unawaited(
        controller
            .animate([track.to(1, motion: motion)])
            .orCancel
            .then((_) => completed = true, onError: (_) {}),
      );
      await tester.pump();
      for (var i = 0; i < 89; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(completed, isFalse);
      expect(controller.isAnimating, isTrue);
      await tester.pump(const Duration(seconds: 2));
      expect(completed, isTrue);
      expect(controller.isAnimating, isFalse);
      expect(controller.status, AnimationStatus.completed);
    });

    testWidgets('a scrub far past a never-settling step shows its value',
        (tester) async {
      final track = Track<double>(MotionConverter.single, initial: 0);
      final controller = TrackController(vsync: tester);
      addTearDown(controller.dispose);
      unawaited(
        controller.animate([track.to(1, motion: _undamped)]).orCancel.then(
              (_) {},
              onError: (_) {},
            ),
      );
      await tester.pump();
      final simulation = _undamped.createSimulation();
      for (final t in [10.0, 3600.0, 86400.0]) {
        controller.scrubTo(_duration(t));
        expect(
          controller.value(track),
          closeTo(simulation.x(t), 1e-6),
          reason: '$t',
        );
      }
      controller.resume();
      await tester.pump(const Duration(seconds: 1));
      expect(controller.isAnimating, isTrue);
      unawaited(controller.stop(canceled: true));
      await tester.pump();
      expect(controller.isAnimating, isFalse);
    });

    testWidgets('a ticker that jumps a day ahead in a loop catches up',
        (tester) async {
      final track = Track<double>(MotionConverter.single, initial: 0);
      final controller = TrackController(vsync: tester);
      addTearDown(controller.dispose);
      const steps = [
        TrackStep<double>.to(1, motion: _undamped, until: WaitUntil.duration),
        TrackStep<double>.to(0, motion: _undamped, until: WaitUntil.duration),
      ];
      unawaited(
        controller
            .animate([track(steps)], loop: LoopMode.loop)
            .orCancel
            .then((_) {}, onError: (_) {}),
      );
      await tester.pump();
      // One frame a day later: the ticker delivers the whole gap at once.
      await tester.pump(const Duration(days: 1));
      final expected = _playback(steps, loop: LoopMode.loop);
      for (var t = 0.0; t < 86400; t += 60) {
        expected.advanceTo(t);
      }
      expected.advanceTo(86400);
      expect(controller.value(track), closeTo(expected.values.single, 1e-6));
      unawaited(controller.stop(canceled: true));
      await tester.pump();
    });
  });
}
