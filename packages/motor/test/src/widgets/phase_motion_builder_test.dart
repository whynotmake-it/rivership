// ignore_for_file: avoid_positional_boolean_parameters

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

enum TestPhase { idle, active, complete }

void main() {
  group('PhaseMotionBuilder', () {
    late PhaseSequence<TestPhase, double> sequence;

    setUp(() {
      sequence = PhaseSequence.map(
        const {
          TestPhase.idle: 0.0,
          TestPhase.active: 100.0,
          TestPhase.complete: 50.0,
        },
        motion: const CupertinoMotion.smooth(),
      );
    });

    testWidgets('builds with initial value', (tester) async {
      double? capturedValue;
      TestPhase? capturedPhase;

      await tester.pumpWidget(
        PhaseMotionBuilder<TestPhase, double>(
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
        PhaseMotionBuilder<TestPhase, double>(
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
        PhaseMotionBuilder<TestPhase, double>(
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
        PhaseMotionBuilder<TestPhase, double>(
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
        return PhaseMotionBuilder<TestPhase, double>(
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
        return PhaseMotionBuilder<TestPhase, double>(
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
        return PhaseMotionBuilder<TestPhase, double>(
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
        PhaseMotionBuilder<TestPhase, double>(
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
      late PhaseSequence<TestPhase, Offset> offsetSequence;

      setUp(() {
        offsetSequence = PhaseSequence.map(
          const {
            TestPhase.idle: Offset.zero,
            TestPhase.active: Offset(100, 50),
            TestPhase.complete: Offset(200, 100),
          },
          motion: const CupertinoMotion.smooth(),
        );
      });

      testWidgets('animates Offset values correctly', (tester) async {
        Offset? capturedValue;

        await tester.pumpWidget(
          PhaseMotionBuilder<TestPhase, Offset>(
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

  group('SinglePhaseMotionBuilder', () {
    testWidgets('builds with initial phase', (tester) async {
      double? capturedValue;

      await tester.pumpWidget(
        SinglePhaseMotionBuilder<double>(
          phases: const [0.0, 1.0, 0.5],
          motion: const CupertinoMotion.smooth(),
          playing: false,
          builder: (context, value, child) {
            capturedValue = value;
            return const SizedBox();
          },
        ),
      );

      expect(capturedValue, equals(0.0));
    });

    testWidgets('animates to specified currentPhase', (tester) async {
      double? capturedValue;

      await tester.pumpWidget(
        SinglePhaseMotionBuilder<double>(
          phases: const [0.0, 1.0, 0.5],
          motion: const CupertinoMotion.smooth(),
          playing: false,
          currentPhase: 1,
          builder: (context, value, child) {
            capturedValue = value;
            return const SizedBox();
          },
        ),
      );

      await tester.pump(const Duration(milliseconds: 16));
      expect(capturedValue, greaterThan(0.0));
      expect(capturedValue, lessThanOrEqualTo(1.0));

      await tester.pumpAndSettle();
      expect(capturedValue, closeTo(1.0, 0.001));
    });

    testWidgets('starts sequence when playing is true', (tester) async {
      double? capturedValue;

      await tester.pumpWidget(
        SinglePhaseMotionBuilder<double>(
          phases: const [0.0, 1.0, 0.5],
          motion: const CupertinoMotion.smooth(),
          builder: (context, value, child) {
            capturedValue = value;
            return const SizedBox();
          },
        ),
      );

      expect(capturedValue, equals(0.0));

      // Wait for animation to start progressing
      await tester.pump(const Duration(milliseconds: 100));
      final valueAfterStart = capturedValue;

      await tester.pump(const Duration(milliseconds: 500));
      final valueAfterProgress = capturedValue;

      // Should have progressed from the initial value
      expect(valueAfterStart, greaterThanOrEqualTo(0.0));
      expect(valueAfterProgress, greaterThan(valueAfterStart!));
    });

    testWidgets('calls onPhaseChanged callback', (tester) async {
      double? callbackPhase;

      await tester.pumpWidget(
        SinglePhaseMotionBuilder<double>(
          phases: const [0.0, 1.0, 0.5],
          motion: const CupertinoMotion.smooth(),
          playing: false,
          currentPhase: 1,
          onPhaseChanged: (phase) => callbackPhase = phase,
          builder: (context, value, child) => const SizedBox(),
        ),
      );

      await tester.pump();
      expect(callbackPhase, equals(1.0));
    });

    testWidgets('updates sequence when phases change', (tester) async {
      double? capturedValue;

      Widget buildWidget(List<double> phases) {
        return SinglePhaseMotionBuilder<double>(
          phases: phases,
          motion: const CupertinoMotion.smooth(),
          playing: false,
          currentPhase: phases.last,
          builder: (context, value, child) {
            capturedValue = value;
            return const SizedBox();
          },
        );
      }

      await tester.pumpWidget(buildWidget([0.0, 100.0]));
      await tester.pumpAndSettle();
      expect(capturedValue, closeTo(100.0, 0.001));

      await tester.pumpWidget(buildWidget([0.0, 200.0]));
      await tester.pumpAndSettle();
      expect(capturedValue, closeTo(200.0, 0.001));
    });

    testWidgets('passes child widget to builder', (tester) async {
      const childKey = Key('test-child');
      Widget? capturedChild;

      await tester.pumpWidget(
        SinglePhaseMotionBuilder<double>(
          phases: const [0.0, 1.0],
          motion: const CupertinoMotion.smooth(),
          playing: false,
          child: const SizedBox(key: childKey),
          builder: (context, value, child) {
            capturedChild = child;
            return child ?? const SizedBox();
          },
        ),
      );

      expect(capturedChild, isA<SizedBox>());
      expect((capturedChild! as SizedBox).key, equals(childKey));
    });

    testWidgets('respects restartTrigger', (tester) async {
      double? capturedValue;
      Object? trigger = 'initial';

      Widget buildWidget(Object? restartTrigger) {
        return SinglePhaseMotionBuilder<double>(
          phases: const [0.0, 100.0],
          motion: const CupertinoMotion.smooth(),
          playing: false,
          currentPhase: 100,
          restartTrigger: restartTrigger,
          builder: (context, value, child) {
            capturedValue = value;
            return const SizedBox();
          },
        );
      }

      await tester.pumpWidget(buildWidget(trigger));
      await tester.pumpAndSettle();
      expect(capturedValue, closeTo(100.0, 0.001));

      trigger = 'restart';
      await tester.pumpWidget(buildWidget(trigger));
      await tester.pump(const Duration(milliseconds: 50));

      expect(capturedValue, greaterThanOrEqualTo(0.0));
      expect(capturedValue, lessThanOrEqualTo(100.0));
    });
  });
}
