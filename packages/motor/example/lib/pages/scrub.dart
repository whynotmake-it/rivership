// The playhead reads the controller's position from the inspection API.
// ignore_for_file: experimental_member_use

import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/chapters.dart';
import 'package:motor_example/widgets/chapter_page.dart';
import 'package:motor_example/widgets/controls.dart';
import 'package:motor_example/widgets/live_timeline.dart';
import 'package:motor_example/widgets/style.dart';

/// Any choreography can be paused, scrubbed and resumed.
class ScrubPage extends StatefulWidget {
  const ScrubPage({super.key});

  @override
  State<ScrubPage> createState() => _ScrubPageState();
}

const _length = Duration(milliseconds: 2400);
const _button = 220.0;
const _puck = 60.0;

class _ScrubPageState extends State<ScrubPage>
    with SingleTickerProviderStateMixin {
  late final _send = TrackController(vsync: this, debugLabel: 'Send money');

  final _width = Track<double>(.single, initial: _button, debugLabel: 'Width');
  final _spinner = Track<double>(.single, initial: 0, debugLabel: 'Spinner');
  final _check = Track<double>(.single, initial: 0, debugLabel: 'Check');
  final _burst = Track<double>(.single, initial: 0, debugLabel: 'Confetti');
  final _caption = Track<double>(.single, initial: 0, debugLabel: 'Caption');

  late final _timeline = TrackTimeline([
    _width([
      .to(_puck, motion: .smoothSpring(duration: Duration(milliseconds: 380))),
      .sync(token: #paid),
      .to(84, motion: .bouncySpring(extraBounce: .2)),
    ]),
    _spinner([
      .hold(const Duration(milliseconds: 250)),
      .to(2, motion: .linear(Duration(milliseconds: 1000))),
      .sync(token: #paid),
    ]),
    _check([
      .sync(token: #paid),
      .to(1, motion: .curved(Duration(milliseconds: 380), Curves.easeOutCubic)),
    ]),
    _burst([
      .sync(token: #paid),
      .to(1, motion: .smoothSpring(duration: Duration(milliseconds: 1000))),
    ]),
    _caption([
      .sync(token: #paid),
      .hold(const Duration(milliseconds: 120)),
      .to(1, motion: .smoothSpring()),
    ]),
  ]);

  var _origin = Duration.zero;
  var _scrubbing = false;

  final _code = ValueNotifier('// Tap Send to play.\nsend.play(timeline);');

  @override
  void dispose() {
    _send.dispose();
    _code.dispose();
    super.dispose();
  }

  void _play() {
    _code.value = '// Plays the whole choreography.\nsend.play(timeline);';
    _send
      ..stop(canceled: true)
      ..set(_timeline.startValues)
      ..play(_timeline);
    _origin = _send.inspectPlayback().position;
  }

  void _scrub(double fraction) {
    if (!_scrubbing) {
      if (_send.status == AnimationStatus.dismissed) _play();
      setState(() => _scrubbing = true);
      _send.pause();
    }
    final time = _length * fraction.clamp(0.0, 1.0);
    _code.value =
        '// Scrubbing: every track shows its value at this time.\n'
        'send..pause()..scrubTo(${(time.inMilliseconds / 1000).toStringAsFixed(2)}.s);';
    _send.scrubTo(_origin + time);
  }

  void _release() {
    setState(() => _scrubbing = false);
    _code.value = '// Let go: playback carries on from here.\nsend.resume();';
    _send.resume();
  }

  @override
  Widget build(BuildContext context) {
    final t = Palette.of(context);
    return ChapterPage(
      chapter: chapterNamed('Scrub'),
      lead:
          'Tap Send, then drag the scrubber. Wherever you stop, the button '
          'looks exactly as it would at that moment of playback, springs and '
          'sync barrier included. Let go and it plays on from there.',
      code: _code,
      below: LiveTimeline(
        controller: _send,
        lanes: {
          _width: 'button',
          _spinner: 'spinner',
          _check: 'check',
          _burst: 'confetti',
          _caption: 'caption',
        },
      ),
      stageHeight: 380,
      stage: AnimatedBuilder(
        animation: _send,
        builder: (context, _) {
          final value = _send.value;
          final elapsed = _send.inspectPlayback().position - _origin;
          final progress = _send.status == AnimationStatus.dismissed
              ? 0.0
              : (elapsed.inMicroseconds / _length.inMicroseconds).clamp(
                  0.0,
                  1.0,
                );
          return Column(
            children: [
              Expanded(
                child: Center(
                  child: GestureDetector(
                    onTap: _play,
                    child: _SendButton(
                      width: value(_width),
                      spinner: value(_spinner),
                      check: value(_check),
                      burst: value(_burst),
                    ),
                  ),
                ),
              ),
              Reveal(
                progress: value(_caption),
                child: Column(
                  children: [
                    Text('\$42 sent', style: t.title.copyWith(fontSize: 20)),
                    const SizedBox(height: 2),
                    Text('to Jules', style: t.caption),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                child: Row(
                  children: [
                    PillButton(
                      label: 'Send',
                      icon: CupertinoIcons.paperplane_fill,
                      filled: true,
                      onTap: _play,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _Scrubber(
                        progress: progress,
                        scrubbing: _scrubbing,
                        onScrub: _scrub,
                        onRelease: _release,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.width,
    required this.spinner,
    required this.check,
    required this.burst,
  });

  final double width;
  final double spinner;
  final double check;
  final double burst;

  @override
  Widget build(BuildContext context) {
    final t = Palette.of(context);
    final label = ((width - _puck) / (_button - _puck)).clamp(0.0, 1.0);
    final spinning = spinner > 0 && spinner < 2 && check == 0;
    return SizedBox(
      width: 260,
      height: 200,
      child: CustomPaint(
        painter: _ConfettiPainter(burst, t.accent),
        child: Center(
          child: Container(
            width: width,
            height: math.min(width, _puck),
            decoration: BoxDecoration(
              color: Color.lerp(t.text, t.accent, check),
              borderRadius: BorderRadius.circular(width),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Reveal(
                  progress: label,
                  offset: Offset.zero,
                  child: OverflowBox(
                    maxWidth: _button,
                    child: Text(
                      'Send \$42',
                      style: archivo(15, weight: 560, color: t.canvas),
                    ),
                  ),
                ),
                if (spinning)
                  Transform.rotate(
                    angle: spinner * 2 * math.pi,
                    child: CustomPaint(
                      size: const Size.square(26),
                      painter: _ArcPainter(t.canvas),
                    ),
                  ),
                if (check > 0)
                  CustomPaint(
                    size: const Size.square(30),
                    painter: _CheckPainter(check, CupertinoColors.white),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Scrubber extends StatelessWidget {
  const _Scrubber({
    required this.progress,
    required this.scrubbing,
    required this.onScrub,
    required this.onRelease,
  });

  final double progress;
  final bool scrubbing;
  final ValueChanged<double> onScrub;
  final VoidCallback onRelease;

  @override
  Widget build(BuildContext context) {
    final t = Palette.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        double fraction(Offset position) => position.dx / width;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (details) =>
              onScrub(fraction(details.localPosition)),
          onHorizontalDragUpdate: (details) =>
              onScrub(fraction(details.localPosition)),
          onHorizontalDragEnd: (_) => onRelease(),
          onTapDown: (details) => onScrub(fraction(details.localPosition)),
          onTapUp: (_) => onRelease(),
          child: SizedBox(
            height: 40,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(height: 4, color: t.control),
                Container(width: progress * width, height: 4, color: t.accent),
                Positioned(
                  left: progress * (width - 4),
                  child: Container(
                    width: 4,
                    height: 26,
                    color: scrubbing ? t.accent : t.text,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawArc(
      Offset.zero & size,
      0,
      math.pi * 1.4,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter oldDelegate) => oldDelegate.color != color;
}

class _CheckPainter extends CustomPainter {
  _CheckPainter(this.progress, this.color);

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * .2, size.height * .52)
      ..lineTo(size.width * .42, size.height * .72)
      ..lineTo(size.width * .8, size.height * .3);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress.clamp(0, 1)),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.burst, this.accent);

  final double burst;
  final Color accent;

  static const _count = 14;

  @override
  void paint(Canvas canvas, Size size) {
    if (burst <= 0 || burst >= 1) return;
    final center = size.center(Offset.zero);
    for (var i = 0; i < _count; i++) {
      final angle = i / _count * 2 * math.pi + .3;
      final reach = 60.0 + (i % 3) * 22;
      final color = accent;
      final position =
          center + Offset(math.cos(angle), math.sin(angle)) * reach * burst;
      canvas.drawCircle(
        position,
        4.5 * (1 - burst * .6),
        Paint()
          ..color = color.withValues(alpha: math.min(1, (1 - burst) * 1.4)),
      );
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) =>
      oldDelegate.burst != burst;
}
