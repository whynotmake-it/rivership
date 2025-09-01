import 'package:flutter/cupertino.dart';
import 'package:motor/motor.dart';

class ManualPhaseControl extends StatefulWidget {
  const ManualPhaseControl({super.key});

  @override
  State<ManualPhaseControl> createState() => _ManualPhaseControlState();
}

class _ManualPhaseControlState extends State<ManualPhaseControl> {
  var phase = 0;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: 300),
        child: AspectRatio(
          aspectRatio: 1,
          child: SequenceMotionBuilder(
              sequence: [
                Alignment(-1, -1),
                Alignment(1, -1),
                Alignment(1, 1),
                Alignment(-1, 1),
              ].toSteps(motion: Motion.smoothSpring()),
              converter: AlignmentMotionConverter(),
              currentPhase: phase,
              playing: false,
              builder: (context, alignment, _, child) {
                return Stack(
                  children: [
                    Positioned.fill(
                        child: Placeholder(
                      color: CupertinoColors.lightBackgroundGray
                          .withValues(alpha: 0.1),
                    )),
                    Align(
                      alignment: alignment,
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: CupertinoColors.activeBlue,
                        ),
                      ),
                    ),
                    Center(
                      child: CupertinoButton.filled(
                        child: const Text('Next Phase'),
                        onPressed: () {
                          setState(() {
                            phase = (phase + 1) % 4;
                          });
                        },
                      ),
                    )
                  ],
                );
              }),
        ),
      ),
    );
  }
}
