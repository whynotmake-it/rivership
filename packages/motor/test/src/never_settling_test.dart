import 'dart:async';

import 'package:flutter/animation.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:motor/src/simulations/step_playback.dart';

import 'util.dart';

double _seconds(Duration duration) => duration.inMicroseconds / 1e6;

StepPlayback<double> _playback(
  List<TrackStep<double>> steps, {
  LoopMode loop = LoopMode.none,
}) =>
    StepPlayback<double>(
      steps: steps,
      converter: MotionConverter.single,
      start: 0,
      loop: loop,
    );

/// A spring without damping: it oscillates forever.
const _undamped = SpringMotion(
  SpringDescription(mass: 1, stiffness: 100, damping: 0),
  snapToEnd: false,
);

/// Moves toward its target at a constant speed and overshoots forever: no
/// duration and no [SettlingSimulation].
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
      _DriftSimulation(start, end > start ? 1 : -1);

  @override
  bool operator ==(Object other) => other is _Drift;

  @override
  int get hashCode => (_Drift).hashCode;
}

class _DriftSimulation extends Simulation {
  _DriftSimulation(this.start, this.speed);

  final double start;
  final double speed;

  @override
  double x(double time) => start + speed * time;

  @override
  double dx(double time) => speed;

  @override
  bool isDone(double time) => false;
}

/// A spring motion whose simulation has no [SettlingSimulation], so its step
/// lasts until it is done, found by sampling.
class _PlainSpring extends Motion {
  const _PlainSpring();

  static const _spring = SpringDescription(
    mass: 1,
    stiffness: 200,
    damping: 18,
  );

  @override
  bool get needsSettle => true;

  @override
  Simulation createSimulation({
    double start = 0,
    double end = 1,
    double velocity = 0,
  }) =>
      SpringSimulation(_spring, start, end, velocity);

  @override
  bool operator ==(Object other) => other is _PlainSpring;

  @override
  int get hashCode => (_PlainSpring).hashCode;
}

/// Falls forever.
class _Gravity extends FreeMotion {
  const _Gravity();

  @override
  Simulation createSimulation({double start = 0, double velocity = 0}) =>
      GravitySimulation(-9.8, start, 1e12, velocity);

  @override
  bool operator ==(Object other) => other is _Gravity;

  @override
  int get hashCode => (_Gravity).hashCode;
}

/// The first time [simulation] is done, on a 1e-5 s grid.
double _firstDone(Simulation simulation) {
  var t = 0.0;
  while (!simulation.isDone(t)) {
    t += 1e-5;
  }
  return t;
}

void main() {
  group('settlingDuration', () {
    test('is null for motions that never settle', () {
      expect(_undamped.settlingDuration(), isNull);
      expect(_undamped.duration, isNotNull);
      expect(const _Drift().settlingDuration(), isNull);
      expect(const _Gravity().settlingDuration(velocity: 3), isNull);
    });

    test('the default samples a custom motion to its end', () {
      const motion = _PlainSpring();
      final settle = motion.settlingDuration(end: 300, velocity: -800)!;
      final simulation = motion.createSimulation(end: 300, velocity: -800);
      expect(_seconds(settle), closeTo(_firstDone(simulation), 2e-5));
      expect(simulation.isDone(_seconds(settle)), isTrue);

      const friction = FreeMotion.friction();
      final coast = friction.settlingDuration(start: 4, velocity: 100)!;
      final coasting = friction.createSimulation(start: 4, velocity: 100);
      expect(_seconds(coast), closeTo(_firstDone(coasting), 2e-5));
    });

    test('a step with a custom motion ends where it settles', () {
      const motion = _PlainSpring();
      final settle = _seconds(motion.settlingDuration(end: 300)!);
      final playback = _playback([const TrackStep.to(300, motion: motion)])
        ..advanceTo(settle - 1e-3);
      expect(playback.isDone, isFalse);
      playback.advanceTo(settle);
      expect(playback.isDone, isTrue);
    });
  });

  group('a motion that never settles', () {
    test('hands over at its duration in the middle of a plan', () {
      final playback = _playback([
        const TrackStep.to(1, motion: _undamped),
        const TrackStep.to(0, motion: CupertinoMotion.snappy()),
      ])
        ..advanceTo(1);
      expect(
        playback.forwardSegmentSeconds.first,
        _seconds(_undamped.duration!),
      );
      expect(playback.currentStepIndex, 1);
    });

    test('without a duration, keeps a middle step running', () {
      final playback = _playback([
        const TrackStep.to(1, motion: _Drift()),
        const TrackStep.to(0, motion: CupertinoMotion.snappy()),
      ])
        ..advanceTo(500);
      expect(playback.currentStepIndex, 0);
      expect(playback.values.single, closeTo(500, 1e-9));
      expect(playback.segmentsView.last.end, isNull);
      expect(playback.isDone, isFalse);
    });

    test('keeps a last step running past any horizon', () {
      final playback = _playback([const TrackStep.to(1, motion: _undamped)]);
      for (final t in [10.0, 200.0, 86400.0, 200000.0]) {
        playback.advanceTo(t);
        expect(playback.isDone, isFalse, reason: '$t');
        expect(playback.segmentsView.last.end, isNull, reason: '$t');
        final simulation = _undamped.createSimulation();
        expect(playback.values.single, closeTo(simulation.x(t), 1e-6));
      }
    });

    test('keeps a free step running', () {
      final playback = _playback([
        const TrackStep.free(motion: _Gravity()),
        const TrackStep.to(0, motion: CupertinoMotion.snappy()),
      ])
        ..advanceTo(300);
      expect(playback.currentStepIndex, 0);
      expect(playback.isDone, isFalse);
    });

    test('ticking and seeking agree', () {
      final steps = <TrackStep<double>>[
        const TrackStep.to(1, motion: _undamped),
        const TrackStep.hold(Duration(milliseconds: 200)),
        const TrackStep.to(-1, motion: _Drift()),
        const TrackStep.to(0, motion: CupertinoMotion.snappy()),
      ];
      final ticked = _playback(steps);
      for (var t = 0.0; t <= 4; t += 1 / 120) {
        ticked.advanceTo(t);
        final sought = _playback(steps)..advanceTo(t);
        expect(sought.values.single, ticked.values.single, reason: '$t');
        expect(sought.currentStepIndex, ticked.currentStepIndex);
      }
    });

    test('in a loop that can never repeat asserts', () {
      expect(
        () => _playback(
          const [TrackStep.free(motion: _Gravity())],
          loop: LoopMode.loop,
        ),
        throwsAssertionError,
      );
      expect(
        () => _playback(
          const [TrackStep.to(1, motion: _undamped, untilSettled: true)],
          loop: LoopMode.pingPong,
        ),
        throwsAssertionError,
      );
      // With a duration, the loop hands over and repeats.
      expect(
        () => _playback(
          const [TrackStep.to(1, motion: _undamped)],
          loop: LoopMode.loop,
        ).advanceTo(10),
        returnsNormally,
      );
    });

    testWidgets('keeps the controller animating; its future never completes',
        (tester) async {
      final track = Track<double>(MotionConverter.single, initial: 0);
      final controller = TrackController(vsync: tester);
      addTearDown(controller.dispose);
      var completed = false;
      unawaited(
        controller
            .animate([track.to(1, motion: _undamped)])
            .orCancel
            .then((_) => completed = true, onError: (_) {}),
      );
      for (var i = 0; i < 300; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(controller.isAnimating, isTrue);
      expect(completed, isFalse);
      expect(controller.status, AnimationStatus.forward);
      unawaited(controller.stop(canceled: true));
      await tester.pump();
      expect(controller.isAnimating, isFalse);
    });
  });

  group('wrappers', () {
    test('scaleTo paces a never-settling parent by its step', () {
      final scaled = _undamped
          .scaleTo(const Duration(seconds: 1))
          .createSimulation() as SettlingSimulation;
      final parent = _undamped.createSimulation();
      final factor = _seconds(_undamped.duration!);
      expect(scaled.x(0.5), closeTo(parent.x(0.5 * factor), 1e-9));
      expect(
        _undamped.scaleTo(const Duration(seconds: 1)).duration,
        const Duration(seconds: 1),
      );
      expect(scaled.settlesAt, isNull);
    });

    test('scaleTo plays a parent without timing at its own speed', () {
      final scaled =
          const _Drift().scaleTo(const Duration(seconds: 1)).createSimulation();
      final parent = const _Drift().createSimulation();
      expect(scaled.x(0.5), closeTo(parent.x(0.5), 1e-9));
    });

    test(
        'trimmed takes the slice from the duration of a never-settling '
        'parent', () {
      final trimmed = _undamped.trimmed(fromEnd: 0.5);
      final expected =
          _seconds(_undamped.duration!) * 0.5 - _undamped.tolerance.time;
      expect(
        _seconds(trimmed.settlingDuration()!),
        closeTo(expected, 1e-6),
      );
      final simulation = trimmed.createSimulation();
      expect(simulation.isDone(expected + 1e-6), isTrue);
      expect(simulation.isDone(expected - 1e-3), isFalse);
    });
  });
}
