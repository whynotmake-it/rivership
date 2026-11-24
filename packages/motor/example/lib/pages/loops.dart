import 'dart:math' as math;

import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/chapters.dart';
import 'package:motor_example/widgets/chapter_page.dart';
import 'package:motor_example/widgets/icons.dart';
import 'package:motor_example/widgets/live_timeline.dart';
import 'package:motor_example/widgets/style.dart';

/// Repeating slices of steps, finite counts, and lockstep loops.
class LoopsPage extends StatefulWidget {
  const LoopsPage({super.key});

  @override
  State<LoopsPage> createState() => _LoopsPageState();
}

enum _LoopScene { modes, together, count, mixed }

const _railLeg = Motion.curved(
  Duration(milliseconds: 420),
  Curves.easeInOutCubic,
);
const _sweep = Motion.linear(Duration(milliseconds: 1200));
const _fastLeg = Motion.curved(
  Duration(milliseconds: 260),
  Curves.easeInOutCubic,
);
const _midLeg = Motion.curved(
  Duration(milliseconds: 380),
  Curves.easeInOutCubic,
);
const _slowLeg = Motion.curved(
  Duration(milliseconds: 560),
  Curves.easeInOutCubic,
);

class _LoopsPageState extends State<LoopsPage>
    with SingleTickerProviderStateMixin {
  late final _controller = TrackController(vsync: this, debugLabel: 'Loops');

  // Modes scene tracks.
  final _loop = Track<double>(.single, initial: 0, debugLabel: 'Loop');
  final _pingPong = Track<double>(.single, initial: 0, debugLabel: 'Ping-pong');
  final _seamless = Track<double>(.single, initial: 0, debugLabel: 'Seamless');

  // Together scene tracks.
  final _fast = Track<double>(.single, initial: 0, debugLabel: 'Fast');
  final _mid = Track<double>(.single, initial: 0, debugLabel: 'Medium');
  final _slow = Track<double>(.single, initial: 0, debugLabel: 'Slow');

  // Count scene tracks (intro -> loop -> outro).
  final _scale = Track<double>(.single, initial: 0.65, debugLabel: 'Scale');
  final _ring = Track<double>(.single, initial: 0, debugLabel: 'Ring');
  final _check = Track<double>(.single, initial: 0, debugLabel: 'Check');

  // Mixed scene tracks (one-shot + finite + infinite).
  final _intro = Track<double>(.single, initial: 0, debugLabel: 'Intro');
  final _finite = Track<double>(.single, initial: 0, debugLabel: 'Pulse (2×)');
  final _orbit = Track<double>(.single, initial: 0, debugLabel: 'Orbit (∞)');

  final _code = ValueNotifier('');

  var _scene = _LoopScene.modes;
  var _together = true;
  int? _count = 3;
  var _runId = 0;

  // Live counters updated from onStep so the stage shows rhythm and phase.
  final _togetherCycles = <Track<Object>, int>{};
  var _countCycle = 0;
  var _countStage = 'Intro';
  var _mixedIntroDone = false;
  var _mixedFiniteCycles = 0;
  var _mixedFiniteDone = false;
  var _mixedOrbitCycles = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _play();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _code.dispose();
    super.dispose();
  }

  void _selectScene(_LoopScene scene) {
    if (_scene == scene) return;
    setState(() => _scene = scene);
    _play();
  }

  void _play() {
    _runId++;
    _controller.stop(canceled: true);
    switch (_scene) {
      case .modes:
        _playModes();
      case .together:
        _playTogether();
      case .count:
        _playCount();
      case .mixed:
        _playMixed();
    }
  }

  void _playModes() {
    _code.value =
        '// Three tracks on one clock, each with its own loop mode.\n'
        'controller.animate([\n'
        '  loop([.loop([.to(0.5), .to(1), .to(0)])]),\n'
        '  pingPong([.loop([.to(0), .to(0.5), .hold(240ms), .to(1)], mode: .pingPong)]),\n'
        '  seamless([.loop([.to(0, motion: .instant()), .to(1)], mode: .seamless)]),\n'
        ']);';
    _controller
      ..set([_loop.value(0), _pingPong.value(0), _seamless.value(0)])
      ..animate([
        _loop([
          const .loop([
            .to(0.5, motion: _railLeg),
            .to(1, motion: _railLeg),
            .to(0, motion: _railLeg),
          ]),
        ]),
        _pingPong([
          const .loop([
            .to(0, motion: _railLeg),
            .to(0.5, motion: _railLeg),
            .hold(Duration(milliseconds: 240)),
            .to(1, motion: _railLeg),
          ], mode: .pingPong),
        ]),
        _seamless([
          const .loop([
            .to(0, motion: .instant()),
            .to(1, motion: _sweep),
          ], mode: .seamless),
        ]),
      ]);
  }

  void _playTogether() {
    _togetherCycles
      ..clear()
      ..[_fast] = 0
      ..[_mid] = 0
      ..[_slow] = 0;
    final token = _together ? #beat : null;
    _code.value = _together
        ? '// Shared together token: fast tracks wait for the slow one each cycle.\n'
              'controller.animate([\n'
              '  fast([.loop([.to(1, motion: fast), .to(0, motion: fast)], together: #beat)]),\n'
              '  mid( [.loop([.to(1, motion: mid),  .to(0, motion: mid)],  together: #beat)]),\n'
              '  slow([.loop([.to(1, motion: slow), .to(0, motion: slow)], together: #beat)]),\n'
              ']);'
        : '// No token: each loop runs on its own cadence and drifts into polyrhythm.\n'
              'controller.animate([\n'
              '  fast([.loop([.to(1, motion: fast), .to(0, motion: fast)])]),\n'
              '  mid( [.loop([.to(1, motion: mid),  .to(0, motion: mid)])]),\n'
              '  slow([.loop([.to(1, motion: slow), .to(0, motion: slow)])]),\n'
              ']);';
    _controller
      ..set([_fast.value(0), _mid.value(0), _slow.value(0)])
      ..animate([
        _fast([
          .loop(const [
            .to(1, motion: _fastLeg),
            .to(0, motion: _fastLeg),
          ], together: token),
        ]),
        _mid([
          .loop(const [
            .to(1, motion: _midLeg),
            .to(0, motion: _midLeg),
          ], together: token),
        ]),
        _slow([
          .loop(const [
            .to(1, motion: _slowLeg),
            .to(0, motion: _slowLeg),
          ], together: token),
        ]),
      ], onStep: _onTogetherStep);
  }

  void _onTogetherStep(Track<Object> track, int stepIndex) {
    if (stepIndex == 0 && _togetherCycles.containsKey(track)) {
      _togetherCycles[track] = (_togetherCycles[track] ?? 0) + 1;
    }
  }

  void _playCount() {
    final runId = _runId;
    _countCycle = 0;
    _countStage = 'Intro';
    final count = _count;
    final countArg = count == null ? '' : 'count: $count, ';
    _code.value = count == null
        ? '// One plan: intro plays once, then loops forever.\n'
              'scale([\n'
              '  .to(1, motion: .smoothSpring()), // intro\n'
              '  .loop([.to(1.16), .to(0.94)], together: #pulse),\n'
              ']);'
        : '// One plan: intro, $count loop cycles, then outro.\n'
              'scale([\n'
              '  .to(1, motion: .smoothSpring()), // intro\n'
              '  .loop([.to(1.16), .to(0.94)], ${countArg}together: #pulse),\n'
              '  .sync(token: #done),\n'
              '  .to(1, motion: .smoothSpring()), // outro\n'
              ']);';
    _controller.set([_scale.value(0.65), _ring.value(0), _check.value(0)]);
    final future = _controller.animate([
      _scale([
        const .to(
          1,
          motion: .smoothSpring(duration: Duration(milliseconds: 380)),
        ),
        const .sync(token: #entered),
        .loop(
          const [
            .to(
              1.16,
              motion: .bouncySpring(duration: Duration(milliseconds: 360)),
            ),
            .to(
              0.94,
              motion: .smoothSpring(duration: Duration(milliseconds: 360)),
            ),
          ],
          count: count,
          together: #pulse,
        ),
        if (count != null) ...[
          const .sync(token: #done),
          const .to(
            1,
            motion: .smoothSpring(duration: Duration(milliseconds: 360)),
          ),
        ],
      ]),
      _ring([
        const .sync(token: #entered),
        .loop(
          const [
            .to(0, motion: .instant()),
            .to(1, motion: .curved(Duration(milliseconds: 700), easeOut)),
          ],
          mode: .seamless,
          count: count,
          together: #pulse,
        ),
        if (count != null) ...[
          const .sync(token: #done),
          const .to(0, motion: .instant()),
        ],
      ]),
      if (count != null)
        _check([
          const .sync(token: #done),
          const .to(1, motion: .curved(Duration(milliseconds: 320), easeOut)),
        ]),
    ], onStep: _onCountStep);
    if (count != null) {
      future.orCancel.then((_) {
        if (mounted && _runId == runId) {
          setState(() => _countStage = 'Settled');
        }
      }, onError: (_) {});
    }
  }

  void _onCountStep(Track<Object> track, int stepIndex) {
    if (!identical(track, _scale)) return;
    if (stepIndex == 2) {
      _countCycle++;
      _countStage = _count == null
          ? 'Cycle $_countCycle'
          : 'Cycle $_countCycle / $_count';
    } else if (stepIndex == 5) {
      _countStage = 'Outro';
    }
  }

  void _playMixed() {
    _mixedIntroDone = false;
    _mixedFiniteCycles = 0;
    _mixedFiniteDone = false;
    _mixedOrbitCycles = 0;
    _code.value =
        '// One-shot, finite (count: 2) and infinite loops in one animate call.\n'
        '// Pulse exits #sync after 2 cycles; Orbit keeps going without deadlocking.\n'
        'controller.animate([\n'
        '  intro([.to(1)]),                                                     // once\n'
        '  pulse([.loop([.to(1), .to(0)], count: 2, together: #sync)]),         // 2×\n'
        '  orbit([.loop([.to(0), .to(1)], mode: .seamless, together: #sync)]),  // ∞\n'
        ']);';
    _controller
      ..set([_intro.value(0), _finite.value(0), _orbit.value(0)])
      ..animate([
        _intro([
          const .to(
            1,
            motion: .smoothSpring(duration: Duration(milliseconds: 620)),
          ),
        ]),
        _finite([
          const .loop(
            [.to(1, motion: _midLeg), .to(0, motion: _midLeg)],
            count: 2,
            together: #sync,
          ),
        ]),
        _orbit([
          const .loop(
            [
              .to(0, motion: .instant()),
              .to(1, motion: .linear(Duration(milliseconds: 900))),
            ],
            mode: .seamless,
            together: #sync,
          ),
        ]),
      ], onStep: _onMixedStep);
  }

  void _onMixedStep(Track<Object> track, int stepIndex) {
    if (identical(track, _finite) && stepIndex == 0) {
      _mixedFiniteCycles++;
    } else if (identical(track, _orbit) && stepIndex == 1) {
      _mixedOrbitCycles++;
      if (_mixedOrbitCycles >= 3) {
        _mixedFiniteDone = true;
      }
      _mixedIntroDone = true;
    }
  }

  Map<Track<Object>, String> get _lanes => switch (_scene) {
    .modes => {_loop: 'loop', _pingPong: 'pingPong', _seamless: 'seamless'},
    .together => {_fast: 'fast', _mid: 'medium', _slow: 'slow'},
    .count => {_scale: 'scale', _ring: 'ring', _check: 'check'},
    .mixed => {_intro: 'intro', _finite: 'pulse 2×', _orbit: 'orbit ∞'},
  };

  @override
  Widget build(BuildContext context) {
    return ChapterPage(
      chapter: chapterNamed('Loops'),
      lead:
          'Wrap any slice of steps in .loop() to repeat it. Pick a mode, cap '
          'it with count: so it exits into following steps, or share a '
          'together: token to lock sibling loops in rhythm.',
      code: _code,
      below: LiveTimeline(
        key: ValueKey(_scene),
        controller: _controller,
        lanes: _lanes,
      ),
      stageHeight: 430,
      stage: Column(
        children: [
          Expanded(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => switch (_scene) {
                .modes => _ModesStage(
                  loop: _controller.value(_loop),
                  pingPong: _controller.value(_pingPong),
                  seamless: _controller.value(_seamless),
                ),
                .together => _TogetherStage(
                  fast: _controller.value(_fast),
                  mid: _controller.value(_mid),
                  slow: _controller.value(_slow),
                  fastCycles: _togetherCycles[_fast] ?? 0,
                  midCycles: _togetherCycles[_mid] ?? 0,
                  slowCycles: _togetherCycles[_slow] ?? 0,
                  together: _together,
                  onToggle: (value) {
                    setState(() => _together = value);
                    _play();
                  },
                ),
                .count => _CountStage(
                  scale: _controller.value(_scale),
                  ring: _controller.value(_ring),
                  check: _controller.value(_check),
                  stageLabel: _countStage,
                  count: _count,
                  onCountChanged: (count) {
                    setState(() => _count = count);
                    _play();
                  },
                ),
                .mixed => _MixedStage(
                  intro: _controller.value(_intro),
                  finite: _controller.value(_finite),
                  orbit: _controller.value(_orbit),
                  introDone: _mixedIntroDone || _controller.value(_intro) > .99,
                  finiteCycles: _mixedFiniteCycles,
                  finiteDone: _mixedFiniteDone,
                  orbitCycles: _mixedOrbitCycles,
                ),
              },
            ),
          ),
          Padding(
            padding: const .fromLTRB(16, 0, 16, 16),
            child: Row(
              mainAxisAlignment: .spaceBetween,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: .scaleDown,
                    alignment: .centerLeft,
                    child: CoilTabs<_LoopScene>(
                      value: _scene,
                      onChanged: _selectScene,
                      tabs: const [
                        CoilTab(value: .modes, label: Text('Modes')),
                        CoilTab(value: .together, label: Text('Together')),
                        CoilTab(value: .count, label: Text('Count')),
                        CoilTab(value: .mixed, label: Text('Mixed')),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                CoilButton(
                  variant: .secondary,
                  leading: const GlyphIcon(Glyph.rotateCcw),
                  onPressed: _play,
                  child: const Text('Replay'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModesStage extends StatelessWidget {
  const _ModesStage({
    required this.loop,
    required this.pingPong,
    required this.seamless,
  });

  final double loop;
  final double pingPong;
  final double seamless;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final text = CoilTheme.textOf(context);
    return Padding(
      padding: const .fromLTRB(24, 24, 24, 12),
      child: Column(
        mainAxisAlignment: .spaceEvenly,
        children: [
          _RailRow(
            label: '.loop',
            caption: '0 → 0.5 → 1 → 0 in order',
            value: loop,
            stops: const [0, 0.5, 1],
            holdStop: null,
          ),
          _RailRow(
            label: '.pingPong',
            caption: 'bounces 0 ↔ 1, interior hold plays both ways',
            value: pingPong,
            stops: const [0, 0.5, 1],
            holdStop: 0.5,
          ),
          Row(
            children: [
              SizedBox(
                width: 84,
                child: Text(
                  '.seamless',
                  style: mono(12, weight: 520, color: palette.text),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 68,
                height: 68,
                child: CustomPaint(
                  painter: _SeamlessDialPainter(
                    progress: seamless,
                    palette: palette,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'jumps 1 ⇝ 0 at 12 o’clock without reversing',
                  style: text.muted.caption,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RailRow extends StatelessWidget {
  const _RailRow({
    required this.label,
    required this.caption,
    required this.value,
    required this.stops,
    required this.holdStop,
  });

  final String label;
  final String caption;
  final double value;
  final List<double> stops;
  final double? holdStop;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final text = CoilTheme.textOf(context);
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        Row(
          children: [
            Text(label, style: mono(12, weight: 520, color: palette.text)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                caption,
                maxLines: 1,
                overflow: .ellipsis,
                style: text.muted.caption,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 28,
          child: CustomPaint(
            painter: _RailPainter(
              value: value,
              stops: stops,
              holdStop: holdStop,
              palette: palette,
            ),
          ),
        ),
      ],
    );
  }
}

class _RailPainter extends CustomPainter {
  _RailPainter({
    required this.value,
    required this.stops,
    required this.holdStop,
    required this.palette,
  });

  final double value;
  final List<double> stops;
  final double? holdStop;
  final Palette palette;

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 12.0;
    final left = pad;
    final right = size.width - pad;
    final y = size.height / 2;
    final span = math.max(0.0, right - left);

    canvas.drawLine(
      Offset(left, y),
      Offset(right, y),
      Paint()
        ..color = palette.borderStrong
        ..strokeWidth = 3
        ..strokeCap = .round,
    );

    for (final stop in stops) {
      final x = left + span * stop;
      final isHold = holdStop == stop;
      canvas.drawCircle(
        Offset(x, y),
        isHold ? 5 : 3.5,
        Paint()..color = isHold ? palette.accent : palette.borderStrong,
      );
      if (isHold) {
        canvas.drawCircle(
          Offset(x, y),
          9,
          Paint()
            ..color = palette.accentSoft
            ..style = .stroke
            ..strokeWidth = 2,
        );
      }
    }

    final puckX = left + span * value.clamp(0.0, 1.0);
    canvas.drawCircle(Offset(puckX, y), 10, Paint()..color = palette.text);
  }

  @override
  bool shouldRepaint(_RailPainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.palette != palette;
}

class _SeamlessDialPainter extends CustomPainter {
  _SeamlessDialPainter({required this.progress, required this.palette});

  final double progress;
  final Palette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(.zero);
    final radius = size.shortestSide / 2 - 6;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = palette.borderStrong
        ..style = .stroke
        ..strokeWidth = 3,
    );

    // Subtle accent tick at 12 o'clock marking the 1 -> 0 seam.
    canvas.drawLine(
      Offset(center.dx, center.dy - radius - 4),
      Offset(center.dx, center.dy - radius + 4),
      Paint()
        ..color = palette.accent
        ..strokeWidth = 2.5
        ..strokeCap = .round,
    );

    final angle = -math.pi / 2 + progress * 2 * math.pi;
    final tip = center + Offset(math.cos(angle), math.sin(angle)) * radius;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      progress.clamp(0.0, 1.0) * 2 * math.pi,
      false,
      Paint()
        ..color = palette.text
        ..style = .stroke
        ..strokeWidth = 3
        ..strokeCap = .round,
    );
    canvas.drawCircle(tip, 5.5, Paint()..color = palette.text);
  }

  @override
  bool shouldRepaint(_SeamlessDialPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.palette != palette;
}

class _TogetherStage extends StatelessWidget {
  const _TogetherStage({
    required this.fast,
    required this.mid,
    required this.slow,
    required this.fastCycles,
    required this.midCycles,
    required this.slowCycles,
    required this.together,
    required this.onToggle,
  });

  final double fast;
  final double mid;
  final double slow;
  final int fastCycles;
  final int midCycles;
  final int slowCycles;
  final bool together;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final waitingFast = together && fast < 0.01 && slow > 0.02;
    final waitingMid = together && mid < 0.01 && slow > 0.02;
    return Padding(
      padding: const .fromLTRB(24, 24, 24, 12),
      child: Column(
        children: [
          Align(
            alignment: .centerLeft,
            child: CoilSwitch(
              value: together,
              onChanged: onToggle,
              label: const Text('together: #beat'),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: .spaceEvenly,
              children: [
                _BeatLane(
                  label: 'Fast',
                  duration: '520 ms',
                  value: fast,
                  cycles: fastCycles,
                  waiting: waitingFast,
                ),
                _BeatLane(
                  label: 'Medium',
                  duration: '760 ms',
                  value: mid,
                  cycles: midCycles,
                  waiting: waitingMid,
                ),
                _BeatLane(
                  label: 'Slow',
                  duration: '1120 ms',
                  value: slow,
                  cycles: slowCycles,
                  waiting: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BeatLane extends StatelessWidget {
  const _BeatLane({
    required this.label,
    required this.duration,
    required this.value,
    required this.cycles,
    required this.waiting,
  });

  final String label;
  final String duration;
  final double value;
  final int cycles;
  final bool waiting;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final text = CoilTheme.textOf(context);
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        Row(
          children: [
            Text(
              label,
              style: text.caption.copyWith(fontWeight: text.emphasis),
            ),
            const SizedBox(width: 8),
            Text(duration, style: mono(11, color: palette.textSecondary)),
            const Spacer(),
            if (waiting)
              Padding(
                padding: const .only(right: 8),
                child: Text(
                  'waiting',
                  style: mono(11, weight: 520, color: palette.accent),
                ),
              ),
            Text(
              'cycle $cycles',
              style: mono(
                11,
                color: palette.textSecondary,
              ).copyWith(fontFeatures: const [.tabularFigures()]),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 22,
          child: CustomPaint(
            painter: _BeatBarPainter(
              value: value,
              waiting: waiting,
              palette: palette,
            ),
          ),
        ),
      ],
    );
  }
}

class _BeatBarPainter extends CustomPainter {
  _BeatBarPainter({
    required this.value,
    required this.waiting,
    required this.palette,
  });

  final double value;
  final bool waiting;
  final Palette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height / 2);
    final track = RRect.fromRectAndRadius(Offset.zero & size, radius);
    canvas.drawRRect(track, Paint()..color = palette.control);

    final fillWidth =
        (size.height + (size.width - size.height) * value.clamp(0.0, 1.0));
    final fill = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, fillWidth, size.height),
      radius,
    );
    canvas.drawRRect(
      fill,
      Paint()..color = waiting ? palette.accent : palette.text,
    );
  }

  @override
  bool shouldRepaint(_BeatBarPainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.waiting != waiting ||
      oldDelegate.palette != palette;
}

class _CountStage extends StatelessWidget {
  const _CountStage({
    required this.scale,
    required this.ring,
    required this.check,
    required this.stageLabel,
    required this.count,
    required this.onCountChanged,
  });

  final double scale;
  final double ring;
  final double check;
  final String stageLabel;
  final int? count;
  final ValueChanged<int?> onCountChanged;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final text = CoilTheme.textOf(context);
    return Padding(
      padding: const .fromLTRB(24, 18, 24, 8),
      child: Column(
        children: [
          Row(
            children: [
              CoilTabs<int?>(
                value: count,
                onChanged: onCountChanged,
                tabs: const [
                  CoilTab(value: 2, label: Text('2×')),
                  CoilTab(value: 3, label: Text('3×')),
                  CoilTab(value: null, label: Text('∞')),
                ],
              ),
              const Spacer(),
              CoilBadge(child: Text(stageLabel, style: text.caption.tabular)),
            ],
          ),
          Expanded(
            child: Center(
              child: SizedBox.square(
                dimension: 180,
                child: CustomPaint(
                  painter: _PulseBadgePainter(
                    scale: scale,
                    ring: ring,
                    check: check,
                    palette: palette,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseBadgePainter extends CustomPainter {
  _PulseBadgePainter({
    required this.scale,
    required this.ring,
    required this.check,
    required this.palette,
  });

  final double scale;
  final double ring;
  final double check;
  final Palette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(.zero);
    if (ring > 0.01 && ring < 0.99) {
      final radius = 34 + ring * 52;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = palette.accent.withValues(alpha: (1 - ring) * 0.7)
          ..style = .stroke
          ..strokeWidth = 3 * (1 - ring * 0.5),
      );
    }

    final coreRadius = 34 * scale.clamp(0.4, 1.5);
    final fillColor = Color.lerp(palette.text, palette.accent, check)!;
    canvas.drawCircle(center, coreRadius, Paint()..color = fillColor);

    if (check > 0) {
      final path = Path()
        ..moveTo(center.dx - 13, center.dy + 1)
        ..lineTo(center.dx - 3, center.dy + 11)
        ..lineTo(center.dx + 14, center.dy - 9);
      final metric = path.computeMetrics().first;
      canvas.drawPath(
        metric.extractPath(0, metric.length * check.clamp(0.0, 1.0)),
        Paint()
          ..color = palette.onAccent
          ..style = .stroke
          ..strokeWidth = 3.5
          ..strokeCap = .round
          ..strokeJoin = .round,
      );
    }
  }

  @override
  bool shouldRepaint(_PulseBadgePainter oldDelegate) =>
      oldDelegate.scale != scale ||
      oldDelegate.ring != ring ||
      oldDelegate.check != check ||
      oldDelegate.palette != palette;
}

class _MixedStage extends StatelessWidget {
  const _MixedStage({
    required this.intro,
    required this.finite,
    required this.orbit,
    required this.introDone,
    required this.finiteCycles,
    required this.finiteDone,
    required this.orbitCycles,
  });

  final double intro;
  final double finite;
  final double orbit;
  final bool introDone;
  final int finiteCycles;
  final bool finiteDone;
  final int orbitCycles;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    return Padding(
      padding: const .fromLTRB(24, 18, 24, 8),
      child: Column(
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: .center,
            children: [
              _StatusChip(
                label: 'Intro',
                status: introDone ? 'settled' : 'playing',
                accent: false,
              ),
              _StatusChip(
                label: 'Pulse',
                status: finiteDone
                    ? '2 / 2 · done'
                    : '${math.min(finiteCycles, 2)} / 2',
                accent: !finiteDone,
              ),
              _StatusChip(
                label: 'Orbit',
                status: 'lap $orbitCycles · ∞',
                accent: false,
              ),
            ],
          ),
          Expanded(
            child: Center(
              child: SizedBox.square(
                dimension: 200,
                child: CustomPaint(
                  painter: _MixedInstrumentPainter(
                    intro: intro,
                    finite: finite,
                    orbit: orbit,
                    finiteDone: finiteDone,
                    palette: palette,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.status,
    required this.accent,
  });

  final String label;
  final String status;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: accent ? palette.accentSoft : palette.surface,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(color: accent ? palette.accent : palette.border),
        ),
      ),
      child: Padding(
        padding: const .symmetric(horizontal: 10, vertical: 4),
        child: Row(
          mainAxisSize: .min,
          children: [
            Text('$label ', style: mono(11, weight: 540, color: palette.text)),
            Text(
              status,
              style: mono(
                11,
                color: accent ? palette.accent : palette.textSecondary,
              ).copyWith(fontFeatures: const [.tabularFigures()]),
            ),
          ],
        ),
      ),
    );
  }
}

class _MixedInstrumentPainter extends CustomPainter {
  _MixedInstrumentPainter({
    required this.intro,
    required this.finite,
    required this.orbit,
    required this.finiteDone,
    required this.palette,
  });

  final double intro;
  final double finite;
  final double orbit;
  final bool finiteDone;
  final Palette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(.zero);
    final outer = size.shortestSide / 2 - 14;

    // Outer continuous orbit track.
    canvas.drawCircle(
      center,
      outer,
      Paint()
        ..color = palette.borderStrong
        ..style = .stroke
        ..strokeWidth = 2,
    );
    final angle = -math.pi / 2 + orbit * 2 * math.pi;
    final orbiter = center + Offset(math.cos(angle), math.sin(angle)) * outer;
    canvas.drawCircle(orbiter, 7, Paint()..color = palette.text);

    // Middle finite pulse halo (2 cycles in lockstep with orbit, then rests).
    final pulseRadius = 38 + finite.clamp(0.0, 1.0) * 28;
    canvas.drawCircle(
      center,
      pulseRadius,
      Paint()
        ..color = finiteDone ? palette.border : palette.accent
        ..style = .stroke
        ..strokeWidth = finiteDone ? 1.5 : 3,
    );

    // Inner one-shot intro core.
    final coreRadius = 8 + intro.clamp(0.0, 1.2) * 16;
    canvas.drawCircle(center, coreRadius, Paint()..color = palette.text);
  }

  @override
  bool shouldRepaint(_MixedInstrumentPainter oldDelegate) =>
      oldDelegate.intro != intro ||
      oldDelegate.finite != finite ||
      oldDelegate.orbit != orbit ||
      oldDelegate.finiteDone != finiteDone ||
      oldDelegate.palette != palette;
}
