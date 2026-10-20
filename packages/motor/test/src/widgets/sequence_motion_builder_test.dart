// ignore_for_file: avoid_positional_boolean_parameters
// ignore_for_file: deprecated_member_use_from_same_package

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

import '../util.dart';

enum TestPhase { idle, active, complete }

const _linear1s = Motion.linear(Duration(seconds: 1));
const _linear500 = Motion.linear(Duration(milliseconds: 500));

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

    testWidgets('builds with initial value and passes the child',
        (tester) async {
      const childKey = Key('test-child');
      double? capturedValue;
      TestPhase? capturedPhase;
      Widget? capturedChild;

      await tester.pumpWidget(
        SequenceMotionBuilder<TestPhase, double>(
          sequence: sequence,
          converter: const SingleMotionConverter(),
          playing: false,
          child: const SizedBox(key: childKey),
          builder: (context, value, phase, child) {
            capturedValue = value;
            capturedPhase = phase;
            capturedChild = child;
            return child ?? const SizedBox();
          },
        ),
      );

      expect(capturedValue, equals(0.0));
      expect(capturedPhase, equals(TestPhase.idle));
      expect(capturedChild, isA<SizedBox>());
      expect((capturedChild! as SizedBox).key, equals(childKey));
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

    testWidgets(
        'a static currentPhase settles there and restarts on restartTrigger '
        'change', (tester) async {
      double? capturedValue;
      TestPhase? capturedPhase;
      PhaseTransition<TestPhase>? callbackTransition;

      Widget buildWidget(Object? restartTrigger) {
        return SequenceMotionBuilder<TestPhase, double>(
          sequence: sequence,
          converter: const SingleMotionConverter(),
          playing: false,
          currentPhase: TestPhase.active,
          restartTrigger: restartTrigger,
          onTransition: (t) => callbackTransition = t,
          builder: (context, value, phase, child) {
            capturedValue = value;
            capturedPhase = phase;
            return const SizedBox();
          },
        );
      }

      await tester.pumpWidget(buildWidget('initial'));
      await tester.pump();
      expect(callbackTransition, equals(const PhaseSettled(TestPhase.active)));

      await tester.pump(const Duration(milliseconds: 16));
      expect(capturedValue, greaterThan(0.0));
      expect(capturedValue, lessThanOrEqualTo(100.0));
      expect(capturedPhase, equals(TestPhase.active));

      await tester.pumpAndSettle();
      expect(capturedValue, closeTo(100.0, error));

      await tester.pumpWidget(buildWidget('restart'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(capturedValue, greaterThanOrEqualTo(0.0));
      expect(capturedValue, lessThanOrEqualTo(100.0));
    });

    testWidgets('playing runs through the sequence and reports transitions',
        (tester) async {
      double? capturedValue;
      TestPhase? capturedPhase;
      final capturedTransitions = <PhaseTransition<TestPhase>>[];

      await tester.pumpWidget(
        SequenceMotionBuilder<TestPhase, double>(
          sequence: sequence,
          converter: const SingleMotionConverter(),
          onTransition: capturedTransitions.add,
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

      await tester.pump(const Duration(seconds: 2));
      expect(capturedPhase, equals(TestPhase.active));

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

    testWidgets(
        'changing currentPhase animates there and reports the animation status',
        (tester) async {
      double? capturedValue;
      TestPhase? capturedPhase;
      final capturedStatuses = <AnimationStatus>[];

      Widget buildWidget(TestPhase? currentPhase) {
        return SequenceMotionBuilder<TestPhase, double>(
          sequence: sequence,
          converter: const SingleMotionConverter(),
          playing: false,
          currentPhase: currentPhase,
          onAnimationStatusChanged: capturedStatuses.add,
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
      expect(capturedValue, closeTo(50.0, error));
      expect(capturedStatuses, contains(AnimationStatus.forward));
    });

    testWidgets('stops calling onAnimationStatusChanged when widget updates',
        (tester) async {
      final capturedStatuses = <AnimationStatus>[];

      Widget buildWidget(
        TestPhase phase, {
        ValueChanged<AnimationStatus>? callback,
      }) {
        return SequenceMotionBuilder<TestPhase, double>(
          sequence: sequence,
          converter: const SingleMotionConverter(),
          playing: false,
          currentPhase: phase,
          onAnimationStatusChanged: callback,
          builder: (context, value, phase, child) => const SizedBox(),
        );
      }

      await tester.pumpWidget(
        buildWidget(TestPhase.active, callback: capturedStatuses.add),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      final statusCountAfterFirst = capturedStatuses.length;

      await tester.pumpWidget(buildWidget(TestPhase.complete));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(capturedStatuses.length, equals(statusCountAfterFirst));
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

    testWidgets('animates Offset values', (tester) async {
      Offset? capturedValue;

      await tester.pumpWidget(
        SequenceMotionBuilder<TestPhase, Offset>(
          sequence: const MotionSequence.states(
            {
              TestPhase.idle: Offset.zero,
              TestPhase.active: Offset(100, 50),
              TestPhase.complete: Offset(200, 100),
            },
            motion: CupertinoMotion.smooth(),
          ),
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
      expect(capturedValue!.dx, closeTo(100.0, error));
      expect(capturedValue!.dy, closeTo(50.0, error));
    });

    test('sequences that differ in one property are unequal', () {
      const base = MotionSequence.states(
        {TestPhase.idle: 0.0, TestPhase.active: 100.0},
        motion: Motion.none(),
      );
      const chainBase = MotionSequence.states(
        {TestPhase.idle: 0.0},
        motion: _linear1s,
      );

      final cases = <(
        String,
        MotionSequence<Object, double>,
        MotionSequence<Object, double>
      )>[
        (
          'StateSequence motion',
          const MotionSequence.states(
            {TestPhase.idle: 0.0, TestPhase.active: 100.0},
            motion: _linear1s,
          ),
          const MotionSequence.states(
            {TestPhase.idle: 0.0, TestPhase.active: 100.0},
            motion: _linear500,
          ),
        ),
        (
          'StateSequence per-phase motion',
          const MotionSequence.statesWithMotions({
            TestPhase.idle: (0.0, _linear1s),
            TestPhase.active: (100.0, _linear1s),
          }),
          const MotionSequence.statesWithMotions({
            TestPhase.idle: (0.0, _linear500),
            TestPhase.active: (100.0, _linear1s),
          }),
        ),
        (
          'StateSequence value',
          const MotionSequence.states(
            {TestPhase.idle: 0.0, TestPhase.active: 100.0},
            motion: _linear1s,
          ),
          const MotionSequence.states(
            {TestPhase.idle: 0.0, TestPhase.active: 50.0},
            motion: _linear1s,
          ),
        ),
        (
          'StateSequence loop',
          const MotionSequence.states(
            {TestPhase.idle: 0.0, TestPhase.active: 100.0},
            motion: _linear1s,
          ),
          const MotionSequence.states(
            {TestPhase.idle: 0.0, TestPhase.active: 100.0},
            motion: _linear1s,
            loop: LoopMode.loop,
          ),
        ),
        (
          'StepSequence motion',
          MotionSequence.steps([0.0, 100.0], motion: _linear1s),
          MotionSequence.steps([0.0, 100.0], motion: _linear500),
        ),
        (
          'StepSequence ping-pong motion',
          const StepSequence(
            [0, 1],
            motion: _linear1s,
            loop: LoopMode.pingPong,
          ),
          const StepSequence(
            [0, 1],
            motion: _linear500,
            loop: LoopMode.pingPong,
          ),
        ),
        (
          'StepSequence per-step motion',
          MotionSequence.stepsWithMotions([
            (0.0, _linear1s),
            (100.0, _linear1s),
          ]),
          MotionSequence.stepsWithMotions([
            (0.0, _linear500),
            (100.0, _linear1s),
          ]),
        ),
        (
          'StepSequence value',
          MotionSequence.steps([0.0, 100.0], motion: _linear1s),
          MotionSequence.steps([0.0, 50.0], motion: _linear1s),
        ),
        (
          'SpanningSequence motion',
          MotionSequence.spanning({0.0: 0.0, 1.0: 100.0}, motion: _linear1s),
          MotionSequence.spanning({0.0: 0.0, 1.0: 100.0}, motion: _linear500),
        ),
        (
          'SpanningSequence value',
          MotionSequence.spanning({0.0: 0.0, 1.0: 100.0}, motion: _linear1s),
          MotionSequence.spanning({0.0: 0.0, 1.0: 50.0}, motion: _linear1s),
        ),
        (
          'SpanningSequence position',
          MotionSequence.spanning({0.0: 0.0, 1.0: 100.0}, motion: _linear1s),
          MotionSequence.spanning({0.0: 0.0, 2.0: 100.0}, motion: _linear1s),
        ),
        (
          'SingleMotionPhaseSequence motion',
          base.withSingleMotion(_linear1s),
          base.withSingleMotion(_linear500),
        ),
        (
          'SingleMotionPhaseSequence parent',
          base.withSingleMotion(_linear1s),
          const MotionSequence.states(
            {TestPhase.idle: 0.0, TestPhase.active: 50.0},
            motion: Motion.none(),
          ).withSingleMotion(_linear1s),
        ),
        (
          'chained sequence',
          chainBase.chain(
            const MotionSequence.states(
              {TestPhase.active: 100.0},
              motion: _linear1s,
            ),
          ),
          chainBase.chain(
            const MotionSequence.states(
              {TestPhase.active: 50.0},
              motion: _linear1s,
            ),
          ),
        ),
      ];

      for (final (name, a, b) in cases) {
        expect(a, isNot(equals(b)), reason: name);
        expect(a.hashCode, isNot(equals(b.hashCode)), reason: name);
      }

      const pingPong1s = StepSequence(
        [0, 1],
        motion: _linear1s,
        loop: LoopMode.pingPong,
      );
      const pingPong500 = StepSequence(
        [0, 1],
        motion: _linear500,
        loop: LoopMode.pingPong,
      );
      expect(
        pingPong1s.motionForPhase(toPhase: 1, fromPhase: 0),
        isNot(equals(pingPong500.motionForPhase(toPhase: 1, fromPhase: 0))),
      );
    });

    testWidgets('a rebuilt sequence with a new motion duration takes effect',
        (tester) async {
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
}
