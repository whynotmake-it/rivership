import 'dart:math' as math;

import 'package:coil/coil.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/chapters.dart';
import 'package:motor_example/widgets/chapter_page.dart';
import 'package:motor_example/widgets/style.dart';

/// Interrupting a spring keeps its velocity; interrupting a curve doesn't.
class RetargetPage extends StatefulWidget {
  const RetargetPage({super.key});

  @override
  State<RetargetPage> createState() => _RetargetPageState();
}

const _spring = Motion.cupertino(
  duration: Duration(milliseconds: 520),
  bounce: .12,
);
const _curve = Motion.curved(Duration(milliseconds: 520), Curves.easeInOut);
const _dot = 14.0;
const _trailWindow = Duration(milliseconds: 1200);

class _Sample {
  const _Sample(this.time, this.position);

  final Duration time;
  final Offset position;
}

class _RetargetPageState extends State<RetargetPage>
    with TickerProviderStateMixin {
  late final _springDot = MotionController<Offset>(
    motion: _spring,
    converter: .offset,
    vsync: this,
    initialValue: Offset.zero,
    debugLabel: 'Spring dot',
  );
  late final _curveDot = MotionController<Offset>(
    motion: _curve,
    converter: .offset,
    vsync: this,
    initialValue: Offset.zero,
    debugLabel: 'Curve dot',
  );

  late final Ticker _ticker = createTicker(_tick);
  final _springTrail = <_Sample>[];
  final _curveTrail = <_Sample>[];
  final _frame = ValueNotifier(0);
  final _speeds = ValueNotifier((spring: 0, curve: 0));
  final _code = ValueNotifier(
    '// Click the stage, then click again before the dots arrive.\n'
    'spring.animateTo(target);\n'
    'curve.animateTo(target);',
  );

  Size? _size;
  Offset? _target;
  var _now = Duration.zero;
  var _placed = false;

  @override
  void dispose() {
    _ticker.dispose();
    _springDot.dispose();
    _curveDot.dispose();
    _frame.dispose();
    _speeds.dispose();
    _code.dispose();
    super.dispose();
  }

  Offset _clamp(Offset point, Size size) => Offset(
    point.dx.clamp(_dot / 2, math.max(_dot / 2, size.width - _dot / 2)),
    point.dy.clamp(_dot / 2, math.max(_dot / 2, size.height - _dot / 2)),
  );

  /// Places the dots when the stage first has a size, and keeps them inside
  /// it when it changes.
  void _layout(Size size) {
    final previous = _size;
    if (previous == size) return;
    _size = size;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (previous == null) {
        _springDot.value = size.center(Offset.zero);
        _curveDot.value = size.center(Offset.zero);
        _record();
        setState(() => _placed = true);
        return;
      }
      final target = _target;
      if (target != null) _target = _clamp(target, size);
      for (final dot in [_springDot, _curveDot]) {
        final moving = dot.isAnimating;
        dot.value = _clamp(dot.value, size);
        if (moving && _target != null) dot.animateTo(_target!);
      }
      setState(() {});
    });
  }

  void _tap(Offset point) {
    final size = _size;
    if (size == null) return;
    final target = _clamp(point, size);
    final speed = _springDot.isAnimating ? _springDot.velocity.distance : 0.0;
    final moving = speed > 1;
    final at = 'Offset(${target.dx.round()}, ${target.dy.round()})';
    _code.value = moving
        ? '// Moving at ${speed.round()} px/s. The spring keeps that speed;\n'
              '// the curve starts again from rest.\n'
              'spring.animateTo($at);\n'
              'curve.animateTo($at);'
        : 'spring.animateTo($at);\n'
              'curve.animateTo($at);';
    setState(() => _target = target);
    _springDot.animateTo(target);
    _curveDot.animateTo(target);
    if (!_ticker.isActive) _ticker.start();
  }

  void _record() {
    _springTrail.add(_Sample(_now, _springDot.value));
    _curveTrail.add(_Sample(_now, _curveDot.value));
  }

  void _tick(Duration elapsed) {
    _now = elapsed;
    _record();
    for (final trail in [_springTrail, _curveTrail]) {
      trail.removeWhere((sample) => _now - sample.time > _trailWindow);
    }
    _speeds.value = (
      spring: _springDot.isAnimating ? _springDot.velocity.distance.round() : 0,
      curve: _curveDot.isAnimating ? _curveDot.velocity.distance.round() : 0,
    );
    _frame.value++;
    final moving = _springDot.isAnimating || _curveDot.isAnimating;
    // Nothing is moving and the trails have faded: stop asking for frames.
    if (!moving && _springTrail.length <= 1 && _curveTrail.length <= 1) {
      _ticker.stop();
      _springTrail.clear();
      _curveTrail.clear();
      _frame.value++;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final readout = mono(
      11,
      color: colors.mutedForeground,
    ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    return ChapterPage(
      chapter: chapterNamed('Retarget'),
      lead:
          'Click anywhere on the stage, then click somewhere else before the '
          'dots arrive. Both start from where they are, so nothing jumps. The '
          'spring keeps its speed and bends toward the new target; the curve '
          'starts its easing again, which shows as a corner in its trail.',
      code: _code,
      stageHeight: 400,
      stage: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          _layout(size);
          final ready = _placed;
          return GestureDetector(
            key: const ValueKey('retarget stage'),
            behavior: .opaque,
            onTapDown: (details) => _tap(details.localPosition),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _TrailPainter(
                      repaint: _frame,
                      now: () => _now,
                      springTrail: _springTrail,
                      curveTrail: _curveTrail,
                      springColor: colors.brand,
                      curveColor: colors.mutedForeground,
                    ),
                  ),
                ),
                if (_target case final target?)
                  Positioned(
                    left: target.dx - 5,
                    top: target.dy - 5,
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        shape: CircleBorder(
                          side: BorderSide(
                            color: colors.foreground.withValues(alpha: .4),
                            width: 1.5,
                          ),
                        ),
                      ),
                      child: const SizedBox.square(dimension: 10),
                    ),
                  ),
                if (ready) ...[
                  _DotAt(
                    key: const ValueKey('curve dot'),
                    controller: _curveDot,
                    color: colors.mutedForeground,
                  ),
                  _DotAt(
                    key: const ValueKey('spring dot'),
                    controller: _springDot,
                    color: colors.brand,
                  ),
                ],
                PositionedDirectional(
                  start: 16,
                  top: 16,
                  child: Row(
                    mainAxisSize: .min,
                    children: [
                      _LegendEntry(color: colors.brand, label: 'Spring'),
                      const SizedBox(width: 16),
                      _LegendEntry(
                        color: colors.mutedForeground,
                        label: 'Curve',
                      ),
                    ],
                  ),
                ),
                PositionedDirectional(
                  start: 16,
                  bottom: 16,
                  child: ValueListenableBuilder(
                    valueListenable: _speeds,
                    builder: (context, speeds, _) => Row(
                      mainAxisSize: .min,
                      children: [
                        SizedBox(
                          width: 128,
                          child: Text(
                            'Spring ${speeds.spring} px/s',
                            style: readout,
                          ),
                        ),
                        SizedBox(
                          width: 128,
                          child: Text(
                            'Curve ${speeds.curve} px/s',
                            style: readout,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DotAt extends StatelessWidget {
  const _DotAt({required this.controller, required this.color, super.key});

  final MotionController<Offset> controller;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) => Positioned(
        left: controller.value.dx - _dot / 2,
        top: controller.value.dy - _dot / 2,
        child: child!,
      ),
      child: DecoratedBox(
        decoration: ShapeDecoration(shape: const CircleBorder(), color: color),
        child: const SizedBox.square(dimension: _dot),
      ),
    );
  }
}

class _LegendEntry extends StatelessWidget {
  const _LegendEntry({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    return Row(
      mainAxisSize: .min,
      children: [
        DecoratedBox(
          decoration: ShapeDecoration(
            shape: const CircleBorder(),
            color: color,
          ),
          child: const SizedBox.square(dimension: 8),
        ),
        const SizedBox(width: 6),
        Text(label, style: text.muted.caption),
      ],
    );
  }
}

/// Draws each dot's last stretch of positions as a line that fades toward
/// its tail.
class _TrailPainter extends CustomPainter {
  _TrailPainter({
    required Listenable repaint,
    required this.now,
    required this.springTrail,
    required this.curveTrail,
    required this.springColor,
    required this.curveColor,
  }) : super(repaint: repaint);

  final Duration Function() now;
  final List<_Sample> springTrail;
  final List<_Sample> curveTrail;
  final Color springColor;
  final Color curveColor;

  @override
  void paint(Canvas canvas, Size size) {
    _paintTrail(canvas, curveTrail, curveColor);
    _paintTrail(canvas, springTrail, springColor);
  }

  void _paintTrail(Canvas canvas, List<_Sample> trail, Color color) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final now = this.now();
    for (var i = 1; i < trail.length; i++) {
      final age = now - trail[i].time;
      final fade = 1 - age.inMicroseconds / _trailWindow.inMicroseconds;
      if (fade <= 0) continue;
      paint.color = color.withValues(alpha: fade.clamp(0.0, 1.0) * .8);
      canvas.drawLine(trail[i - 1].position, trail[i].position, paint);
    }
  }

  @override
  bool shouldRepaint(_TrailPainter oldDelegate) =>
      oldDelegate.springColor != springColor ||
      oldDelegate.curveColor != curveColor;
}
