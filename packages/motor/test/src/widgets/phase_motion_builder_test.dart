// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

enum TestPhase { idle, active, loading }

void main() {
  group('PhaseMotionBuilder', () {
    late MapPhaseSequence<Offset, TestPhase> testSequence;

    setUp(() {
      testSequence = MapPhaseSequence<Offset, TestPhase>(
        const {
          TestPhase.idle: Offset(100, 40),
          TestPhase.active: Offset(120, 45),
          TestPhase.loading: Offset(40, 40),
        },
        motion: (_) => const CupertinoMotion.smooth(),
      );
    });

    testWidgets('builds with initial phase when currentPhase is null',
        (tester) async {
      Offset? capturedValue;
      TestPhase? capturedPhase;

      await tester.pumpWidget(
        PhaseMotionBuilder<Offset, TestPhase>(
          sequence: testSequence,
          converter: const OffsetMotionConverter(),
          playing: false,
          builder: (context, value, phase, child) {
            capturedValue = value;
            capturedPhase = phase;
            return const SizedBox();
          },
        ),
      );

      expect(capturedValue!.dx, equals(100.0));
      expect(capturedValue!.dy, equals(40.0));
      expect(capturedPhase, equals(TestPhase.idle));
    });

    testWidgets('starts at specified currentPhase', (tester) async {
      Offset? capturedValue;
      TestPhase? capturedPhase;

      await tester.pumpWidget(
        PhaseMotionBuilder<Offset, TestPhase>(
          sequence: testSequence,
          converter: const OffsetMotionConverter(),
          current: TestPhase.loading,
          playing: false,
          builder: (context, value, phase, child) {
            capturedValue = value;
            capturedPhase = phase;
            return const SizedBox();
          },
        ),
      );

      expect(capturedValue!.dx, equals(40.0));
      expect(capturedValue!.dy, equals(40.0));
      expect(capturedPhase, equals(TestPhase.loading));
    });

    testWidgets('transitions to new currentPhase when changed', (tester) async {
      Offset? capturedValue;
      TestPhase? capturedPhase;

      await tester.pumpWidget(
        PhaseMotionBuilder<Offset, TestPhase>(
          sequence: testSequence,
          converter: const OffsetMotionConverter(),
          current: TestPhase.idle,
          playing: false,
          builder: (context, value, phase, child) {
            capturedValue = value;
            capturedPhase = phase;
            return const SizedBox();
          },
        ),
      );

      expect(capturedValue!.dx, equals(100.0));
      expect(capturedValue!.dy, equals(40.0));
      expect(capturedPhase, equals(TestPhase.idle));

      // Change to active phase
      await tester.pumpWidget(
        PhaseMotionBuilder<Offset, TestPhase>(
          sequence: testSequence,
          converter: const OffsetMotionConverter(),
          current: TestPhase.active,
          playing: false,
          builder: (context, value, phase, child) {
            capturedValue = value;
            capturedPhase = phase;
            return const SizedBox();
          },
        ),
      );

      expect(capturedPhase, equals(TestPhase.active));

      // Wait for animation to complete
      await tester.pumpAndSettle();
      expect(capturedValue!.dx, closeTo(120.0, 0.1));
      expect(capturedValue!.dy, closeTo(45.0, 0.1));
    });

    testWidgets('continues playing after phase transition when playing is true',
        (tester) async {
      TestPhase? capturedPhase;
      final phaseChanges = <TestPhase>[];

      await tester.pumpWidget(
        PhaseMotionBuilder<Offset, TestPhase>(
          sequence: testSequence,
          converter: const OffsetMotionConverter(),
          current: TestPhase.idle,
          playing: true,
          loopMode: PhaseLoopMode.loop,
          onPhaseChanged: phaseChanges.add,
          builder: (context, value, phase, child) {
            capturedPhase = phase;
            return const SizedBox();
          },
        ),
      );

      expect(capturedPhase, equals(TestPhase.idle));

      // Change to active phase while playing
      await tester.pumpWidget(
        PhaseMotionBuilder<Offset, TestPhase>(
          sequence: testSequence,
          converter: const OffsetMotionConverter(),
          current: TestPhase.active,
          playing: true,
          loopMode: PhaseLoopMode.loop,
          onPhaseChanged: phaseChanges.add,
          builder: (context, value, phase, child) {
            capturedPhase = phase;
            return const SizedBox();
          },
        ),
      );

      expect(capturedPhase, equals(TestPhase.active));

      // Wait a bit for potential phase progression
      await tester.pump(const Duration(milliseconds: 100));

      // Should have at least recorded the active phase change
      expect(phaseChanges, contains(TestPhase.active));
    });

    testWidgets('respects playing flag with currentPhase changes',
        (tester) async {
      Offset? capturedValue;
      TestPhase? capturedPhase;

      await tester.pumpWidget(
        PhaseMotionBuilder<Offset, TestPhase>(
          sequence: testSequence,
          converter: const OffsetMotionConverter(),
          current: TestPhase.idle,
          playing: false,
          builder: (context, value, phase, child) {
            capturedValue = value;
            capturedPhase = phase;
            return const SizedBox();
          },
        ),
      );

      expect(capturedPhase, equals(TestPhase.idle));

      // Change phase while not playing
      await tester.pumpWidget(
        PhaseMotionBuilder<Offset, TestPhase>(
          sequence: testSequence,
          converter: const OffsetMotionConverter(),
          current: TestPhase.loading,
          playing: false,
          builder: (context, value, phase, child) {
            capturedValue = value;
            capturedPhase = phase;
            return const SizedBox();
          },
        ),
      );

      expect(capturedPhase, equals(TestPhase.loading));

      // Should animate to the new phase even when playing is false
      await tester.pumpAndSettle();
      expect(capturedValue!.dx, closeTo(40.0, 0.1));
      expect(capturedValue!.dy, closeTo(40.0, 0.1));
    });

    testWidgets('onPhaseChanged callback is called when currentPhase changes',
        (tester) async {
      final phaseChanges = <TestPhase>[];

      await tester.pumpWidget(
        PhaseMotionBuilder<Offset, TestPhase>(
          sequence: testSequence,
          converter: const OffsetMotionConverter(),
          current: TestPhase.idle,
          playing: false,
          onPhaseChanged: phaseChanges.add,
          builder: (context, value, phase, child) => const SizedBox(),
        ),
      );

      expect(phaseChanges.length, greaterThan(0));

      // Change to active phase
      await tester.pumpWidget(
        PhaseMotionBuilder<Offset, TestPhase>(
          sequence: testSequence,
          converter: const OffsetMotionConverter(),
          current: TestPhase.active,
          playing: false,
          onPhaseChanged: phaseChanges.add,
          builder: (context, value, phase, child) => const SizedBox(),
        ),
      );

      expect(phaseChanges, contains(TestPhase.active));
    });

    testWidgets('currentPhase takes precedence over restartTrigger',
        (tester) async {
      TestPhase? capturedPhase;
      var triggerValue = 0;

      await tester.pumpWidget(
        PhaseMotionBuilder<Offset, TestPhase>(
          sequence: testSequence,
          converter: const OffsetMotionConverter(),
          current: TestPhase.loading,
          restartTrigger: triggerValue,
          playing: false,
          builder: (context, value, phase, child) {
            capturedPhase = phase;
            return const SizedBox();
          },
        ),
      );

      expect(capturedPhase, equals(TestPhase.loading));

      // Change both currentPhase and restartTrigger
      triggerValue = 1;
      await tester.pumpWidget(
        PhaseMotionBuilder<Offset, TestPhase>(
          sequence: testSequence,
          converter: const OffsetMotionConverter(),
          current: TestPhase.active,
          restartTrigger: triggerValue,
          playing: false,
          builder: (context, value, phase, child) {
            capturedPhase = phase;
            return const SizedBox();
          },
        ),
      );

      // Should be at the currentPhase, not reset to initial phase
      expect(capturedPhase, equals(TestPhase.active));
    });
  });

  group('SinglePhaseMotionBuilder', () {
    testWidgets('works with numeric phases', (tester) async {
      double? capturedValue;

      await tester.pumpWidget(
        SinglePhaseMotionBuilder<double>(
          phases: const [0.0, 50.0, 100.0],
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

    testWidgets('starts at specified currentPhase', (tester) async {
      double? capturedValue;

      await tester.pumpWidget(
        SinglePhaseMotionBuilder<double>(
          phases: const [0.0, 50.0, 100.0],
          motion: const CupertinoMotion.smooth(),
          current: 100,
          playing: false,
          builder: (context, value, child) {
            capturedValue = value;
            return const SizedBox();
          },
        ),
      );

      expect(capturedValue, equals(100.0));
    });

    testWidgets('transitions to new currentPhase when changed', (tester) async {
      double? capturedValue;

      await tester.pumpWidget(
        SinglePhaseMotionBuilder<double>(
          phases: const [0.0, 50.0, 100.0],
          motion: const CupertinoMotion.smooth(),
          current: 0,
          playing: false,
          builder: (context, value, child) {
            capturedValue = value;
            return const SizedBox();
          },
        ),
      );

      expect(capturedValue, equals(0.0));

      // Change to different phase
      await tester.pumpWidget(
        SinglePhaseMotionBuilder<double>(
          phases: const [0.0, 50.0, 100.0],
          motion: const CupertinoMotion.smooth(),
          current: 50,
          playing: false,
          builder: (context, value, child) {
            capturedValue = value;
            return const SizedBox();
          },
        ),
      );

      // Wait for animation to complete
      await tester.pumpAndSettle();
      expect(capturedValue, closeTo(50.0, 0.1));
    });
  });
}
