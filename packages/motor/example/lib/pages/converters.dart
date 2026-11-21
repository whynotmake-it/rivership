import 'dart:math' as math;

import 'package:coil/coil.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/chapters.dart';
import 'package:motor_example/widgets/chapter_page.dart';
import 'package:motor_example/widgets/style.dart';

/// A converter splits a value into numbers and springs each one on its own:
/// an offset, a color and an angle.
class ConvertersPage extends StatefulWidget {
  const ConvertersPage({super.key});

  @override
  State<ConvertersPage> createState() => _ConvertersPageState();
}

enum _Kind { offset, color, angle }

const _offsetCode =
    '// Released at your finger\'s speed; x and y spring on their own.\n'
    'square.animateTo(center, withVelocity: fling);\n'
    '// converter: .offset';

const _colorCode =
    'MotionBuilder(\n'
    '  // Channels are bounded to 0..1, so the color stays valid\n'
    '  // while the spring overshoots.\n'
    '  converter: .colorRgb,\n'
    '  motion: .bouncySpring(),\n'
    '  value: picked,\n'
    '  builder: …,\n'
    ')';

class _ConvertersPageState extends State<ConvertersPage> {
  final _code = ValueNotifier(_offsetCode);
  var _kind = _Kind.offset;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _select(_Kind kind) {
    setState(() => _kind = kind);
    _code.value = switch (kind) {
      _Kind.offset => _offsetCode,
      _Kind.color => _colorCode,
      _Kind.angle => _angleCode(shortWay: true, degrees: null),
    };
  }

  @override
  Widget build(BuildContext context) {
    return ChapterPage(
      chapter: chapterNamed('Converters'),
      lead:
          'A converter splits a value into numbers, and each number gets its '
          'own spring. Fling the square: x and y settle on their own, so the '
          'path curves.',
      stageHeight: 400,
      code: _code,
      stage: Stack(
        fit: StackFit.expand,
        children: [
          switch (_kind) {
            _Kind.offset => _OffsetDemo(onCode: (code) => _code.value = code),
            _Kind.color => _ColorDemo(),
            _Kind.angle => _AngleDemo(onCode: (code) => _code.value = code),
          },
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: CoilTabs<_Kind>(
                value: _kind,
                onChanged: _select,
                tabs: const [
                  CoilTab(value: _Kind.offset, label: Text('Offset')),
                  CoilTab(value: _Kind.color, label: Text('Color')),
                  CoilTab(value: _Kind.angle, label: Text('Angle')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

TextStyle _readout(CoilColors colors) => mono(
  11,
  color: colors.mutedForeground,
).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

// ---------------------------------------------------------------------------
// Offset
// ---------------------------------------------------------------------------

const _square = 56.0;
const _trailWindow = Duration(seconds: 1);

class _TrailSample {
  const _TrailSample(this.time, this.position);

  final Duration time;
  final Offset position;
}

class _OffsetDemo extends StatefulWidget {
  const _OffsetDemo({required this.onCode});

  final ValueChanged<String> onCode;

  @override
  State<_OffsetDemo> createState() => _OffsetDemoState();
}

class _OffsetDemoState extends State<_OffsetDemo>
    with TickerProviderStateMixin {
  late final _controller = MotionController<Offset>(
    motion: .bouncySpring(),
    converter: .offset,
    vsync: this,
    initialValue: Offset.zero,
    debugLabel: 'Offset square',
  );
  late final Ticker _ticker = createTicker(_tick);
  final _trail = <_TrailSample>[];
  final _frame = ValueNotifier(0);

  Size? _size;
  var _placed = false;
  var _dragging = false;
  var _now = Duration.zero;

  @override
  void dispose() {
    _ticker.dispose();
    _controller.dispose();
    _frame.dispose();
    super.dispose();
  }

  Offset _clamp(Offset point, Size size) => Offset(
    point.dx.clamp(
      _square / 2,
      math.max(_square / 2, size.width - _square / 2),
    ),
    point.dy.clamp(
      _square / 2,
      math.max(_square / 2, size.height - _square / 2),
    ),
  );

  void _layout(Size size) {
    final previous = _size;
    if (previous == size) return;
    _size = size;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (previous == null) {
        _controller.value = size.center(Offset.zero);
        setState(() => _placed = true);
        return;
      }
      if (_controller.isAnimating) {
        _controller.animateTo(size.center(Offset.zero));
      } else {
        _controller.value = _clamp(_controller.value, size);
      }
      setState(() {});
    });
  }

  void _start() {
    if (!_ticker.isActive) _ticker.start();
  }

  void _tick(Duration elapsed) {
    _now = elapsed;
    _trail
      ..add(_TrailSample(_now, _controller.value))
      ..removeWhere((sample) => _now - sample.time > _trailWindow);
    _frame.value++;
    if (!_dragging && !_controller.isAnimating && _trail.length <= 1) {
      _trail.clear();
      _ticker.stop();
    }
  }

  void _dragStart(DragStartDetails details) {
    _dragging = true;
    _controller.stop();
    _start();
  }

  void _dragUpdate(DragUpdateDetails details) {
    final size = _size;
    if (size == null) return;
    _controller.value = _clamp(_controller.value + details.delta, size);
  }

  void _dragEnd(DragEndDetails details) {
    final size = _size;
    if (size == null) return;
    _dragging = false;
    final fling = details.velocity.pixelsPerSecond;
    final center = size.center(Offset.zero);
    _controller.animateTo(center, withVelocity: fling);
    final speed = fling.distance.round();
    widget.onCode(
      '// Released at $speed px/s; x and y spring on their own.\n'
      'square.animateTo(\n'
      '  Offset(${center.dx.round()}, ${center.dy.round()}),\n'
      '  withVelocity: Offset(${fling.dx.round()}, ${fling.dy.round()}),\n'
      ');\n'
      '// converter: .offset',
    );
    _start();
  }

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final radius = BorderRadius.circular(CoilTheme.radiiOf(context).item);
    return LayoutBuilder(
      builder: (context, constraints) {
        _layout(constraints.biggest);
        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _TrailPainter(
                    trail: _trail,
                    now: () => _now,
                    color: colors.brand,
                    repaint: _frame,
                  ),
                ),
              ),
            ),
            if (_placed)
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final position = _controller.value;
                  return Positioned(
                    left: position.dx - _square / 2,
                    top: position.dy - _square / 2,
                    child: child!,
                  );
                },
                child: GestureDetector(
                  onPanStart: _dragStart,
                  onPanUpdate: _dragUpdate,
                  onPanEnd: _dragEnd,
                  onPanCancel: () => _dragging = false,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        color: colors.foreground,
                        shape: RoundedSuperellipseBorder(borderRadius: radius),
                      ),
                      child: const SizedBox.square(dimension: _square),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TrailPainter extends CustomPainter {
  _TrailPainter({
    required this.trail,
    required this.now,
    required this.color,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final List<_TrailSample> trail;
  final Duration Function() now;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final current = now();
    for (var i = 1; i < trail.length; i++) {
      final age =
          (current - trail[i].time).inMicroseconds /
          _trailWindow.inMicroseconds;
      final fade = (1 - age).clamp(0.0, 1.0);
      paint.color = color.withValues(alpha: color.a * fade);
      canvas.drawLine(trail[i - 1].position, trail[i].position, paint);
    }
  }

  @override
  bool shouldRepaint(_TrailPainter oldDelegate) => oldDelegate.color != color;
}

// ---------------------------------------------------------------------------
// Color
// ---------------------------------------------------------------------------

class _ColorDemo extends StatefulWidget {
  @override
  State<_ColorDemo> createState() => _ColorDemoState();
}

class _ColorDemoState extends State<_ColorDemo> {
  var _picked = 0;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final radius = BorderRadius.circular(CoilTheme.radiiOf(context).container);
    final swatches = [
      ('Foreground', colors.foreground),
      ('Brand', colors.brand),
      ('Success', colors.success),
      ('Warning', colors.warning),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 64, bottom: 16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MotionBuilder<Color>(
              converter: .colorRgb,
              motion: .bouncySpring(),
              value: swatches[_picked].$2,
              debugLabel: 'Color tile',
              builder: (context, color, _) => DecoratedBox(
                decoration: ShapeDecoration(
                  color: color,
                  shape: RoundedSuperellipseBorder(borderRadius: radius),
                ),
                child: const SizedBox.square(dimension: 120),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (i, (label, color)) in swatches.indexed)
                  _Swatch(
                    label: label,
                    color: color,
                    selected: i == _picked,
                    onPressed: () => setState(() => _picked = i),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.label,
    required this.color,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: SizedBox.square(
            dimension: 40,
            child: Center(
              // A ring in the foreground marks the picked swatch.
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  shape: CircleBorder(
                    side: BorderSide(
                      color: selected ? colors.foreground : colors.border,
                      width: selected ? 2 : 1,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      shape: const CircleBorder(),
                      color: color,
                    ),
                    child: const SizedBox.square(dimension: 24),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Angle
// ---------------------------------------------------------------------------

const _dial = 160.0;

String _angleCode({required bool shortWay, required int? degrees}) {
  final converter = shortWay ? 'angle' : 'single';
  return '// Cross 0° / 360°: .angle takes the short way, .single spins\n'
      '// the long way round.\n'
      'final needle = MotionController<double>(\n'
      '  converter: MotionConverter.$converter,\n'
      '  motion: .bouncySpring(),\n'
      '  …,\n'
      ');\n'
      'needle.animateTo(${degrees == null ? 'target' : '$degrees * pi / 180'});';
}

class _AngleDemo extends StatefulWidget {
  const _AngleDemo({required this.onCode});

  final ValueChanged<String> onCode;

  @override
  State<_AngleDemo> createState() => _AngleDemoState();
}

class _AngleDemoState extends State<_AngleDemo> with TickerProviderStateMixin {
  late MotionController<double> _controller = _create(MotionConverter.angle, 0);
  var _shortWay = true;
  double? _target;

  MotionController<double> _create(
    MotionConverter<double> converter,
    double initial,
  ) => MotionController<double>(
    motion: .bouncySpring(),
    converter: converter,
    vsync: this,
    initialValue: initial,
    debugLabel: 'Angle needle',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Angle in radians clockwise from the top, in `[0, 2π)`.
  double _angleAt(Offset local) {
    const center = Offset(_dial / 2, _dial / 2);
    final delta = local - center;
    final angle = math.atan2(delta.dx, -delta.dy);
    return angle < 0 ? angle + 2 * math.pi : angle;
  }

  void _aim(Offset local) {
    final target = _angleAt(local);
    setState(() => _target = target);
    _controller.animateTo(target);
    widget.onCode(
      _angleCode(
        shortWay: _shortWay,
        degrees: (target * 180 / math.pi).round() % 360,
      ),
    );
  }

  void _setShortWay(bool shortWay) {
    final current = _controller.value;
    final target = _target;
    final old = _controller;
    // The converter is fixed per controller, so the new one starts where the
    // needle is.
    _controller = _create(
      shortWay ? MotionConverter.angle : MotionConverter.single,
      current,
    );
    setState(() => _shortWay = shortWay);
    if (target != null) _controller.animateTo(target);
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    widget.onCode(
      _angleCode(
        shortWay: shortWay,
        degrees: target == null ? null : (target * 180 / math.pi).round() % 360,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final gap = CoilTheme.metricsOf(context).gap;
    final target = _target;
    return Padding(
      padding: const EdgeInsets.only(top: 64, bottom: 16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTapDown: (details) => _aim(details.localPosition),
              onPanStart: (details) => _aim(details.localPosition),
              onPanUpdate: (details) => _aim(details.localPosition),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: ListenableBuilder(
                  listenable: _controller,
                  builder: (context, _) => CustomPaint(
                    size: const Size.square(_dial),
                    painter: _DialPainter(
                      angle: _controller.value,
                      target: target,
                      line: colors.border,
                      needle: colors.foreground,
                      marker: colors.brand,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: gap * 2,
              runSpacing: gap,
              children: [
                SizedBox(
                  width: 96,
                  child: Text(
                    target == null
                        ? 'target –'
                        : 'target ${(target * 180 / math.pi).round() % 360}°',
                    style: _readout(colors),
                  ),
                ),
                CoilSwitch(
                  value: _shortWay,
                  onChanged: _setShortWay,
                  label: const Text('Short way round'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  const _DialPainter({
    required this.angle,
    required this.target,
    required this.line,
    required this.needle,
    required this.marker,
  });

  /// The needle, in radians clockwise from the top.
  final double angle;
  final double? target;
  final Color line;
  final Color needle;
  final Color marker;

  Offset _at(Offset center, double radius, double radians) =>
      center + Offset(math.sin(radians), -math.cos(radians)) * radius;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 1;
    final hairline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = line;
    canvas.drawCircle(center, radius, hairline);
    for (var i = 0; i < 12; i++) {
      final radians = i * math.pi / 6;
      canvas.drawLine(
        _at(center, radius - (i % 3 == 0 ? 10 : 6), radians),
        _at(center, radius, radians),
        hairline,
      );
    }
    final target = this.target;
    if (target != null) {
      canvas.drawCircle(
        _at(center, radius - 18, target),
        4,
        Paint()..color = marker,
      );
    }
    canvas.drawLine(
      center,
      _at(center, radius - 24, angle),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = needle,
    );
    canvas.drawCircle(center, 4, Paint()..color = needle);
  }

  @override
  bool shouldRepaint(_DialPainter oldDelegate) =>
      oldDelegate.angle != angle ||
      oldDelegate.target != target ||
      oldDelegate.line != line ||
      oldDelegate.needle != needle ||
      oldDelegate.marker != marker;
}
