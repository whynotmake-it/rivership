// ignore_for_file: cascade_invocations, unawaited_futures

import 'package:flutter/scheduler.dart' show timeDilation;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';

const _linear100 = Motion.linear(Duration(milliseconds: 100));
const _frame = Duration(milliseconds: 16);

/// How a [MotionFuture] resolved, recorded in order.
final class _Outcome {
  _Outcome(MotionFuture future) {
    future.ended.then((_) => events.add('ended'));
    future.orCancel.then(
      (_) => events.add('settled'),
      onError: (Object error) =>
          events.add(error is TickerCanceled ? 'canceled' : 'error: $error'),
    );
  }

  final events = <String>[];

  bool get ended => events.contains('ended');
  bool get settled => events.contains('settled');
  bool get canceled => events.contains('canceled');
}

class _Observer implements MotorInspectionObserver {
  @override
  void didRegisterController(TrackController controller) {}

  @override
  void didUnregisterController(TrackController controller) {}
}

void main() {
  final a = Track<double>(MotionConverter.single, initial: 0);
  final b = Track<double>(MotionConverter.single, initial: 0);

  group('re-entrancy', () {
    testWidgets(
        'animate from onStep in the frame the plan finishes keeps playing',
        (tester) async {
      final controller = TrackController(vsync: tester);
      addTearDown(controller.dispose);
      _Outcome? next;
      controller.animate(
        [
          a([
            const TrackStep.to(1, motion: _linear100),
            const TrackStep.to(2, motion: Motion.linear(Duration.zero)),
          ]),
        ],
        onStep: (track, step) {
          if (step == 1 && next == null) {
            next = _Outcome(controller.animate([b.to(5, motion: _linear100)]));
          }
        },
      );
      await tester.pump();
      // One frame enters and finishes the last step.
      await tester.pump(const Duration(milliseconds: 200));
      expect(next, isNotNull);
      expect(controller.isAnimating, isTrue);

      await tester.pump(const Duration(milliseconds: 50));
      expect(controller.value(b), closeTo(2.5, 1e-9));
      await tester.pump(const Duration(milliseconds: 60));
      expect(controller.value(b), 5);
      expect(controller.isAnimating, isFalse);
      expect(next!.events, ['ended', 'settled']);
    });

    testWidgets('restarting the same track from onStep keeps playing',
        (tester) async {
      final controller = TrackController(vsync: tester);
      addTearDown(controller.dispose);
      var restarts = 0;
      void onStep(Track track, int step) {
        if (step == 1 && restarts++ == 0) {
          controller.animate([a.to(0, motion: _linear100)]);
        }
      }

      controller.animate(
        [
          a([
            const TrackStep.to(1, motion: _linear100),
            const TrackStep.to(2, motion: Motion.linear(Duration.zero)),
          ]),
        ],
        onStep: onStep,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(controller.value(a), 2);
      expect(controller.isAnimating, isTrue);
      await tester.pump(const Duration(milliseconds: 50));
      expect(controller.value(a), closeTo(1, 1e-9));
      await tester.pump(const Duration(milliseconds: 60));
      expect(controller.value(a), 0);
      expect(controller.isAnimating, isFalse);
    });

    testWidgets('a canceling stop from onStep stops every track at once',
        (tester) async {
      final controller = TrackController(vsync: tester);
      addTearDown(controller.dispose);
      final outcome = _Outcome(
        controller.animate(
          [
            a([
              const TrackStep.to(1, motion: _linear100),
              const TrackStep.to(2, motion: _linear100),
            ]),
            b.to(1, motion: const Motion.linear(Duration(seconds: 1))),
          ],
          onStep: (track, step) {
            if (step == 1) controller.stop(canceled: true);
          },
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      final stoppedAt = (controller.value(a), controller.value(b));
      await tester.pump(const Duration(milliseconds: 150));
      expect((controller.value(a), controller.value(b)), stoppedAt);
      expect(controller.isAnimating, isFalse);
      expect(outcome.events, ['canceled']);
    });

    testWidgets('a graceful stop from onStep settles the springs',
        (tester) async {
      final controller = TrackController(vsync: tester);
      addTearDown(controller.dispose);
      MotionFuture? stop;
      controller.animate(
        [
          a([
            const TrackStep.to(1, motion: Motion.bouncySpring()),
            const TrackStep.to(-1, motion: Motion.bouncySpring()),
          ]),
        ],
        onStep: (track, step) {
          if (step == 1) stop = controller.stop();
        },
      );
      await tester.pumpAndSettle();
      expect(stop, isNotNull);
      final outcome = _Outcome(stop!);
      await tester.pump();
      expect(outcome.events, ['ended', 'settled']);
      expect(controller.isAnimating, isFalse);
      expect(controller.value(a).isFinite, isTrue);
    });

    testWidgets('dispose from onStep leaves nothing running', (tester) async {
      final controller = TrackController(vsync: tester);
      final outcome = _Outcome(
        controller.animate(
          [
            a([
              const TrackStep.to(1, motion: _linear100),
              const TrackStep.to(2, motion: _linear100),
            ]),
            b.to(1, motion: _linear100),
          ],
          onStep: (track, step) {
            if (step == 1) controller.dispose();
          },
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.takeException(), isNull);
      expect(outcome.events, ['canceled']);
    });

    testWidgets('dispose from a status listener leaves nothing running',
        (tester) async {
      final controller = TrackController(vsync: tester);
      controller.addStatusListener((status) {
        if (status == AnimationStatus.completed) controller.dispose();
      });
      final outcome =
          _Outcome(controller.animate([a.to(1, motion: _linear100)]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.takeException(), isNull);
      expect(outcome.events, ['ended', 'settled']);
    });

    testWidgets('animating from a status listener chains runs', (tester) async {
      final controller = TrackController(vsync: tester);
      addTearDown(controller.dispose);
      final statuses = <AnimationStatus>[];
      var bounces = 0;
      controller.addStatusListener((status) {
        statuses.add(status);
        if (!status.isAnimating && bounces++ < 3) {
          controller.animate([a.to(bounces.isOdd ? 0 : 1, motion: _linear100)]);
        }
      });
      controller.animate([a.to(1, motion: _linear100)]);
      for (var i = 0; i < 60; i++) {
        await tester.pump(_frame);
      }
      expect(controller.isAnimating, isFalse);
      expect(bounces, 4);
      expect(controller.value(a), 0);
      expect(statuses, [
        for (var i = 0; i < 2; i++) ...[
          AnimationStatus.forward,
          AnimationStatus.completed,
          AnimationStatus.reverse,
          AnimationStatus.dismissed,
        ],
      ]);
    });

    testWidgets('animating from future callbacks chains in order',
        (tester) async {
      final controller = TrackController(vsync: tester);
      addTearDown(controller.dispose);
      final log = <String>[];
      final first = controller.animate([
        a.to(1, motion: const Motion.bouncySpring()),
      ]);
      first.ended.then((_) {
        log.add('first ended');
        controller.animate([b.to(1, motion: _linear100)]).then((_) {
          log.add('second settled');
          controller.stop(canceled: true);
        });
      });
      first.then((_) => log.add('first settled'));
      await tester.pumpAndSettle();
      expect(log, ['first ended', 'second settled']);
      // The canceling stop halted `a` too, so its settle was canceled.
      expect(controller.isAnimating, isFalse);
    });
  });

  group('interrupting and resuming time', () {
    testWidgets('a muted ticker catches up in one frame and matches a scrub',
        (tester) async {
      final subscription = MotorInspectionRegistry.attach(_Observer());
      addTearDown(subscription.dispose);
      final key = GlobalKey<_HostState>();
      Widget host({required bool enabled}) => TickerMode(
            enabled: enabled,
            child: _Host(key: key),
          );
      await tester.pumpWidget(host(enabled: true));
      final controller = key.currentState!.controller;
      final timeline = TrackTimeline(
        [
          a([
            const TrackStep.to(1, motion: Motion.bouncySpring()),
            const TrackStep.sync(token: #meet),
            const TrackStep.to(0, motion: _linear100),
          ]),
          b([
            const TrackStep.to(1, motion: Motion.linear(Duration(seconds: 2))),
            const TrackStep.sync(token: #meet),
            const TrackStep.to(3, motion: Motion.smoothSpring()),
          ]),
        ],
        loop: LoopMode.pingPong,
      );
      controller.play(timeline);
      await tester.pump();
      for (var i = 0; i < 20; i++) {
        await tester.pump(_frame);
      }

      await tester.pumpWidget(host(enabled: false));
      final mutedAt = (controller.value(a), controller.value(b));
      await tester.pump(const Duration(seconds: 30));
      expect((controller.value(a), controller.value(b)), mutedAt);

      await tester.pumpWidget(host(enabled: true));
      await tester.pump(_frame);
      final position = controller.inspectPlayback().position;
      expect(position, greaterThan(const Duration(seconds: 30)));

      final reference = TrackController(vsync: tester)
        ..play(timeline)
        ..pause()
        ..scrubTo(position);
      addTearDown(reference.dispose);
      expect(controller.value(a), closeTo(reference.value(a), 1e-9));
      expect(controller.value(b), closeTo(reference.value(b), 1e-9));
      controller.stop(canceled: true);
    });

    testWidgets(
        'speed, dilation and pauses change when, not what, playback shows',
        (tester) async {
      final subscription = MotorInspectionRegistry.attach(_Observer());
      addTearDown(subscription.dispose);
      addTearDown(() => timeDilation = 1);
      final timeline = TrackTimeline([
        a([
          const TrackStep.to(1, motion: Motion.bouncySpring()),
          const TrackStep.at(
            Duration(milliseconds: 900),
            0,
            motion: _linear100,
          ),
          const TrackStep.to(2, motion: Motion.smoothSpring()),
        ]),
        b([
          const TrackStep.hold(Duration(milliseconds: 200)),
          const TrackStep.to(
            1,
            motion: Motion.snappySpring(),
            until: WaitUntil.duration,
          ),
          const TrackStep.to(-1, motion: Motion.linear(Duration(seconds: 1))),
        ]),
      ]);
      final controller = TrackController(vsync: tester)..play(timeline);
      addTearDown(controller.dispose);
      final reference = TrackController(vsync: tester)
        ..play(timeline)
        ..pause();
      addTearDown(reference.dispose);

      await tester.pump();
      final chaos = <void Function()>[
        () => controller.playbackSpeed = 0.25,
        () => controller.playbackSpeed = 3,
        () => controller.playbackSpeed = 1,
        () => timeDilation = 5,
        () => timeDilation = 1,
        controller.pause,
        controller.resume,
      ];
      for (var i = 0; i < 200 && controller.isAnimating; i++) {
        chaos[i * 7 % chaos.length]();
        if (!controller.isAnimating && i.isEven) controller.resume();
        await tester.pump(Duration(milliseconds: 5 + i * 13 % 40));
        reference.scrubTo(controller.inspectPlayback().position);
        expect(controller.value(a), closeTo(reference.value(a), 1e-9));
        expect(controller.value(b), closeTo(reference.value(b), 1e-9));
        expect(controller.velocity(a), closeTo(reference.velocity(a), 1e-6));
      }
      controller.playbackSpeed = 1;
      timeDilation = 1;
      controller.resume();
      await tester.pumpAndSettle();
      expect(controller.value(a), 2);
      expect(controller.value(b), -1);
    });

    testWidgets('seeking back and forth, then resuming, replays the same',
        (tester) async {
      final subscription = MotorInspectionRegistry.attach(_Observer());
      addTearDown(subscription.dispose);
      final timeline = TrackTimeline([
        a([
          const TrackStep.to(1, motion: Motion.bouncySpring()),
          const TrackStep.sync(token: #s),
          const TrackStep.to(0, motion: Motion.smoothSpring()),
        ]),
        b([
          const TrackStep.to(2, motion: Motion.linear(Duration(seconds: 1))),
          const TrackStep.sync(token: #s),
          const TrackStep.to(0, motion: _linear100),
        ]),
      ]);
      final live = TrackController(vsync: tester)..play(timeline);
      addTearDown(live.dispose);
      final recorded = <(Duration, double, double)>[];
      await tester.pump();
      for (var i = 0; i < 150; i++) {
        await tester.pump(_frame);
        recorded.add(
          (
            live.inspectPlayback().position,
            live.value(a),
            live.value(b),
          ),
        );
      }

      final scrubbed = TrackController(vsync: tester)..play(timeline);
      addTearDown(scrubbed.dispose);
      await tester.pump();
      scrubbed.pause();
      for (var i = 0; i < 300; i++) {
        final (position, valueA, valueB) = recorded[(i * 37) % recorded.length];
        scrubbed.scrubTo(position);
        expect(scrubbed.value(a), closeTo(valueA, 1e-9), reason: '$position');
        expect(scrubbed.value(b), closeTo(valueB, 1e-9), reason: '$position');
      }
      final (start, _, _) = recorded[10];
      scrubbed
        ..scrubTo(start)
        ..resume();
      // A restarted ticker's first frame is at its start.
      await tester.pump();
      for (var i = 11; i < recorded.length; i++) {
        await tester.pump(_frame);
        final (position, valueA, valueB) = recorded[i];
        expect(scrubbed.inspectPlayback().position, position);
        expect(scrubbed.value(a), closeTo(valueA, 1e-9), reason: 'frame $i');
        expect(scrubbed.value(b), closeTo(valueB, 1e-9), reason: 'frame $i');
      }
    });
  });

  group('failing callbacks and simulations', () {
    testWidgets(
      'a throwing onStep is reported and playback continues',
      (tester) async {
        final controller = TrackController(vsync: tester);
        addTearDown(controller.dispose);
        controller.animate(
          [
            a([
              const TrackStep.to(1, motion: _linear100),
              const TrackStep.to(2, motion: _linear100),
            ]),
          ],
          onStep: (track, step) {
            if (step == 1) throw StateError('onStep');
          },
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));
        expect(tester.takeException(), isStateError);
        await tester.pump(const Duration(milliseconds: 100));
        expect(controller.value(a), 2);
        expect(controller.isAnimating, isFalse);
      },
    );

    testWidgets(
      'a retarget after a throwing simulation plays',
      (tester) async {
        final controller = TrackController(vsync: tester);
        addTearDown(controller.dispose);
        controller.animate([a.to(1, motion: const _ThrowingMotion())]);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isStateError);

        controller.animate([a.to(2, motion: _linear100)]);
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 100));
        expect(controller.value(a), 2);
        await tester.pumpAndSettle();
        expect(controller.isAnimating, isFalse);
      },
    );
  });
}

class _Host extends StatefulWidget {
  const _Host({super.key});

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with TickerProviderStateMixin {
  late final controller = TrackController(vsync: this);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

class _ThrowingMotion extends Motion {
  const _ThrowingMotion();

  @override
  bool get needsSettle => false;

  @override
  Simulation createSimulation({
    double start = 0,
    double end = 1,
    double velocity = 0,
  }) =>
      _ThrowingSimulation();

  @override
  bool operator ==(Object other) => other is _ThrowingMotion;

  @override
  int get hashCode => (_ThrowingMotion).hashCode;
}

class _ThrowingSimulation extends Simulation {
  @override
  double x(double time) => time > 0.05 ? throw StateError('x') : time;

  @override
  double dx(double time) => 1;

  @override
  bool isDone(double time) => false;
}
