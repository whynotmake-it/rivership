// ignore_for_file: cascade_invocations

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';

import 'fuzz_support.dart';

/// Builders rebuilt every frame with random changes to what they play and
/// how.
void main() {
  const sessions = 8 * fuzzScale;

  group('TrackBuilder rebuilt at random', () {
    for (var run = 0; run < sessions; run++) {
      final seed = fuzzSeed + 800000 + run;
      testWidgets('session $seed', (tester) async {
        final log = <String>[];
        await runCaseAsync(
          seed,
          () => log.join('\n'),
          () => _rebuildTrackBuilder(tester, math.Random(seed), log),
        );
      });
    }
  });

  group('TrackBuilder', () {
    final track = Track<double>(MotionConverter.single, initial: 0);
    final animations = [
      track([
        const TrackStep.to(
          1,
          motion: Motion.linear(Duration(milliseconds: 200)),
        ),
        const TrackStep.to(3, motion: Motion.bouncySpring()),
      ]),
    ];

    testWidgets('a restart every frame replays from the start every frame',
        (tester) async {
      late double shown;
      Widget build(int restart) => TrackBuilder(
            animations: animations,
            restartTrigger: restart,
            builder: (context, value, child) {
              shown = value(track);
              return const SizedBox();
            },
          );
      await tester.pumpWidget(build(0));
      for (var restart = 1; restart < 60; restart++) {
        await tester.pumpWidget(
          build(restart),
          duration: const Duration(milliseconds: 16),
        );
        // Rebuilt with the new trigger, the track jumped back to its start.
        expect(shown, 0, reason: 'restart $restart');
      }
      await tester.pump(const Duration(milliseconds: 100));
      expect(shown, closeTo(0.5, 1e-9));
      await tester.pumpAndSettle();
      expect(shown, 3);
    });

    testWidgets('muting, rate changes and unmuting keep one timeline',
        (tester) async {
      late double shown;
      Widget build({required bool enabled, TickerRate? rate}) => TickerMode(
            enabled: enabled,
            child: TrackBuilder(
              animations: [
                track.to(10, motion: const Motion.linear(Duration(seconds: 1))),
              ],
              tickerRate: rate,
              builder: (context, value, child) {
                shown = value(track);
                return const SizedBox();
              },
            ),
          );
      await tester.pumpWidget(build(enabled: true));
      await tester.pump(const Duration(milliseconds: 200));
      expect(shown, closeTo(2, 1e-9));

      await tester.pumpWidget(
        build(
          enabled: true,
          rate: const TickerRate.interval(Duration(milliseconds: 50)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(shown, closeTo(3, 1e-9));

      await tester.pumpWidget(build(enabled: false));
      await tester.pump(const Duration(milliseconds: 300));
      expect(shown, closeTo(3, 1e-9));
      await tester.pumpWidget(build(enabled: true));
      await tester.pump(const Duration(milliseconds: 16));
      // A muted ticker keeps its start, so time kept passing meanwhile.
      expect(shown, closeTo(6.16, 1e-9));
      await tester.pumpAndSettle();
      expect(shown, 10);
    });
  });

  group('PhaseTrackBuilder rebuilt at random', () {
    for (var run = 0; run < sessions; run++) {
      final seed = fuzzSeed + 900000 + run;
      testWidgets('session $seed', (tester) async {
        final log = <String>[];
        await runCaseAsync(
          seed,
          () => log.join('\n'),
          () => _rebuildPhaseTrackBuilder(tester, math.Random(seed), log),
        );
      });
    }
  });
}

/// Counts the controllers builders create and dispose.
class _Counter implements MotorInspectionObserver {
  int registered = 0;
  int unregistered = 0;

  @override
  void didRegisterController(TrackController controller) => registered++;

  @override
  void didUnregisterController(TrackController controller) => unregistered++;
}

final _tracks = <Track<Object>>[
  Track<double>(
    MotionConverter.single,
    initial: 0,
    motion: const Motion.smoothSpring(),
  ),
  Track<double>(MotionConverter.single, initial: 1),
  Track<Offset>(
    MotionConverter.offset,
    initial: Offset.zero,
    motion: const Motion.bouncySpring(),
  ),
];

TrackAnimation _generate(Track<Object> track, PlanGenerator generator) =>
    switch (track) {
      final Track<double> track => track(
          generator.steps(
            1,
            (values) => values.single,
            allowFallback: track.motion != null,
          ),
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

TrackAnimation _settleAt(Track<Object> track, double value) => switch (track) {
      final Track<double> track =>
        track.to(value, motion: const Motion.snappySpring()),
      final Track<Offset> track =>
        track.to(Offset(value, -value), motion: const Motion.snappySpring()),
      _ => throw StateError('unexpected track $track'),
    };

List<double> _read(TrackValueReader value, Track<Object> track) =>
    _normalize(track, value(track));

List<double> _normalize<T extends Object>(Track<T> track, Object value) =>
    track.converter.normalize(value as T);

List<double>? _endOf(TrackAnimation animation) => switch (animation.endValue) {
      final end? => _normalize(animation.track, end.value),
      null => null,
    };

const _rates = <TickerRate?>[
  null,
  TickerRate.interval(Duration(milliseconds: 33)),
];

Future<void> _rebuildTrackBuilder(
  WidgetTester tester,
  math.Random random,
  List<String> log,
) async {
  final counter = _Counter();
  final subscription = MotorInspectionRegistry.attach(counter);
  addTearDown(subscription.dispose);
  // Plans that can loop, so that changing the loop mode alone is valid.
  final generator = PlanGenerator(
    random,
    loop: LoopMode.loop,
    tokens: const [#meet],
    maxSteps: 4,
  );
  var animations = [for (final track in _tracks) _generate(track, generator)];
  var loop = LoopMode.none;
  var active = true;
  var restart = 0;
  var key = 0;
  var rate = _rates.first;
  var ticking = true;
  var useTimeline = false;
  late TrackValueReader shown;
  final statuses = <(int, AnimationStatus)>[];
  final entered = <(Track, int)>[];

  Widget build() {
    Widget builder(BuildContext context, TrackValueReader value, Widget? _) {
      shown = value;
      for (final track in _tracks) {
        for (final component in _read(value, track)) {
          expect(component.isFinite, isTrue);
        }
      }
      return const SizedBox();
    }

    final child = useTimeline
        ? TrackBuilder.timeline(
            TrackTimeline(animations, loop: loop),
            key: ValueKey(key),
            active: active,
            restartTrigger: restart,
            tickerRate: rate,
            onStep: (track, step) => entered.add((track, step)),
            onAnimationStatusChanged: (status) => statuses.add((key, status)),
            builder: builder,
          )
        : TrackBuilder(
            key: ValueKey(key),
            animations: animations,
            loop: loop,
            active: active,
            restartTrigger: restart,
            tickerRate: rate,
            onStep: (track, step) => entered.add((track, step)),
            onAnimationStatusChanged: (status) => statuses.add((key, status)),
            builder: builder,
          );
    return TickerMode(enabled: ticking, child: child);
  }

  await tester.pumpWidget(build());
  // Built inactive, tracks start at their start values; changes while
  // inactive then jump them to their end values.
  var atStart = false;
  for (var frame = 0; frame < 100; frame++) {
    final change = random.nextInt(14);
    final previousTimeline = TrackTimeline(animations, loop: loop);
    final previousAnimations = animations;
    final wasTimeline = useTimeline;
    switch (change) {
      case 0 || 1 || 2 || 3:
        final index = random.nextInt(_tracks.length);
        animations = [...animations]..[index] =
            _generate(_tracks[index], generator);
        log.add('frame $frame: track $index plays\n'
            '${describeSteps(animations[index].steps)}');
      case 4:
        active = !active;
        log.add('frame $frame: active $active');
      case 5:
        restart++;
        log.add('frame $frame: restart');
      case 6:
        key++;
        log.add('frame $frame: new key');
      case 7:
        loop = LoopMode.values[random.nextInt(LoopMode.values.length)];
        log.add('frame $frame: loop $loop');
      case 8:
        rate = _rates[random.nextInt(_rates.length)];
        log.add('frame $frame: ticker rate $rate');
      case 9:
        ticking = !ticking;
        log.add('frame $frame: ticking $ticking');
      case 10:
        useTimeline = !useTimeline;
        log.add('frame $frame: timeline $useTimeline');
    }
    if (change == 6 && !active) atStart = true;
    if (change == 4 ||
        wasTimeline != useTimeline ||
        (useTimeline
            ? previousTimeline != TrackTimeline(animations, loop: loop)
            : !_sameAnimations(previousAnimations, animations))) {
      atStart = false;
    }
    await tester.pumpWidget(
      build(),
      duration: Duration(milliseconds: [0, 8, 16, 16, 16, 250][frame % 6]),
    );
    expect(tester.takeException(), isNull, reason: 'frame $frame');
    if (!active) {
      for (final animation in animations) {
        final expected = atStart
            ? _normalize(animation.track, animation.track.initial!)
            : _endOf(animation);
        if (expected == null) continue;
        expect(
          _read(shown, animation.track),
          expected,
          reason: 'frame $frame, ${atStart ? 'start' : 'end'} value',
        );
      }
    }
  }

  for (final (track, step) in entered) {
    expect(_tracks, contains(track));
    expect(step, inInclusiveRange(0, 5));
  }
  // Each controller reports a status only when it changes.
  for (var i = 1; i < statuses.length; i++) {
    if (statuses[i].$1 != statuses[i - 1].$1) continue;
    expect(statuses[i], isNot(statuses[i - 1]), reason: 'status $i repeats');
  }

  // Once changes stop, every track comes to rest where it was sent.
  animations = [
    for (final (index, track) in _tracks.indexed) _settleAt(track, index + 0.5),
  ];
  active = true;
  ticking = true;
  loop = LoopMode.none;
  // Fixed-rate tickers run on timers, which pumpAndSettle doesn't wait for.
  rate = null;
  log.add('settle');
  await tester.pumpWidget(build());
  await tester.pumpAndSettle();
  for (final animation in animations) {
    expect(_read(shown, animation.track), _endOf(animation));
  }

  await tester.pumpWidget(const SizedBox());
  expect(counter.unregistered, counter.registered);
  expect(counter.registered, key + 1);
}

bool _sameAnimations(List<TrackAnimation> a, List<TrackAnimation> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

enum _Phase { rest, lift, fly }

Future<void> _rebuildPhaseTrackBuilder(
  WidgetTester tester,
  math.Random random,
  List<String> log,
) async {
  final counter = _Counter();
  final subscription = MotorInspectionRegistry.attach(counter);
  addTearDown(subscription.dispose);
  final generator = PlanGenerator(
    random,
    loop: LoopMode.loop,
    tokens: const [],
    maxSteps: 3,
  );

  TrackPhaseTimeline<_Phase> timeline() {
    final phases = _Phase.values.sublist(0, 2 + random.nextInt(2));
    return TrackPhaseTimeline(
      {
        for (final phase in phases)
          phase: [
            for (final track in _tracks)
              if (random.nextInt(3) > 0) _generate(track, generator),
          ],
      },
      phaseLoop: LoopMode.values[random.nextInt(LoopMode.values.length)],
    );
  }

  var current = timeline();
  _Phase? phase;
  var playing = false;
  var active = true;
  var restart = 0;
  var key = 0;
  late TrackValueReader shown;
  late _Phase shownPhase;
  final transitions = <PhaseTransition<_Phase>>[];

  Widget build() => PhaseTrackBuilder<_Phase>(
        key: ValueKey(key),
        timeline: current,
        currentPhase: phase,
        playing: playing,
        active: active,
        restartTrigger: restart,
        onTransition: transitions.add,
        builder: (context, value, phase, child) {
          shown = value;
          shownPhase = phase;
          for (final track in _tracks) {
            for (final component in _read(value, track)) {
              expect(component.isFinite, isTrue);
            }
          }
          return const SizedBox();
        },
      );

  await tester.pumpWidget(build());
  for (var frame = 0; frame < 100; frame++) {
    switch (random.nextInt(10)) {
      case 0 || 1 || 2:
        final phases = current.phases;
        phase = phases[random.nextInt(phases.length)];
        log.add('frame $frame: phase $phase');
      case 3:
        playing = !playing;
        log.add('frame $frame: playing $playing');
      case 4:
        active = !active;
        log.add('frame $frame: active $active');
      case 5:
        restart++;
        log.add('frame $frame: restart');
      case 6:
        key++;
        log.add('frame $frame: new key');
      case 7:
        current = timeline();
        if (phase != null && !current.phases.contains(phase)) phase = null;
        log.add('frame $frame: new timeline ${current.phaseLoop} ${[
          for (final MapEntry(:key, :value) in current.phaseAnimations.entries)
            '$key:\n${[
              for (final animation in value) describeSteps(animation.steps),
            ].join('\n  --\n')}',
        ].join('\n')}');
    }
    await tester.pumpWidget(
      build(),
      duration: Duration(milliseconds: [0, 16, 16, 16, 300][frame % 5]),
    );
    expect(tester.takeException(), isNull, reason: 'frame $frame');
    expect(current.phases, contains(shownPhase), reason: 'frame $frame');
  }

  for (final transition in transitions) {
    switch (transition) {
      case PhaseTransitioning(:final from, :final to):
        expect(from, isNot(to));
      case PhaseSettled(:final phase):
        expect(_Phase.values, contains(phase));
    }
  }

  // Once changes stop, the tracks rest at the phase they were sent to.
  current = TrackPhaseTimeline({
    for (final (index, phase) in _Phase.values.indexed)
      phase: [
        for (final (offset, track) in _tracks.indexed)
          _settleAt(track, index * 10.0 + offset),
      ],
  });
  phase = _Phase.fly;
  playing = false;
  active = true;
  log.add('settle at fly');
  transitions.clear();
  await tester.pumpWidget(build());
  await tester.pumpAndSettle();
  expect(shownPhase, _Phase.fly);
  for (final animation in current.phaseAnimations[_Phase.fly]!) {
    expect(_read(shown, animation.track), _endOf(animation));
  }
  if (transitions.isNotEmpty) {
    expect(transitions.last, isA<PhaseSettled<_Phase>>());
  }

  await tester.pumpWidget(const SizedBox());
  expect(counter.unregistered, counter.registered);
  expect(counter.registered, key + 1);
}
