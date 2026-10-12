// ignore_for_file: cascade_invocations, unawaited_futures

import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';
import 'package:motor/src/simulations/step_playback.dart';

import 'adversarial/fuzz_support.dart' show FlickeringMotion;

/// Playback must be a function of time alone: ticking live, seeking straight
/// to a time and seeking back to it have to show the same, for springs,
/// curves, holds, keyframes, free motions, sync barriers, every loop mode,
/// and interruptions, including bouncy springs whose `isDone` flickers
/// before they settle.
void main() {
  group('StepPlayback', () {
    for (final plan in _plans) {
      test(
        '${plan.name}: ticking matches seeking there, forward and back',
        () => _checkTickedMatchesSought(plan),
      );
    }
  });

  group('TrackController', () {
    testWidgets('scrubbing a fresh controller matches live playback',
        (tester) async {
      final track = Track<double>(MotionConverter.single, initial: 0);
      TrackTimeline timeline() => TrackTimeline([
            track(_freeThenSprings, withVelocity: 5),
          ]);

      final live = TrackController(vsync: tester)..play(timeline());
      await tester.pump();
      final values = <double>[];
      for (var i = 1; i <= 480; i++) {
        await tester.pump(const Duration(microseconds: 16667));
        values.add(live.value(track));
      }
      live.stop(canceled: true);

      final scrubbed = TrackController(vsync: tester)..play(timeline());
      scrubbed
        ..pause()
        ..scrubTo(const Duration(microseconds: 16667 * 480));
      for (var i = values.length - 1; i >= 0; i -= 5) {
        scrubbed.scrubTo(Duration(microseconds: 16667 * (i + 1)));
        expect(scrubbed.value(track), closeTo(values[i], 1e-9));
      }
      scrubbed.stop(canceled: true);

      live.dispose();
      scrubbed.dispose();
    });

    const frame = Duration(microseconds: 16667);
    const frames = 240;
    const cases = 24;

    for (var seed = 0; seed < cases; seed++) {
      final loop = LoopMode.values[seed % LoopMode.values.length];

      testWidgets('generated plan $seed ($loop): a fresh scrub matches live',
          (tester) async {
        // Loops that cannot fold keep a long history only for tooling.
        final subscription = MotorInspectionRegistry.attach(_Observer());
        addTearDown(subscription.dispose);
        final plan = _GeneratedPlan.generate(math.Random(seed), loop);

        final live = TrackController(vsync: tester)..play(plan.timeline);
        final recorded =
            await _record(tester, live, plan.tracks, frames, frame);
        live
          ..stop(canceled: true)
          ..dispose();

        final scrubbed = TrackController(vsync: tester)
          ..play(plan.timeline)
          ..pause()
          ..scrubTo(recorded.last.position);
        for (var i = frames; i >= 0; i -= 3) {
          scrubbed.scrubTo(recorded[i].position);
          _expectValues(scrubbed, plan.tracks, recorded[i], 'frame $i');
        }
        scrubbed
          ..stop(canceled: true)
          ..dispose();
      });

      testWidgets(
          'generated plan $seed ($loop): scrubbing back over an interruption '
          'matches live', (tester) async {
        final subscription = MotorInspectionRegistry.attach(_Observer());
        final random = math.Random(seed + 1000);
        final plan = _GeneratedPlan.generate(random, loop);
        final redirectAt = 30 + random.nextInt(frames - 60);
        final redirect = plan.tracks.first.call(_steps(random, const []));

        final controller = TrackController(vsync: tester)..play(plan.timeline);
        final recorded = await _record(
          tester,
          controller,
          plan.tracks,
          frames,
          frame,
          onFrame: (i) {
            if (i == redirectAt) controller.animate([redirect]);
          },
        );

        controller.pause();
        for (var i = frames; i >= 0; i -= 3) {
          // Every frame at the redirect's timeline position shows the state
          // before it live, and after it when scrubbed; both are valid there.
          // That includes idle frames before the redirect, since the timeline
          // does not advance while idle. A release at that instant can
          // restart a seamless loop at its start value, and a new curve step
          // starts moving right away.
          if (recorded[i].position == recorded[redirectAt].position) continue;
          controller.scrubTo(recorded[i].position);
          _expectValues(controller, plan.tracks, recorded[i], 'frame $i');
        }
        controller
          ..stop(canceled: true)
          ..dispose();
        subscription.dispose();
      });
    }
  });
}

const _linear100 = Motion.linear(Duration(milliseconds: 100));

const _freeThenSprings = <TrackStep<double>>[
  TrackStep.free(motion: FreeMotion.friction()),
  TrackStep.to(0, motion: Motion.bouncySpring()),
  TrackStep.to(1, motion: Motion.smoothSpring()),
];

/// Hand-picked plans, each played from a start at rest at 0.
final _plans = <_Plan>[
  const _Plan(
    'a hold between two curves',
    [
      TrackStep.to(1, motion: _linear100),
      TrackStep.hold(Duration(milliseconds: 50)),
      TrackStep.to(0, motion: _linear100),
    ],
    seconds: 0.3,
    frame: 1e-3,
  ),
  const _Plan(
    'a looping curve',
    [TrackStep.to(1, motion: _linear100)],
    loop: LoopMode.loop,
    seconds: 0.3,
    frame: 1e-3,
  ),
  const _Plan(
    'a barrier released on arrival',
    [
      TrackStep.to(1, motion: _linear100),
      TrackStep.sync(token: #barrier),
      TrackStep.to(2, motion: _linear100),
    ],
    seconds: 0.3,
    frame: 1e-3,
  ),
  const _Plan(
    'a flickering isDone',
    [
      TrackStep.to(1, motion: FlickeringMotion()),
      TrackStep.to(2, motion: _linear100),
    ],
    seconds: 0.6,
    frame: 1 / 240,
  ),
  for (final (name, steps) in const [
    ('free then springs', _freeThenSprings),
    (
      'bouncy springs',
      <TrackStep<double>>[
        TrackStep.to(1, motion: Motion.bouncySpring()),
        TrackStep.to(0, motion: Motion.bouncySpring(extraBounce: 0.2)),
      ]
    ),
  ])
    for (final loop in LoopMode.values)
      for (final velocity in [0.0, 5.0])
        _Plan(
          '$name, $loop, velocity $velocity',
          steps,
          loop: loop,
          velocity: velocity,
          seconds: 12,
          stride: 7,
        ),
  for (final until in WaitUntil.values)
    for (final loop in [LoopMode.none, LoopMode.pingPong, LoopMode.loop])
      _Plan(
        'springs until $until around a hold, a keyframe and a curve, $loop',
        [
          TrackStep.to(
            300,
            motion: const CupertinoMotion.bouncy(),
            until: until,
          ),
          const TrackStep.hold(Duration(milliseconds: 150)),
          TrackStep.to(
            -50,
            motion: const CupertinoMotion.snappy(),
            until: until,
          ),
          const TrackStep.at(
            Duration(seconds: 2),
            100,
            motion: CupertinoMotion.smooth(),
          ),
          const TrackStep.to(
            20,
            motion: Motion.curved(Duration(milliseconds: 400), Curves.easeOut),
          ),
        ],
        loop: loop,
        velocity: -800,
        seconds: 6,
        frame: 1 / 240,
        tolerance: 0,
      ),
];

class _Plan {
  const _Plan(
    this.name,
    this.steps, {
    required this.seconds,
    this.loop = LoopMode.none,
    this.velocity = 0,
    this.frame = 1 / 60,
    this.stride = 1,
    this.tolerance = 1e-9,
  });

  final String name;
  final List<TrackStep<double>> steps;
  final LoopMode loop;
  final double velocity;

  /// How long to tick for, and the length of each tick.
  final double seconds;
  final double frame;

  /// Every how many ticks, counted back from the last, to seek.
  final int stride;

  final double tolerance;

  StepPlayback<double> build() => StepPlayback<double>(
        steps: steps,
        converter: MotionConverter.single,
        start: 0,
        velocity: velocity,
        loop: loop,
      );
}

/// Advances to [seconds], releasing every barrier the moment it is reached,
/// as a lone controller participant would.
void _advance(StepPlayback<double> playback, double seconds) {
  playback.advanceTo(seconds);
  while (playback.pendingSyncToken != null) {
    playback
      ..releaseSync(atSeconds: playback.pendingSyncArrivalSeconds)
      ..advanceTo(seconds);
  }
}

typedef _State = ({double value, double velocity, bool isDone});

_State _stateOf(StepPlayback<double> playback) => (
      value: playback.values.single,
      velocity: playback.velocities.single,
      isDone: playback.isDone,
    );

void _checkTickedMatchesSought(_Plan plan) {
  final ticked = plan.build();
  final states = <_State>[];
  for (var i = 0; i * plan.frame <= plan.seconds; i++) {
    _advance(ticked, i * plan.frame);
    states.add(_stateOf(ticked));
  }
  // A plan that ends settles at rest on its last target; a loop never does.
  if (plan.loop.isLooping) {
    expect(ticked.isDone, isFalse);
  } else {
    expect(ticked.isDone, isTrue);
    final target = plan.steps.whereType<StepTo<double>>().last.value;
    expect(ticked.values.single, target);
  }

  final soughtBack = plan.build();
  _advance(soughtBack, plan.seconds);
  for (var i = states.length - 1; i >= 0; i -= plan.stride) {
    final seconds = i * plan.frame;
    _advance(soughtBack, seconds);
    _expectState(soughtBack, states[i], plan.tolerance, 'back to ${seconds}s');
    final fresh = plan.build();
    _advance(fresh, seconds);
    _expectState(fresh, states[i], plan.tolerance, 'straight to ${seconds}s');
  }
}

void _expectState(
  StepPlayback<double> actual,
  _State expected,
  double tolerance,
  String reason,
) {
  expect(
    actual.values.single,
    closeTo(expected.value, tolerance),
    reason: 'value $reason',
  );
  expect(
    actual.velocities.single,
    closeTo(
      expected.velocity,
      tolerance * math.max(1, expected.velocity.abs()),
    ),
    reason: 'velocity $reason',
  );
  expect(actual.isDone, expected.isDone, reason: 'isDone $reason');
}

/// Pumps [frames] frames and records every track's value and velocity, and
/// the controller's timeline position, after each one. [onFrame] runs right
/// after frame `i` is recorded.
Future<List<_Frame>> _record(
  WidgetTester tester,
  TrackController controller,
  List<Track<double>> tracks,
  int frames,
  Duration frame, {
  void Function(int frame)? onFrame,
}) async {
  final recorded = <_Frame>[];
  await tester.pump();
  for (var i = 0; i <= frames; i++) {
    if (i > 0) await tester.pump(frame);
    recorded.add(
      (
        position: controller.inspectPlayback().position,
        values: [for (final track in tracks) controller.value(track)],
        velocities: [for (final track in tracks) controller.velocity(track)],
      ),
    );
    onFrame?.call(i);
  }
  return recorded;
}

typedef _Frame = ({
  Duration position,
  List<double> values,
  List<double> velocities,
});

void _expectValues(
  TrackController controller,
  List<Track<double>> tracks,
  _Frame expected,
  String reason,
) {
  for (var t = 0; t < tracks.length; t++) {
    expect(
      controller.value(tracks[t]),
      closeTo(expected.values[t], 1e-6),
      reason: 'track $t at $reason',
    );
    final velocity = expected.velocities[t];
    expect(
      controller.velocity(tracks[t]),
      closeTo(velocity, 1e-6 * math.max(1, velocity.abs())),
      reason: 'track $t velocity at $reason',
    );
  }
}

class _GeneratedPlan {
  _GeneratedPlan(this.tracks, this.timeline);

  factory _GeneratedPlan.generate(math.Random random, LoopMode loop) {
    final tokens = [#a, #b].sublist(0, random.nextInt(3));
    final tracks = [
      for (var i = 0; i < 2 + random.nextInt(2); i++)
        Track<double>(MotionConverter.single, initial: random.nextDouble()),
    ];
    return _GeneratedPlan(
      tracks,
      TrackTimeline(
        [for (final track in tracks) track(_steps(random, tokens))],
        loop: loop,
      ),
    );
  }

  final List<Track<double>> tracks;
  final TrackTimeline timeline;
}

final _motions = <Motion>[
  const Motion.bouncySpring(),
  const Motion.smoothSpring(),
  const Motion.snappySpring(),
  const CupertinoMotion(
    duration: Duration(milliseconds: 400),
    bounce: 0.5,
    snapToEnd: false,
  ),
  const Motion.linear(Duration(milliseconds: 250)),
  const Motion.curved(Duration(milliseconds: 400), Curves.easeInOut),
];

/// Two to five random steps, with each token in [tokens] as a sync barrier
/// in the given order.
List<TrackStep<double>> _steps(math.Random random, List<Object> tokens) {
  final steps = <TrackStep<double>>[];
  var holds = Duration.zero;
  final count = 2 + random.nextInt(4);
  var nextToken = 0;
  for (var i = 0; i < count; i++) {
    if (nextToken < tokens.length && random.nextInt(3) == 0) {
      steps.add(TrackStep.sync(token: tokens[nextToken++]));
      continue;
    }
    final value = random.nextDouble() * 3 - 1;
    final motion = _motions[random.nextInt(_motions.length)];
    switch (random.nextInt(6)) {
      case 0:
        final duration = Duration(milliseconds: 50 + random.nextInt(250));
        holds += duration;
        steps.add(TrackStep.hold(duration));
      case 1:
        holds += Duration(milliseconds: 100 + random.nextInt(600));
        steps.add(TrackStep.at(holds, value, motion: motion));
      case 2:
        steps.add(const TrackStep.free(motion: FreeMotion.friction()));
      default:
        steps.add(TrackStep.to(value, motion: motion));
    }
  }
  for (; nextToken < tokens.length; nextToken++) {
    steps.add(TrackStep.sync(token: tokens[nextToken]));
  }
  return steps;
}

class _Observer implements MotorInspectionObserver {
  @override
  void didRegisterController(TrackController controller) {}

  @override
  void didUnregisterController(TrackController controller) {}
}
