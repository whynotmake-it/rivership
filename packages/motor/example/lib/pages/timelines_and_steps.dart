import 'dart:math' as math;

import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/widgets/example_scaffold.dart';
import 'package:motor_example/widgets/timeline_lanes.dart';

/// Shows reusable timelines, ordered steps, and their loop behavior.
class TimelinesAndStepsPage extends StatefulWidget {
  const TimelinesAndStepsPage({super.key});

  static const routeName = 'Timelines & Steps';

  @override
  State<TimelinesAndStepsPage> createState() => _TimelinesAndStepsPageState();
}

class _TimelinesAndStepsPageState extends State<TimelinesAndStepsPage>
    with SingleTickerProviderStateMixin {
  static const _dotCount = 5;
  static const _offset = Duration(milliseconds: 100);

  final _dots = [
    for (var i = 0; i < _dotCount; i++)
      Track<double>(.single, initial: 0.3),
  ];
  final _angle = Track<double>(.single, initial: 0);
  final _playhead = ValueNotifier(Duration.zero);

  late final Ticker _ticker;
  late TrackTimeline _timeline;
  late Duration _duration;
  LoopMode _loop = LoopMode.loop;

  @override
  void initState() {
    super.initState();
    _rebuildTimeline();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _playhead.dispose();
    super.dispose();
  }

  void _rebuildTimeline() {
    _timeline = _loop == LoopMode.seamless
        ? TrackTimeline(
            [
              _angle([
                // Seamless loops require identical first and last rendered
                // frames. This zero-duration step encodes the instant reset.
                .to(0, motion: .linear(.zero)),
                .to(math.pi, motion: .linear(Duration(milliseconds: 450))),
                .to(2 * math.pi,
                    motion: .linear(Duration(milliseconds: 450))),
              ]),
            ],
            loop: _loop,
          )
        : TrackTimeline(
            [
              for (final (index, dot) in _dots.indexed)
                dot([
                  .hold(_offset * index),
                  .to(
                    1,
                    motion: .smoothSpring(
                      duration: Duration(milliseconds: 250),
                    ),
                  ),
                  .to(
                    0.3,
                    motion: .smoothSpring(
                      duration: Duration(milliseconds: 350),
                    ),
                  ),
                  .hold(_offset * (_dotCount - index)),
                ]),
            ],
            loop: _loop,
          );
    _duration = _loop == LoopMode.seamless
        ? const Duration(milliseconds: 900)
        : const Duration(milliseconds: 1100);
  }

  void _selectLoop(LoopMode? loop) {
    if (loop == null || loop == _loop) return;
    _ticker.stop();
    _playhead.value = Duration.zero;
    setState(() {
      _loop = loop;
      _rebuildTimeline();
    });
    _ticker.start();
  }

  void _tick(Duration elapsed) {
    final total = _duration.inMicroseconds;
    if (total == 0) return;
    final cycle = elapsed.inMicroseconds ~/ total;
    final within = elapsed.inMicroseconds % total;
    final visible = _loop == LoopMode.pingPong && cycle.isOdd
        ? total - within
        : within;
    _playhead.value = Duration(microseconds: visible);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ExampleTheme.of(context);
    final labels = <Track, String>{
      for (final (index, dot) in _dots.indexed) dot: 'dot ${index + 1}',
      _angle: 'spinner',
    };
    return ExamplePage(
      title: TimelinesAndStepsPage.routeName,
      description:
          'A timeline is a reusable value made from steps. Change its loop '
          'mode and watch the same plan jump home, bounce backward, or join '
          'first and last frames seamlessly.',
      action: CupertinoSlidingSegmentedControl<LoopMode>(
        groupValue: _loop,
        onValueChanged: _selectLoop,
        children: const {
          LoopMode.loop: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('loop'),
          ),
          LoopMode.pingPong: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('pingPong'),
          ),
          LoopMode.seamless: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('seamless'),
          ),
        },
      ),
      child: Column(
        children: [
          Surface(
            padding: const EdgeInsets.symmetric(vertical: 34),
            child: Center(
              child: TrackBuilder.timeline(
                _timeline,
                builder: (context, value, _) => _loop == LoopMode.seamless
                    ? Transform.rotate(
                        angle: value(_angle),
                        child: CustomPaint(
                          size: const Size.square(48),
                          painter: _ArcPainter(
                            theme.textPrimary,
                            theme.border,
                          ),
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final dot in _dots)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 7),
                              child: Transform.scale(
                                scale: 0.6 + value(dot) * 0.7,
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: theme.textPrimary.withValues(
                                      alpha: (0.25 + value(dot) * 0.75)
                                          .clamp(0, 1),
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Surface(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
            child: TimelineLanes(
              timeline: _timeline,
              playhead: _playhead,
              laneLabels: labels,
              laneColors: {
                for (final track in _timeline.animations)
                  track.track: theme.textPrimary,
              },
            ),
          ),
          const SizedBox(height: 18),
          const TakeawayText(
            'A timeline is a value: build it once, play it anywhere, loop it. '
            'Its steps read in order — hold, go, hold.',
          ),
        ],
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter(this.color, this.trackColor);

  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawArc(
      rect.deflate(2),
      0,
      2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = trackColor,
    );
    canvas.drawArc(
      rect.deflate(2),
      -math.pi / 2,
      math.pi * 1.2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter oldDelegate) =>
      color != oldDelegate.color || trackColor != oldDelegate.trackColor;
}
