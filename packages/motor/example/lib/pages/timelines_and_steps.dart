import 'dart:math' as math;

import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/widgets/example_scaffold.dart';
import 'package:motor_example/widgets/timeline_inspector.dart';

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

  // Fixed curves make the contrast between the loop modes unambiguous. The
  // inspector reads actual engine timing, so it remains honest if these are
  // replaced with springs later.
  static const _pop = CurvedMotion(
    Duration(milliseconds: 250),
    Curves.easeOutBack,
  );
  static const _fall = CurvedMotion(
    Duration(milliseconds: 350),
    Curves.easeInOutCubic,
  );

  final _dots = [
    for (var i = 0; i < _dotCount; i++) Track<double>(.single, initial: 0.3),
  ];
  final _angle = Track<double>(.single, initial: 0);

  late final _controller = TrackController(vsync: this);
  late TrackTimeline _timeline;
  LoopMode _loop = LoopMode.loop;

  @override
  void initState() {
    super.initState();
    _rebuildTimeline();
    _playTimeline();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _rebuildTimeline() {
    _timeline = _loop == LoopMode.seamless
        ? TrackTimeline([
            _angle([
              // Seamless loops require identical first and last rendered
              // frames. This zero-duration step encodes the instant reset.
              .to(0, motion: .linear(.zero)),
              .to(math.pi, motion: .linear(Duration(milliseconds: 450))),
              .to(2 * math.pi, motion: .linear(Duration(milliseconds: 450))),
            ]),
          ], loop: _loop)
        : TrackTimeline([
            for (final (index, dot) in _dots.indexed)
              dot([
                // Zero-duration anchor: LoopMode.loop appends an implicit
                // return-to-start step that reuses the first step's motion.
                // Anchoring with a free zero-duration step keeps that return
                // instant (the plan already ends at its start value), so the
                // engine's loop period stays equal to the drawn span.
                .to(0.3, motion: .linear(.zero)),
                .hold(_offset * index),
                .to(1, motion: _pop),
                .to(0.3, motion: _fall),
                .hold(_offset * (_dotCount - index)),
              ]),
          ], loop: _loop);
  }

  void _playTimeline() {
    _controller
      ..stop(canceled: true)
      ..set(_timeline.startValues)
      ..play(_timeline);
  }

  void _selectLoop(LoopMode? loop) {
    if (loop == null || loop == _loop) return;
    setState(() {
      _loop = loop;
      _rebuildTimeline();
    });
    _playTimeline();
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
      next: (label: 'Sync Barriers', routeName: 'Sync Barriers'),
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
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => _loop == LoopMode.seamless
                    ? Transform.rotate(
                        angle: _controller.value(_angle),
                        child: CustomPaint(
                          size: const Size.square(48),
                          painter: _ArcPainter(theme.textPrimary, theme.border),
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final dot in _dots)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                              ),
                              child: Transform.scale(
                                scale: 0.6 + _controller.value(dot) * 0.7,
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: theme.textPrimary.withValues(
                                      alpha:
                                          (0.25 + _controller.value(dot) * 0.75)
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
            child: TimelineInspector(
              controller: _controller,
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
