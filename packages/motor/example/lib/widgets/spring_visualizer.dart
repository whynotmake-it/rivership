import 'dart:math' as math;

import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:motor/motor.dart';
import 'package:motor_example/widgets/value_recording_notifier.dart';

/// A draggable horizontal spring playground.
///
/// Drag (or flick) the small target ring; the larger ball springs toward it.
/// The drawn coil stretches and compresses, making the physical object
/// literal. The [duration] and [bounce] tune the [CupertinoMotion] live, so the
/// reader can feel how two numbers change the entire character of the settle.
///
/// If a [recorder] is given, the ball's normalized position (`0..1`, left to
/// right) is sampled every frame so a trajectory graph can plot the settle.
class SpringVisualizer extends StatefulWidget {
  const SpringVisualizer({
    required this.duration,
    required this.bounce,
    this.showSpring = true,
    this.recorder,
    super.key,
  });

  final Duration duration;
  final double bounce;
  final bool showSpring;
  final ValueRecordingNotifier? recorder;

  @override
  State<SpringVisualizer> createState() => _SpringVisualizerState();
}

class _SpringVisualizerState extends State<SpringVisualizer>
    with TickerProviderStateMixin {
  static const _ball = 56.0;
  static const _targetRing = 30.0;

  late final SingleMotionController _controller;
  late final Ticker _ticker;

  // Ball + target positions as a horizontal offset from the center, in pixels.
  double _target = 0;
  double _halfExtent = 1;

  CupertinoMotion get _motion =>
      CupertinoMotion(duration: widget.duration, bounce: widget.bounce);

  @override
  void initState() {
    super.initState();
    _controller = SingleMotionController(
      motion: _motion,
      vsync: this,
      initialValue: 0,
    );
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didUpdateWidget(SpringVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration ||
        oldWidget.bounce != widget.bounce) {
      _controller.motion = _motion;
    }
  }

  void _onTick(Duration _) {
    final recorder = widget.recorder;
    if (recorder == null) return;
    final normalized = (_controller.value / _halfExtent) * 0.5 + 0.5;
    recorder.record(normalized.clamp(0.0, 1.0));
  }

  @override
  void dispose() {
    _ticker.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _aim(Offset local, double width) {
    final extent = (width - _ball) / 2;
    _halfExtent = extent <= 0 ? 1 : extent;
    _target = (local.dx - width / 2).clamp(-_halfExtent, _halfExtent);
    _controller.animateTo(_target);
  }

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _aim(d.localPosition, width),
          onHorizontalDragStart: (d) => _aim(d.localPosition, width),
          onHorizontalDragUpdate: (d) => _aim(d.localPosition, width),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  if (widget.showSpring)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: SpringPainter(
                          start: Offset(_target, 0),
                          end: Offset(_controller.value, 0),
                          color: ExampleTheme.spectrumRed,
                          coils: 12,
                          thickness: 22,
                        ),
                      ),
                    ),
                  // Target ring.
                  Transform.translate(
                    offset: Offset(_target, 0),
                    child: Container(
                      width: _targetRing,
                      height: _targetRing,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: t.textTertiary, width: 3),
                      ),
                    ),
                  ),
                  // Ball.
                  Transform.translate(
                    offset: Offset(_controller.value, 0),
                    child: Container(
                      width: _ball,
                      height: _ball,
                      decoration: BoxDecoration(
                        color: t.surfaceSolid,
                        shape: BoxShape.circle,
                        border: Border.all(color: t.borderStrong, width: 2),
                        boxShadow: t.softShadow,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

/// Paints a coil spring between [start] and [end] (offsets from the canvas
/// center), fading in as it stretches. Ported from the physical_ui talk.
class SpringPainter extends CustomPainter {
  const SpringPainter({
    required this.start,
    required this.end,
    this.thickness = 20.0,
    this.wireThickness = 3.0,
    this.coils = 8,
    this.minVisibleLength = 60.0,
    this.minFullLength = 160.0,
    this.color = const Color(0xFF888888),
  });

  final Offset start;
  final Offset end;
  final double thickness;
  final double wireThickness;
  final double minVisibleLength;
  final double minFullLength;
  final int coils;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final startPoint = center + start;
    final endPoint = center + end;

    final direction = endPoint - startPoint;
    final length = direction.distance;
    if (length == 0) return;

    final centerOpacity =
        ((length - minVisibleLength) / (minFullLength - minVisibleLength))
            .clamp(0.0, 1.0);

    final normalizedDirection = direction / length;
    final maxComponent = math.max(
      normalizedDirection.dx.abs(),
      normalizedDirection.dy.abs(),
    );
    final scaledDirection = normalizedDirection / maxComponent;

    final gradient = LinearGradient(
      begin: Alignment(-scaledDirection.dx, -scaledDirection.dy),
      end: Alignment(scaledDirection.dx, scaledDirection.dy),
      colors: [
        color.withValues(alpha: 0),
        color.withValues(alpha: centerOpacity),
        color.withValues(alpha: 0),
      ],
      stops: const [0.05, .5, .95],
    );

    final paint = Paint()
      ..shader = gradient.createShader(Rect.fromPoints(startPoint, endPoint))
      ..strokeWidth = wireThickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final perpendicular = Offset(
      -normalizedDirection.dy,
      normalizedDirection.dx,
    );

    final path = Path()..moveTo(startPoint.dx, startPoint.dy);
    const segmentsPerCoil = 16;
    final totalSegments = coils * segmentsPerCoil;
    for (var i = 0; i <= totalSegments; i++) {
      final tt = i / totalSegments;
      final alongSpring = startPoint + direction * tt;
      final angle = tt * coils * 2 * math.pi;
      final springOffset = perpendicular * (math.sin(angle) * thickness / 2);
      final point = alongSpring + springOffset;
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(SpringPainter oldDelegate) =>
      start != oldDelegate.start ||
      end != oldDelegate.end ||
      thickness != oldDelegate.thickness ||
      wireThickness != oldDelegate.wireThickness ||
      coils != oldDelegate.coils ||
      color != oldDelegate.color;
}
