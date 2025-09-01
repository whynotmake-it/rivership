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
      expect(capturedPhase, equals(TestPhase.active));

      // Should start animating through sequence
      await tester.pump(const Duration(seconds: 2));
      expect(capturedPhase, equals(TestPhase.complete));
    });

    testWidgets('calls onPhaseChanged callback', (tester) async {
      TestPhase? callbackPhase;

      await tester.pumpWidget(
        SequenceMotionBuilder<TestPhase, double>(
          sequence: sequence,
          converter: const SingleMotionConverter(),
          playing: false,
          currentPhase: TestPhase.active,
          onPhaseChanged: (phase) => callbackPhase = phase,
          builder: (context, value, phase, child) => const SizedBox(),
        ),
      );

      await tester.pump();
      expect(callbackPhase, equals(TestPhase.active));
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
  });
}
