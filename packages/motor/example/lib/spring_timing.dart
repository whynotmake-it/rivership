// A standalone page comparing three ways to time a spring step in a
// sequence, recorded for the motor 2.0 spring-timing poll.
//
// Run it on web:
//   flutter run -d chrome -t lib/spring_timing.dart
// (scaffold the web platform first with `flutter create --platforms web .`)

import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

void main() => runApp(const SpringTimingApp());

/// Distance between positions 0, 1 and 2, in logical pixels.
const _spacing = 260.0;

const _bouncy = CupertinoMotion.bouncy();

/// The bouncy spring's perceptual duration.
final _pace = _bouncy.duration;

const _runs = 3;
const _intro = Duration(milliseconds: 1500);
const _hold = Duration(milliseconds: 1400);

const _canvas = Color(0xFF111113);
const _surface = Color(0xFF1C1C1F);
const _inset = Color(0xFF161618);
const _control = Color(0xFF28282C);
const _border = Color(0xFF2A2A2E);
const _borderStrong = Color(0xFF3F3F46);
const _text = Color(0xFFFAFAFA);
const _textSecondary = Color(0xFFA1A1AA);
const _textTertiary = Color(0xFF71717A);
const _accent = Color(0xFF8AA4FF);
const _accentDeep = Color(0xFF3D63DD);
const _onAccent = Color(0xFF111113);

TextStyle _archivo(double size, {double weight = 400, Color color = _text}) =>
    TextStyle(
      fontFamily: 'Archivo',
      fontSize: size,
      fontVariations: [FontVariation.weight(weight)],
      letterSpacing: size > 24 ? -0.03 * size : 0,
      height: 1.15,
      color: color,
    );

TextStyle _mono(double size, {double weight = 440, Color color = _text}) =>
    TextStyle(
      fontFamily: 'JetBrains Mono',
      fontSize: size,
      fontVariations: [FontVariation.weight(weight)],
      height: 1.3,
      color: color,
    );

double _seconds(Duration duration) =>
    duration.inMicroseconds / Duration.microsecondsPerSecond;

/// Plays [parent] until [duration], then hands on whatever value and velocity
/// it has there, without landing on its target first.
///
/// This emulates keyframe-style timing, where the next step takes over a
/// spring at its duration.
class _HandOffMotion extends Motion {
  _HandOffMotion(this.parent, {required this.duration})
      : super(tolerance: parent.tolerance);

  final Motion parent;
  final Duration duration;

  @override
  bool get needsSettle => parent.needsSettle;

  @override
  Duration settlingDuration({
    double start = 0,
    double end = 1,
    double velocity = 0,
  }) =>
      duration;

  @override
  Simulation createSimulation({
    double start = 0,
    double end = 1,
    double velocity = 0,
  }) =>
      _HandOffSimulation(
        parent.createSimulation(start: start, end: end, velocity: velocity),
        cut: _seconds(duration),
      );

  @override
  bool operator ==(Object other) =>
      other is _HandOffMotion &&
      other.parent == parent &&
      other.duration == duration;

  @override
  int get hashCode => Object.hash(parent, duration);
}

class _HandOffSimulation extends Simulation {
  _HandOffSimulation(this.parent, {required this.cut})
      : super(tolerance: parent.tolerance);

  final Simulation parent;
  final double cut;

  @override
  double x(double time) => parent.x(math.min(time, cut));

  @override
  double dx(double time) => parent.dx(math.min(time, cut));

  @override
  bool isDone(double time) => time >= cut;
}

/// One way of timing the same two-step sequence.
@immutable
class _Option {
  const _Option({
    required this.number,
    required this.label,
    required this.detail,
    required this.track,
    required this.steps,
    required this.stepTwoAt,
    required this.total,
    this.note,
  });

  final int number;
  final String label;
  final String detail;
  final String? note;
  final Track<double> track;
  final List<TrackStep<double>> steps;

  /// When step 2 starts, in seconds.
  final double stepTwoAt;

  /// When the whole sequence is done, in seconds.
  final double total;
}

List<_Option> _buildOptions() {
  // 1. Every step lasts until its spring has settled.
  final settleOne =
      _seconds(_bouncy.settlingDuration(start: 0, end: _spacing)!);
  final settleTwo =
      _seconds(_bouncy.settlingDuration(start: _spacing, end: 2 * _spacing)!);

  // 2. Every step ends at its duration, on its target.
  final onTime = _bouncy.skipTail();

  // 3. The next step takes over at the duration; the last one settles.
  final pace = _seconds(_pace);
  final handOff = _HandOffMotion(_bouncy, duration: _pace);
  final firstStep = _bouncy.createSimulation(end: _spacing);
  final lastSettle = _seconds(
    _bouncy.settlingDuration(
      start: firstStep.x(pace),
      end: 2 * _spacing,
      velocity: firstStep.dx(pace),
    )!,
  );

  return [
    _Option(
      number: 1,
      label: 'Settle by default',
      detail: 'every step settles fully',
      track: Track(MotionConverter.single, initial: 0),
      steps: const [
        TrackStep.to(_spacing, motion: _bouncy),
        TrackStep.to(2 * _spacing, motion: _bouncy),
      ],
      stepTwoAt: settleOne,
      total: settleOne + settleTwo,
    ),
    _Option(
      number: 2,
      label: 'On time by default',
      detail: 'every step ends at 500 ms',
      note: 'shown with .skipTail()',
      track: Track(MotionConverter.single, initial: 0),
      steps: [
        TrackStep.to(_spacing, motion: onTime),
        TrackStep.to(2 * _spacing, motion: onTime),
      ],
      stepTwoAt: pace,
      total: 2 * pace,
    ),
    _Option(
      number: 3,
      label: 'Depends on what follows',
      detail: 'hands off at 500 ms',
      note: 'only the last step settles',
      track: Track(MotionConverter.single, initial: 0),
      steps: [
        TrackStep.to(_spacing, motion: handOff),
        const TrackStep.to(2 * _spacing, motion: _bouncy),
      ],
      stepTwoAt: pace,
      total: pace + lastSettle,
    ),
  ];
}

class SpringTimingApp extends StatelessWidget {
  const SpringTimingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      color: _accent,
      debugShowCheckedModeBanner: false,
      title: 'Spring timing',
      home: SpringTimingPage(),
      pageRouteBuilder: _route,
    );
  }

  static PageRoute<T> _route<T>(
          RouteSettings settings, WidgetBuilder builder) =>
      PageRouteBuilder<T>(
        settings: settings,
        pageBuilder: (context, _, __) => builder(context),
      );
}

class SpringTimingPage extends StatefulWidget {
  const SpringTimingPage({super.key});

  @override
  State<SpringTimingPage> createState() => _SpringTimingPageState();
}

class _SpringTimingPageState extends State<SpringTimingPage>
    with TickerProviderStateMixin {
  late final _options = _buildOptions();
  late final _controller = TrackController(vsync: this);
  late final Ticker _clock = createTicker(_onTick);

  /// The time axis every row's timeline shares, in seconds.
  late final double _axis =
      (_options.map((option) => option.total).reduce(math.max) * 2).ceil() / 2;

  var _run = 0;
  var _elapsed = 0.0;
  Duration _runStartedAt = Duration.zero;
  var _started = false;

  @override
  void initState() {
    super.initState();
    _clock.start();
  }

  void _onTick(Duration now) {
    if (!_started) {
      if (now < _intro) return;
      _startRun(now);
      return;
    }
    final elapsed = _seconds(now - _runStartedAt);
    if (elapsed > _axis + _seconds(_hold)) {
      if (_run < _runs) {
        _startRun(now);
      } else {
        _clock.stop();
      }
      return;
    }
    setState(() => _elapsed = elapsed);
  }

  void _startRun(Duration now) {
    setState(() {
      _started = true;
      _run++;
      _runStartedAt = now;
      _elapsed = 0;
    });
    _controller.play(
      TrackTimeline([
        for (final option in _options)
          option.track(option.steps, from: 0, withVelocity: 0),
      ]),
    );
  }

  void _replay() {
    if (_clock.isActive) return;
    _controller.set([for (final option in _options) option.track.value(0)]);
    setState(() {
      _run = 0;
      _started = false;
      _elapsed = 0;
    });
    _clock.start();
  }

  @override
  void dispose() {
    _clock.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _replay,
      child: ColoredBox(
        color: _canvas,
        child: SizedBox.expand(
          child: FittedBox(
            child: SizedBox(
              width: 1280,
              height: 720,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(56, 44, 56, 44),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Header(run: _run),
                    const SizedBox(height: 28),
                    for (final option in _options) ...[
                      Expanded(
                        child: _OptionRow(
                          option: option,
                          value: _controller.value(option.track),
                          elapsed: _elapsed,
                          axis: _axis,
                        ),
                      ),
                      if (option != _options.last) const SizedBox(height: 14),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.run});

  final int run;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'motor 2.0 · spring timing',
                style: _mono(13, color: _textTertiary),
              ),
              const SizedBox(height: 10),
              Text(
                'Two bouncy springs in a row. When does step 2 start?',
                style: _archivo(34),
              ),
              const SizedBox(height: 10),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: '.to(1, motion: .bouncySpring())'),
                    TextSpan(
                      text: '  then  ',
                      style: _mono(14, color: _textTertiary),
                    ),
                    const TextSpan(text: '.to(2, motion: .bouncySpring())'),
                    TextSpan(
                      text: '    duration: 500 ms',
                      style: _mono(14, color: _textTertiary),
                    ),
                  ],
                ),
                style: _mono(14, color: _textSecondary),
              ),
            ],
          ),
        ),
        Text(
          run == 0 ? '' : 'run $run / $_runs',
          style: _mono(13, color: _textTertiary),
        ),
      ],
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.option,
    required this.value,
    required this.elapsed,
    required this.axis,
  });

  final _Option option;
  final double value;
  final double elapsed;
  final double axis;

  @override
  Widget build(BuildContext context) {
    final done = elapsed >= option.total;
    final shown = math.min(elapsed, option.total);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
        child: Row(
          children: [
            SizedBox(
              width: 272,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        color: _accent,
                        child: Text(
                          '${option.number}',
                          style: _mono(14, weight: 600, color: _onAccent),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(option.label, style: _archivo(21, weight: 500)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    option.detail,
                    style: _mono(12.5, color: _textSecondary),
                  ),
                  if (option.note case final note?) ...[
                    const SizedBox(height: 4),
                    Text(note, style: _mono(12.5, color: _textTertiary)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 52,
                    child: CustomPaint(
                      painter: _StagePainter(value: value),
                      size: Size.infinite,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 40,
                    child: CustomPaint(
                      painter: _TimelinePainter(
                        elapsed: elapsed,
                        stepTwoAt: option.stepTwoAt,
                        total: option.total,
                        axis: axis,
                      ),
                      size: Size.infinite,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 28),
            SizedBox(
              width: 128,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${shown.toStringAsFixed(2)} s',
                    style: _mono(
                      30,
                      weight: 500,
                      color: done ? _accent : _textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    done
                        ? 'total'
                        : elapsed > 0
                            ? 'running'
                            : '',
                    style: _mono(12.5, color: _textTertiary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _square = 34.0;

/// Leaves room on both sides for the spring's overshoot.
const _stageInset = 40.0;

class _StagePainter extends CustomPainter {
  _StagePainter({required this.value});

  final double value;

  double _left(Size size, double position) {
    final travel = size.width - 2 * _stageInset - _square;
    return _stageInset + position / (2 * _spacing) * travel;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final top = (size.height - _square) / 2;
    canvas.drawRect(Offset.zero & size, Paint()..color = _inset);

    final line = Paint()
      ..color = _borderStrong
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(_stageInset, size.height / 2),
      Offset(size.width - _stageInset, size.height / 2),
      line..color = _control,
    );

    final ghost = Paint()
      ..color = _borderStrong
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final left = _left(size, i * _spacing);
      canvas.drawRect(Rect.fromLTWH(left, top, _square, _square), ghost);
      final label = TextPainter(
        text: TextSpan(text: '$i', style: _mono(10, color: _textTertiary)),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(
        canvas,
        Offset(left + _square / 2 - label.width / 2, top - label.height - 1),
      );
    }

    canvas.drawRect(
      Rect.fromLTWH(_left(size, value), top, _square, _square),
      Paint()..color = _accent,
    );
  }

  @override
  bool shouldRepaint(_StagePainter oldDelegate) => oldDelegate.value != value;
}

class _TimelinePainter extends CustomPainter {
  _TimelinePainter({
    required this.elapsed,
    required this.stepTwoAt,
    required this.total,
    required this.axis,
  });

  final double elapsed;
  final double stepTwoAt;
  final double total;
  final double axis;

  static const _barTop = 14.0;
  static const _barHeight = 8.0;

  @override
  void paint(Canvas canvas, Size size) {
    double x(double seconds) => seconds / axis * size.width;

    canvas.drawRect(
      Rect.fromLTWH(0, _barTop, size.width, _barHeight),
      Paint()..color = _control,
    );

    final stepOneEnd = math.min(elapsed, stepTwoAt);
    canvas.drawRect(
      Rect.fromLTRB(0, _barTop, x(stepOneEnd), _barTop + _barHeight),
      Paint()..color = _accentDeep,
    );
    if (elapsed > stepTwoAt) {
      canvas.drawRect(
        Rect.fromLTRB(
          x(stepTwoAt),
          _barTop,
          x(math.min(elapsed, total)),
          _barTop + _barHeight,
        ),
        Paint()..color = _accent,
      );
    }

    for (var second = 0.0; second <= axis + 1e-9; second += 0.5) {
      final whole = second == second.roundToDouble();
      canvas.drawLine(
        Offset(x(second), _barTop + _barHeight + 2),
        Offset(x(second), _barTop + _barHeight + (whole ? 7 : 4)),
        Paint()..color = _borderStrong,
      );
      if (whole) {
        _label(
          canvas,
          '${second.toInt()} s',
          Offset(x(second), _barTop + _barHeight + 8),
          _mono(9.5, color: _textTertiary),
          alignEnd: second >= axis,
        );
      }
    }

    if (elapsed >= stepTwoAt) {
      final markerX = x(stepTwoAt);
      canvas.drawRect(
        Rect.fromLTWH(markerX - 1, 0, 2, _barTop + _barHeight + 3),
        Paint()..color = _text,
      );
      _label(
        canvas,
        'step 2 starts · ${stepTwoAt.toStringAsFixed(2)} s',
        Offset(markerX + 6, -1),
        _mono(10.5, weight: 500, color: _text),
      );
    }

    if (elapsed < total + 0.2) {
      final playhead = x(math.min(elapsed, axis));
      canvas.drawRect(
        Rect.fromLTWH(playhead - 0.5, _barTop - 3, 1, _barHeight + 6),
        Paint()..color = _textSecondary,
      );
    }
  }

  void _label(
    Canvas canvas,
    String text,
    Offset at,
    TextStyle style, {
    bool alignEnd = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, alignEnd ? at - Offset(painter.width, 0) : at);
  }

  @override
  bool shouldRepaint(_TimelinePainter oldDelegate) =>
      oldDelegate.elapsed != elapsed;
}
