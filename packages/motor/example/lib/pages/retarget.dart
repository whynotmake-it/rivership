import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/chapters.dart';
import 'package:motor_example/widgets/chapter_page.dart';
import 'package:motor_example/widgets/controls.dart';
import 'package:motor_example/widgets/style.dart';

/// Interrupting a spring keeps its velocity; interrupting a curve doesn't.
class RetargetPage extends StatefulWidget {
  const RetargetPage({super.key});

  @override
  State<RetargetPage> createState() => _RetargetPageState();
}

const _tabs = ['Day', 'Week', 'Month', 'Year'];
const _stats = ['8,204', '61,930', '248k', '3.1M'];
const _spring = CupertinoMotion(
  duration: Duration(milliseconds: 520),
  bounce: .12,
);
const _curve = CurvedMotion(Duration(milliseconds: 520), Curves.easeInOut);

class _RetargetPageState extends State<RetargetPage>
    with SingleTickerProviderStateMixin {
  late final _indicator = SingleMotionController(
    motion: _spring,
    vsync: this,
    debugLabel: 'Tab indicator',
  )..addListener(_record);

  final _clock = Stopwatch()..start();
  final _trace = <Offset>[];
  var _tab = 0;
  var _useSpring = true;

  @override
  void initState() {
    super.initState();
    _record();
  }

  @override
  void dispose() {
    _indicator.dispose();
    super.dispose();
  }

  void _record() {
    final now = _clock.elapsedMilliseconds.toDouble();
    _trace
      ..add(Offset(now, _indicator.value))
      ..removeWhere((sample) => sample.dx < now - _traceWindow);
  }

  void _select(int tab) {
    setState(() => _tab = tab);
    _record();
    _indicator.animateTo(tab.toDouble());
  }

  void _setSpring(bool spring) {
    setState(() => _useSpring = spring);
    _indicator.motion = spring ? _spring : _curve;
  }

  @override
  Widget build(BuildContext context) {
    return ChapterPage(
      chapter: chapterNamed('Retarget'),
      lead:
          'Tap the tabs quickly. The spring picks up the new target without '
          'dropping its speed, so it never stops to turn. Switch to a curve '
          'and watch the trace kink.',
      code: 'indicator.animateTo(tab); // keeps its velocity',
      stage: AnimatedBuilder(
        animation: _indicator,
        builder: (context, _) => _Stage(
          position: _indicator.value,
          velocity: _indicator.velocity,
          tab: _tab,
          trace: _trace,
          now: _clock.elapsedMilliseconds.toDouble(),
          useSpring: _useSpring,
          onSelect: _select,
          onSpring: _setSpring,
        ),
      ),
    );
  }
}

const _traceWindow = 2400.0;

class _Stage extends StatelessWidget {
  const _Stage({
    required this.position,
    required this.velocity,
    required this.tab,
    required this.trace,
    required this.now,
    required this.useSpring,
    required this.onSelect,
    required this.onSpring,
  });

  final double position;
  final double velocity;
  final int tab;
  final List<Offset> trace;
  final double now;
  final bool useSpring;
  final ValueChanged<int> onSelect;
  final ValueChanged<bool> onSpring;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final barWidth = (width - 48).clamp(0.0, 340.0);
        final tabWidth = (barWidth - 8) / _tabs.length;
        final speed = velocity * tabWidth;
        final stretch = (speed.abs() * .045).clamp(0.0, tabWidth * .6);
        return Column(
          children: [
            const SizedBox(height: 28),
            // The segmented control.
            Container(
              width: barWidth,
              height: 44,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: t.pebble,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: position * tabWidth - stretch / 2,
                    top: 0,
                    bottom: 0,
                    width: tabWidth + stretch,
                    child: Blur(
                      sigma: motionBlur(Offset(speed, 0), strength: .004),
                      child: Container(
                        decoration: BoxDecoration(
                          color: t.surfaceSolid,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: t.hairlineShadow,
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (final (index, label) in _tabs.indexed)
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapDown: (_) => onSelect(index),
                            child: Center(
                              child: Text(
                                label,
                                style: archivo(
                                  14,
                                  weight: index == tab ? 600 : 460,
                                  color: index == tab
                                      ? t.textPrimary
                                      : t.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            // The pages, driven by the same value.
            Expanded(
              child: ClipRect(
                child: Blur(
                  sigma: motionBlur(
                    Offset(velocity * width, 0),
                    strength: .0025,
                  ),
                  child: Stack(
                    children: [
                      for (final (index, stat) in _stats.indexed)
                        Positioned(
                          left: (index - position) * width,
                          width: width,
                          top: 0,
                          bottom: 0,
                          child: Opacity(
                            opacity: (1 - (index - position).abs()).clamp(
                              0.0,
                              1.0,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  stat,
                                  style: t.display.copyWith(fontSize: 64),
                                ),
                                Text(
                                  'steps this ${_tabs[index].toLowerCase()}',
                                  style: t.caption,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            // Position over time.
            SizedBox(
              height: 76,
              width: double.infinity,
              child: CustomPaint(
                painter: _TracePainter(trace: trace, now: now, guide: t.border),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'POSITION OVER TIME',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.eyebrow,
                    ),
                  ),
                  Choice(
                    options: const ['Spring', 'Curve'],
                    selected: useSpring ? 0 : 1,
                    onSelect: (index) => onSpring(index == 0),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TracePainter extends CustomPainter {
  _TracePainter({required this.trace, required this.now, required this.guide});

  final List<Offset> trace;
  final double now;
  final Color guide;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 16.0;
    final height = size.height - 8;
    double y(double value) => 4 + value / (_tabs.length - 1) * height;
    final guidePaint = Paint()..color = guide;
    for (var tab = 0; tab < _tabs.length; tab++) {
      canvas.drawRect(
        Rect.fromLTWH(inset, y(tab.toDouble()), size.width - inset * 2, 1),
        guidePaint,
      );
    }
    if (trace.isEmpty) return;
    final path = Path();
    for (final (index, sample) in trace.indexed) {
      final x =
          inset +
          (1 - (now - sample.dx) / _traceWindow) * (size.width - inset * 2);
      final point = Offset(x, y(sample.dy));
      index == 0
          ? path.moveTo(point.dx, point.dy)
          : path.lineTo(point.dx, point.dy);
    }
    final last = trace.last;
    path.lineTo(size.width - inset, y(last.dy));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..shader = ExampleTheme.spectrum.createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_TracePainter oldDelegate) => true;
}
