import 'dart:math' as math;

import 'package:coil/coil.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/chapters.dart';
import 'package:motor_example/widgets/chapter_page.dart';
import 'package:motor_example/widgets/icons.dart';
import 'package:motor_example/widgets/style.dart';

/// A spring or a curve, with its response drawn next to a dot you can fling.
class SpringLabPage extends StatefulWidget {
  const SpringLabPage({super.key});

  @override
  State<SpringLabPage> createState() => _SpringLabPageState();
}

enum _Kind { spring, curve }

/// The dot's radius, and so how far the track is inset from its edges.
const _dotRadius = 12.0;

/// The ranges the sliders cover, in steps of 50 ms and 0.05.
const _durationRange = (min: 100.0, max: 1500.0, divisions: 28);
const _bounceRange = (min: -0.5, max: 0.9, divisions: 28);

const _curves = <Curve, (String, String)>{
  Curves.easeInOut: ('Ease in out', 'Curves.easeInOut'),
  Curves.easeOut: ('Ease out', 'Curves.easeOut'),
  Curves.linear: ('Linear', 'Curves.linear'),
};

class _SpringLabPageState extends State<SpringLabPage>
    with TickerProviderStateMixin {
  var _kind = _Kind.spring;
  var _durationMs = 500.0;
  var _bounce = 0.2;
  Curve _curve = Curves.easeInOut;

  late Motion _motion = _buildMotion();
  late _Response _response = _Response.of(_motion);

  late final _dot = SingleMotionController(
    motion: _motion,
    vsync: this,
    debugLabel: 'Spring lab dot',
  );
  final _focus = FocusNode(debugLabel: 'Spring lab track');

  /// Whether the dot's last move was a replay, which the chart follows.
  var _replaying = false;

  /// How far the dot's center is from the pointer while dragging, so the dot
  /// doesn't jump under it.
  var _grab = 0.0;

  /// The call the code shows after the motion: what the last move did.
  var _lastCall = 'dot.animateTo(1, withVelocity: fling);';
  late final _code = ValueNotifier(_snippet());

  @override
  void dispose() {
    _dot.dispose();
    _focus.dispose();
    _code.dispose();
    super.dispose();
  }

  Motion _buildMotion() {
    final duration = Duration(milliseconds: _durationMs.round());
    return switch (_kind) {
      _Kind.spring => Motion.cupertino(duration: duration, bounce: _bounce),
      _Kind.curve => Motion.curved(duration, _curve),
    };
  }

  String _snippet() {
    final ms = _durationMs.round();
    final motion = switch (_kind) {
      _Kind.spring =>
        'final motion = Motion.cupertino(\n'
            '  duration: Duration(milliseconds: $ms),\n'
            '  bounce: ${_plain(_bounce)},\n'
            ');',
      _Kind.curve =>
        'final motion = Motion.curved(\n'
            '  Duration(milliseconds: $ms),\n'
            '  ${_curves[_curve]!.$2},\n'
            ');',
    };
    return '$motion\n$_lastCall';
  }

  /// Rebuilds the motion after a control changed. A move in flight carries
  /// on with the new motion from where it is.
  void _changed(VoidCallback change) {
    setState(() {
      change();
      _motion = _buildMotion();
      _response = _Response.of(_motion);
      _replaying = false;
      _dot.motion = _motion;
      _code.value = _snippet();
    });
  }

  void _send(double target, {double? velocity}) {
    _replaying = false;
    final text = _plain(target);
    final fling = velocity == null || _kind == _Kind.curve
        ? ''
        : ', withVelocity: ${velocity.toStringAsFixed(1)}';
    _lastCall = _kind == _Kind.curve
        ? 'dot.animateTo($text);\n// A curve starts from rest, whatever the fling.'
        : 'dot.animateTo($text$fling);';
    _code.value = _snippet();
    _dot.animateTo(target, withVelocity: velocity);
  }

  void _replay() {
    // Always the same move the chart draws: from rest at 0 to 1.
    _dot.value = 0;
    setState(() => _replaying = true);
    _lastCall = 'dot.animateTo(1, withVelocity: 0);';
    _code.value = _snippet();
    _dot.animateTo(1, withVelocity: 0);
  }

  double _fraction(double x, double width) =>
      ((x - _dotRadius) / (width - 2 * _dotRadius)).clamp(0.0, 1.0);

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _send(0);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _send(1);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final gap = CoilTheme.metricsOf(context).gap;
    // Under 900 the stage can be under 600 wide, where the controls stack.
    final stacked = MediaQuery.sizeOf(context).width < 900;
    return ChapterPage(
      chapter: chapterNamed('Spring lab'),
      lead:
          'Drag the dot and let go, or tap the track to send it. Change the '
          'duration and bounce and watch the curve: a spring ends on time and '
          'settles a little later.',
      code: _code,
      stageHeight: stacked ? 620 : 520,
      stage: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 600;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: .stretch,
              children: [
                Expanded(child: _chart(context)),
                const SizedBox(height: 16),
                _track(context),
                const SizedBox(height: 8),
                _replayRow(context, gap),
                const SizedBox(height: 16),
                _controls(context, gap, wide: wide),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _chart(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final scaler = MediaQuery.textScalerOf(context);
    return RepaintBoundary(
      child: CustomPaint(
        painter: _ChartPainter(
          repaint: _dot,
          response: _response,
          playhead: () =>
              _replaying && _dot.isAnimating ? _dot.lastElapsedDuration : null,
          textScaler: scaler,
          hairline: colors.border,
          curve: colors.brand,
          marker: colors.mutedForeground.withValues(alpha: .6),
          playheadColor: colors.foreground,
          labelStyle: _readoutStyle(colors),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }

  Widget _track(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    return Focus(
      focusNode: _focus,
      onKeyEvent: _key,
      child: Semantics(
        label: 'Dot position',
        slider: true,
        onIncrease: () => _send(1),
        onDecrease: () => _send(0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            double dotX() => _dotRadius + _dot.value * (width - 2 * _dotRadius);
            return GestureDetector(
              behavior: .opaque,
              dragStartBehavior: .down,
              onTapUp: (details) {
                _focus.requestFocus();
                _send(_fraction(details.localPosition.dx, width));
              },
              onHorizontalDragDown: (details) {
                _focus.requestFocus();
                _replaying = false;
                final offset = dotX() - details.localPosition.dx;
                _grab = offset.abs() <= _dotRadius + 8 ? offset : 0;
              },
              onHorizontalDragUpdate: (details) {
                _dot.value = _fraction(details.localPosition.dx + _grab, width);
              },
              onHorizontalDragEnd: (details) {
                final fling =
                    details.velocity.pixelsPerSecond.dx /
                    (width - 2 * _dotRadius);
                _send(_dot.value >= .5 ? 1 : 0, velocity: fling);
              },
              onHorizontalDragCancel: () {
                if (!_dot.isAnimating) _send(_dot.value >= .5 ? 1 : 0);
              },
              child: SizedBox(
                height: 48,
                child: CustomPaint(
                  painter: _TrackPainter(
                    line: colors.border,
                    inset: _dotRadius,
                  ),
                  child: AnimatedBuilder(
                    animation: _dot,
                    builder: (context, _) => Stack(
                      clipBehavior: .none,
                      children: [
                        Positioned(
                          left: dotX() - _dotRadius,
                          top: 24 - _dotRadius,
                          child: DecoratedBox(
                            decoration: ShapeDecoration(
                              shape: const CircleBorder(),
                              color: colors.foreground,
                            ),
                            child: const SizedBox.square(
                              dimension: 2 * _dotRadius,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _replayRow(BuildContext context, double gap) {
    final colors = CoilTheme.of(context).colors;
    final style = _readoutStyle(colors);
    return Wrap(
      spacing: 16,
      runSpacing: gap,
      crossAxisAlignment: .center,
      children: [
        CoilButton(
          onPressed: _replay,
          variant: .secondary,
          size: .compact,
          leading: const GlyphIcon(Glyph.rotateCcw),
          child: const Text('Replay'),
        ),
        AnimatedBuilder(
          animation: _dot,
          builder: (context, _) => _Readout(
            chars: 12,
            style: style,
            text: 'value ${_signed(_dot.value, 2)}',
          ),
        ),
        AnimatedBuilder(
          animation: _dot,
          builder: (context, _) => _Readout(
            chars: 18,
            style: style,
            text: 'velocity ${_signed(_dot.velocity, 1)}/s',
          ),
        ),
      ],
    );
  }

  Widget _controls(BuildContext context, double gap, {required bool wide}) {
    final spring = _kind == _Kind.spring;
    final presets = <(String, CupertinoMotion)>[
      ('Smooth', const CupertinoMotion.smooth()),
      ('Snappy', const CupertinoMotion.snappy()),
      ('Bouncy', const CupertinoMotion.bouncy()),
    ];
    final duration = CoilSlider(
      value: _durationMs,
      min: _durationRange.min,
      max: _durationRange.max,
      divisions: _durationRange.divisions,
      onChanged: (value) => _changed(() => _durationMs = value),
      label: const Text('Duration'),
      valueBuilder: (context, value) => Text('${value.round()} ms'),
      semanticFormatter: (value) => '${value.round()} milliseconds',
    );
    final second = spring
        ? CoilSlider(
            value: _bounce,
            min: _bounceRange.min,
            max: _bounceRange.max,
            divisions: _bounceRange.divisions,
            onChanged: (value) =>
                _changed(() => _bounce = (value * 20).round() / 20),
            label: const Text('Bounce'),
            valueBuilder: (context, value) => Text(_plain(value)),
          )
        : Align(
            alignment: AlignmentDirectional.centerStart,
            child: CoilTabs<Curve>(
              value: _curve,
              onChanged: (curve) => _changed(() => _curve = curve),
              tabs: [
                for (final MapEntry(key: curve, value: (label, _))
                    in _curves.entries)
                  CoilTab(value: curve, label: Text(label)),
              ],
            ),
          );
    return LayoutBuilder(
      builder: (context, constraints) {
        final half = (constraints.maxWidth - gap) / 2;
        return Column(
          crossAxisAlignment: .stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: gap,
              children: [
                CoilTabs<_Kind>(
                  value: _kind,
                  onChanged: (kind) => _changed(() => _kind = kind),
                  tabs: const [
                    CoilTab(value: _Kind.spring, label: Text('Spring')),
                    CoilTab(value: _Kind.curve, label: Text('Curve')),
                  ],
                ),
                if (spring)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Presets',
                        style: CoilTheme.textOf(context).muted.caption,
                      ),
                      const SizedBox(width: 8),
                      for (final (label, preset) in presets)
                        CoilButton(
                          onPressed: () => _changed(() {
                            _durationMs = preset.duration.inMilliseconds
                                .toDouble();
                            _bounce = preset.bounce;
                          }),
                          variant: .ghost,
                          size: .compact,
                          child: Text(label),
                        ),
                    ],
                  ),
              ],
            ),
            SizedBox(height: gap),
            Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                SizedBox(
                  width: wide ? half : constraints.maxWidth,
                  child: duration,
                ),
                SizedBox(
                  width: wide ? half : constraints.maxWidth,
                  child: second,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// A fixed-width line of live numbers, so the row doesn't jitter.
class _Readout extends StatelessWidget {
  const _Readout({
    required this.chars,
    required this.style,
    required this.text,
  });

  /// How many characters of [style] fit.
  final int chars;
  final TextStyle style;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return SizedBox(
      // JetBrains Mono's advance is 0.6 em.
      width: scaler.scale(style.fontSize! * .6 * chars),
      child: Text(text, style: style, maxLines: 1, softWrap: false),
    );
  }
}

TextStyle _readoutStyle(CoilColors colors) => mono(
  11,
  color: colors.mutedForeground,
).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

/// [value] with a sign, to [digits] decimals.
String _signed(double value, int digits) {
  final text = value.toStringAsFixed(digits);
  return double.parse(text) == 0 ? text.replaceFirst('-', '') : text;
}

/// [value] to two decimals without trailing zeros: 0.2, -0.05, 1.
String _plain(double value) {
  final text = ((value * 100).round() / 100).toString();
  return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
}

/// 1020 as "1,020".
String _ms(Duration duration) {
  final digits = duration.inMilliseconds.toString();
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return '$out ms';
}

/// A motion's response from 0 to 1 from rest, sampled for the chart.
class _Response {
  _Response._({
    required this.values,
    required this.span,
    required this.ended,
    required this.settled,
  });

  factory _Response.of(Motion motion) {
    final simulation = motion.createSimulation();
    final ended = motion.duration ?? Duration.zero;
    final settled = simulation.simulateSettleTime() ?? ended;
    final span = Duration(
      microseconds: math.max(
        (settled.inMicroseconds * 1.1).round(),
        (ended.inMicroseconds * 1.5).round(),
      ),
    );
    const samples = 240;
    return _Response._(
      values: [
        for (var i = 0; i <= samples; i++)
          simulation.x(span.inMicroseconds / 1e6 * i / samples),
      ],
      span: span,
      ended: ended,
      settled: settled,
    );
  }

  /// Evenly spaced from 0 to [span].
  final List<double> values;
  final Duration span;

  /// When the motion's duration has passed.
  final Duration ended;

  /// When it is at rest on its target.
  final Duration settled;

  /// Curves end and settle together.
  bool get together => (settled - ended).inMilliseconds.abs() < 2;

  @override
  bool operator ==(Object other) =>
      other is _Response && other.span == span && other.values == values;

  @override
  int get hashCode => Object.hash(span, values);
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required Listenable repaint,
    required this.response,
    required this.playhead,
    required this.textScaler,
    required this.hairline,
    required this.curve,
    required this.marker,
    required this.playheadColor,
    required this.labelStyle,
  }) : super(repaint: repaint);

  final _Response response;

  /// How far into a replay the dot is, or null when there is none.
  final Duration? Function() playhead;
  final TextScaler textScaler;
  final Color hairline;
  final Color curve;
  final Color marker;
  final Color playheadColor;
  final TextStyle labelStyle;

  TextPainter _label(String text) => TextPainter(
    text: TextSpan(text: text, style: labelStyle),
    textDirection: TextDirection.ltr,
    textScaler: textScaler,
  )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    final span = response.span.inMicroseconds;
    if (span <= 0) return;
    double x(Duration time) => time.inMicroseconds / span * size.width;

    final labels = response.together
        ? [(response.ended, _label('Ends and settles ${_ms(response.ended)}'))]
        : [
            (response.ended, _label('Ended ${_ms(response.ended)}')),
            (response.settled, _label('Settled ${_ms(response.settled)}')),
          ];
    final lineHeight = labels.first.$2.height;
    // Room for two lines of labels, in case they would collide.
    final top = lineHeight * 2 + 8;
    final bottom = size.height - 4;
    if (bottom - top < 20) return;

    final low = math.min(0.0, response.values.reduce(math.min));
    final high = math.max(1.0, response.values.reduce(math.max));
    double y(double value) =>
        bottom - (value - low) / (high - low) * (bottom - top);

    final line = Paint()
      ..color = hairline
      ..strokeWidth = 1;
    canvas
      ..drawLine(Offset(0, y(0)), Offset(size.width, y(0)), line)
      ..drawLine(Offset(0, y(1)), Offset(size.width, y(1)), line);

    final path = Path();
    final last = response.values.length - 1;
    for (var i = 0; i <= last; i++) {
      final point = Offset(i / last * size.width, y(response.values[i]));
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = curve
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    final dash = Paint()
      ..color = marker
      ..strokeWidth = 1;
    for (final (time, _) in labels) {
      final dx = x(time);
      for (var dy = top - 4; dy < bottom; dy += 6) {
        canvas.drawLine(
          Offset(dx, dy),
          Offset(dx, math.min(dy + 3, bottom)),
          dash,
        );
      }
    }

    // The earlier label ends at its marker, the later one starts at its own,
    // so they sit apart; if they still meet, the later one goes a line down.
    Rect? taken;
    for (final (i, (time, painter)) in labels.indexed) {
      final dx = x(time);
      final room = size.width - painter.width;
      var left = labels.length == 1
          ? (dx > size.width / 2 ? dx - painter.width - 4 : dx + 4)
          : (i == 0 ? dx - painter.width - 4 : dx + 4);
      left = left.clamp(0.0, math.max(0.0, room));
      var rect = Offset(left, 0) & painter.size;
      if (taken != null && rect.overlaps(taken.inflate(4))) {
        rect = rect.shift(Offset(0, lineHeight + 2));
      }
      taken = rect;
      painter.paint(canvas, rect.topLeft);
    }

    if (playhead() case final elapsed?) {
      final dx = x(elapsed).clamp(0.0, size.width);
      canvas.drawLine(
        Offset(dx, top - 4),
        Offset(dx, bottom),
        Paint()
          ..color = playheadColor
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(_ChartPainter oldDelegate) =>
      oldDelegate.response != response ||
      oldDelegate.hairline != hairline ||
      oldDelegate.curve != curve ||
      oldDelegate.marker != marker ||
      oldDelegate.playheadColor != playheadColor ||
      oldDelegate.labelStyle != labelStyle ||
      oldDelegate.textScaler != textScaler;
}

/// The track: a hairline from end to end with a short tick at each end.
class _TrackPainter extends CustomPainter {
  const _TrackPainter({required this.line, required this.inset});

  final Color line;
  final double inset;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = line
      ..strokeWidth = 1;
    final center = size.height / 2;
    canvas
      ..drawLine(
        Offset(inset, center),
        Offset(size.width - inset, center),
        paint,
      )
      ..drawLine(Offset(inset, center - 3), Offset(inset, center + 3), paint)
      ..drawLine(
        Offset(size.width - inset, center - 3),
        Offset(size.width - inset, center + 3),
        paint,
      );
  }

  @override
  bool shouldRepaint(_TrackPainter oldDelegate) =>
      oldDelegate.line != line || oldDelegate.inset != inset;
}
