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
  });
}
