// ignore_for_file: unawaited_futures

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

const _linear100 = Motion.linear(Duration(milliseconds: 100));

/// Starts [animations] through one entry point and reports status changes to
/// [statuses]. Returns the call's future, when the entry point has one,
/// in a record so that awaiting the start doesn't await the future.
typedef StartEntryPoint = Future<(MotionFuture?,)> Function(
  WidgetTester tester,
  List<TrackAnimation> animations,
  List<AnimationStatus> statuses,
);

TrackController _controller(
  WidgetTester tester,
  List<AnimationStatus> statuses,
) {
  final controller = TrackController(vsync: tester)
    ..addStatusListener(statuses.add);
  addTearDown(controller.dispose);
  return controller;
}

enum _Phase { only }

final _entryPoints = <String, StartEntryPoint>{
  'TrackController.animate': (tester, animations, statuses) async =>
      (_controller(tester, statuses).animate(animations),),
  'TrackController.play': (tester, animations, statuses) async =>
      (_controller(tester, statuses).play(TrackTimeline(animations)),),
  'TrackBuilder': (tester, animations, statuses) async {
    await tester.pumpWidget(
      TrackBuilder(
        animations: animations,
        onAnimationStatusChanged: statuses.add,
        builder: (context, value, child) => const SizedBox(),
      ),
    );
    return (null,);
  },
  'TrackBuilder.timeline': (tester, animations, statuses) async {
    await tester.pumpWidget(
      TrackBuilder.timeline(
        TrackTimeline(animations),
        onAnimationStatusChanged: statuses.add,
        builder: (context, value, child) => const SizedBox(),
      ),
    );
    return (null,);
  },
  'PhaseTrackBuilder': (tester, animations, statuses) async {
    await tester.pumpWidget(
      PhaseTrackBuilder<_Phase>(
        timeline: TrackPhaseTimeline({_Phase.only: animations}),
        onAnimationStatusChanged: statuses.add,
        builder: (context, value, phase, child) => const SizedBox(),
      ),
    );
    return (null,);
  },
};

void main() {
  final atThree = Track<double>(
    MotionConverter.single,
    initial: 3,
    motion: _linear100,
  );

  group('an animation that rests on its only target', () {
    for (final MapEntry(key: name, value: start) in _entryPoints.entries) {
      group('through $name', () {
        testWidgets(
            'neither ticks nor reports a status, and its future '
            'completes at once', (tester) async {
          final statuses = <AnimationStatus>[];
          final (future,) = await start(
            tester,
            [
              atThree([const TrackStep.to(3.0)]),
            ],
            statuses,
          );

          expect(tester.binding.hasScheduledFrame, isFalse);
          if (future != null) {
            var ended = false;
            var completed = false;
            future.ended.then((_) => ended = true);
            future.then((_) => completed = true);
            await tester.idle();
            expect(ended, isTrue);
            expect(completed, isTrue);
          }
          await tester.pump(const Duration(milliseconds: 200));
          expect(statuses, isEmpty);
        });

        testWidgets('plays while another track moves', (tester) async {
          final other = Track<double>(MotionConverter.single, initial: 0);
          final statuses = <AnimationStatus>[];
          await start(
            tester,
            [
              atThree([const TrackStep.to(3.0)]),
              other([const TrackStep.to(1.0, motion: _linear100)]),
            ],
            statuses,
          );

          expect(tester.binding.hasScheduledFrame, isTrue);
          await tester.pumpAndSettle();
          expect(
            statuses,
            [AnimationStatus.forward, AnimationStatus.completed],
          );
        });
      });
    }
  });

  group('the rule for resting', () {
    late TrackController controller;
    late List<AnimationStatus> statuses;

    setUp(() => statuses = []);

    Future<bool> plays(
      WidgetTester tester,
      TrackAnimation<double> animation, {
      LoopMode loop = LoopMode.none,
    }) async {
      controller = _controller(tester, statuses)
        ..animate([animation], loop: loop);
      final playing = controller.isAnimating;
      controller.stop(canceled: true);
      return playing;
    }

    testWidgets('rests when from: is the target', (tester) async {
      final track = Track<double>(
        MotionConverter.single,
        initial: 0,
        motion: _linear100,
      );
      expect(
        await plays(tester, track([const TrackStep.to(2.0)], from: 2.0)),
        isFalse,
      );
      expect(controller.value(track), 2.0);
    });

    testWidgets(
        'a spring on its target with velocity overshoots with the '
        'usual status', (tester) async {
      final spring = Track<double>(
        MotionConverter.single,
        initial: 3,
        motion: const CupertinoMotion.bouncy(),
      );
      controller = _controller(tester, statuses)
        ..animate([
          spring([const TrackStep.to(3.0)], withVelocity: 10),
        ]);
      expect(controller.isAnimating, isTrue);

      var highest = 3.0;
      controller.addListener(() {
        if (controller.value(spring) > highest) {
          highest = controller.value(spring);
        }
      });
      await tester.pumpAndSettle();

      expect(highest, greaterThan(3.1));
      expect(controller.value(spring), 3.0);
      expect(statuses, [AnimationStatus.forward, AnimationStatus.completed]);
    });

    testWidgets('a curve rests whatever the velocity, since it ignores it',
        (tester) async {
      expect(
        await plays(
          tester,
          atThree([const TrackStep.to(3.0)], withVelocity: 1),
        ),
        isFalse,
      );
    });

    testWidgets('an instant move plays', (tester) async {
      expect(
        await plays(
          tester,
          atThree([const TrackStep.to(4.0, motion: Motion.instant())]),
        ),
        isTrue,
      );
    });

    testWidgets('plays with more than one step', (tester) async {
      expect(
        await plays(
          tester,
          atThree([const TrackStep.to(3.0), const TrackStep.to(3.0)]),
        ),
        isTrue,
      );
    });

    testWidgets('plays a keyframe', (tester) async {
      expect(
        await plays(
          tester,
          atThree([const TrackStep.at(Duration(milliseconds: 100), 3.0)]),
        ),
        isTrue,
      );
    });

    testWidgets('plays when looping', (tester) async {
      expect(
        await plays(
          tester,
          atThree([const TrackStep.to(3.0)]),
          loop: LoopMode.loop,
        ),
        isTrue,
      );
    });

    testWidgets(
        'replaces a plan that is holding on the target, which then '
        'counts as finished', (tester) async {
      controller = _controller(tester, statuses)
        ..animate([
          atThree([
            const TrackStep.to(4.0),
            const TrackStep.hold(Duration(seconds: 1)),
          ]),
        ]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(controller.isAnimating, isTrue);

      final future = controller.animate([
        atThree([const TrackStep.to(4.0)]),
      ]);

      expect(controller.isAnimating, isFalse);
      expect(controller.value(atThree), 4.0);
      await expectLater(future, completes);
      expect(statuses, [AnimationStatus.forward, AnimationStatus.completed]);
    });
  });

  group('PhaseTrackController', () {
    testWidgets('reports the phase settled when nothing moves', (tester) async {
      final controller = PhaseTrackController<_Phase>(vsync: tester);
      addTearDown(controller.dispose);
      final transitions = <PhaseTransition<_Phase>>[];

      controller.playPhases(
        TrackPhaseTimeline({
          _Phase.only: [
            atThree([const TrackStep.to(3.0)]),
          ],
        }),
        onTransition: transitions.add,
      );

      expect(controller.isAnimating, isFalse);
      expect(transitions, [const PhaseSettled(_Phase.only)]);
    });
  });
}
