import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:motor/motor.dart';

/// Example demonstrating phase animations with Motor.
///
/// This example shows several different ways to use phase animations:
/// 1. Simple button state phases
/// 2. Loading animation phases
/// 3. Complex multi-property phases
class PhaseAnimationExamples extends StatelessWidget {
  const PhaseAnimationExamples({super.key});

  static const String name = 'Phase Animations';
  static const String path = 'phase-animations';

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(),
      child: const Padding(
        padding: EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Button State Phase Animation',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              ButtonPhaseExample(),
              SizedBox(height: 32),
              Text(
                'Complex Multi-Property Animation',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              ComplexPhaseExample(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Simple button phase animation example.
class ButtonPhaseExample extends StatefulWidget {
  const ButtonPhaseExample({super.key});

  @override
  State<ButtonPhaseExample> createState() => _ButtonPhaseExampleState();
}

class _ButtonPhaseExampleState extends State<ButtonPhaseExample> {
  int tapCount = 0;

  @override
  Widget build(BuildContext context) {
    return SinglePhaseMotionBuilder<double>(
      phases: [0.5, 0.6, 0.7, 0.8, 1.0], // Scale values for phases
      motion: CupertinoMotion.bouncy(),
      loopMode: PhaseLoopMode.none,
      trigger: tapCount, // Restart animation on tap
      builder: (context, scale, child) {
        return GestureDetector(
          onTap: () {
            setState(() {
              tapCount++;
            });
          },
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: 200,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: .3),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  'Tap Me!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Complex phase animation with multiple properties.
class ComplexPhaseExample extends StatefulWidget {
  const ComplexPhaseExample({super.key});

  @override
  State<ComplexPhaseExample> createState() => _ComplexPhaseExampleState();
}

class _ComplexPhaseExampleState extends State<ComplexPhaseExample> {
  int animationTrigger = 0;

  @override
  Widget build(BuildContext context) {
    final sequence = MapPhaseSequence<CardProperties, CardPhase>(
      motion: (_) => CupertinoMotion.smooth(),
      phaseMap: {
        CardPhase.idle: const CardProperties(
          width: 1020,
          height: 100,
          borderRadius: 12,
          color: Colors.red,
          elevation: 4,
        ),
        CardPhase.hover: const CardProperties(
          width: 210,
          height: 105,
          borderRadius: 16,
          color: Colors.blueAccent,
          elevation: 8,
        ),
        CardPhase.pressed: const CardProperties(
          width: 195,
          height: 98,
          borderRadius: 10,
          color: Colors.indigo,
          elevation: 2,
        ),
        CardPhase.success: const CardProperties(
          width: 220,
          height: 110,
          borderRadius: 20,
          color: Colors.green,
          elevation: 12,
        ),
      },
    );

    return Center(
      child: GestureDetector(
        onTap: () {
          setState(() {
            animationTrigger++;
          });
        },
        child: PhaseMotionBuilder<CardProperties, CardPhase>(
          sequence: sequence,
          converter: const CardPropertiesConverter(),
          restartTrigger: animationTrigger,
          loopMode: PhaseLoopMode.loop,
          builder: (context, properties, phase, child) {
            return Container(
              width: properties.width,
              height: properties.height,
              decoration: BoxDecoration(
                color: properties.color,
                borderRadius: BorderRadius.circular(properties.borderRadius),
              ),
              child: Center(
                child: Text(
                  phase.name.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// Data structures for complex phase animation

enum CardPhase { idle, hover, pressed, success }

@immutable
class CardProperties {
  const CardProperties({
    required this.width,
    required this.height,
    required this.borderRadius,
    required this.color,
    required this.elevation,
  });

  final double width;
  final double height;
  final double borderRadius;
  final Color color;
  final double elevation;
}

class CardPropertiesConverter implements MotionConverter<CardProperties> {
  const CardPropertiesConverter();

  @override
  List<double> normalize(CardProperties value) => [
        value.width,
        value.height,
        value.borderRadius,
        value.color.r.toDouble(),
        value.color.g.toDouble(),
        value.color.b.toDouble(),
        value.elevation,
      ];

  @override
  CardProperties denormalize(List<double> values) => CardProperties(
        width: values[0],
        height: values[1],
        borderRadius: values[2],
        color: Color.from(
          alpha: 1,
          red: values[3],
          green: values[4],
          blue: values[5],
        ),
        elevation: values[6],
      );
}
