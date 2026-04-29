import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/widgets/example_scaffold.dart';

const _routeName = 'Timeline Choreography';

class TimelineChoreographyPage extends StatefulWidget {
  const TimelineChoreographyPage({super.key});
  static const routeName = _routeName;

  @override
  State<TimelineChoreographyPage> createState() =>
      _TimelineChoreographyPageState();
}

class _TimelineChoreographyPageState extends State<TimelineChoreographyPage> {
  var _replay = 0;
  var _step = 'ready';

  final offset = Track(.offset, initial: Offset(0, 500));
  final scale = Track(.single, initial: .84);
  final opacity = Track<double>(.single, initial: 0);
  final rotation = Track<double>(.single, initial: -.08);
  final tint = Track<Color>(.colorRgb, initial: Color(0xFF0A84FF));

  get _launchTimeline => TrackTimeline([
    offset([
      .to(
        Offset(0, 100),
        motion: .smoothSpring(duration: Duration(milliseconds: 520)),
      ),
      .at(
        Duration(milliseconds: 120),
        Offset.zero,
        motion: .bouncySpring(
          duration: Duration(milliseconds: 420),
          extraBounce: .08,
        ),
      ),
    ]),
    scale([
      .to(1.04, motion: .smoothSpring(duration: Duration(milliseconds: 210))),
      .to(
        1,
        motion: .bouncySpring(
          duration: Duration(milliseconds: 360),
          extraBounce: .05,
        ),
      ),
    ]),
    opacity([
      .to(1, motion: .curved(Duration(milliseconds: 500), Curves.ease)),
    ]),
    rotation([
      .to(.035, motion: .snappySpring(duration: Duration(milliseconds: 420))),
      .to(0, motion: .smoothSpring(duration: Duration(milliseconds: 380))),
    ]),
    tint([
      .hold(Duration(milliseconds: 120)),
      .to(
        const Color(0xFFBF5AF2),
        motion: Motion.smoothSpring(duration: Duration(milliseconds: 420)),
      ),
      .to(
        const Color(0xFF34C759),
        motion: Motion.smoothSpring(duration: Duration(milliseconds: 420)),
      ),
    ]),
  ]);

  @override
  Widget build(BuildContext context) {
    return ExamplePage(
      title: _routeName,
      description:
          'A TrackTimeline owns multiple property tracks. Each track can have '
          'its own steps, holds, and motion while the builder reads one '
          'coherent animated value set.',
      action: CupertinoButton.filled(
        onPressed: () {
          setState(() {
            _replay++;
            _step = 'replaying';
          });
        },
        child: const Text('Replay timeline'),
      ),
      child: MultiTrackMotionBuilder(
        from: [
          // The timeline should always start from the initial values,
          // so we set them here.
          offset.value(offset.initial),
          scale.value(scale.initial),
          opacity.value(opacity.initial),
          rotation.value(rotation.initial),
          tint.value(tint.initial),
        ],
        timeline: _launchTimeline,
        restartTrigger: _replay,
        onStep: (track, stepIndex) {
          if (!identical(track, tint)) return;
          setState(() => _step = 'color step ${stepIndex + 1}');
        },
        builder: (context, value, child) {
          final scaleV = value(scale);
          return Transform.translate(
            offset: value(offset),
            child: Transform.rotate(
              angle: value(rotation),
              child: Transform.scale(
                scale: scaleV,
                child: Opacity(
                  opacity: value(opacity).clamp(0.0, 1.0).toDouble(),
                  child: _LaunchCard(tint: value(tint), step: _step),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LaunchCard extends StatelessWidget {
  const _LaunchCard({required this.tint, required this.step});

  final Color tint;
  final String step;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Surface(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              LiveDot(color: tint),
              const SizedBox(width: 10),
              Text(
                step.toUpperCase(),
                style: TextStyle(
                  color: tint,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Launch checklist',
            style: TextStyle(
              color: t.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -.8,
            ),
          ),
          const SizedBox(height: 16),
          _ChecklistRow('Warm up physics slots', color: t.accentGreen),
          _ChecklistRow('Stagger content tracks', color: t.accentGreen),
          _ChecklistRow('Redirect tint mid-flight', color: t.accentGreen),
        ],
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(CupertinoIcons.check_mark_circled_solid, color: color, size: 20),
          const SizedBox(width: 10),
          Text(text, style: TextStyle(color: t.textSecondary, fontSize: 15)),
        ],
      ),
    );
  }
}
