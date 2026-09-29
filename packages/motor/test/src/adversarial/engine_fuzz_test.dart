// ignore_for_file: cascade_invocations

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';
import 'package:motor/src/simulations/step_playback.dart';

import 'fuzz_support.dart';

/// Randomized plans of two-dimensional steps, played straight through
/// [StepPlayback], checked against the timing model's invariants.
void main() {
  const cases = 160 * fuzzScale;

  group('StepPlayback fuzz', () {
    test('any schedule of ticks and seeks matches seeking straight there', () {
      for (var run = 0; run < cases; run++) {
        final seed = fuzzSeed + run;
        final plan = _Plan.generate(seed);
        runCase(seed, plan.describe, () => _checkParity(plan, seed));
      }
    });

    test('values stay finite and segments stay bounded', () {
      for (var run = 0; run < cases; run++) {
        final seed = fuzzSeed + 100000 + run;
        final plan = _Plan.generate(seed);
        runCase(seed, plan.describe, () => _checkBounded(plan, seed));
      }
    });

    test('handoffs are continuous in value and velocity', () {
      for (var run = 0; run < cases * 2; run++) {
        final seed = fuzzSeed + 200000 + run;
        final plan = _Plan.generate(seed, loop: LoopMode.none);
        runCase(seed, plan.describe, () => _checkHandoffs(plan));
      }
    });

    test('keyframes land on time and settled steps end at rest on target', () {
      for (var run = 0; run < cases * 2; run++) {
        final seed = fuzzSeed + 300000 + run;
        final plan = _Plan.generate(seed, loop: LoopMode.none);
        runCase(seed, plan.describe, () => _checkKeyframes(plan));
      }
    });

    test('playback ends no later than it settles, and stays ended', () {
      for (var run = 0; run < cases; run++) {
        final seed = fuzzSeed + 400000 + run;
        final plan = _Plan.generate(seed, loop: LoopMode.none);
        runCase(seed, plan.describe, () => _checkEndedBeforeSettled(plan));
      }
    });
  });
}

final class _Plan {
  _Plan({
    required this.steps,
    required this.loop,
    required this.start,
    required this.velocity,
    required this.fallback,
  });

  factory _Plan.generate(int seed, {LoopMode? loop}) {
    final random = math.Random(seed);
    final mode =
        loop ?? LoopMode.values[random.nextInt(LoopMode.values.length)];
    final generator = PlanGenerator(random, loop: mode);
    final fallback = random.nextBool()
        ? generator.targetMotion(until: WaitUntil.settled)
        : null;
    return _Plan(
      steps: generator.steps<Offset>(
        2,
        (values) => Offset(values[0], values[1]),
        allowFallback: fallback != null,
      ),
      loop: mode,
      start: Offset(generator.value(), generator.value()),
      velocity: Offset(
        random.nextDouble() * 10 - 5,
        random.nextDouble() * 10 - 5,
      ),
      fallback: fallback,
    );
  }

  final List<TrackStep<Offset>> steps;
  final LoopMode loop;
  final Offset start;
  final Offset velocity;
  final Motion? fallback;

  StepPlayback<Offset> build() => StepPlayback<Offset>(
        steps: steps,
        converter: MotionConverter.offset,
        start: start,
        velocity: velocity,
        loop: loop,
        fallbackMotion: fallback,
      );

  bool get hasSync => steps.any((step) => step is StepSync);

  /// Whether this loop may fling friction further every cycle: its return
  /// chains straight into the friction, which takes over the return's end
  /// slope, so the plan itself can gain energy without bound.
  bool get divergesKnowingly =>
      loop.isLooping &&
      steps.any(
        (step) => step is StepFree<Offset> && step.motion is! FreeDrift,
      );

  /// The motions [step] plays, one per dimension, or null if it has none.
  List<MotionBase>? motionsOf(TrackStep<Offset> step) => switch (step) {
        StepTo(:final motion?) || StepAt(:final motion?) => [motion, motion],
        StepTo(:final motionPerDimension?) ||
        StepAt(:final motionPerDimension?) =>
          motionPerDimension,
        StepTo() || StepAt() => [fallback!, fallback!],
        StepFree(:final motion) => [motion, motion],
        _ => null,
      };

  String describe() => 'loop: $loop, start: $start, velocity: $velocity, '
      'fallback: $fallback\n${describeSteps(steps)}';
}

/// Advances to [seconds], releasing every barrier the moment it is reached,
/// as a lone controller participant would. Returns false if it gave up
/// because a loop kept reaching barriers without time passing.
bool _advance(StepPlayback<Offset> playback, double seconds) {
  playback.advanceTo(seconds);
  for (var i = 0; playback.pendingSyncToken != null; i++) {
    if (i == 1000) return false;
    playback
      ..releaseSync(atSeconds: playback.pendingSyncArrivalSeconds)
      ..advanceTo(seconds);
  }
  return true;
}

void _expectFinite(StepPlayback<Offset> playback, String reason) {
  for (final value in [...playback.values, ...playback.velocities]) {
    expect(value.isFinite, isTrue, reason: 'not finite: $value, $reason');
  }
}

Matcher _near(double expected) =>
    closeTo(expected, 1e-9 * math.max(1, expected.abs()));

void _checkParity(_Plan plan, int seed) {
  final random = math.Random(seed ^ 0x5eed);
  final ticked = plan.build();
  // Boundaries come from a separate playback, and the one under test only
  // looks ahead now and then, as inspection tooling does.
  final probe = plan.build();
  final canFold = !plan.loop.isLooping || !plan.hasSync;
  var time = 0.0;
  final schedule = <double>[];
  printOnFailure('schedule: $schedule');
  for (var tick = 0; tick < 50; tick++) {
    if (!_advance(probe, time + 2)) return;
    final segments = probe.segmentsView;
    final boundary =
        segments.isEmpty ? null : segments[random.nextInt(segments.length)].end;
    time = switch (random.nextInt(10)) {
      0 => time,
      1 => time + 1e-9,
      2 => time + random.nextDouble() * 5,
      // Loops that can't fold resolve every cycle again for each fresh seek.
      3 => time + (canFold ? 1000 : 20) * random.nextDouble(),
      // Loops that don't repeat exactly keep only their latest cycles.
      4 when segments.isEmpty || segments.first.start == 0 =>
        random.nextDouble() * time,
      5 when boundary != null && boundary >= time => boundary,
      6 when boundary != null && boundary > time + 1e-9 => boundary - 1e-9,
      _ => time + 1 / 60,
    };
    schedule.add(time);
    if (random.nextInt(4) == 0) ticked.segmentsView;
    if (!_advance(ticked, time)) return;
    final sought = plan.build();
    if (!_advance(sought, time)) return;
    final reason = 'tick $tick at t=$time\nticked ${ticked.segmentsView} '
        'period ${ticked.loopPeriodSeconds} from '
        '${ticked.loopRepeatStartSeconds}\nsought ${sought.segmentsView}';
    for (var d = 0; d < 2; d++) {
      expect(ticked.values[d], _near(sought.values[d]), reason: 'x$d $reason');
      expect(
        ticked.velocities[d],
        _near(sought.velocities[d]),
        reason: 'dx$d $reason',
      );
    }
    expect(ticked.isDone, sought.isDone, reason: 'isDone $reason');
    expect(ticked.hasEnded, sought.hasEnded, reason: 'hasEnded $reason');
    expect(
      ticked.currentStepIndex,
      sought.currentStepIndex,
      reason: 'step $reason',
    );
  }
}

void _checkBounded(_Plan plan, int seed) {
  final random = math.Random(seed ^ 0xb0b);
  final playback = plan.build();
  var time = 0.0;
  var bound = 0;
  for (var tick = 0; tick < 80; tick++) {
    time += switch (random.nextInt(4)) {
      0 => random.nextDouble() * 100,
      1 => 0,
      _ => 1 / 60,
    };
    if (!_advance(playback, time)) return;
    if (!plan.divergesKnowingly) _expectFinite(playback, 't=$time');
    final segments = playback.debugSegmentCount;
    if (!plan.loop.isLooping) {
      // Plus one where a spring settles on after a last hold or barrier.
      expect(
        segments,
        lessThanOrEqualTo(plan.steps.length + 1),
        reason: 't=$time',
      );
    } else {
      // A cycle has at most two passes over the steps plus the return step,
      // and a loop keeps a handful of cycles before folding or dropping.
      bound = 12 * 2 * (plan.steps.length + 1);
      expect(segments, lessThanOrEqualTo(bound), reason: 't=$time');
    }
  }
  if (plan.loop.isLooping) {
    // A loop that doesn't repeat exactly resolves every cycle on the way.
    _advance(playback, time + (playback.loopPeriodSeconds != null ? 1e6 : 1e3));
    expect(playback.debugSegmentCount, lessThanOrEqualTo(bound));
    if (!plan.divergesKnowingly) _expectFinite(playback, 'after a long jump');
  }
}

/// Samples playback just before and just after every boundary between two
/// segments, and checks that nothing jumps unless the timing model says it
/// may.
void _checkHandoffs(_Plan plan) {
  final playback = plan.build();
  if (!_advance(playback, 30)) return;
  final segments = playback.segmentsView;
  const delta = 1e-6;
  for (var i = 0; i + 1 < segments.length; i++) {
    final previous = segments[i];
    final next = segments[i + 1];
    final boundary = previous.end!;
    final nextEnd = next.end ?? double.infinity;
    if (boundary - previous.start < 4 * delta) continue;
    if (nextEnd - boundary < 4 * delta) continue;
    final previousStep = plan.steps[previous.stepIndex];
    final nextStep = plan.steps[next.stepIndex];
    final previousMotions = plan.motionsOf(previousStep) ?? const [];
    final nextMotions = plan.motionsOf(nextStep) ?? const [];
    if ([...previousMotions, ...nextMotions].any((m) => traitsOf(m).jumps)) {
      continue;
    }
    // A keyframe stops its spring at its time, and one without time left
    // arrives at once.
    // A keyframe stops a spring at its time, and one that settles off its
    // target snaps onto it.
    if (previousStep is StepAt &&
        previousMotions.any(
          (m) => traitsOf(m).needsSettle || !traitsOf(m).settlesOnTarget,
        )) {
      continue;
    }
    if (nextStep is StepAt<Offset> &&
        (next.start - nextStep.at.inMicroseconds / 1e6).abs() < 1e-5) {
      continue;
    }

    playback.advanceTo(boundary - delta);
    final before = [...playback.values];
    final velocityBefore = [...playback.velocities];
    playback.advanceTo(boundary + delta);
    final after = [...playback.values];
    final velocityAfter = [...playback.velocities];
    final reason = 'boundary $i at $boundary, $previousStep -> $nextStep';
    for (var d = 0; d < 2; d++) {
      final speed = velocityBefore[d].abs() + velocityAfter[d].abs();
      expect(
        (after[d] - before[d]).abs(),
        lessThanOrEqualTo(2 * delta * speed + 2.5e-3),
        reason: 'x$d jumps from ${before[d]} to ${after[d]}, $reason',
      );
    }

    // A step chained right after another takes over its velocity: at its
    // duration, or, for motions that end with their slope, once settled.
    final handsOver = switch (previousStep) {
      StepTo(until: WaitUntil.duration) ||
      StepFree(until: WaitUntil.duration)
          when previousMotions.every((m) => m.duration != null) =>
        true,
      StepTo() ||
      StepFree() =>
        previousMotions.every((m) => traitsOf(m).endsWithSlope),
      _ => false,
    };
    // A hold or barrier plays out what moves physically; a curve that has
    // ended stops there.
    final keepsVelocity = switch (nextStep) {
      StepHold() ||
      StepSync() =>
        previousMotions.every((m) => traitsOf(m).keepsVelocity),
      _ => nextMotions.every((m) => traitsOf(m).keepsVelocity),
    };
    if (!handsOver || !keepsVelocity) continue;
    for (var d = 0; d < 2; d++) {
      expect(
        (velocityAfter[d] - velocityBefore[d]).abs(),
        lessThanOrEqualTo(0.05 + 1e-3 * velocityBefore[d].abs()),
        reason: 'dx$d jumps from ${velocityBefore[d]} to '
            '${velocityAfter[d]}, $reason',
      );
    }
  }
}

void _checkKeyframes(_Plan plan) {
  final playback = plan.build();
  if (!_advance(playback, 30)) return;
  final segments = playback.segmentsView;
  for (var i = 0; i < segments.length; i++) {
    final segment = segments[i];
    final step = plan.steps[segment.stepIndex];
    final end = segment.end;
    final nextStep = segment.stepIndex + 1 < plan.steps.length
        ? plan.steps[segment.stepIndex + 1]
        : null;
    final reason = 'segment $i ($step) from ${segment.start} to $end';

    if (step case StepAt<Offset>(:final at, :final value)) {
      final arrival = at.inMicroseconds / 1e6;
      if (segment.start >= arrival - 1e-6) continue;
      // Started in time: it arrives exactly then, unless the next keyframe
      // cuts it short to arrive on its own time.
      expect(end, isNotNull, reason: reason);
      expect(end, lessThanOrEqualTo(arrival + 1e-6), reason: reason);
      if (end! < arrival - 1e-6) {
        expect(nextStep, isA<StepAt<Offset>>(), reason: 'cut short, $reason');
        continue;
      }
      // Zero-length steps starting at the same instant show their value
      // instead, and a step starting then may already have jumped.
      if (i + 1 < segments.length && segments[i + 1].start <= arrival + 1e-6) {
        final next = segments[i + 1];
        final nextMotions =
            plan.motionsOf(plan.steps[next.stepIndex]) ?? const [];
        if ((next.end ?? double.infinity) - next.start < 1e-6 ||
            nextMotions.any((m) => traitsOf(m).jumps)) {
          continue;
        }
      }
      playback.advanceTo(arrival);
      final shown = playback.values;
      expect(shown[0], _near(value.dx), reason: 'x0 at $arrival, $reason');
      expect(shown[1], _near(value.dy), reason: 'x1 at $arrival, $reason');
    }

    if (step case StepTo<Offset>(:final value, until: WaitUntil.settled)) {
      if (end == null || nextStep is StepAt) continue;
      if (end - segment.start < 1e-6) continue;
      final motions = plan.motionsOf(step)!;
      if (!motions.every((m) => traitsOf(m).settlesOnTarget)) continue;
      // Just before the next step starts, which may jump.
      playback.advanceTo(end - 1e-7);
      final shown = playback.values;
      expect(shown[0], closeTo(value.dx, 1.5e-3), reason: 'x0, $reason');
      expect(shown[1], closeTo(value.dy, 1.5e-3), reason: 'x1, $reason');
    }
  }
}

void _checkEndedBeforeSettled(_Plan plan) {
  final playback = plan.build();
  var ended = false;
  for (var time = 0.0; time < 20; time += 1 / 60) {
    if (!_advance(playback, time)) return;
    if (playback.isDone) {
      expect(
        playback.hasEnded,
        isTrue,
        reason: 'settled before ended at $time',
      );
    }
    if (ended) {
      expect(playback.hasEnded, isTrue, reason: 'no longer ended at $time');
    }
    ended = playback.hasEnded;
    if (playback.isDone) return;
  }
}
