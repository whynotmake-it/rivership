import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

/// The seed fuzz tests start from. Override it to explore other plans:
/// `flutter test --dart-define=MOTOR_FUZZ_SEED=123 test/src/adversarial`.
const fuzzSeed = int.fromEnvironment('MOTOR_FUZZ_SEED', defaultValue: 20260929);

/// How many generated cases each fuzz test runs, scaled by
/// `--dart-define=MOTOR_FUZZ_SCALE=10` for longer local hunts.
const fuzzScale = int.fromEnvironment('MOTOR_FUZZ_SCALE', defaultValue: 1);

/// Prints every case seed before it runs, to find one that hangs:
/// `--dart-define=MOTOR_FUZZ_VERBOSE=true`.
const fuzzVerbose = bool.fromEnvironment('MOTOR_FUZZ_VERBOSE');

/// Runs [body] for one generated case, naming the seed that reproduces it
/// when it fails.
void runCase(int seed, String Function() describe, void Function() body) {
  // ignore: avoid_print
  if (fuzzVerbose) print('case $seed\n${describe()}');
  try {
    body();
  } on Object catch (error, stack) {
    printOnFailure(
      'Reproduce with --dart-define=MOTOR_FUZZ_SEED=$seed '
      '(case seed $seed)\n${describe()}',
    );
    Error.throwWithStackTrace(error, stack);
  }
}

/// Async variant of [runCase].
Future<void> runCaseAsync(
  int seed,
  String Function() describe,
  Future<void> Function() body,
) async {
  // ignore: avoid_print
  if (fuzzVerbose) print('case $seed\n${describe()}');
  try {
    await body();
  } on Object catch (error, stack) {
    printOnFailure(
      'Reproduce with --dart-define=MOTOR_FUZZ_SEED=$seed '
      '(case seed $seed)\n${describe()}',
    );
    Error.throwWithStackTrace(error, stack);
  }
}

/// What a motion in the fuzz pool is known to do, so invariants can skip
/// the moments where a jump or a velocity reset is by design.
final class MotionTraits {
  const MotionTraits({
    this.jumps = false,
    this.keepsVelocity = false,
    this.settlesOnTarget = true,
    this.settles = true,
    this.needsSettle = false,
    this.flickers = false,
  });

  /// Moves discontinuously at some point (no motion, zero length).
  final bool jumps;

  /// Starts from the velocity it is given.
  final bool keepsVelocity;

  /// Ends its step on its target, at rest, when the step waits to settle.
  final bool settlesOnTarget;

  /// Settles at all.
  final bool settles;

  /// A graceful stop settles it (springs).
  final bool needsSettle;

  /// Its `isDone` turns true and false again. Mixed with other motions in
  /// one step, where the step ends depends on how far playback resolved
  /// (see the skipped look-ahead regression test), so the fuzzers keep it
  /// out of per-dimension steps.
  final bool flickers;
}

const _linear100 = Motion.linear(Duration(milliseconds: 100));

/// A spring without damping: it oscillates forever.
const undampedSpring = SpringMotion(
  SpringDescription(mass: 1, stiffness: 100, damping: 0),
  snapToEnd: false,
);

/// Target motions the fuzzers draw from, with what each is known to do.
final Map<Motion, MotionTraits> targetMotions = {
  _linear100: const MotionTraits(),
  const Motion.linear(Duration.zero): const MotionTraits(jumps: true),
  // Flutter's Cubic curves are only solved to within 0.001 of their input,
  // so they jump by up to about their slope times that at their ends; exact
  // curves keep continuity checks tight.
  const Motion.curved(Duration(milliseconds: 250), Curves.decelerate):
      const MotionTraits(),
  const Motion.curved(Duration(milliseconds: 300), OvershootCurve()):
      const MotionTraits(),
  // Holds where it started, so a keyframe with it snaps on arrival.
  const Motion.none(Duration(milliseconds: 40)): const MotionTraits(
    jumps: true,
    settlesOnTarget: false,
  ),
  const Motion.none(): const MotionTraits(jumps: true, settlesOnTarget: false),
  const Motion.smoothSpring(): const MotionTraits(
    keepsVelocity: true,
    needsSettle: true,
  ),
  const Motion.bouncySpring(duration: Duration(milliseconds: 300)):
      const MotionTraits(keepsVelocity: true, needsSettle: true),
  const CupertinoMotion(duration: Duration(milliseconds: 200), bounce: -0.5):
      const MotionTraits(keepsVelocity: true, needsSettle: true),
  const CupertinoMotion(
    duration: Duration(milliseconds: 400),
    bounce: 0.5,
    snapToEnd: false,
  ): const MotionTraits(keepsVelocity: true, needsSettle: true),
  const Motion.snappySpring().scaleTo(const Duration(milliseconds: 200)):
      const MotionTraits(keepsVelocity: true, needsSettle: true),
  const Motion.bouncySpring().scaleTo(Duration.zero): const MotionTraits(
    jumps: true,
  ),
  const Motion.bouncySpring(duration: Duration(milliseconds: 300))
      .trimmed(fromStart: 0.2, fromEnd: 0.1): const MotionTraits(),
  const Motion.curved(Duration(milliseconds: 200), Curves.decelerate)
      .trimmed(fromStart: 0.3): const MotionTraits(),
  _linear100.scaleTo(const Duration(milliseconds: 170)): const MotionTraits(),
  const ReportingMotion(): const MotionTraits(),
  const PlainMotion(): const MotionTraits(),
  const RestartingMotion(): const MotionTraits(),
  const FlickeringMotion(): const MotionTraits(
    settlesOnTarget: false,
    flickers: true,
  ),
  const LateReportingMotion(): const MotionTraits(),
  const EarlyReportingMotion(): const MotionTraits(),
  undampedSpring: const MotionTraits(
    keepsVelocity: true,
    settles: false,
    settlesOnTarget: false,
  ),
  const DriftMotion(duration: Duration(milliseconds: 150)): const MotionTraits(
    settles: false,
    settlesOnTarget: false,
  ),
};

/// Free motions the fuzzers draw from.
final Map<FreeMotion, MotionTraits> freeMotions = {
  const FrictionMotion(drag: 0.05): const MotionTraits(keepsVelocity: true),
  // Scales its start velocity along with time, by design.
  const FrictionMotion(drag: 0.05).scaleTo(const Duration(milliseconds: 300)):
      const MotionTraits(),
  const FreeDrift(duration: Duration(milliseconds: 120)): const MotionTraits(
    keepsVelocity: true,
    settles: false,
  ),
  const FreeDrift(): const MotionTraits(keepsVelocity: true, settles: false),
};

MotionTraits traitsOf(MotionBase motion) =>
    targetMotions[motion] ?? freeMotions[motion] ?? const MotionTraits();

/// Whether playback can loop a step with [motion] under [until]: a step that
/// never settles has to hand over at a duration.
bool loopsWith(MotionBase motion, WaitUntil until) =>
    traitsOf(motion).settles ||
    (until == WaitUntil.duration && motion.duration != null);

/// Random plans for one track: steps, motions and keyframe times.
final class PlanGenerator {
  PlanGenerator(
    this.random, {
    required this.loop,
    this.tokens = const [#barrier],
    this.maxSteps = 6,
    this.keyframes = true,
  });

  final math.Random random;
  final LoopMode loop;
  final List<Object> tokens;
  final int maxSteps;

  /// Whether to include `.at` steps.
  final bool keyframes;

  late final _targets = targetMotions.keys.toList();
  late final _frees = freeMotions.keys.toList();

  T pick<T>(List<T> list) => list[random.nextInt(list.length)];

  double value() => (random.nextDouble() * 4 - 2).roundToDouble() / 2;

  WaitUntil until() =>
      random.nextBool() ? WaitUntil.duration : WaitUntil.settled;

  Motion targetMotion({
    required WaitUntil until,
    bool forKeyframe = false,
    bool perDimension = false,
  }) {
    while (true) {
      final motion = pick(_targets);
      if (perDimension && traitsOf(motion).flickers) continue;
      if (!loop.isLooping) return motion;
      if (forKeyframe ? traitsOf(motion).settles : loopsWith(motion, until)) {
        return motion;
      }
    }
  }

  FreeMotion freeMotion({required WaitUntil until}) {
    while (true) {
      final motion = pick(_frees);
      if (!loop.isLooping || loopsWith(motion, until)) return motion;
    }
  }

  /// Steps for a converter of [dimensions] values, built by [make] from the
  /// per-dimension values.
  List<TrackStep<T>> steps<T extends Object>(
    int dimensions,
    T Function(List<double> values) make, {
    bool allowFallback = false,
  }) {
    final steps = <TrackStep<T>>[];
    var earliest = 0.0;
    var lastAt = 0.0;
    final count = 1 + random.nextInt(maxSteps);
    for (var i = 0; i < count; i++) {
      final target = make([for (var d = 0; d < dimensions; d++) value()]);
      switch (random.nextInt(10)) {
        case 0 || 1 || 2:
          final wait = until();
          final perDimension = dimensions > 1 && random.nextInt(3) == 0;
          if (allowFallback && random.nextInt(5) == 0) {
            steps.add(TrackStep.to(target, until: wait));
          } else if (perDimension) {
            steps.add(
              TrackStep.to(
                target,
                motionPerDimension: [
                  for (var d = 0; d < dimensions; d++)
                    // Dimensions hand over together only if all have a
                    // duration, so a loop needs every one to settle.
                    targetMotion(until: WaitUntil.settled, perDimension: true),
                ],
                until: wait,
              ),
            );
          } else {
            steps.add(
              TrackStep.to(
                target,
                motion: targetMotion(until: wait),
                until: wait,
              ),
            );
          }
        case 3:
          final microseconds = pick([0, 1, 30000, 120000]);
          earliest += microseconds / 1e6;
          steps.add(TrackStep.hold(Duration(microseconds: microseconds)));
        case 4 || 5 when keyframes:
          // Sometimes at the same time as the previous keyframe, or as soon
          // as the holds before it allow.
          final at = switch (random.nextInt(4)) {
            0 => math.max(earliest, lastAt),
            _ => math.max(earliest, lastAt) + random.nextDouble() * 0.6,
          };
          lastAt = at;
          earliest = math.max(earliest, at);
          steps.add(
            TrackStep.at(
              Duration(microseconds: (at * 1e6).ceil()),
              target,
              motion: targetMotion(until: WaitUntil.settled, forKeyframe: true),
            ),
          );
        case 6:
          if (tokens.isEmpty) continue;
          steps.add(TrackStep.sync(token: pick(tokens)));
        case 7:
          final wait = until();
          steps.add(
            TrackStep.free(motion: freeMotion(until: wait), until: wait),
          );
        default:
          final wait = until();
          steps.add(
            TrackStep.to(
              target,
              motion: targetMotion(until: wait),
              until: wait,
            ),
          );
      }
    }
    if (steps.isEmpty) {
      steps.add(
        TrackStep.to(
          make(List.filled(dimensions, 1)),
          motion: _linear100,
        ),
      );
    }
    return steps;
  }
}

String describeSteps(List<TrackStep<Object>> steps) =>
    steps.map((step) => '  $step').join('\n');

bool isFiniteValue(double value) => value.isFinite;

/// Overshoots its end by about 17 % and comes back, continuous at both ends,
/// unlike `Curves.elasticOut` (which jumps by 2^-10 at 1).
class OvershootCurve extends Curve {
  const OvershootCurve();

  @override
  double transformInternal(double t) => t + 0.6 * math.sin(math.pi * t);
}

// ---------------------------------------------------------------------------
// Custom and lying simulations.
// ---------------------------------------------------------------------------

/// Ramps linearly to its end over 0.2 s and says so.
class ReportingMotion extends Motion {
  const ReportingMotion();

  @override
  bool get needsSettle => false;

  @override
  Simulation createSimulation({
    double start = 0,
    double end = 1,
    double velocity = 0,
  }) =>
      _Ramp(start, end, arrive: 0.2, reports: 0.2);

  @override
  bool operator ==(Object other) => other is ReportingMotion;

  @override
  int get hashCode => (ReportingMotion).hashCode;
}

/// Ramps to its end over 0.1 s but claims to settle at 0.4 s.
class LateReportingMotion extends Motion {
  const LateReportingMotion();

  @override
  bool get needsSettle => false;

  @override
  Simulation createSimulation({
    double start = 0,
    double end = 1,
    double velocity = 0,
  }) =>
      _Ramp(start, end, arrive: 0.1, reports: 0.4);

  @override
  bool operator ==(Object other) => other is LateReportingMotion;

  @override
  int get hashCode => (LateReportingMotion).hashCode;
}

/// Ramps to its end over 0.3 s but claims to settle at 0.05 s.
class EarlyReportingMotion extends Motion {
  const EarlyReportingMotion();

  @override
  bool get needsSettle => false;

  @override
  Simulation createSimulation({
    double start = 0,
    double end = 1,
    double velocity = 0,
  }) =>
      _Ramp(start, end, arrive: 0.3, reports: 0.05);

  @override
  bool operator ==(Object other) => other is EarlyReportingMotion;

  @override
  int get hashCode => (EarlyReportingMotion).hashCode;
}

class _Ramp extends Simulation with SettlingSimulation {
  _Ramp(this.start, this.end, {required this.arrive, required this.reports});

  final double start;
  final double end;
  final double arrive;
  final double reports;

  @override
  Duration get settlesAt => Duration(microseconds: (reports * 1e6).round());

  @override
  double x(double time) =>
      start + (end - start) * (time / arrive).clamp(0.0, 1.0);

  @override
  double dx(double time) => time < arrive ? (end - start) / arrive : 0;

  @override
  bool isDone(double time) => time >= arrive;
}

/// Approaches its end exponentially, without [SettlingSimulation], so
/// playback samples `isDone`.
class PlainMotion extends Motion {
  const PlainMotion();

  @override
  bool get needsSettle => false;

  @override
  Simulation createSimulation({
    double start = 0,
    double end = 1,
    double velocity = 0,
  }) =>
      _Exponential(start, end);

  @override
  bool operator ==(Object other) => other is PlainMotion;

  @override
  int get hashCode => (PlainMotion).hashCode;
}

class _Exponential extends Simulation {
  _Exponential(this.start, this.end);

  final double start;
  final double end;
  static const _rate = 20.0;

  @override
  double x(double time) =>
      isDone(time) ? end : end + (start - end) * math.exp(-_rate * time);

  @override
  double dx(double time) =>
      isDone(time) ? 0 : -_rate * (start - end) * math.exp(-_rate * time);

  @override
  bool isDone(double time) =>
      (start - end).abs() * math.exp(-_rate * time) < 1e-3;
}

/// A damped spring integrated in fixed steps, keeping its state between
/// calls and restarting from an earlier checkpoint when asked about an
/// earlier time, as motor allows.
class RestartingMotion extends Motion {
  const RestartingMotion();

  @override
  bool get needsSettle => false;

  @override
  Simulation createSimulation({
    double start = 0,
    double end = 1,
    double velocity = 0,
  }) =>
      _Integrating(start, end, velocity);

  @override
  bool operator ==(Object other) => other is RestartingMotion;

  @override
  int get hashCode => (RestartingMotion).hashCode;
}

class _Integrating extends Simulation {
  _Integrating(this.start, this.end, this.velocity) {
    _restart();
  }

  final double start;
  final double end;
  final double velocity;
  static const _step = 1 / 480;
  static const _stiffness = 300.0;
  static const _damping = 40.0;

  /// The state every 1/60 s integrated so far, to restart from.
  final List<(double, double)> _checkpoints = [];
  late int _steps;
  late double _x;
  late double _v;

  void _restart() {
    _steps = 0;
    _x = start;
    _v = velocity;
    _checkpoints
      ..clear()
      ..add((_x, _v));
  }

  /// The step at which it came to rest, once integration got there; it
  /// stays at rest.
  int? _restStep;

  void _integrateTo(double time) {
    final target = (time / _step).floor();
    if (target < _steps) {
      final checkpoint = math.min(target ~/ 8, _checkpoints.length - 1);
      final (x, v) = _checkpoints[checkpoint];
      _x = x;
      _v = v;
      _steps = checkpoint * 8;
    }
    // Past where it came to rest, nothing is left to integrate.
    final restStep = _restStep;
    final last = restStep == null ? target : math.min(target, restStep);
    while (_steps < last) {
      final a = -_stiffness * (_x - end) - _damping * _v;
      _v += a * _step;
      _x += _v * _step;
      _steps++;
      if (_steps % 8 == 0 && _steps ~/ 8 == _checkpoints.length) {
        _checkpoints.add((_x, _v));
      }
      if (_restStep == null && (_x - end).abs() < 1e-3 && _v.abs() < 1e-2) {
        _restStep = _steps;
        break;
      }
    }
  }

  @override
  double x(double time) {
    if (isDone(time)) return end;
    _integrateTo(time);
    return _x;
  }

  @override
  double dx(double time) {
    if (isDone(time)) return 0;
    _integrateTo(time);
    return _v;
  }

  @override
  bool isDone(double time) {
    final step = (time / _step).floor();
    if (_restStep case final rest? when step >= rest) return true;
    _integrateTo(time);
    return _restStep != null && step >= _restStep!;
  }
}

/// Moves linearly to its end over 0.3 s, but reports done early, at 0.1 s
/// to 0.2 s, as an underdamped spring can near a peak.
class FlickeringMotion extends Motion {
  const FlickeringMotion();

  @override
  bool get needsSettle => false;

  @override
  Simulation createSimulation({
    double start = 0,
    double end = 1,
    double velocity = 0,
  }) =>
      _Flickering(start, end);

  @override
  bool operator ==(Object other) => other is FlickeringMotion;

  @override
  int get hashCode => (FlickeringMotion).hashCode;
}

class _Flickering extends Simulation {
  _Flickering(this.start, this.end);

  final double start;
  final double end;

  @override
  double x(double time) => start + (end - start) * (time / 0.3).clamp(0.0, 1.0);

  @override
  double dx(double time) => time < 0.3 ? (end - start) / 0.3 : 0;

  @override
  bool isDone(double time) => (time >= 0.1 && time < 0.2) || time >= 0.3;
}

/// A target motion with a duration that drifts past its target forever.
class DriftMotion extends Motion {
  const DriftMotion({this.duration});

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
      _Drift(start, 1);

  @override
  bool operator ==(Object other) =>
      other is DriftMotion && other.duration == duration;

  @override
  int get hashCode => duration.hashCode;
}

/// A free motion that drifts at its start velocity forever and says so.
class FreeDrift extends FreeMotion {
  const FreeDrift({this.duration});

  @override
  final Duration? duration;

  @override
  Simulation createSimulation({double start = 0, double velocity = 0}) =>
      _Drift(start, velocity);

  @override
  bool operator ==(Object other) =>
      other is FreeDrift && other.duration == duration;

  @override
  int get hashCode => duration.hashCode;
}

class _Drift extends Simulation with SettlingSimulation {
  _Drift(this.start, this.velocity);

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
