import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

enum AnimationPhase { start, middle, end }

Color _getPhaseColor(AnimationPhase phase) {
  switch (phase) {
    case AnimationPhase.start:
      return Colors.red;
    case AnimationPhase.middle:
      return Colors.blue;
    case AnimationPhase.end:
      return Colors.green;
  }
}

void main() {
  group('PhaseMotionBuilder', () {
    const frameSize = Size(200, 2);
    const rectSize = 2.0;

    late AnimationSheetBuilder animationSheet;

    setUp(() {
      animationSheet = AnimationSheetBuilder(frameSize: frameSize);
    });

    group('with MapPhaseSequence', () {
      const phaseMap = <AnimationPhase, double>{
        AnimationPhase.start: -1.0,
        AnimationPhase.middle: 0,
        AnimationPhase.end: 1,
      };

      Widget buildTestApp({
        required PhaseSequence<AnimationPhase, double> sequence,
        bool playing = false,
        AnimationPhase? currentPhase,
        Object? restartTrigger,
      }) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: Colors.black,
            body: SizedBox(
              width: frameSize.width,
              height: frameSize.height,
              child: PhaseMotionBuilder<AnimationPhase, double>(
                sequence: sequence,
                converter: const SingleMotionConverter(),
                playing: playing,
                currentPhase: currentPhase,
                restartTrigger: restartTrigger,
                builder: (context, offset, phase, child) {
                  return Stack(
                    children: [
                      Align(
                        alignment: Alignment(offset, 0),
                        child: Container(
                          width: rectSize,
                          height: rectSize,
                          color: _getPhaseColor(phase),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      }

      testWidgets('1D horizontal phase animation through sequence',
          (tester) async {
        final sequence = PhaseSequence.map(
          phaseMap,
          motion: const CupertinoMotion.bouncy(),
        );

        final widget = animationSheet.record(
          buildTestApp(
            sequence: sequence,
            playing: true,
          ),
        );

        await tester.pumpWidget(widget);
        await tester.pumpFrames(widget, const Duration(milliseconds: 2000));

        await expectLater(
          animationSheet.collate(1),
          matchesGoldenFile('golden/phase_motion_1d_animation.png'),
        );
      });

      testWidgets('phase change triggers animation correctly', (tester) async {
        final sequence = PhaseSequence.map(
          phaseMap,
          motion: const CupertinoMotion.smooth(),
        );

        var currentPhase = AnimationPhase.start;
        void Function(void Function())? setStateFn;

        final widget = animationSheet.record(
          StatefulBuilder(
            builder: (context, setState) {
              setStateFn = setState;
              return buildTestApp(
                sequence: sequence,
                currentPhase: currentPhase,
              );
            },
          ),
        );

        await tester.pumpWidget(widget);

        // Change phase to middle after some frames
        await tester.pump(const Duration(milliseconds: 500));

        setStateFn!(() {
          currentPhase = AnimationPhase.middle;
        });

        await tester.pumpFrames(widget, const Duration(milliseconds: 500));

        setStateFn!(() {
          currentPhase = AnimationPhase.end;
        });

        await tester.pumpFrames(widget, const Duration(milliseconds: 500));

        await expectLater(
          animationSheet.collate(1),
          matchesGoldenFile('golden/phase_motion_manual_changes.png'),
        );
      });

      testWidgets('restart trigger jumps animation correctly', (tester) async {
        final sequence = PhaseSequence.map(
          phaseMap,
          motion: const CupertinoMotion.smooth(),
        );

        var currentPhase = AnimationPhase.start;
        var restartTrigger = 0;
        var isPlaying = false;
        void Function(void Function())? setStateFn;

        final widget = animationSheet.record(
          StatefulBuilder(
            builder: (context, setState) {
              setStateFn = setState;
              return buildTestApp(
                sequence: sequence,
                currentPhase: currentPhase,
                restartTrigger: restartTrigger,
                playing: isPlaying,
              );
            },
          ),
        );

        await tester.pumpWidget(widget);

        // Change phase to middle after some frames
        await tester.pump(const Duration(milliseconds: 500));

        setStateFn!(() {
          currentPhase = AnimationPhase.middle;
          restartTrigger++;
          isPlaying = true;
        });

        await tester.pumpFrames(widget, const Duration(milliseconds: 500));

        await expectLater(
          animationSheet.collate(1),
          matchesGoldenFile('golden/restart_trigger.png'),
        );
      });

      testWidgets('loop works well', (tester) async {
        final sequence = PhaseSequence.map(
          phaseMap,
          loopMode: SequenceLoopMode.loop,
          motion: const CurvedMotion(duration: Duration(milliseconds: 500)),
        );

        final widget = animationSheet.record(
          buildTestApp(
            sequence: sequence,
            playing: true,
          ),
        );

        await tester.pumpFrames(widget, const Duration(seconds: 2));

        await expectLater(
          animationSheet.collate(1),
          matchesGoldenFile('golden/loop_mode_loop.png'),
        );
      });

      testWidgets('ping pong loop works well', (tester) async {
        final sequence = PhaseSequence.map(
          phaseMap,
          loopMode: SequenceLoopMode.pingPong,
          motion: const CurvedMotion(duration: Duration(milliseconds: 500)),
        );

        final widget = animationSheet.record(
          buildTestApp(
            sequence: sequence,
            playing: true,
          ),
        );

        await tester.pumpFrames(widget, const Duration(seconds: 3));

        await expectLater(
          animationSheet.collate(1),
          matchesGoldenFile('golden/loop_mode_ping_pong.png'),
        );
      });

      testWidgets('seamless loop works well', (tester) async {
        final sequence = PhaseSequence.map(
          phaseMap,
          loopMode: SequenceLoopMode.seamless,
          motion: const CurvedMotion(duration: Duration(milliseconds: 500)),
        );

        final widget = animationSheet.record(
          buildTestApp(
            sequence: sequence,
            playing: true,
          ),
        );

        await tester.pumpFrames(widget, const Duration(seconds: 3));

        await expectLater(
          animationSheet.collate(1),
          matchesGoldenFile('golden/loop_mode_seamless.png'),
        );
      });
    });

    group('PhaseMotionBuilder with Timeline', () {
      testWidgets('timeline sequence', (tester) async {
        final sequence = TimelineSequence<double>(
          {
            0: -1,
            1: 0,
            2: 1,
          },
          loopMode: SequenceLoopMode.pingPong,
          motion: const CurvedMotion(duration: Duration(seconds: 1)),
        );

        final widget = animationSheet.record(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: Colors.black,
              body: SizedBox(
                width: frameSize.width,
                height: frameSize.height,
                child: PhaseMotionBuilder(
                  sequence: sequence,
                  converter: const SingleMotionConverter(),
                  builder: (context, offset, phase, child) {
                    return Stack(
                      children: [
                        Align(
                          alignment: Alignment(offset, 0),
                          child: Container(
                            width: rectSize,
                            height: rectSize,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );

        await tester.pumpFrames(widget, const Duration(seconds: 2));

        await expectLater(
          animationSheet.collate(1),
          matchesGoldenFile('golden/timeline.png'),
        );
      });
    });
  });
}
