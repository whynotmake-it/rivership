import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:motor/motor.dart';

/// Demonstrates the difference between seamless and regular loop modes.
///
/// This example shows two rotating squares - one using seamless looping
/// and one using regular looping to clearly show the jump at the end.
class LoopComparisonExample extends StatefulWidget {
  const LoopComparisonExample({super.key});

  @override
  State<LoopComparisonExample> createState() => _LoopComparisonExampleState();
}

class _LoopComparisonExampleState extends State<LoopComparisonExample> {
  int retrigger = 0;

  Widget _buildArrow(
    BuildContext context, {
    required String title,
    required MotionSequence<int, double> sequence,
    Color color = CupertinoColors.activeBlue,
  }) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: CupertinoColors.label,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 60,
          child: SequenceMotionBuilder(
            restartTrigger: retrigger,
            converter: SingleMotionConverter(),
            sequence: sequence,
            builder: (context, rotation, _, child) {
              return Center(
                child: Transform.rotate(
                  angle: rotation,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        CupertinoIcons.arrow_up,
                        color: CupertinoColors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            // Seamless looping example
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: CupertinoColors.systemBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: CupertinoColors.separator,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildArrow(
                      context,
                      title: 'No Loop',
                      color: CupertinoColors.systemRed,
                      sequence: const [
                        0.0,
                        math.pi / 2,
                        math.pi,
                        3 * math.pi / 2,
                        2 * math.pi
                      ].toSteps(
                        motion: Motion.cupertino(),
                        loopMode: LoopMode.none,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _buildArrow(
                      context,
                      title: 'Loop',
                      color: CupertinoColors.systemGreen,
                      sequence: const [
                        0.0,
                        math.pi / 2,
                        math.pi,
                        3 * math.pi / 2,
                        2 * math.pi
                      ].toSteps(
                        motion: Motion.cupertino(),
                        loopMode: LoopMode.loop,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _buildArrow(
                      context,
                      title: 'Ping Pong',
                      color: CupertinoColors.systemOrange,
                      sequence: const [
                        0.0,
                        math.pi / 2,
                        math.pi,
                        3 * math.pi / 2,
                        2 * math.pi
                      ].toSteps(
                        motion: Motion.cupertino(),
                        loopMode: LoopMode.pingPong,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _buildArrow(
                      context,
                      title: 'Seamless',
                      color: CupertinoColors.activeBlue,
                      sequence: const [
                        0.0,
                        math.pi / 2,
                        math.pi,
                        3 * math.pi / 2,
                        2 * math.pi
                      ].toSteps(
                        motion: Motion.cupertino(),
                        loopMode: LoopMode.seamless,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Seamless loop treats the last and first phases as identical.',
                    style: TextStyle(
                      fontSize: 14,
                      color: CupertinoTheme.of(context)
                          .textTheme
                          .textStyle
                          .color
                          ?.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                CupertinoButton(
                  minimumSize: Size.square(32),
                  padding: EdgeInsets.zero,
                  child: Icon(CupertinoIcons.refresh),
                  onPressed: () {
                    setState(() {
                      retrigger++;
                    });
                  },
                )
              ],
            ),
          ],
        ),
      ],
    );
  }
}
