import 'dart:math' as math;

import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/widgets/example_scaffold.dart';

/// Loading indicators built on Motor: a dot-grid driven by an array of tracks,
/// a seamless spinner, and a side-by-side look at loop modes.
class LoadersPage extends StatelessWidget {
  const LoadersPage({super.key});
  static const routeName = 'Loaders';

  @override
  Widget build(BuildContext context) {
    return ExamplePage(
      title: routeName,
      description:
          'Looping motion as a product feature. The dot row builds one track '
          'per dot in an array and staggers them on a single clock; the spinner '
          'and the bars below show how loop modes differ.',
      child: Column(
        children: const [
          Surface(
            padding: EdgeInsets.symmetric(vertical: 36),
            child: Center(child: _DotRow()),
          ),
          SizedBox(height: 18),
          Surface(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: _Spinner()),
          ),
          SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _LoopCard(mode: LoopMode.loop, label: 'loop'),
              ),
              SizedBox(width: 18),
              Expanded(
                child: _LoopCard(mode: LoopMode.pingPong, label: 'pingPong'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A staggered dot loader. Each dot is its own [Track], created in an array and
/// played together with a looping [TrackTimeline].
class _DotRow extends StatelessWidget {
  const _DotRow();

  static const _count = 10;
  static const _offsetMs = 120;
  static final _dots = [
    for (var i = 0; i < _count; i++) Track<double>(.single, origin: 0.3),
  ];

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return MultiTrackMotionBuilder(
      loop: LoopMode.loop,
      play: [
        for (final (i, dot) in _dots.indexed)
          dot([
            .hold(Duration(milliseconds: i * _offsetMs)),
            .to(
              1,
              motion: .smoothSpring(duration: Duration(milliseconds: 300)),
            ),
            .to(
              0.3,
              motion: .smoothSpring(duration: Duration(milliseconds: 450)),
            ),
            .hold(Duration(milliseconds: (_count - i) * _offsetMs)),
          ]),
      ],
      builder: (context, value, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final dot in _dots)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Transform.scale(
                scale: 0.6 + value(dot) * 0.7,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: t.textPrimary.withValues(
                      alpha: (0.25 + value(dot) * 0.75).clamp(0.0, 1.0),
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A continuously rotating arc using a seamless loop.
class _Spinner extends StatelessWidget {
  const _Spinner();

  static final _angle = Track<double>(
    .single,
    origin: 0.0,
    motion: LinearMotion(Duration(milliseconds: 900)),
  );

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return MultiTrackMotionBuilder(
      play: [
        _angle([.to(0.0), .to(math.pi), .to(2 * math.pi)]),
      ],
      loop: .seamless,
      builder: (context, value, _) => Transform.rotate(
        angle: value(_angle),
        child: CustomPaint(
          size: const Size.square(44),
          painter: _ArcPainter(t.textPrimary, t.border),
        ),
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
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = trackColor;
    canvas.drawArc(rect.deflate(2), 0, 2 * math.pi, false, track);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect.deflate(2), -math.pi / 2, math.pi * 1.2, false, arc);
  }

  @override
  bool shouldRepaint(_ArcPainter oldDelegate) =>
      color != oldDelegate.color || trackColor != oldDelegate.trackColor;
}

/// A small bar that shows how a [LoopMode] cycles a value through positions.
class _LoopCard extends StatelessWidget {
  const _LoopCard({required this.mode, required this.label});
  final LoopMode mode;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Surface(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 18,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final span = constraints.maxWidth - 16;
                return SequenceMotionBuilder<int, double>(
                  sequence: [0.0, 0.5, 1.0].toSteps(
                    motion: const CupertinoMotion.smooth(
                      duration: Duration(milliseconds: 600),
                    ),
                    loopMode: mode,
                  ),
                  converter: MotionConverter.single,
                  builder: (context, value, _, __) => Stack(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: t.border,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Positioned(
                        left: value.clamp(0.0, 1.0) * span,
                        top: 0,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: t.textPrimary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'LoopMode.$label',
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontFamilyFallback: const ['monospace', 'Menlo'],
              fontSize: 11,
              color: t.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
