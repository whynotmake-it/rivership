import 'dart:math';

import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/widgets/example_scaffold.dart';

class LoopModesPage extends StatefulWidget {
  const LoopModesPage({super.key});
  static const routeName = 'Loop Modes';

  @override
  State<LoopModesPage> createState() => _LoopModesPageState();
}

class _LoopModesPageState extends State<LoopModesPage> {
  int _restartKey = 0;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return ExamplePage(
      title: LoopModesPage.routeName,
      description:
          'Four LoopMode variants side by side. Each arrow rotates '
          'through the same steps but with a different loop behavior.',
      action: CupertinoButton(
        onPressed: () => setState(() => _restartKey++),
        child: const Text('Restart'),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _LoopModeDemo(
            label: 'None',
            loopMode: LoopMode.none,
            color: t.accentBlue,
            restartKey: _restartKey,
          ),
          _LoopModeDemo(
            label: 'Loop',
            loopMode: LoopMode.loop,
            color: t.accentGreen,
            restartKey: _restartKey,
          ),
          _LoopModeDemo(
            label: 'PingPong',
            loopMode: LoopMode.pingPong,
            color: t.accentPurple,
            restartKey: _restartKey,
          ),
          _LoopModeDemo(
            label: 'Seamless',
            loopMode: LoopMode.seamless,
            color: t.accentOrange,
            restartKey: _restartKey,
          ),
        ],
      ),
    );
  }
}

class _LoopModeDemo extends StatelessWidget {
  const _LoopModeDemo({
    required this.label,
    required this.loopMode,
    required this.color,
    required this.restartKey,
  });

  final String label;
  final LoopMode loopMode;
  final Color color;
  final int restartKey;

  static final _rotation = Track<double>(.single, origin: 0);

  @override
  Widget build(BuildContext context) {
    final motion = Motion.curved(Duration(milliseconds: 600), Curves.easeInOut);
    final sequence = _rotation([
      .to(pi / 2, motion: motion),
      .to(pi, motion: motion),
      .to(3 * pi / 2, motion: motion),
      .to(2 * pi, motion: motion),
    ]);

    return Surface(
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        width: 140,
        height: 140,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Center(
                child: MultiTrackMotionBuilder(
                  timeline: TrackTimeline([sequence], loop: loopMode),
                  restartTrigger: restartKey,
                  builder: (context, value, child) {
                    return Transform.rotate(
                      angle: value(_rotation),
                      child: Icon(
                        CupertinoIcons.arrow_up,
                        color: color,
                        size: 36,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
