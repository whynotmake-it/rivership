// ignore_for_file: cascade_invocations, unawaited_futures

import 'dart:math' as math;

import 'package:flutter/scheduler.dart' show timeDilation;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';

import 'fuzz_support.dart';

/// Randomized controller sessions: generated multi-track timelines under
/// timing chaos, random sequences of calls, and retargets every frame.
void main() {
  const sessions = 10 * fuzzScale;

  group('TrackController under timing chaos', () {
    for (var run = 0; run < sessions; run++) {
      final seed = fuzzSeed + 500000 + run;
      testWidgets('session $seed matches a scrub, and barriers meet',
          (tester) async {
        final subscription = MotorInspectionRegistry.attach(_Observer());
        addTearDown(subscription.dispose);
        addTearDown(() => timeDilation = 1);
        final session = _Session.generate(seed);
        await runCaseAsync(
          seed,
          session.describe,
          () => _playWithChaos(tester, session, math.Random(seed)),
        );
      });
    }
  });

  group('TrackController futures', () {
    for (var run = 0; run < sessions; run++) {
      final seed = fuzzSeed + 600000 + run;
      testWidgets('session $seed resolves every future once, in order',
          (tester) async {
        final log = <String>[];
        await runCaseAsync(
          seed,
          () => log.join('\n'),
          () => _callAtRandom(tester, math.Random(seed), log),
        );
      });
    }
  });

  group('TrackController retargets', () {
    for (var run = 0; run < sessions; run++) {
      final seed = fuzzSeed + 700000 + run;
      testWidgets('session $seed retargets every frame without jumping',
          (tester) async {
        await runCaseAsync(
          seed,
          () => 'retargets',
          () => _retargetEveryFrame(tester, math.Random(seed)),
        );
      });
    }
  });
}

class _Observer implements MotorInspectionObserver {
  @override
  void didRegisterController(TrackController controller) {}

  @override
  void didUnregisterController(TrackController controller) {}
}

final class _Session {
  _Session(this.tracks, this.timeline);

  factory _Session.generate(int seed) {
    final random = math.Random(seed);
    final loop = LoopMode.values[random.nextInt(LoopMode.values.length)];
    final generator = PlanGenerator(
      random,
      loop: loop,
      tokens: const [#meet, #meet, #solo],
      maxSteps: 5,
    );
    final tracks = <Track<Object>>[];
    final animations = <TrackAnimation>[];
    // Barrier rounds that take no time at all are capped per frame, so a
    // frame and a scrub may stop at different rounds; cycles take a moment.
    const cycle = Duration(milliseconds: 1);
    for (var i = 0; i < 2 + random.nextInt(2); i++) {
      if (random.nextBool()) {
        final track = Track<double>(
          MotionConverter.single,
          initial: generator.value(),
          motion: const Motion.smoothSpring(),
        );
        tracks.add(track);
        animations.add(
          track(
            [
              ...generator.steps(1, (values) => values.single),
              if (loop.isLooping) const TrackStep.hold(cycle),
            ],
            withVelocity: random.nextDouble() * 4 - 2,
          ),
        );
      } else {
        final track = Track<Offset>(
          MotionConverter.offset,
          initial: Offset(generator.value(), generator.value()),
          motion: const Motion.bouncySpring(),
        );
        tracks.add(track);
        animations.add(
          track([
            ...generator.steps(2, (values) => Offset(values[0], values[1])),
            if (loop.isLooping) const TrackStep.hold(cycle),
          ]),
        );
      }
    }
    return _Session(tracks, TrackTimeline(animations, loop: loop));
  }

  final List<Track<Object>> tracks;
  final TrackTimeline timeline;

  String describe() => 'loop: ${timeline.loop}\n${[
        for (final animation in timeline.animations)
          [
            'track ${animation.track.converter.runtimeType}:',
            describeSteps(animation.steps),
          ].join('\n'),
      ].join('\n')}';
}

List<double> _normalized(TrackController controller, Track<Object> track) =>
    _normalize(track, controller.value(track));

List<double> _normalizedVelocity(
  TrackController controller,
  Track<Object> track,
) =>
    _normalize(track, controller.velocity(track));

List<double> _normalize<T extends Object>(Track<T> track, Object value) =>
    track.converter.normalize(value as T);

void _expectSame(
  List<double> actual,
  List<double> expected,
  String reason, {
  double tolerance = 1e-9,
}) {
  for (var i = 0; i < actual.length; i++) {
    expect(actual[i].isFinite, isTrue, reason: 'not finite, $reason');
    expect(
      actual[i],
      closeTo(expected[i], tolerance * math.max(1, expected[i].abs())),
      reason: reason,
    );
  }
}

Future<void> _playWithChaos(
  WidgetTester tester,
  _Session session,
  math.Random random,
) async {
  final live = TrackController(vsync: tester)..play(session.timeline);
  addTearDown(live.dispose);
  final reference = TrackController(vsync: tester)
    ..play(session.timeline)
    ..pause();
  addTearDown(reference.dispose);
  final positions = <Duration>[];
  await tester.pump();

  for (var frame = 0; frame < 160; frame++) {
    var gap = const Duration(milliseconds: 16);
    final action = random.nextInt(20);
    switch (action) {
      case 0:
        gap = Duration(milliseconds: random.nextInt(5000));
      case 1:
        gap = Duration(seconds: 10 + random.nextInt(50));
      case 2:
        gap = Duration.zero;
      case 3:
        live.playbackSpeed = [0.1, 0.5, 1.0, 2.0, 4.0][random.nextInt(5)];
      case 4:
        timeDilation = [0.5, 1.0, 3.0][random.nextInt(3)];
      case 5:
        live.pause();
      case 6 || 7:
        live.resume();
      case 8 when positions.isNotEmpty:
        // Loops that can't repeat exactly keep only their latest cycles.
        final kept = _earliestKept(live.inspectPlayback());
        final candidates = [
          for (final position in positions)
            if (position >= kept) position,
        ];
        if (candidates.isNotEmpty) {
          live
            ..pause()
            ..scrubTo(candidates[random.nextInt(candidates.length)]);
        }
      case 9:
        live
          ..pause()
          ..scrubTo(
            live.inspectPlayback().position + const Duration(seconds: 1),
          )
          ..resume();
    }
    await tester.pump(gap);
    final position = live.inspectPlayback().position;
    printOnFailure('frame $frame: action $action, gap $gap, speed '
        '${live.playbackSpeed}, position $position, animating '
        '${live.isAnimating}, values ${[
      for (final track in session.tracks) _normalized(live, track),
    ]}');
    positions.add(position);
    reference.scrubTo(position);
    for (final (index, track) in session.tracks.indexed) {
      final reason = 'track $index, frame $frame at $position';
      _expectSame(
        _normalized(live, track),
        _normalized(reference, track),
        'value, $reason',
      );
      _expectSame(
        _normalizedVelocity(live, track),
        _normalizedVelocity(reference, track),
        'velocity, $reason',
        tolerance: 1e-6,
      );
    }
  }
  live.playbackSpeed = 1;
  timeDilation = 1;
  _expectBarriersMeet(live.inspectPlayback(), session);
  live.stop(canceled: true);
}

/// The earliest time every track still shows as it played.
Duration _earliestKept(PlaybackSnapshot snapshot) {
  var kept = Duration.zero;
  for (final track in snapshot.tracks) {
    if (track.segments.isEmpty) continue;
    final start = track.startOffset + track.segments.first.start;
    if (start > kept) kept = start;
  }
  return kept;
}

/// Every round of a barrier releases all tracks that reached it at once,
/// when the last one arrived.
void _expectBarriersMeet(PlaybackSnapshot snapshot, _Session session) {
  final releases = <Object, List<List<(Duration, Duration?)>>>{};
  for (final track in snapshot.tracks) {
    // Earlier cycles were dropped, so rounds can't be counted.
    if (track.segments.isEmpty || track.segments.first.start != Duration.zero) {
      return;
    }
    final perToken = <Object, List<(Duration, Duration?)>>{};
    for (final segment in track.segments) {
      final step = track.steps[segment.stepIndex];
      if (step is! StepSync) continue;
      (perToken[step.token] ??= []).add(
        (
          track.startOffset + segment.start,
          segment.end == null ? null : track.startOffset + segment.end!,
        ),
      );
    }
    for (final MapEntry(:key, :value) in perToken.entries) {
      (releases[key] ??= []).add(value);
    }
  }
  for (final MapEntry(key: token, value: tracks) in releases.entries) {
    if (tracks.length < 2) continue;
    final rounds = tracks.map((arrivals) => arrivals.length).reduce(math.min);
    for (var round = 0; round < rounds; round++) {
      final arrivals = [for (final track in tracks) track[round]];
      if (arrivals.any((arrival) => arrival.$2 == null)) continue;
      final latest = arrivals.map((arrival) => arrival.$1).reduce(
            (a, b) => a > b ? a : b,
          );
      for (final (arrived, released) in arrivals) {
        expect(
          (released! - latest).inMicroseconds.abs(),
          lessThanOrEqualTo(2),
          reason: '$token round $round: arrived at $arrived, released at '
              '$released, the last arrived at $latest\n${session.describe()}',
        );
      }
    }
  }
}

/// A future's outcome: ended, settled or canceled, in the order they came.
final class _Watched {
  _Watched(this.name, this.future, this.tracks, {required this.loops}) {
    future.ended.then((_) => events.add('ended'));
    future.orCancel.then(
      (_) => events.add('settled'),
      onError: (Object error) =>
          events.add(error is TickerCanceled ? 'canceled' : 'error: $error'),
    );
  }

  final String name;
  final MotionFuture future;
  final Set<Track<Object>> tracks;
  final bool loops;
  final events = <String>[];

  /// Set once a restart or a canceling stop interrupted it before it
  /// settled.
  bool interrupted = false;

  /// Set once a graceful stop stopped all of its tracks.
  bool stopped = false;

  /// Set once a graceful stop settled one of its tracks, which ends and
  /// cancels it.
  bool settledByStop = false;

  bool get resolved =>
      events.contains('settled') || events.contains('canceled');
}

Future<void> _callAtRandom(
  WidgetTester tester,
  math.Random random,
  List<String> log,
) async {
  final tracks = <Track<Object>>[
    Track<double>(
      MotionConverter.single,
      initial: 0,
      motion: const Motion.smoothSpring(),
    ),
    Track<double>(MotionConverter.single, initial: 1, motion: _linear),
    Track<Offset>(
      MotionConverter.offset,
      initial: Offset.zero,
      motion: const Motion.bouncySpring(),
    ),
  ];
  final controller = TrackController(vsync: tester);
  addTearDown(controller.dispose);
  final watched = <_Watched>[];
  await tester.pump();

  void expectConsistent(_Watched future) {
    final events = future.events;
    final reason = '${future.name}: $events';
    expect(events.toSet().length, events.length, reason: 'twice, $reason');
    expect(events.where((e) => e.startsWith('error')), isEmpty, reason: reason);
    expect(
      events.contains('settled') && events.contains('canceled'),
      isFalse,
      reason: reason,
    );
    if (events.contains('settled')) {
      expect(events.indexOf('ended'), 0, reason: 'settled first, $reason');
    }
    if (future.interrupted) {
      expect(events.contains('settled'), isFalse, reason: reason);
    }
    if (future.stopped && !events.contains('canceled')) {
      expect(events.contains('ended'), isTrue, reason: 'stopped, $reason');
    }
    if (future.settledByStop && !future.interrupted) {
      expect(events, ['ended', 'canceled'], reason: 'stopped, $reason');
    }
    if (future.loops && !future.stopped && !future.settledByStop) {
      expect(events.contains('ended'), isFalse, reason: 'loop ended, $reason');
      expect(events.contains('settled'), isFalse, reason: reason);
    }
  }

  for (var call = 0; call < 60; call++) {
    final subset = [
      for (final track in tracks)
        if (random.nextBool()) track,
    ];
    final targets = subset.isEmpty ? tracks.take(1).toList() : subset;
    switch (random.nextInt(10)) {
      case 0 || 1 || 2 || 3:
        final loop = random.nextInt(8) == 0 ? LoopMode.loop : LoopMode.none;
        final generator = PlanGenerator(
          random,
          loop: loop,
          tokens: const [#t],
          maxSteps: 3,
        );
        final animations = [
          for (final track in targets) _randomAnimation(track, generator),
        ];
        final name = 'call $call: animate ${targets.length} tracks, $loop';
        log.add('$name\n${[
          for (final animation in animations) describeSteps(animation.steps),
        ].join('\n')}');
        for (final future in watched) {
          if (!future.resolved && future.tracks.any(targets.contains)) {
            future.interrupted = true;
          }
        }
        watched.add(
          _Watched(
            name,
            controller.animate(animations, loop: loop),
            targets.toSet(),
            loops: loop.isLooping,
          ),
        );
      case 4:
        final all = random.nextBool();
        log.add('call $call: stop ${all ? 'all' : targets.length}');
        for (final future in watched) {
          if (!future.resolved &&
              (all || future.tracks.every(targets.contains))) {
            future.stopped = true;
          }
        }
        final stop = controller.stop(tracks: all ? null : targets);
        // Its future waits for the tracks that settle, which just started
        // a one-step plan to where they are.
        final snapshot = controller.inspectPlayback();
        final settling = {
          for (final playback in snapshot.tracks)
            if ((all || targets.contains(playback.track)) &&
                playback.startOffset == snapshot.position &&
                playback.steps.length == 1 &&
                controller.isAnimating)
              playback.track,
        };
        // A graceful stop ends the futures of the tracks it settles and
        // cancels them, as in 1.x.
        for (final future in watched) {
          if (!future.resolved && future.tracks.any(settling.contains)) {
            future.settledByStop = true;
          }
        }
        watched.add(
          _Watched('call $call: stop', stop, settling, loops: false),
        );
      case 5:
        final all = random.nextBool();
        log.add('call $call: stop ${all ? 'all' : targets.length} canceled');
        for (final future in watched) {
          if (!future.resolved &&
              (all || future.tracks.any(targets.contains))) {
            future.interrupted = true;
          }
        }
        controller.stop(tracks: all ? null : targets, canceled: true);
      case 6:
        log.add('call $call: set');
        // Like a canceling stop, it cancels the futures of that track.
        for (final future in watched) {
          if (!future.resolved && future.tracks.contains(targets.first)) {
            future.interrupted = true;
          }
        }
        controller.set([_restValue(targets.first)]);
    }
    final gap = switch (random.nextInt(6)) {
      0 => Duration(milliseconds: random.nextInt(3000)),
      1 => Duration.zero,
      _ => const Duration(milliseconds: 16),
    };
    await tester.pump(gap);
    for (final track in tracks) {
      for (final value in _normalized(controller, track)) {
        expect(value.isFinite, isTrue, reason: 'call $call');
      }
    }
    watched.forEach(expectConsistent);
  }

  controller.stop(canceled: true);
  await tester.pump();
  for (final future in watched) {
    expectConsistent(future);
    expect(future.resolved, isTrue, reason: '${future.name} is pending');
  }
}

const _linear = Motion.linear(Duration(milliseconds: 150));

TrackAnimation _randomAnimation(Track<Object> track, PlanGenerator generator) =>
    switch (track) {
      final Track<double> track => track(
          generator.steps(1, (values) => values.single, allowFallback: true),
        ),
      final Track<Offset> track => track(
          generator.steps(
            2,
            (values) => Offset(values[0], values[1]),
            allowFallback: true,
          ),
        ),
      _ => throw StateError('unexpected track $track'),
    };

TrackValue<T> _restValue<T extends Object>(Track<T> track) =>
    track.value(track.initial!);

Future<void> _retargetEveryFrame(
  WidgetTester tester,
  math.Random random,
) async {
  final tracks = [
    Track<double>(MotionConverter.single, initial: 0),
    Track<Offset>(MotionConverter.offset, initial: Offset.zero),
  ];
  final motions = <Motion>[
    const Motion.smoothSpring(),
    const Motion.bouncySpring(duration: Duration(milliseconds: 300)),
    const Motion.interactiveSpring(),
    const CupertinoMotion(bounce: 0.6, snapToEnd: false),
    const Motion.snappySpring().scaleTo(const Duration(milliseconds: 200)),
  ];
  final controller = TrackController(vsync: tester);
  addTearDown(controller.dispose);
  final futures = <_Watched>[];
  await tester.pump();

  for (var frame = 0; frame < 240; frame++) {
    final track = tracks[random.nextInt(tracks.length)];
    final motion = motions[random.nextInt(motions.length)];
    final before = _normalized(controller, track);
    final velocityBefore = _normalizedVelocity(controller, track);
    final future = switch (track) {
      final Track<double> track => controller.animate([
          track.to(random.nextDouble() * 400 - 200, motion: motion),
        ]),
      final Track<Offset> track => controller.animate([
          track([
            TrackStep.to(
              Offset(random.nextDouble() * 400, random.nextDouble() * 400),
              motion: motion,
              until: WaitUntil.duration,
            ),
            TrackStep.to(Offset.zero, motion: motion),
          ]),
        ]),
      _ => throw StateError('unexpected track'),
    };
    futures.add(_Watched('frame $frame', future, {track}, loops: false));
    // A retarget starts where the track is, with its velocity.
    _expectSame(
      _normalized(controller, track),
      before,
      'value at frame $frame',
    );
    _expectSame(
      _normalizedVelocity(controller, track),
      velocityBefore,
      'velocity at frame $frame',
      tolerance: 1e-6,
    );
    await tester.pump(Duration(milliseconds: [4, 8, 16, 16, 33][frame % 5]));
    for (final value in _normalized(controller, track)) {
      expect(value.isFinite, isTrue);
      expect(value.abs(), lessThan(1e4), reason: 'frame $frame');
    }
  }
  expect(controller.debugTrackCount, tracks.length);
  await tester.pumpAndSettle();
  await tester.pump();
  for (final (index, future) in futures.indexed) {
    // Only the last call of each track can have settled; the rest were
    // retargeted.
    final settled = future.events.contains('settled');
    final isLast = futures.skip(index + 1).every(
          (later) => !later.tracks.containsAll(future.tracks),
        );
    expect(settled, isLast, reason: '${future.name}: ${future.events}');
    expect(future.resolved, isTrue, reason: future.name);
  }
}
