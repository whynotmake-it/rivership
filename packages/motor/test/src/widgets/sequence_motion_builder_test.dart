// ignore_for_file: avoid_positional_boolean_parameters

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

enum TestPhase { idle, active, complete }

void main() {
  group('SequenceMotionBuilder', () {
    late MotionSequence<TestPhase, double> sequence;

    setUp(() {
      sequence = const MotionSequence.states(
        {
          TestPhase.idle: 0.0,
          TestPhase.active: 100.0,
          TestPhase.complete: 50.0,
        },
        motion: CupertinoMotion.smooth(),
      );
    });

    testWidgets('builds with initial value', (tester) async {
      double? capturedValue;
      TestPhase? capturedPhase;

      await tester.pumpWidget(
        SequenceMotionBuilder<TestPhase, double>(
          sequence: sequence,
          converter: const SingleMotionConverter(),
          playing: false,
          builder: (context, value, phase, child) {
            capturedValue = value;
            capturedPhase = phase;
            return const SizedBox();
          },
        ),
      );

      expect(capturedValue, equals(0.0));
      expect(capturedPhase, equals(TestPhase.idle));
    });

    testWidgets('supports a single value', (tester) async {
      double? capturedValue;
      TestPhase? capturedPhase;

      await tester.pumpWidget(
        SequenceMotionBuilder<TestPhase, double>(
          sequence: const MotionSequence.states(
            {
              TestPhase.idle: 0.0,
            },
            motion: Motion.none(),
          ),
          converter: const SingleMotionConverter(),
          builder: (context, value, phase, child) {
            capturedValue = value;
            capturedPhase = phase;
            return const SizedBox();
          },
        ),
      );

      expect(capturedValue, equals(0.0));
      expect(capturedPhase, equals(TestPhase.idle));
    });

    testWidgets('animates to specified currentPhase', (tester) async {
      double? capturedValue;
      TestPhase? capturedPhase;

      await tester.pumpWidget(
        SequenceMotionBuilder<TestPhase, double>(
          sequence: sequence,
          converter: const SingleMotionConverter(),
          playing: false,
          currentPhase: TestPhase.active,
          builder: (context, value, phase, child) {
            capturedValue = value;
            capturedPhase = phase;
            return const SizedBox();
          },
        ),
      );

      // Should animate to the specified phase
      await tester.pump(const Duration(milliseconds: 16));
      expect(capturedValue, greaterThan(0.0));
      expect(capturedValue, lessThanOrEqualTo(100.0));
      expect(capturedPhase, equals(TestPhase.active));

      await tester.pumpAndSettle();
      expect(capturedValue, closeTo(100.0, 0.001));
    });

    testWidgets('starts sequence when playing is true', (tester) async {
      double? capturedValue;
      TestPhase? capturedPhase;

      await tester.pumpWidget(
        SequenceMotionBuilder<TestPhase, double>(
          sequence: sequence,
          converter: const SingleMotionConverter(),
          builder: (context, value, phase, child) {
            capturedValue = value;
            capturedPhase = phase;
            return const SizedBox();
          },
        ),
      );

      // We immediately start going to the next phase
      expect(capturedValue, equals(0.0));
      expect(capturedPhase, equals(TestPhase.idle));

      // Should start animating through sequence
      await tester.pump(const Duration(seconds: 2));
      expect(capturedPhase, equals(TestPhase.active));
    });

    testWidgets('calls onTransition callback when static phase set',
        (tester) async {
      PhaseTransition<TestPhase>? callbackTransition;

      await tester.pumpWidget(
        SequenceMotionBuilder<TestPhase, double>(
          sequence: sequence,
          converter: const SingleMotionConverter(),
          playing: false,
          currentPhase: TestPhase.active,
          onTransition: (t) => callbackTransition = t,
          builder: (context, value, phase, child) => const SizedBox(),
        ),
      );

      await tester.pump();
      expect(callbackTransition, equals(const PhaseSettled(TestPhase.active)));
    });

    testWidgets('provides correct transition sequence during playback',
        (tester) async {
      final capturedTransitions = <PhaseTransition<TestPhase>>[];

      await tester.pumpWidget(
        SequenceMotionBuilder<TestPhase, double>(
          sequence: sequence,
          converter: const SingleMotionConverter(),
          onTransition: capturedTransitions.add,
          builder: (context, value, phase, child) => const SizedBox(),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        capturedTransitions,
        containsAllInOrder([
          const PhaseTransitioning(
            from: TestPhase.idle,
            to: TestPhase.active,
          ),
          const PhaseTransitioning(
            from: TestPhase.active,
            to: TestPhase.complete,
          ),
          const PhaseSettled(TestPhase.complete),
        ]),
      );
    });

    testWidgets('provides correct transition sequence when setting phases',
        (tester) async {
      final capturedTransitions = <PhaseTransition<TestPhase>>[];

      Widget build(TestPhase phase) {
        return SequenceMotionBuilder<TestPhase, double>(
          sequence: sequence,
          currentPhase: phase,
          playing: false,
          converter: const SingleMotionConverter(),
          onTransition: capturedTransitions.add,
          builder: (context, value, phase, child) => const SizedBox(),
        );
      }

      await tester.pumpWidget(build(TestPhase.idle));

      await tester.pumpAndSettle();

      await tester.pumpWidget(build(TestPhase.active));
      await tester.pumpAndSettle();

      await tester.pumpWidget(build(TestPhase.complete));

      await tester.pump(const Duration(milliseconds: 1000));

      await tester.pumpWidget(build(TestPhase.idle));

      expect(
        capturedTransitions,
        containsAllInOrder([
          const PhaseTransitioning(
            from: TestPhase.idle,
            to: TestPhase.active,
          ),
          const PhaseSettled(TestPhase.active),
          const PhaseTransitioning(
            from: TestPhase.active,
            to: TestPhase.complete,
          ),
          const PhaseTransitioning(
            from: TestPhase.complete,
            to: TestPhase.idle,
          ),
          const PhaseSettled(TestPhase.idle),
        ]),
      );
    });

    testWidgets('calls onAnimationStatusChanged callback', (tester) async {
      final capturedStatuses = <AnimationStatus>[];

      await tester.pumpWidget(
        SequenceMotionBuilder<TestPhase, double>(
          sequence: sequence,
          converter: const SingleMotionConverter(),
          playing: false,
          currentPhase: TestPhase.active,
          onAnimationStatusChanged: capturedStatuses.add,
          builder: (context, value, phase, child) => const SizedBox(),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      // Should have received some status updates
      expect(capturedStatuses, isNotEmpty);
      expect(capturedStatuses, contains(AnimationStatus.forward));
    });

    testWidgets('stops calling onAnimationStatusChanged when widget updates',
        (tester) async {
      final capturedStatuses = <AnimationStatus>[];

      Widget buildWidget({ValueChanged<AnimationStatus>? callback}) {
        return SequenceMotionBuilder<TestPhase, double>(
          sequence: sequence,
          converter: const SingleMotionConverter(),
          playing: false,
          currentPhase: TestPhase.active,
          onAnimationStatusChanged: callback,
          builder: (context, value, phase, child) => const SizedBox(),
        );
      }

      // Start with callback
      await tester.pumpWidget(buildWidget(callback: capturedStatuses.add));
      await tester.pump();
      await tester.pumpAndSettle();

      final statusCountAfterFirst = capturedStatuses.length;

      // Update to remove callback

      await tester.pumpWidget(
        SequenceMotionBuilder<TestPhase, double>(
          sequence: sequence,
          converter: const SingleMotionConverter(),
          playing: false,
          currentPhase: TestPhase.complete,
          builder: (context, value, phase, child) => const SizedBox(),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      // Should not have received any new status updates
      expect(capturedStatuses.length, equals(statusCountAfterFirst));
    });

    testWidgets('updates animation when currentPhase changes', (tester) async {
      double? capturedValue;
      TestPhase? capturedPhase;

      Widget buildWidget(TestPhase? currentPhase) {
        return SequenceMotionBuilder<TestPhase, double>(
          sequence: sequence,
          converter: const SingleMotionConverter(),
          playing: false,
          currentPhase: currentPhase,
          builder: (context, value, phase, child) {
            capturedValue = value;
            capturedPhase = phase;
            return const SizedBox();
          },
        );
      }

      await tester.pumpWidget(buildWidget(TestPhase.idle));
      expect(capturedValue, equals(0.0));
      expect(capturedPhase, equals(TestPhase.idle));

      await tester.pumpWidget(buildWidget(TestPhase.complete));
      await tester.pump(const Duration(milliseconds: 16));
      expect(capturedPhase, equals(TestPhase.complete));
      expect(capturedValue, greaterThan(0.0));
      expect(capturedValue, lessThan(50.0));

      await tester.pumpAndSettle();
      expect(capturedValue, closeTo(50.0, 0.001));
    });

    testWidgets('stops sequence when playing changes to false', (tester) async {
      double? capturedValue;

      Widget buildWidget(bool playing) {
        return SequenceMotionBuilder<TestPhase, double>(
          sequence: sequence,
          converter: const SingleMotionConverter(),
          playing: playing,
          builder: (context, value, phase, child) {
            capturedValue = value;
            return const SizedBox();
          },
        );
      }

      await tester.pumpWidget(buildWidget(true));
      await tester.pump(const Duration(milliseconds: 500));

      final valueWhilePlaying = capturedValue;

      await tester.pumpWidget(buildWidget(false));
      await tester.pump(const Duration(milliseconds: 100));

      // Value should not change significantly when stopped
      expect((capturedValue! - valueWhilePlaying!).abs(), lessThan(10.0));
    });

    testWidgets('restarts animation on restartTrigger change', (tester) async {
      double? capturedValue;
      Object? trigger = 'initial';

      Widget buildWidget(Object? restartTrigger) {
        return SequenceMotionBuilder<TestPhase, double>(
          sequence: sequence,
          converter: const SingleMotionConverter(),
          playing: false,
          currentPhase: TestPhase.active,
          restartTrigger: restartTrigger,
          builder: (context, value, phase, child) {
            capturedValue = value;
            return const SizedBox();
          },
        );
      }

      await tester.pumpWidget(buildWidget(trigger));
      await tester.pumpAndSettle();
      expect(capturedValue, closeTo(100.0, 0.001));

      // Change trigger to restart animation
      trigger = 'restart';
      await tester.pumpWidget(buildWidget(trigger));
      await tester.pump(const Duration(milliseconds: 50));

      // Should be animating again
      expect(capturedValue, greaterThanOrEqualTo(0.0));
      expect(capturedValue, lessThanOrEqualTo(100.0));
    });

    testWidgets('passes child widget to builder', (tester) async {
      const childKey = Key('test-child');
      Widget? capturedChild;

      await tester.pumpWidget(
        SequenceMotionBuilder<TestPhase, double>(
          sequence: sequence,
          converter: const SingleMotionConverter(),
          playing: false,
          child: const SizedBox(key: childKey),
          builder: (context, value, phase, child) {
            capturedChild = child;
            return child ?? const SizedBox();
          },
        ),
      );

      expect(capturedChild, isA<SizedBox>());
      expect((capturedChild! as SizedBox).key, equals(childKey));
    });

    group('with Offset values', () {
      late MotionSequence<TestPhase, Offset> offsetSequence;

      setUp(() {
        offsetSequence = const MotionSequence.states(
          {
            TestPhase.idle: Offset.zero,
            TestPhase.active: Offset(100, 50),
            TestPhase.complete: Offset(200, 100),
          },
          motion: CupertinoMotion.smooth(),
        );
      });

      testWidgets('animates Offset values correctly', (tester) async {
        Offset? capturedValue;

        await tester.pumpWidget(
          SequenceMotionBuilder<TestPhase, Offset>(
            sequence: offsetSequence,
            converter: const OffsetMotionConverter(),
            playing: false,
            currentPhase: TestPhase.active,
            builder: (context, value, phase, child) {
              capturedValue = value;
              return const SizedBox();
            },
          ),
        );

        await tester.pump(const Duration(milliseconds: 16));
        expect(capturedValue!.dx, greaterThan(0.0));
        expect(capturedValue!.dx, lessThanOrEqualTo(100.0));
        expect(capturedValue!.dy, greaterThan(0.0));
        expect(capturedValue!.dy, lessThanOrEqualTo(50.0));

        await tester.pumpAndSettle();
        expect(capturedValue!.dx, closeTo(100.0, 0.001));
        expect(capturedValue!.dy, closeTo(50.0, 0.001));
      });
    });

    group('sequence equality', () {
      group('StateSequence', () {
        testWidgets('detects motion changes in single motion sequences',
            (tester) async {
          const seq1 = MotionSequence.states(
            {
              TestPhase.idle: 0.0,
              TestPhase.active: 100.0,
            },
            motion: Motion.linear(Duration(seconds: 1)),
          );

          const seq2 = MotionSequence.states(
            {
              TestPhase.idle: 0.0,
              TestPhase.active: 100.0,
            },
            motion: Motion.linear(Duration(milliseconds: 500)),
          );

          expect(seq1, isNot(equals(seq2)));
          expect(seq1.hashCode, isNot(equals(seq2.hashCode)));
        });

        testWidgets('detects motion changes in per-phase motion sequences',
            (tester) async {
          const seq1 = MotionSequence.statesWithMotions({
            TestPhase.idle: (0.0, Motion.linear(Duration(seconds: 1))),
            TestPhase.active: (100.0, Motion.linear(Duration(seconds: 1))),
          });

          const seq2 = MotionSequence.statesWithMotions({
            TestPhase.idle: (0.0, Motion.linear(Duration(milliseconds: 500))),
            TestPhase.active: (100.0, Motion.linear(Duration(seconds: 1))),
          });

          expect(seq1, isNot(equals(seq2)));
          expect(seq1.hashCode, isNot(equals(seq2.hashCode)));
        });

        testWidgets('detects value changes', (tester) async {
          const seq1 = MotionSequence.states(
            {
              TestPhase.idle: 0.0,
              TestPhase.active: 100.0,
            },
            motion: Motion.linear(Duration(seconds: 1)),
          );

          const seq2 = MotionSequence.states(
            {
              TestPhase.idle: 0.0,
              TestPhase.active: 50.0, // Different value
            },
            motion: Motion.linear(Duration(seconds: 1)),
          );

          expect(seq1, isNot(equals(seq2)));
          expect(seq1.hashCode, isNot(equals(seq2.hashCode)));
        });

        testWidgets('detects loop mode changes', (tester) async {
          const seq1 = MotionSequence.states(
            {
              TestPhase.idle: 0.0,
              TestPhase.active: 100.0,
            },
            motion: Motion.linear(Duration(seconds: 1)),
          );

          const seq2 = MotionSequence.states(
            {
              TestPhase.idle: 0.0,
              TestPhase.active: 100.0,
            },
            motion: Motion.linear(Duration(seconds: 1)),
            loop: LoopMode.loop,
          );

          expect(seq1, isNot(equals(seq2)));
          expect(seq1.hashCode, isNot(equals(seq2.hashCode)));
        });
      });

      group('StepSequence', () {
        testWidgets('detects motion changes in single motion sequences',
            (tester) async {
          final seq1 = MotionSequence.steps(
            [0.0, 100.0],
            motion: const Motion.linear(Duration(seconds: 1)),
          );

          final seq2 = MotionSequence.steps(
            [0.0, 100.0],
            motion: const Motion.linear(Duration(milliseconds: 500)),
          );

          expect(seq1, isNot(equals(seq2)));
          expect(seq1.hashCode, isNot(equals(seq2.hashCode)));
        });

        testWidgets('detects motion changes in per-step motion sequences',
            (tester) async {
          final seq1 = MotionSequence.stepsWithMotions([
            (0.0, const Motion.linear(Duration(seconds: 1))),
            (100.0, const Motion.linear(Duration(seconds: 1))),
          ]);

          final seq2 = MotionSequence.stepsWithMotions([
            (0.0, const Motion.linear(Duration(milliseconds: 500))),
            (100.0, const Motion.linear(Duration(seconds: 1))),
          ]);

          expect(seq1, isNot(equals(seq2)));
          expect(seq1.hashCode, isNot(equals(seq2.hashCode)));
        });

        testWidgets('detects value changes', (tester) async {
          final seq1 = MotionSequence.steps(
            [0.0, 100.0],
            motion: const Motion.linear(Duration(seconds: 1)),
          );

          final seq2 = MotionSequence.steps(
            [0.0, 50.0],
            motion: const Motion.linear(Duration(seconds: 1)),
          );

          expect(seq1, isNot(equals(seq2)));
          expect(seq1.hashCode, isNot(equals(seq2.hashCode)));
        });
      });

      group('SpanningSequence', () {
        testWidgets('detects motion changes', (tester) async {
          final seq1 = MotionSequence.spanning(
            {
              0.0: 0.0,
              1.0: 100.0,
            },
            motion: const Motion.linear(Duration(seconds: 1)),
          );

          final seq2 = MotionSequence.spanning(
            {
              0.0: 0.0,
              1.0: 100.0,
            },
            motion: const Motion.linear(Duration(milliseconds: 500)),
          );

          expect(seq1, isNot(equals(seq2)));
          expect(seq1.hashCode, isNot(equals(seq2.hashCode)));
        });

        testWidgets('detects value changes', (tester) async {
          final seq1 = MotionSequence.spanning(
            {
              0.0: 0.0,
              1.0: 100.0,
            },
            motion: const Motion.linear(Duration(seconds: 1)),
          );

          final seq2 = MotionSequence.spanning(
            {
              0.0: 0.0,
              1.0: 50.0, // Different value
            },
            motion: const Motion.linear(Duration(seconds: 1)),
          );

          expect(seq1, isNot(equals(seq2)));
          expect(seq1.hashCode, isNot(equals(seq2.hashCode)));
        });

        testWidgets('detects position changes', (tester) async {
          final seq1 = MotionSequence.spanning(
            {
              0.0: 0.0,
              1.0: 100.0,
            },
            motion: const Motion.linear(Duration(seconds: 1)),
          );

          final seq2 = MotionSequence.spanning(
            {
              0.0: 0.0,
              2.0: 100.0, // Different position
            },
            motion: const Motion.linear(Duration(seconds: 1)),
          );

          expect(seq1, isNot(equals(seq2)));
          expect(seq1.hashCode, isNot(equals(seq2.hashCode)));
        });
      });

      group('SingleMotionPhaseSequence', () {
        testWidgets('detects motion changes', (tester) async {
          const baseSequence = MotionSequence.states(
            {
              TestPhase.idle: 0.0,
              TestPhase.active: 100.0,
            },
            motion: Motion.none(),
          );

          final seq1 = baseSequence
              .withSingleMotion(const Motion.linear(Duration(seconds: 1)));
          final seq2 = baseSequence.withSingleMotion(
            const Motion.linear(Duration(milliseconds: 500)),
          );

          expect(seq1, isNot(equals(seq2)));
          expect(seq1.hashCode, isNot(equals(seq2.hashCode)));
        });

        testWidgets('detects parent sequence changes', (tester) async {
          const baseSequence1 = MotionSequence.states(
            {
              TestPhase.idle: 0.0,
              TestPhase.active: 100.0,
            },
            motion: Motion.none(),
          );

          const baseSequence2 = MotionSequence.states(
            {
              TestPhase.idle: 0.0,
              TestPhase.active: 50.0, // Different value
            },
            motion: Motion.none(),
          );

          const motion = Motion.linear(Duration(seconds: 1));
          final seq1 = baseSequence1.withSingleMotion(motion);
          final seq2 = baseSequence2.withSingleMotion(motion);

          expect(seq1, isNot(equals(seq2)));
          expect(seq1.hashCode, isNot(equals(seq2.hashCode)));
        });
      });

      group('Chained sequences', () {
        testWidgets('detects changes in chained sequences', (tester) async {
          const baseSequence = MotionSequence.states(
            {
              TestPhase.idle: 0.0,
            },
            motion: Motion.linear(Duration(seconds: 1)),
          );

          const chainSequence1 = MotionSequence.states(
            {
              TestPhase.active: 100.0,
            },
            motion: Motion.linear(Duration(seconds: 1)),
          );

          const chainSequence2 = MotionSequence.states(
            {
              TestPhase.active: 50.0, // Different value
            },
            motion: Motion.linear(Duration(seconds: 1)),
          );

          final seq1 = baseSequence.chain(chainSequence1);
          final seq2 = baseSequence.chain(chainSequence2);

          expect(seq1, isNot(equals(seq2)));
          expect(seq1.hashCode, isNot(equals(seq2.hashCode)));
        });
      });
    });

    group('value updates', () {
      testWidgets('detects sequence changes when motion duration changes',
          (tester) async {
        // Test that sequences with different motion durations are
        // considered different
        const seq1 = StepSequence(
          [0, 1],
          motion: Motion.linear(Duration(seconds: 1)),
          loop: LoopMode.pingPong,
        );

        const seq2 = StepSequence(
          [0, 1],
          motion: Motion.linear(Duration(milliseconds: 500)),
          loop: LoopMode.pingPong,
        );

        expect(seq1, isNot(equals(seq2)));
        expect(seq1.hashCode, isNot(equals(seq2.hashCode)));

        // The motions for transitions from phase 0 to phase 1 should be
        // different
        expect(
          seq1.motionForPhase(toPhase: 1, fromPhase: 0),
          isNot(equals(seq2.motionForPhase(toPhase: 1, fromPhase: 0))),
        );
      });

      testWidgets('updates correctly with duration', (tester) async {
        final duration = ValueNotifier(const Duration(seconds: 1));
        var overHalf = false;
        var counter = 0;

        final widget = ValueListenableBuilder(
          valueListenable: duration,
          builder: (context, value, child) {
            return SequenceMotionBuilder<int, double>(
              sequence: StepSequence(
                const [0, 1],
                motion: Motion.linear(value),
                loop: LoopMode.pingPong,
              ),
              converter: const SingleMotionConverter(),
              builder: (context, value, phase, child) {
                if (value > 0.5 && !overHalf) {
                  overHalf = true;
                  counter++;
                } else if (value <= 0.5 && overHalf) {
                  overHalf = false;
                }

                return const SizedBox();
              },
            );
          },
        );

        await tester.pumpFrames(widget, const Duration(seconds: 2));

        expect(counter, equals(1));

        await tester.pumpFrames(widget, const Duration(seconds: 1));

        expect(counter, equals(2));

        await tester.pumpFrames(widget, const Duration(seconds: 1));

        // We should be around zero here
        // Double the speed and reset counter
        counter = 0;
        duration.value = const Duration(milliseconds: 500);

        await tester.pumpFrames(widget, const Duration(seconds: 2));
        expect(counter, equals(2));
      });
    });
  });
}
