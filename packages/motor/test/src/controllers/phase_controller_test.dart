// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter/animation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

void main() {
  group('PhaseController', () {
    late TickerProvider vsync;

    setUp(() {
      vsync = const TestVSync();
    });

    group('PhaseLoopMode.seamless', () {
      test('seamless loop mode should be recognized as looping', () {
        expect(PhaseLoopMode.seamless.isLooping, isTrue);
      });

      testWidgets('should transition seamlessly from last to first phase',
          (tester) async {
        final sequence = PhaseSequence.values(
          [0.0, 50.0, 100.0],
          motion: (_) => const CupertinoMotion.smooth(),
          loopMode: PhaseLoopMode.seamless,
        );

        final phaseChanges = <double>[];

        final controller = PhaseController(
          sequence: sequence,
          converter: const SingleMotionConverter(),
          vsync: vsync,
          onPhaseChanged: phaseChanges.add,
        );

        // Start at first phase
        expect(controller.currentPhase, equals(0.0));
        expect(controller.currentPhaseIndex, equals(0));

        // Move to last phase manually
        controller.goToPhase(100);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(controller.currentPhase, equals(100.0));
        expect(controller.currentPhaseIndex, equals(2));

        // Test seamless transition back to first
        controller.nextPhase();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(controller.currentPhase, equals(0.0));
        expect(controller.currentPhaseIndex, equals(0));
        expect(phaseChanges.contains(100.0), isTrue);
        expect(phaseChanges.contains(0.0), isTrue);

        controller
          ..stop()
          ..dispose();
      });

      testWidgets('should handle seamless backwards transition',
          (tester) async {
        final sequence = PhaseSequence.values(
          [0.0, 50.0, 100.0],
          motion: (_) => const CupertinoMotion.smooth(),
          loopMode: PhaseLoopMode.seamless,
        );

        final controller = PhaseController(
          sequence: sequence,
          converter: const SingleMotionConverter(),
          vsync: vsync,
        );

        // Start at first phase, should be able to go to last seamlessly
        expect(controller.currentPhase, equals(0.0));

        controller.previousPhase();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(controller.currentPhase, equals(100.0));
        expect(controller.currentPhaseIndex, equals(2));

        controller
          ..stop()
          ..dispose();
      });

      testWidgets('should support manual phase transitions in seamless mode',
          (tester) async {
        final sequence = PhaseSequence.values(
          [10.0, 20.0, 30.0],
          motion: (_) => const CupertinoMotion.smooth(),
          loopMode: PhaseLoopMode.seamless,
        );

        final phaseChanges = <double>[];

        final controller = PhaseController(
          sequence: sequence,
          converter: const SingleMotionConverter(),
          vsync: vsync,
          onPhaseChanged: phaseChanges.add,
        );

        expect(controller.currentPhase, equals(10.0));

        // Manually advance through phases
        controller.nextPhase();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        controller.nextPhase();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Should have moved through phases
        expect(phaseChanges.isNotEmpty, isTrue);

        controller
          ..stop()
          ..dispose();
      });
    });

    group('compared to regular loop mode', () {
      testWidgets('regular loop should work as before', (tester) async {
        final sequence = PhaseSequence.values(
          [10.0, 20.0, 30.0],
          motion: (_) => const CupertinoMotion.smooth(),
          loopMode: PhaseLoopMode.loop,
        );

        final controller = PhaseController(
          sequence: sequence,
          converter: const SingleMotionConverter(),
          vsync: vsync,
        );

        expect(controller.currentPhase, equals(10.0));

        // Go to last phase
        controller.goToPhase(30);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(controller.currentPhase, equals(30.0));

        // Next should loop back to first
        controller.nextPhase();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(controller.currentPhase, equals(10.0));

        controller
          ..stop()
          ..dispose();
      });

      testWidgets('none mode should not loop', (tester) async {
        final sequence = PhaseSequence.values(
          [10.0, 20.0, 30.0],
          motion: (_) => const CupertinoMotion.smooth(),
          loopMode: PhaseLoopMode.none,
        );

        final controller = PhaseController(
          sequence: sequence,
          converter: const SingleMotionConverter(),
          vsync: vsync,
        )
          // Go to last phase
          ..goToPhase(30);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(controller.currentPhase, equals(30.0));

        // Next should do nothing
        controller.nextPhase();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(controller.currentPhase, equals(30.0)); // Should stay the same

        controller.dispose();
      });
    });

    group('edge cases', () {
      testWidgets('should handle single phase with seamless mode',
          (tester) async {
        final sequence = PhaseSequence.values(
          [42.0],
          motion: (_) => const CupertinoMotion.smooth(),
          loopMode: PhaseLoopMode.seamless,
        );

        final controller = PhaseController(
          sequence: sequence,
          converter: const SingleMotionConverter(),
          vsync: vsync,
        );

        expect(controller.currentPhase, equals(42.0));

        // Next/previous should stay on same phase
        controller.nextPhase();
        await tester.pump();

        expect(controller.currentPhase, equals(42.0));

        controller.previousPhase();
        await tester.pump();

        expect(controller.currentPhase, equals(42.0));

        controller.dispose();
      });

      testWidgets('should handle empty sequence gracefully', (tester) async {
        final sequence = PhaseSequence.values(
          <double>[],
          motion: (_) => const CupertinoMotion.smooth(),
          loopMode: PhaseLoopMode.seamless,
        );

        expect(
          () {
            PhaseController(
              sequence: sequence,
              converter: const SingleMotionConverter(),
              vsync: vsync,
            );
          },
          throwsStateError,
        );
      });
    });

    group('sequence switching', () {
      testWidgets('should handle switching from timeline to single sequence',
          (tester) async {
        // Create a timeline sequence similar to the button example (no loop)
        final timelineSequence = TimelineSequence(
          {
            0: 1.0,
            0.05: 0.85,
            0.4: 1.1,
            0.9: 1.0,
          },
          motion: CupertinoMotion.bouncy(),
          loopMode: PhaseLoopMode.none, // Explicitly no loop
        );

        // Create a single value sequence like the pressed state
        final singleSequence = PhaseSequence.single(
          0.5,
          motion: CupertinoMotion.smooth(),
        );

        final controller = PhaseController(
          sequence: timelineSequence,
          converter: const SingleMotionConverter(),
          vsync: vsync,
        );

        // Start playing like the button example does
        controller.start();
        await tester.pump(const Duration(milliseconds: 50));

        // Switch to single sequence (like pressing the button)
        controller.sequence = singleSequence;
        await tester.pump(); // Allow initial setup

        // Should smoothly animate to the single value
        expect(controller.currentPhase, equals(0.0));

        // Switch back to timeline sequence (like releasing the button)
        controller.sequence = timelineSequence;
        await tester.pump(); // Allow initial setup

        // Should NOT immediately jump to phase 0, should stay at current phase
        // and should stop playing since timeline doesn't loop
        expect(controller.currentPhase, equals(0)); // Should be at phase 0

        // Wait for animation to settle
        await tester.pumpAndSettle();

        // Should settle at the timeline value for phase 0, not restart the sequence
        expect(controller.value, closeTo(1.0, 0.1));

        // Should not be playing anymore since timeline doesn't loop
        expect(controller.status, isNot(AnimationStatus.forward));

        controller.dispose();
      });

      testWidgets(
          'should restart looping sequences when switching while playing',
          (tester) async {
        // Create a looping timeline sequence
        final loopingSequence = TimelineSequence(
          {
            0: 1.0,
            0.5: 0.5,
            1.0: 1.0,
          },
          motion: CupertinoMotion.smooth(),
          loopMode: PhaseLoopMode.loop, // This one loops
        );

        // Create a single value sequence
        final singleSequence = PhaseSequence.single(
          0.2,
          motion: CupertinoMotion.smooth(),
        );

        final controller = PhaseController(
          sequence: loopingSequence,
          converter: const SingleMotionConverter(),
          vsync: vsync,
        );

        // Start playing
        controller.start();
        await tester.pump(const Duration(milliseconds: 50));

        // Switch to single sequence
        controller.sequence = singleSequence;
        await tester.pump();

        // Switch back to looping sequence
        controller.sequence = loopingSequence;
        await tester.pump();

        // Should restart from the beginning since it's a looping sequence
        expect(controller.currentPhase, equals(0));
        expect(controller.currentPhaseIndex, equals(0));

        controller.dispose();
      });
    });
  });
}
