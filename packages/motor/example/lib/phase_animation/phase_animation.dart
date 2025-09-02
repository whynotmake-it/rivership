import 'package:flutter/cupertino.dart';
import 'package:motor_example/phase_animation/card_stack.dart';
import 'package:motor_example/phase_animation/logo_animation.dart';
import 'package:motor_example/phase_animation/loop_comparison.dart';
import 'package:motor_example/phase_animation/manual_phase_control.dart';

/// Comprehensive example demonstrating phase animations with Motor.
///
/// Phase animations allow you to define sequences of states (phases) that your
/// UI smoothly transitions through. This example showcases:
/// 1. Simple single-property phase transitions
/// 2. Complex multi-property phase sequences
/// 3. Different triggering mechanisms and loop modes
class SequenceAnimationExamples extends StatelessWidget {
  const SequenceAnimationExamples({super.key});

  static const String name = 'Sequence Animations';
  static const String path = 'sequence-animations';

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Sequence Animations'),
      ),
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              spacing: 64,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSection(
                  context,
                  'Logo Animation',
                  'The simplest use case of sequence animations are animation timelines.',
                  LogoAnimation(),
                ),
                _buildSection(
                  context,
                  'Manual Phase Control',
                  'Phase Sequences don\'t always have to play automatically. '
                      '\nYou can base the phase transitions on user input'
                      '\n\nTry spamming the button and see how the ball redirects smoothly',
                  const ManualPhaseControl(),
                ),
                _buildSection(
                  context,
                  'From Gesture to Sequence',
                  'Drag a Card to move it to the back of the stack. '
                      'Watch how it always magically clears the stack before returning. '
                      '\n\nThis is an example of a fully physics-based sequence.',
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 64),
                    child: CardStack(),
                  ),
                ),
                _buildSection(
                  context,
                  'Looping Sequence Animations',
                  'Sequence animations can be configured to loop in four ways.',
                  const LoopComparisonExample(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    String description,
    Widget child,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: CupertinoTheme.of(context).textTheme.textStyle.color,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: CupertinoTheme.of(context).textTheme.textStyle,
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }
}
