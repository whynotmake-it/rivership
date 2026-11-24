import 'dart:math' as math;

import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/chapters.dart';
import 'package:motor_example/widgets/chapter_page.dart';
import 'package:motor_example/widgets/grab_detector.dart';
import 'package:motor_example/widgets/icons.dart';
import 'package:motor_example/widgets/style.dart';

/// Real UI patterns built with `.loop()`, `count:`, `together:`, and looping
/// phase timelines.
class LoopsPage extends StatefulWidget {
  const LoopsPage({super.key});

  @override
  State<LoopsPage> createState() => _LoopsPageState();
}

enum _LoopScene { upload, typing, bell, recording, slide }

class _LoopsPageState extends State<LoopsPage> {
  final _code = ValueNotifier('');
  var _scene = _LoopScene.upload;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _selectScene(_LoopScene scene) {
    if (_scene == scene) return;
    setState(() => _scene = scene);
  }

  @override
  Widget build(BuildContext context) {
    return ChapterPage(
      chapter: chapterNamed('Loops'),
      lead:
          'Wrap any slice of steps in .loop() to repeat it. Leave a loop with '
          'new steps or count:, lock siblings in step with together:, or loop '
          'a choreographed phase timeline.',
      code: _code,
      stageHeight: 420,
      stage: Column(
        children: [
          Expanded(
            child: switch (_scene) {
              .upload => _UploadScene(code: _code),
              .typing => _TypingScene(code: _code),
              .bell => _BellScene(code: _code),
              .recording => _RecordingScene(code: _code),
              .slide => _SlideScene(code: _code),
            },
          ),
          Padding(
            padding: const .fromLTRB(16, 0, 16, 16),
            child: Center(
              child: FittedBox(
                fit: .scaleDown,
                child: CoilTabs<_LoopScene>(
                  value: _scene,
                  onChanged: _selectScene,
                  tabs: const [
                    CoilTab(value: .upload, label: Text('Upload')),
                    CoilTab(value: .typing, label: Text('Typing')),
                    CoilTab(value: .bell, label: Text('Bell')),
                    CoilTab(value: .recording, label: Text('Recording')),
                    CoilTab(value: .slide, label: Text('Slide')),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 1. Upload button: intro, seamless spinner, finish lap into checkmark
// ---------------------------------------------------------------------------

enum _UploadState { idle, uploading, done }

const _pillSpring = Motion.cupertino(
  duration: Duration(milliseconds: 360),
  bounce: 0.14,
);
const _lap = Motion.linear(Duration(milliseconds: 900));
const _finishLap = Motion.curved(Duration(milliseconds: 340), easeOut);
const _checkDraw = Motion.curved(Duration(milliseconds: 280), easeOut);
const _labelFade = Motion.curved(Duration(milliseconds: 180), easeOut);

class _UploadScene extends StatefulWidget {
  const _UploadScene({required this.code});

  final ValueNotifier<String> code;

  @override
  State<_UploadScene> createState() => _UploadSceneState();
}

class _UploadSceneState extends State<_UploadScene> {
  final _buttonWidth = Track<double>(
    .single,
    initial: 168,
    motion: _pillSpring,
    debugLabel: 'Button width',
  );
  final _arcTurn = Track<double>(
    .single,
    initial: 0,
    motion: _finishLap,
    debugLabel: 'Arc turn',
  );
  final _checkStroke = Track<double>(
    .single,
    initial: 0,
    motion: _checkDraw,
    debugLabel: 'Check stroke',
  );
  final _labelOpacity = Track<double>(
    .single,
    initial: 1,
    motion: _labelFade,
    debugLabel: 'Label opacity',
  );

  var _state = _UploadState.idle;

  @override
  void initState() {
    super.initState();
    _syncCode();
  }

  void _syncCode() {
    widget.code.value =
        '// Seamless loop; ending it is just new steps on rebuild, with no snap.\n'
        'TrackBuilder(animations: [\n'
        '  buttonWidth([.to(state == .uploading ? 48 : 168)]),\n'
        '  arcTurn(switch (state) {\n'
        '    .uploading => [\n'
        '      .loop([.to(0, motion: .instant()), .to(1, motion: lap)], mode: .seamless),\n'
        '    ],\n'
        '    .done => [.to(1, motion: finishLap)],\n'
        '    .idle => [.to(0, motion: .instant())],\n'
        '  }),\n'
        '  checkStroke([.to(state == .done ? 1 : 0)]),\n'
        '])';
  }

  void _tapPill() {
    setState(() {
      _state = switch (_state) {
        .idle => .uploading,
        .uploading => .done,
        .done => .idle,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final text = CoilTheme.textOf(context);
    final uploading = _state == .uploading;
    final done = _state == .done;

    return Padding(
      padding: const .fromLTRB(24, 24, 24, 12),
      child: Column(
        mainAxisAlignment: .center,
        children: [
          TrackBuilder(
            debugLabel: 'Upload button',
            animations: [
              _buttonWidth([.to(uploading ? 48 : 168)]),
              _arcTurn(switch (_state) {
                .uploading => const [
                  .loop([
                    .to(0, motion: .instant()),
                    .to(1, motion: _lap),
                  ], mode: .seamless),
                ],
                .done => const [.to(1, motion: _finishLap)],
                .idle => const [.to(0, motion: .instant())],
              }),
              _checkStroke([
                if (done) const .hold(Duration(milliseconds: 140)),
                .to(done ? 1 : 0),
              ]),
              _labelOpacity([
                if (!uploading) const .hold(Duration(milliseconds: 120)),
                .to(uploading ? 0 : 1),
              ]),
            ],
            builder: (context, values, _) {
              final width = values(_buttonWidth).clamp(48.0, 220.0);
              final turn = values(_arcTurn);
              final check = values(_checkStroke).clamp(0.0, 1.0);
              final labelAlpha = values(_labelOpacity).clamp(0.0, 1.0);
              return GestureDetector(
                onTap: _tapPill,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    width: width,
                    height: 48,
                    decoration: ShapeDecoration(
                      color: done ? palette.accent : palette.text,
                      shape: const StadiumBorder(),
                    ),
                    clipBehavior: .antiAlias,
                    child: Stack(
                      alignment: .center,
                      children: [
                        if (uploading)
                          SizedBox(
                            width: 26,
                            height: 26,
                            child: CustomPaint(
                              painter: _UploadArcPainter(
                                turn: turn,
                                check: 0,
                                color: palette.canvas,
                              ),
                            ),
                          ),
                        if (labelAlpha > 0.01)
                          Opacity(
                            opacity: labelAlpha,
                            child: OverflowBox(
                              minWidth: 168,
                              maxWidth: 168,
                              child: Row(
                                mainAxisAlignment: .center,
                                children: [
                                  if (done)
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CustomPaint(
                                        painter: _UploadArcPainter(
                                          turn: turn,
                                          check: check,
                                          color: palette.onAccent,
                                        ),
                                      ),
                                    )
                                  else
                                    IconTheme(
                                      data: IconThemeData(
                                        size: 18,
                                        color: palette.canvas,
                                      ),
                                      child: const GlyphIcon(Glyph.cloudUpload),
                                    ),
                                  const SizedBox(width: 8),
                                  Text(
                                    done ? 'Done' : 'Upload',
                                    style: text.body.copyWith(
                                      fontWeight: text.emphasis,
                                      color: done
                                          ? palette.onAccent
                                          : palette.canvas,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: .center,
            children: [
              if (_state == .idle)
                CoilButton(
                  variant: .secondary,
                  onPressed: () => setState(() => _state = .uploading),
                  child: const Text('Start upload'),
                )
              else if (_state == .uploading)
                CoilButton(
                  variant: .secondary,
                  onPressed: () => setState(() => _state = .done),
                  child: const Text('Finish upload'),
                )
              else
                CoilButton(
                  variant: .secondary,
                  leading: const GlyphIcon(Glyph.rotateCcw),
                  onPressed: () => setState(() => _state = .idle),
                  child: const Text('Reset'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            switch (_state) {
              .idle => 'Tap Upload to start the seamless spinner.',
              .uploading => 'Tap Finish mid-lap: arc completes its turn without snapping.',
              .done => 'Lap finished smoothly and morphed into Done.',
            },
            textAlign: .center,
            style: text.muted.caption,
          ),
        ],
      ),
    );
  }
}

class _UploadArcPainter extends CustomPainter {
  _UploadArcPainter({
    required this.turn,
    required this.check,
    required this.color,
  });

  final double turn;
  final double check;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final center = size.center(.zero);
    final radius = math.max(0.0, size.shortestSide / 2 - 2.5);

    if (check < 0.99 && radius > 0) {
      final arcAlpha = (1 - check).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = color.withValues(alpha: arcAlpha)
        ..style = .stroke
        ..strokeWidth = 2.4
        ..strokeCap = .round;
      final startAngle = -math.pi / 2 + turn * 2 * math.pi;
      const sweepAngle = math.pi * 1.45;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }

    if (check > 0.01) {
      final path = Path()
        ..moveTo(size.width * 0.2, size.height * 0.54)
        ..lineTo(size.width * 0.42, size.height * 0.74)
        ..lineTo(size.width * 0.82, size.height * 0.3);
      final metric = path.computeMetrics().first;
      final drawn = metric.extractPath(0, metric.length * check);
      canvas.drawPath(
        drawn,
        Paint()
          ..color = color
          ..style = .stroke
          ..strokeWidth = 2.4
          ..strokeCap = .round
          ..strokeJoin = .round,
      );
    }
  }

  @override
  bool shouldRepaint(_UploadArcPainter oldDelegate) =>
      oldDelegate.turn != turn ||
      oldDelegate.check != check ||
      oldDelegate.color != color;
}

// ---------------------------------------------------------------------------
// 2. Typing indicator: intro + staggered hold inside a together loop
// ---------------------------------------------------------------------------

const _dotPop = Motion.cupertino(
  duration: Duration(milliseconds: 300),
  bounce: 0.25,
);
const _dotBounce = Motion.curved(
  Duration(milliseconds: 240),
  Curves.easeInOutCubic,
);

class _TypingScene extends StatefulWidget {
  const _TypingScene({required this.code});

  final ValueNotifier<String> code;

  @override
  State<_TypingScene> createState() => _TypingSceneState();
}

class _TypingSceneState extends State<_TypingScene> {
  final _bubbleScale = Track<double>(
    .single,
    initial: 0.86,
    motion: _dotPop,
    debugLabel: 'Bubble scale',
  );
  final _dotLift = [
    for (var i = 0; i < 3; i++)
      Track<double>(
        .single,
        initial: 10,
        motion: _dotPop,
        debugLabel: 'Dot ${i + 1}',
      ),
  ];

  var _typing = true;
  var _keepInStep = true;
  var _restart = 0;

  @override
  void initState() {
    super.initState();
    _syncCode();
  }

  void _syncCode() {
    final togetherArg = _keepInStep ? ', together: #typing' : '';
    widget.code.value =
        '// Intro runs once; hold repeats every cycle; together keeps the wave in step.\n'
        'for (final (i, dot) in dotLift.indexed)\n'
        '  dot([\n'
        '    .to(0, motion: pop),\n'
        '    .loop([\n'
        '      .hold(Duration(milliseconds: 120 * i)),\n'
        '      .to(-6, motion: bounce),\n'
        '      .to(0, motion: bounce),\n'
        '    ]$togetherArg),\n'
        '  ]),';
  }

  void _toggleTogether(bool value) {
    setState(() {
      _keepInStep = value;
      _restart++;
    });
    _syncCode();
  }

  void _toggleTyping() {
    setState(() {
      _typing = !_typing;
      if (_typing) _restart++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final text = CoilTheme.textOf(context);
    final token = _keepInStep ? #typing : null;

    return Padding(
      padding: const .fromLTRB(24, 20, 24, 12),
      child: Column(
        mainAxisAlignment: .center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Column(
              crossAxisAlignment: .stretch,
              children: [
                Align(
                  alignment: .centerRight,
                  child: Container(
                    padding: const .symmetric(horizontal: 14, vertical: 10),
                    decoration: ShapeDecoration(
                      color: palette.text,
                      shape: RoundedSuperellipseBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text(
                      'Shipping loops today?',
                      style: text.caption.copyWith(color: palette.canvas),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: .centerLeft,
                  child: TrackBuilder(
                    debugLabel: 'Typing indicator',
                    restartTrigger: _restart,
                    initialValues: [
                      _bubbleScale.value(0.86),
                      for (final dot in _dotLift) dot.value(10),
                    ],
                    animations: [
                      _bubbleScale([.to(_typing ? 1 : 0.86)]),
                      for (final (i, dot) in _dotLift.indexed)
                        dot(
                          _typing
                              ? [
                                  const .to(0, motion: _dotPop),
                                  .loop([
                                    .hold(Duration(milliseconds: 120 * i)),
                                    const .to(-6, motion: _dotBounce),
                                    const .to(0, motion: _dotBounce),
                                  ], together: token),
                                ]
                              : const [.to(0, motion: _dotBounce)],
                        ),
                    ],
                    builder: (context, values, _) {
                      final scale = values(_bubbleScale).clamp(0.75, 1.15);
                      return Transform.scale(
                        scale: scale,
                        alignment: .bottomLeft,
                        child: Opacity(
                          opacity: _typing ? 1 : 0.45,
                          child: Container(
                            padding: const .symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: ShapeDecoration(
                              color: palette.surface,
                              shape: RoundedSuperellipseBorder(
                                borderRadius: BorderRadius.circular(18),
                                side: BorderSide(color: palette.border),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: .min,
                              children: [
                                for (final (i, dot) in _dotLift.indexed) ...[
                                  if (i > 0) const SizedBox(width: 7),
                                  Transform.translate(
                                    offset: Offset(0, values(dot)),
                                    child: Container(
                                      width: 9,
                                      height: 9,
                                      decoration: BoxDecoration(
                                        color: palette.text,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 10,
            crossAxisAlignment: .center,
            alignment: .center,
            children: [
              CoilSwitch(
                value: _keepInStep,
                onChanged: _toggleTogether,
                label: const Text('together: #typing'),
              ),
              CoilButton(
                variant: .secondary,
                onPressed: _toggleTyping,
                child: Text(_typing ? 'Stop typing' : 'Start typing'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _keepInStep
                ? 'Earlier dots wait at the end of each cycle so the wave stays in step.'
                : 'Without together, different stagger holds drift the dots out of phase.',
            textAlign: .center,
            style: text.muted.caption,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. Notification bell: finite pingPong count, then settle to rest
// ---------------------------------------------------------------------------

const _badgePop = Motion.cupertino(
  duration: Duration(milliseconds: 360),
  bounce: 0.42,
);
const _bellSwing = Motion.curved(
  Duration(milliseconds: 110),
  Curves.easeInOutSine,
);
const _bellRest = Motion.cupertino(
  duration: Duration(milliseconds: 340),
  bounce: 0.25,
);

class _BellScene extends StatefulWidget {
  const _BellScene({required this.code});

  final ValueNotifier<String> code;

  @override
  State<_BellScene> createState() => _BellSceneState();
}

class _BellSceneState extends State<_BellScene>
    with SingleTickerProviderStateMixin {
  late final _controller = TrackController(
    vsync: this,
    debugLabel: 'Notification bell',
  );
  final _badgeScale = Track<double>(
    .single,
    initial: 0,
    motion: _badgePop,
    debugLabel: 'Badge scale',
  );
  final _bellAngle = Track<double>(
    .single,
    initial: 0,
    motion: _bellSwing,
    debugLabel: 'Bell angle',
  );

  var _unread = 1;
  var _rings = 3;
  var _ringing = false;
  var _runId = 0;

  @override
  void initState() {
    super.initState();
    _syncCode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ring(increment: false);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _syncCode() {
    widget.code.value =
        '// Finite pingPong loop runs $_rings times, then hands off to the rest step.\n'
        'controller.animate([\n'
        '  badgeScale([.to(1, motion: pop)]),\n'
        '  bellAngle([\n'
        '    .loop([.to(-0.25), .to(0.25)], mode: .pingPong, count: $_rings),\n'
        '    .to(0, motion: settle),\n'
        '  ]),\n'
        ']);';
  }

  void _ring({required bool increment}) {
    final runId = ++_runId;
    setState(() {
      if (increment) _unread++;
      _ringing = true;
    });
    _controller.set([_badgeScale.value(0.45), _bellAngle.value(0)]);
    final future = _controller.animate([
      _badgeScale([const .to(1, motion: _badgePop)]),
      _bellAngle([
        .loop(
          const [.to(-0.26, motion: _bellSwing), .to(0.26, motion: _bellSwing)],
          mode: .pingPong,
          count: _rings,
        ),
        const .to(0, motion: _bellRest),
      ]),
    ]);
    future.orCancel.then((_) {
      if (mounted && _runId == runId) {
        setState(() => _ringing = false);
      }
    }, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final text = CoilTheme.textOf(context);

    return Padding(
      padding: const .fromLTRB(24, 24, 24, 12),
      child: Column(
        mainAxisAlignment: .center,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final angle = _controller.value(_bellAngle);
              final scale = _controller.value(_badgeScale).clamp(0.0, 1.5);
              return Container(
                width: 84,
                height: 84,
                decoration: ShapeDecoration(
                  color: palette.surface,
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: BorderSide(color: palette.border),
                  ),
                ),
                child: Stack(
                  clipBehavior: .none,
                  alignment: .center,
                  children: [
                    Transform.rotate(
                      angle: angle,
                      alignment: const Alignment(0, -0.55),
                      child: IconTheme(
                        data: IconThemeData(size: 36, color: palette.text),
                        child: GlyphIcon(
                          _ringing ? Glyph.bellRing : Glyph.bell,
                        ),
                      ),
                    ),
                    Positioned(
                      top: -6,
                      right: -6,
                      child: Transform.scale(
                        scale: scale,
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 26,
                            minHeight: 26,
                          ),
                          padding: const .symmetric(horizontal: 7),
                          decoration: ShapeDecoration(
                            color: palette.accent,
                            shape: const StadiumBorder(),
                          ),
                          alignment: .center,
                          child: Text(
                            '$_unread',
                            style: mono(
                              12,
                              weight: 600,
                              color: palette.onAccent,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: .center,
            alignment: .center,
            children: [
              CoilButton(
                onPressed: () => _ring(increment: true),
                leading: const GlyphIcon(Glyph.bellRing),
                child: const Text('New message'),
              ),
              FittedBox(
                fit: .scaleDown,
                child: CoilTabs<int>(
                  value: _rings,
                  onChanged: (rings) {
                    setState(() => _rings = rings);
                    _syncCode();
                    _ring(increment: false);
                  },
                  tabs: const [
                    CoilTab(value: 1, label: Text('1×')),
                    CoilTab(value: 2, label: Text('2×')),
                    CoilTab(value: 3, label: Text('3×')),
                    CoilTab(value: 5, label: Text('5×')),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _ringing
                ? 'Ringing $_rings× then handing off to .to(0)…'
                : 'Settled cleanly at rest.',
            textAlign: .center,
            style: text.muted.caption,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4. Recording pill: independent organic loops + reduced motion (`active`)
// ---------------------------------------------------------------------------

const _recRed = Color(0xFFE5484D);
const _breath = Motion.curved(
  Duration(milliseconds: 680),
  Curves.easeInOutSine,
);
const _barMotions = [
  Motion.curved(Duration(milliseconds: 310), Curves.easeInOutSine),
  Motion.curved(Duration(milliseconds: 440), Curves.easeInOutSine),
  Motion.curved(Duration(milliseconds: 270), Curves.easeInOutSine),
  Motion.curved(Duration(milliseconds: 520), Curves.easeInOutSine),
  Motion.curved(Duration(milliseconds: 370), Curves.easeInOutSine),
];
const _barSettle = Motion.curved(Duration(milliseconds: 240), easeOut);

class _RecordingScene extends StatefulWidget {
  const _RecordingScene({required this.code});

  final ValueNotifier<String> code;

  @override
  State<_RecordingScene> createState() => _RecordingSceneState();
}

class _RecordingSceneState extends State<_RecordingScene> {
  final _dotGlow = Track<double>(
    .single,
    initial: 0.4,
    motion: _breath,
    debugLabel: 'Dot glow',
  );
  final _barHeight = [
    for (var i = 0; i < 5; i++)
      Track<double>(
        .single,
        initial: 0.3,
        motion: _barMotions[i],
        debugLabel: 'Bar ${i + 1}',
      ),
  ];

  var _recording = true;
  var _reducedMotion = false;

  @override
  void initState() {
    super.initState();
    _syncCode();
  }

  void _syncCode() {
    widget.code.value =
        '// Loops without together drift organically; active: false jumps to rest.\n'
        'TrackBuilder(\n'
        '  active: !reducedMotion,\n'
        '  animations: [\n'
        '    dotGlow([.loop([.to(1), .to(0.4)], mode: .pingPong)]),\n'
        '    for (final (i, bar) in barHeight.indexed)\n'
        '      bar([.loop([.to(1, motion: barMotions[i]), .to(0.3, motion: barMotions[i])])]),\n'
        '  ],\n'
        ')';
  }

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final text = CoilTheme.textOf(context);
    final systemReduced = MediaQuery.disableAnimationsOf(context);
    final active = !(_reducedMotion || systemReduced);

    return Padding(
      padding: const .fromLTRB(24, 24, 24, 12),
      child: Column(
        mainAxisAlignment: .center,
        children: [
          TrackBuilder(
            debugLabel: 'Recording pill',
            active: active,
            animations: [
              _dotGlow(
                _recording
                    ? const [.loop([.to(1), .to(0.4)], mode: .pingPong)]
                    : const [.to(0.4, motion: _barSettle)],
              ),
              for (final (i, bar) in _barHeight.indexed)
                bar(
                  _recording
                      ? [
                          .loop([
                            .to(1, motion: _barMotions[i]),
                            .to(0.28, motion: _barMotions[i]),
                          ]),
                        ]
                      : const [.to(0.28, motion: _barSettle)],
                ),
            ],
            builder: (context, values, _) {
              final glow = values(_dotGlow).clamp(0.0, 1.0);
              return Container(
                padding: const .symmetric(horizontal: 18, vertical: 12),
                decoration: ShapeDecoration(
                  color: palette.surface,
                  shape: StadiumBorder(
                    side: BorderSide(color: palette.border),
                  ),
                ),
                child: Row(
                  mainAxisSize: .min,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: Stack(
                        alignment: .center,
                        children: [
                          if (_recording)
                            Container(
                              width: 10 + 8 * glow,
                              height: 10 + 8 * glow,
                              decoration: BoxDecoration(
                                color: _recRed.withValues(alpha: 0.25 * glow),
                                shape: BoxShape.circle,
                              ),
                            ),
                          Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: _recRed.withValues(
                                alpha: _recording ? 0.45 + 0.55 * glow : 0.35,
                              ),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _recording ? 'REC' : 'IDLE',
                      style: mono(
                        12,
                        weight: 600,
                        spacing: 0.8,
                        color: palette.text,
                      ),
                    ),
                    const SizedBox(width: 14),
                    SizedBox(
                      height: 24,
                      child: Row(
                        mainAxisSize: .min,
                        children: [
                          for (final (i, bar) in _barHeight.indexed) ...[
                            if (i > 0) const SizedBox(width: 4),
                            Container(
                              width: 3.5,
                              height: 6 + 18 * values(bar).clamp(0.0, 1.0),
                              decoration: ShapeDecoration(
                                color: palette.text,
                                shape: const StadiumBorder(),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 10,
            crossAxisAlignment: .center,
            alignment: .center,
            children: [
              CoilButton(
                variant: .secondary,
                onPressed: () => setState(() => _recording = !_recording),
                child: Text(_recording ? 'Stop recording' : 'Record'),
              ),
              CoilSwitch(
                value: _reducedMotion,
                onChanged: (value) => setState(() => _reducedMotion = value),
                label: const Text('Reduced motion'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            active
                ? 'Five prime-ish durations drift apart on purpose for an organic meter.'
                : 'active: false jumps every looping track straight to its resting value.',
            textAlign: .center,
            style: text.muted.caption,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 5. "Slide to unlock" hint: looping PhaseTrackBuilder paused while dragging
// ---------------------------------------------------------------------------

enum _SlideHint { rest, nudge, shimmer }

const _thumbSpring = Motion.cupertino(
  duration: Duration(milliseconds: 380),
  bounce: 0.16,
);
const _shimmerSweep = Motion.curved(
  Duration(milliseconds: 900),
  Curves.easeInOut,
);

class _SlideScene extends StatefulWidget {
  const _SlideScene({required this.code});

  final ValueNotifier<String> code;

  @override
  State<_SlideScene> createState() => _SlideSceneState();
}

class _SlideSceneState extends State<_SlideScene> {
  final _thumbX = Track<double>(
    .single,
    initial: 0,
    motion: _thumbSpring,
    debugLabel: 'Thumb X',
  );
  final _shimmer = Track<double>(
    .single,
    initial: 0,
    motion: _shimmerSweep,
    debugLabel: 'Shimmer',
  );

  late final _timeline = TrackPhaseTimeline<_SlideHint>(
    {
      .rest: [
        _thumbX([
          const .to(0, motion: _thumbSpring),
          const .hold(Duration(milliseconds: 360)),
        ]),
        _shimmer([const .to(0, motion: .instant())]),
      ],
      .nudge: [
        _thumbX([
          const .to(24, motion: _thumbSpring, until: .ended),
        ]),
      ],
      .shimmer: [
        _shimmer([
          const .to(0, motion: .instant()),
          const .to(1, motion: _shimmerSweep),
        ]),
      ],
    },
    loop: .loop,
  );

  var _dragging = false;
  var _unlocked = false;
  double _dragX = 0;

  @override
  void initState() {
    super.initState();
    widget.code.value =
        '// Choreographed phases loop with momentum; playing: false pauses on drag.\n'
        'PhaseTrackBuilder(\n'
        '  playing: !dragging && !unlocked,\n'
        '  timeline: TrackPhaseTimeline({\n'
        '    .rest:    [thumbX([.to(0), .hold(360ms)])],\n'
        '    .nudge:   [thumbX([.to(24, until: .ended)])],\n'
        '    .shimmer: [shimmer([.to(0, motion: .instant()), .to(1, motion: sweep)])],\n'
        '  }, loop: .loop),\n'
        ')';
  }

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final text = CoilTheme.textOf(context);
    const thumbSize = 44.0;
    const pad = 4.0;

    return Padding(
      padding: const .fromLTRB(24, 24, 24, 12),
      child: Column(
        mainAxisAlignment: .center,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final trackWidth = math.min(268.0, constraints.maxWidth);
              final maxTravel = math.max(0.0, trackWidth - thumbSize - pad * 2);

              if (_unlocked) {
                return Container(
                  width: trackWidth,
                  height: thumbSize + pad * 2,
                  decoration: ShapeDecoration(
                    color: palette.accent,
                    shape: const StadiumBorder(),
                  ),
                  alignment: .center,
                  child: Row(
                    mainAxisSize: .min,
                    children: [
                      IconTheme(
                        data: IconThemeData(size: 18, color: palette.onAccent),
                        child: const GlyphIcon(Glyph.check),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Unlocked',
                        style: text.body.copyWith(
                          fontWeight: text.emphasis,
                          color: palette.onAccent,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return PhaseTrackBuilder<_SlideHint>(
                debugLabel: 'Slide hint',
                playing: !_dragging,
                currentPhase: .rest,
                timeline: _timeline,
                builder: (context, values, _, _) {
                  final hintX = values(_thumbX).clamp(0.0, maxTravel);
                  final x = _dragging ? _dragX.clamp(0.0, maxTravel) : hintX;
                  final shimmer = _dragging
                      ? 0.0
                      : values(_shimmer).clamp(0.0, 1.0);
                  final fade = maxTravel > 0
                      ? (1 - (x / maxTravel) * 1.4).clamp(0.0, 1.0)
                      : 1.0;

                  return Container(
                    width: trackWidth,
                    height: thumbSize + pad * 2,
                    padding: const .all(pad),
                    decoration: ShapeDecoration(
                      color: palette.surface,
                      shape: StadiumBorder(
                        side: BorderSide(color: palette.border),
                      ),
                    ),
                    child: Stack(
                      alignment: .centerLeft,
                      children: [
                        Center(
                          child: Opacity(
                            opacity: fade,
                            child: Padding(
                              padding: const .only(left: 24),
                              child: ShaderMask(
                                blendMode: BlendMode.srcIn,
                                shaderCallback: (bounds) {
                                  final sweepPos = -0.3 + shimmer * 1.6;
                                  return LinearGradient(
                                    colors: [
                                      palette.textTertiary,
                                      palette.text,
                                      palette.textTertiary,
                                    ],
                                    stops: [
                                      (sweepPos - 0.22).clamp(0.0, 1.0),
                                      sweepPos.clamp(0.0, 1.0),
                                      (sweepPos + 0.22).clamp(0.0, 1.0),
                                    ],
                                  ).createShader(bounds);
                                },
                                child: Text(
                                  'Slide to unlock',
                                  maxLines: 1,
                                  overflow: .ellipsis,
                                  style: text.caption.copyWith(
                                    fontWeight: text.emphasis,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Transform.translate(
                          offset: Offset(x, 0),
                          child: GrabDetector(
                            onStart: (_) {
                              setState(() {
                                _dragging = true;
                                _dragX = hintX;
                              });
                            },
                            onUpdate: (details) {
                              setState(() {
                                _dragX = (_dragX + details.delta.dx).clamp(
                                  0.0,
                                  maxTravel,
                                );
                              });
                            },
                            onEnd: (_) {
                              setState(() {
                                if (maxTravel > 0 &&
                                    _dragX >= maxTravel * 0.78) {
                                  _unlocked = true;
                                }
                                _dragging = false;
                                _dragX = 0;
                              });
                            },
                            onCancel: () {
                              setState(() {
                                _dragging = false;
                                _dragX = 0;
                              });
                            },
                            child: MouseRegion(
                              cursor: _dragging
                                  ? SystemMouseCursors.grabbing
                                  : SystemMouseCursors.grab,
                              child: Container(
                                width: thumbSize,
                                height: thumbSize,
                                decoration: BoxDecoration(
                                  color: palette.text,
                                  shape: BoxShape.circle,
                                ),
                                alignment: .center,
                                child: IconTheme(
                                  data: IconThemeData(
                                    size: 18,
                                    color: palette.canvas,
                                  ),
                                  child: const GlyphIcon(Glyph.arrowRight),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 22),
          if (_unlocked)
            CoilButton(
              variant: .secondary,
              leading: const GlyphIcon(Glyph.rotateCcw),
              onPressed: () => setState(() => _unlocked = false),
              child: const Text('Lock again'),
            )
          else
            Text(
              _dragging
                  ? 'Hint paused — drag past the end to unlock.'
                  : 'Grab the handle to pause the looping phase hint.',
              textAlign: .center,
              style: text.muted.caption,
            ),
        ],
      ),
    );
  }
}
