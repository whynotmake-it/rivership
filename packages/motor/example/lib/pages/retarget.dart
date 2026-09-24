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
const Motion _spring = .cupertino(
  duration: Duration(milliseconds: 520),
  bounce: .12,
);
const Motion _curve = .curved(Duration(milliseconds: 520), Curves.easeInOut);

class _RetargetPageState extends State<RetargetPage>
    with SingleTickerProviderStateMixin {
  late final _indicator = SingleMotionController(
    motion: _spring,
    vsync: this,
    debugLabel: 'Tab indicator',
  )..addListener(_record);

  final _clock = Stopwatch()..start();
  final _trace = <Offset>[];
  final _code = ValueNotifier(
    '// Tap the tabs quickly.\nindicator.animateTo(1);',
  );
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
    _code.dispose();
    super.dispose();
  }

  void _record() {
    final now = _clock.elapsedMilliseconds.toDouble();
    _trace.add(Offset(now, _indicator.value));
    // Keep one sample before the window so the line reaches its left edge.
    while (_trace.length > 1 && _trace[1].dx < now - _traceWindow) {
      _trace.removeAt(0);
    }
  }

  void _select(int tab) {
    setState(() => _tab = tab);
    _record();
    final speed = _indicator.velocity.abs();
    _code.value = speed < .05
        ? '// At rest.\nindicator.animateTo($tab);'
        : _useSpring
        ? '// Moving at ${speed.toStringAsFixed(1)} tabs/s. The spring keeps '
              'that speed.\nindicator.animateTo($tab);'
        : '// Moving at ${speed.toStringAsFixed(1)} tabs/s. The curve starts '
              'again from 0.\nindicator.animateTo($tab);';
    _indicator.animateTo(tab.toDouble());
  }

  void _setSpring(bool spring) {
    setState(() => _useSpring = spring);
    _code.value = spring
        ? 'indicator.motion = .cupertino(bounce: .12);'
        : 'indicator.motion = .curved(Duration(milliseconds: 520), Curves.easeInOut);';
    _indicator.motion = spring ? _spring : _curve;
  }

  @override
  Widget build(BuildContext context) {
    return ChapterPage(
      chapter: chapterNamed('Retarget'),
      lead:
          'Tap the tabs quickly, before the indicator settles. A spring that '
          'gets a new target keeps its current speed and bends toward it. '
          'Switch to a curve and it stops and starts again at every tap, which '
          'shows up as corners in the trace.',
      code: _code,
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

const _traceWindow = 1800.0;

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
    final p = Palette.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final barWidth = (width - 48).clamp(0.0, 340.0);
        final tabWidth = ((barWidth - 8) / _tabs.length).clamp(
          0.0,
          double.infinity,
        );
        final speed = velocity * tabWidth;
        final stretch = (speed.abs() * .045).clamp(0.0, tabWidth * .6);
        return Column(
          children: [
            const SizedBox(height: 28),
            // The segmented control.
            Container(
              width: barWidth,
              height: 40,
              padding: const .all(3),
              decoration: BoxDecoration(
                color: p.control,
                borderRadius: .circular(radius),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: position * tabWidth - stretch / 2,
                    top: 0,
                    bottom: 0,
                    width: tabWidth + stretch,
                    child: Blur(
                      sigma: motionBlur(Offset(speed, 0)),
                      child: Container(
                        decoration: BoxDecoration(
                          color: p.surface,
                          borderRadius: .circular(radius),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (final (index, label) in _tabs.indexed)
                        Expanded(
                          child: GestureDetector(
                            behavior: .opaque,
                            onTapDown: (_) => onSelect(index),
                            child: Center(
                              child: Text(
                                label.toUpperCase(),
                                style: mono(
                                  11.5,
                                  weight: 500,
                                  spacing: .5,
                                  color: index == tab ? p.text : p.textTertiary,
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
                            mainAxisAlignment: .center,
                            children: [
                              Text(
                                stat,
                                style: p.display.copyWith(fontSize: 60),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'steps this ${_tabs[index].toLowerCase()}',
                                style: p.caption,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Position over time.
            SizedBox(
              height: 110,
              width: double.infinity,
              child: CustomPaint(
                painter: _TracePainter(
                  trace: trace,
                  now: now,
                  guide: p.border,
                  line: p.accent,
                ),
              ),
            ),
            Padding(
              padding: const .fromLTRB(16, 10, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Position over time',
                      maxLines: 1,
                      overflow: .ellipsis,
                      style: p.caption,
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
  _TracePainter({
    required this.trace,
    required this.now,
    required this.guide,
    required this.line,
  });

  final List<Offset> trace;
  final double now;
  final Color guide;
  final Color line;

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
    canvas.clipRect(Rect.fromLTRB(inset, 0, size.width - inset, size.height));
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
        ..style = .stroke
        ..strokeWidth = 2
        ..strokeJoin = .round
        ..strokeCap = .round
        ..color = line,
    );
  }

  @override
  bool shouldRepaint(_TracePainter oldDelegate) => true;
}
