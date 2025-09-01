import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/card_stack.dart';

/// Comprehensive example demonstrating phase animations with Motor.
///
/// Phase animations allow you to define sequences of states (phases) that your
/// UI smoothly transitions through. This example showcases:
/// 1. Simple single-property phase transitions
/// 2. Complex multi-property phase sequences
/// 3. Different triggering mechanisms and loop modes
class PhaseAnimationExamples extends StatelessWidget {
  const PhaseAnimationExamples({super.key});

  static const String name = 'Phase Animations';
  static const String path = 'phase-animations';

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Phase Animations'),
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
                  'From Gesture to Sequence',
                  'Drag a Card to move it to the back of the stack. '
                      'Watch how it always magically clears the stack before returning. '
                      '\nThis is an example of a fully physics-based sequence.',
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 64),
                    child: CardStack(),
                  ),
                ),
                _buildSection(
                  context,
                  'Looping Phase Sequences',
                  'Phase animations can be configured to loop in four ways.',
                  const LoopComparisonExample(),
                ),
                _buildSection(
                  context,
                  'Interactive Card States',
                  'Tap to cycle through different interactive states with smooth transitions',
                  const InteractiveCardExample(),
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

/// Demonstrates a bouncy button that scales through multiple phases when tapped.
///
/// This example uses SinglePhaseMotionBuilder to animate a single property (scale)
/// through a sequence of phases. Each tap triggers a restart of the animation.
class BouncyButtonExample extends StatefulWidget {
  const BouncyButtonExample({super.key});

  @override
  State<BouncyButtonExample> createState() => _BouncyButtonExampleState();
}

class _BouncyButtonExampleState extends State<BouncyButtonExample> {
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          PhaseMotionBuilder(
            sequence: pressed
                ? PhaseSequence.value(0.0, 0.5, CupertinoMotion.smooth())
                : TimelineSequence<double>(
                    {
                      0: 1.0,
                      0.4: 1.1,
                      0.9: 1.0,
                    },
                    motion: CupertinoMotion.smooth(),
                  ),
            // Define the scale values for each phase
            converter: const SingleMotionConverter(),
            builder: (context, scale, _, child) {
              return GestureDetector(
                onTapDown: (_) {
                  setState(() {
                    pressed = true;
                  });
                },
                onTapUp: (_) {
                  setState(() {
                    pressed = false;
                  });
                },
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 200,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          CupertinoColors.activeBlue,
                          CupertinoColors.systemBlue
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color:
                              CupertinoColors.systemBlue.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'Tap for Bounce!',
                        style: TextStyle(
                          color: CupertinoColors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

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
    required PhaseSequence<int, double> sequence,
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
          child: PhaseMotionBuilder(
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
                      ].asSequence(
                        withMotion: Motion.cupertino(),
                        loopMode: SequenceLoopMode.none,
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
                      ].asSequence(
                        withMotion: Motion.cupertino(),
                        loopMode: SequenceLoopMode.loop,
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
                      ].asSequence(
                        withMotion: Motion.cupertino(),
                        loopMode: SequenceLoopMode.pingPong,
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
                      ].asSequence(
                        withMotion: Motion.cupertino(),
                        loopMode: SequenceLoopMode.seamless,
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

/// Demonstrates complex multi-property phase animations.
///
/// This example shows how to animate multiple properties simultaneously
/// using PhaseMotionBuilder with custom data structures and converters.
class InteractiveCardExample extends StatefulWidget {
  const InteractiveCardExample({super.key});

  @override
  State<InteractiveCardExample> createState() => _InteractiveCardExampleState();
}

class _InteractiveCardExampleState extends State<InteractiveCardExample> {
  CardPhase currentPhase = CardPhase.idle;
  int phaseIndex = 0;

  void _nextPhase() {
    setState(() {
      phaseIndex = (phaseIndex + 1) % CardPhase.values.length;
      currentPhase = CardPhase.values[phaseIndex];
    });
  }

  @override
  Widget build(BuildContext context) {
    final sequence = {
      CardPhase.idle: const CardProperties(
        width: 280,
        borderRadius: 16,
        color: CupertinoColors.systemGrey,
        shadowBlur: 4,
      ),
      CardPhase.focused: const CardProperties(
        width: 300,
        borderRadius: 20,
        color: CupertinoColors.activeBlue,
        shadowBlur: 12,
      ),
      CardPhase.pressed: const CardProperties(
        width: 270,
        borderRadius: 12,
        color: CupertinoColors.systemIndigo,
        shadowBlur: 2,
      ),
      CardPhase.success: const CardProperties(
        width: 320,
        borderRadius: 24,
        color: CupertinoColors.systemGreen,
        shadowBlur: 16,
      ),
    }.asSequence(withMotion: Motion.bouncySpring());

    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _nextPhase,
            child: PhaseMotionBuilder(
              sequence: sequence,
              converter: const CardPropertiesConverter(),
              currentPhase: currentPhase,
              playing: false,
              builder: (context, properties, phase, child) {
                return Container(
                  width: properties.width,
                  height: 200,
                  decoration: ShapeDecoration(
                    color: properties.color,
                    shape: RoundedSuperellipseBorder(
                      borderRadius:
                          BorderRadius.circular(properties.borderRadius),
                    ),
                    shadows: [
                      BoxShadow(
                        color: CupertinoColors.black.withValues(alpha: 0.15),
                        blurRadius: properties.shadowBlur,
                        offset: Offset(0, properties.shadowBlur / 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _getIconForPhase(phase),
                          color: CupertinoColors.white,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _getDisplayName(phase),
                          style: const TextStyle(
                            color: CupertinoColors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Tap the card to cycle through states',
            style: TextStyle(
              fontSize: 14,
              color: CupertinoTheme.of(context)
                  .textTheme
                  .textStyle
                  .color
                  ?.withValues(alpha: .7),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForPhase(CardPhase phase) {
    switch (phase) {
      case CardPhase.idle:
        return CupertinoIcons.rectangle;
      case CardPhase.focused:
        return CupertinoIcons.eye;
      case CardPhase.pressed:
        return CupertinoIcons.hand_thumbsup;
      case CardPhase.success:
        return CupertinoIcons.checkmark_circle_fill;
    }
  }

  String _getDisplayName(CardPhase phase) {
    switch (phase) {
      case CardPhase.idle:
        return 'Idle';
      case CardPhase.focused:
        return 'Focused';
      case CardPhase.pressed:
        return 'Pressed';
      case CardPhase.success:
        return 'Success';
    }
  }
}

/// Data structures for complex phase animations

/// Represents different states that the interactive card can be in
enum CardPhase {
  /// Default resting state
  idle,

  /// Card is being focused/hovered
  focused,

  /// Card is being pressed/touched
  pressed,

  /// Action completed successfully
  success
}

/// Holds all the visual properties that can be animated for a card
@immutable
class CardProperties {
  const CardProperties({
    required this.width,
    required this.borderRadius,
    required this.color,
    required this.shadowBlur,
  });

  final double width;
  final double borderRadius;
  final Color color;
  final double shadowBlur;
}

/// Converts CardProperties to/from a list of doubles for smooth animation
///
/// This converter allows Motor to interpolate between complex data structures
/// by breaking them down into animatable numeric values.
class CardPropertiesConverter implements MotionConverter<CardProperties> {
  const CardPropertiesConverter();

  @override
  List<double> normalize(CardProperties value) => [
        value.width,
        value.borderRadius,
        value.color.r.toDouble(),
        value.color.g.toDouble(),
        value.color.b.toDouble(),
        value.shadowBlur,
      ];

  @override
  CardProperties denormalize(List<double> values) => CardProperties(
        width: values[0],
        borderRadius: values[1],
        color: Color.from(
          alpha: 1,
          red: values[2],
          green: values[3],
          blue: values[4],
        ),
        shadowBlur: values[5],
      );
}
