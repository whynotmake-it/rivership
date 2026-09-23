// ignore_for_file: cascade_invocations, unawaited_futures

import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';

/// Generated plans must play back as a function of time: scrubbing shows
/// exactly what live playback showed, for springs, curves, holds, keyframes,
/// free motions, sync barriers, every loop mode, and interruptions.
void main() {
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
      final plan = _Plan.generate(math.Random(seed), loop);

      final live = TrackController(vsync: tester)..play(plan.timeline);
      final recorded = await _record(tester, live, plan.tracks, frames, frame);
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
      final plan = _Plan.generate(random, loop);
      final redirectAt = 30 + random.nextInt(frames - 60);
      final redirect = plan.tracks.first(_steps(random, const []));

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
}

/// Pumps [frames] frames and records every track's value and velocity, and
/// the controller's timeline position, after each one. [onFrame] runs right after
/// frame `i` is recorded.
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

class _Plan {
  _Plan(this.tracks, this.timeline);

  factory _Plan.generate(math.Random random, LoopMode loop) {
    final tokens = [#a, #b].sublist(0, random.nextInt(3));
    final tracks = [
      for (var i = 0; i < 2 + random.nextInt(2); i++)
        Track<double>(MotionConverter.single, initial: random.nextDouble()),
    ];
    return _Plan(
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
