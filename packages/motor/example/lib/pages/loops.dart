import 'dart:math' as math;

import 'package:coil/coil.dart';
import 'package:flutter/scheduler.dart' show timeDilation;
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/chapters.dart';
import 'package:motor_example/widgets/chapter_page.dart';
import 'package:motor_example/widgets/grab_detector.dart';
import 'package:motor_example/widgets/icons.dart';
import 'package:motor_example/widgets/style.dart';

/// Four scenes, each isolating one loop transition: entering and leaving a
/// seamless loop, a counted ping-pong, lockstep siblings, and a looping phase
/// timeline that hands the same track to a drag and back.
class LoopsPage extends StatefulWidget {
  const LoopsPage({super.key});

  @override
  State<LoopsPage> createState() => _LoopsPageState();
}

enum _LoopScene { spinner, bell, typing, slide }

class _LoopsPageState extends State<LoopsPage> {
  final _code = ValueNotifier('');
  var _scene = _LoopScene.spinner;
  var _slowMotion = false;

  @override
  void dispose() {
    timeDilation = 1;
    _code.dispose();
    super.dispose();
  }

  void _setSlowMotion(bool value) {
    setState(() => _slowMotion = value);
    timeDilation = value ? 5 : 1;
  }

  @override
  Widget build(BuildContext context) {
    return ChapterPage(
      chapter: chapterNamed('Loops'),
      lead:
          'Wrap any slice of steps in .loop() to repeat it. Each scene isolates '
          'one way in or out of a loop; turn on slow motion to check that '
          'nothing jumps.',
      code: _code,
      stageHeight: 420,
      stage: Column(
        children: [
          Expanded(
            child: switch (_scene) {
              .spinner => _SpinnerScene(code: _code),
              .bell => _BellScene(code: _code),
              .typing => _TypingScene(code: _code),
              .slide => _SlideScene(code: _code),
            },
          ),
          Padding(
            padding: const .fromLTRB(16, 0, 16, 16),
            child: Wrap(
              spacing: 16,
              runSpacing: 10,
              alignment: .center,
              crossAxisAlignment: .center,
              children: [
                FittedBox(
                  fit: .scaleDown,
                  child: CoilTabs<_LoopScene>(
                    value: _scene,
                    onChanged: (scene) => setState(() => _scene = scene),
                    tabs: const [
                      CoilTab(value: .spinner, label: Text('Spinner')),
                      CoilTab(value: .bell, label: Text('Bell')),
                      CoilTab(value: .typing, label: Text('Typing')),
                      CoilTab(value: .slide, label: Text('Slide')),
                    ],
                  ),
                ),
                CoilSwitch(
                  value: _slowMotion,
                  onChanged: _setSlowMotion,
                  label: const Text('Slow motion'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Lays out a scene: the subject, its controls, and what to notice.
class _SceneLayout extends StatelessWidget {
  const _SceneLayout({
    required this.subject,
    required this.controls,
    required this.notice,
  });

  final Widget subject;
  final Widget controls;
  final String notice;

  @override
  Widget build(BuildContext context) {
    final text = CoilTheme.textOf(context);
    return Padding(
      padding: const .fromLTRB(24, 24, 24, 12),
      child: Column(
        mainAxisAlignment: .center,
        children: [
          subject,
          const SizedBox(height: 32),
          controls,
          const SizedBox(height: 12),
          Text(notice, textAlign: .center, style: text.muted.caption),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 1. Spinner: ease into a seamless loop, finish the lap, rest, fade
// ---------------------------------------------------------------------------

const _lapTime = Duration(milliseconds: 900);
const _lap = Motion.linear(_lapTime);
const _appear = Motion.smoothSpring(duration: Duration(milliseconds: 420));
const _fade = Motion.curved(Duration(milliseconds: 320), Curves.easeOut);

class _SpinnerScene extends StatefulWidget {
  const _SpinnerScene({required this.code});

  final ValueNotifier<String> code;

  @override
  State<_SpinnerScene> createState() => _SpinnerSceneState();
}

class _SpinnerSceneState extends State<_SpinnerScene>
    with SingleTickerProviderStateMixin {
  late final _controller = TrackController(vsync: this, debugLabel: 'Spinner');

  /// Turns of the arc. A whole turn looks the same as none.
  final _arcTurn = Track<double>(.single, initial: 0, debugLabel: 'Arc turn');

  /// How present the arc is: 0 hidden, 1 shown.
  final _arcReveal = Track<double>(
    .single,
    initial: 0,
    debugLabel: 'Arc reveal',
  );

  var _spinning = false;

  @override
  void initState() {
    super.initState();
    widget.code.value =
        '// Start: ease in, then repeat one lap. The jump back is a whole turn.\n'
        'arcReveal([.to(1, motion: appear)]),\n'
        'arcTurn([\n'
        '  .loop([.to(0, motion: .instant()), .to(1, motion: lap)],\n'
        '      mode: .seamless),\n'
        ']),\n'
        '\n'
        '// Stop: finish the lap at lap speed, come to rest, then fade.\n'
        'final brake = lapTime * (2 * (home - turn));\n'
        'arcTurn([.to(home, motion: .curved(brake, Curves.decelerate))]),\n'
        'arcReveal([.hold(brake), .to(0, motion: fade)]),';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _start() {
    setState(() => _spinning = true);
    // Stopped mid-brake? Finish that turn at lap speed before looping, so the
    // loop's jump back to 0 lands on a whole turn.
    final turn = _controller.value(_arcTurn);
    final home = turn.ceilToDouble();
    _controller.animate([
      _arcReveal([const .to(1, motion: _appear)]),
      _arcTurn([
        if (home > turn) .to(home, motion: .linear(_lapTime * (home - turn))),
        const .loop([
          .to(0, motion: .instant()),
          .to(1, motion: _lap),
        ], mode: .seamless),
      ]),
    ]);
  }

  void _stop() {
    setState(() => _spinning = false);
    final turn = _controller.value(_arcTurn);
    // The next whole turn, unless it is too close to brake into gently.
    var home = turn.floorToDouble() + 1;
    if (home - turn < 0.25) home += 1;
    // Curves.decelerate starts at twice its average speed, so this length
    // starts the brake at exactly lap speed.
    final brake = _lapTime * (2 * (home - turn));
    _controller.animate([
      _arcTurn([.to(home, motion: .curved(brake, Curves.decelerate))]),
      _arcReveal([.hold(brake), const .to(0, motion: _fade)]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    return _SceneLayout(
      subject: SizedBox.square(
        dimension: 56,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final reveal = _controller.value(_arcReveal).clamp(0.0, 1.0);
            return Opacity(
              opacity: reveal,
              child: Transform.scale(
                scale: 0.6 + 0.4 * reveal,
                child: Transform.rotate(
                  angle: _controller.value(_arcTurn) * 2 * math.pi,
                  child: CustomPaint(
                    painter: _ArcPainter(color: palette.text),
                    size: const Size.square(56),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      controls: Wrap(
        spacing: 10,
        runSpacing: 8,
        alignment: .center,
        children: [
          CoilButton(
            variant: .secondary,
            leading: const GlyphIcon(Glyph.play),
            onPressed: _spinning ? null : _start,
            child: const Text('Start'),
          ),
          CoilButton(
            variant: .secondary,
            leading: const GlyphIcon(Glyph.pause),
            onPressed: _spinning ? _stop : null,
            child: const Text('Stop'),
          ),
        ],
      ),
      notice:
          'Stop mid-lap: the arc keeps its speed, finishes the turn, then '
          'fades.',
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: size.center(.zero),
      radius: size.shortestSide / 2 - 3,
    );
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 1.5,
      false,
      Paint()
        ..color = color
        ..style = .stroke
        ..strokeWidth = 4
        ..strokeCap = .round,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter oldDelegate) => oldDelegate.color != color;
}

// ---------------------------------------------------------------------------
// 2. Bell: a counted ping-pong, then a step out of the loop
// ---------------------------------------------------------------------------

const _ringAngle = 0.32;
const _swing = Motion.smoothSpring(duration: Duration(milliseconds: 200));
const _settle = Motion.cupertino(
  duration: Duration(milliseconds: 420),
  bounce: 0.3,
);

class _BellScene extends StatefulWidget {
  const _BellScene({required this.code});

  final ValueNotifier<String> code;

  @override
  State<_BellScene> createState() => _BellSceneState();
}

class _BellSceneState extends State<_BellScene>
    with SingleTickerProviderStateMixin {
  late final _controller = TrackController(vsync: this, debugLabel: 'Bell');

  /// The bell's tilt in radians, pivoting at its top.
  final _bellAngle = Track<double>(.single, initial: 0, debugLabel: 'Angle');

  @override
  void initState() {
    super.initState();
    widget.code.value =
        '// Three round trips, then a step out of the loop.\n'
        '// Tapping again restarts from the current angle and speed.\n'
        'controller.animate([\n'
        '  bellAngle([\n'
        '    .loop([\n'
        '      .to(-ring, motion: swing, until: .ended),\n'
        '      .to(ring, motion: swing, until: .ended),\n'
        '    ], mode: .pingPong, count: 3),\n'
        '    .to(0, motion: settle),\n'
        '  ]),\n'
        ']);';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _ring() {
    _controller.animate([
      _bellAngle(const [
        .loop(
          [
            .to(-_ringAngle, motion: _swing, until: .ended),
            .to(_ringAngle, motion: _swing, until: .ended),
          ],
          mode: .pingPong,
          count: 3,
        ),
        .to(0, motion: _settle),
      ]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    return _SceneLayout(
      subject: GestureDetector(
        onTap: _ring,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) => Transform.rotate(
              angle: _controller.value(_bellAngle),
              alignment: const Alignment(0, -0.8),
              child: child,
            ),
            child: IconTheme(
              data: IconThemeData(size: 64, color: palette.text),
              child: const GlyphIcon(Glyph.bell),
            ),
          ),
        ),
      ),
      controls: CoilButton(
        variant: .secondary,
        onPressed: _ring,
        child: const Text('Ring'),
      ),
      notice: 'Ring again mid-swing: the bell carries on from where it is.',
    );
  }
}

// ---------------------------------------------------------------------------
// 3. Typing dots: a staggered hold inside the loop, kept in step by together
// ---------------------------------------------------------------------------

const _dotStagger = Duration(milliseconds: 140);
const _dotLiftHeight = 8.0;
const _bounce = Motion.curved(
  Duration(milliseconds: 260),
  Curves.easeInOutSine,
);
const _land = Motion.smoothSpring(duration: Duration(milliseconds: 260));

class _TypingScene extends StatefulWidget {
  const _TypingScene({required this.code});

  final ValueNotifier<String> code;

  @override
  State<_TypingScene> createState() => _TypingSceneState();
}

class _TypingSceneState extends State<_TypingScene> {
  /// How far each dot is lifted, in logical pixels upward.
  final _dotLift = [
    for (var i = 0; i < 3; i++)
      Track<double>(.single, initial: 0, debugLabel: 'Dot ${i + 1} lift'),
  ];

  var _inStep = true;

  @override
  void initState() {
    super.initState();
    _syncCode();
  }

  void _syncCode() {
    final together = _inStep ? ', together: #typing' : '';
    widget.code.value =
        '// Each dot waits its turn inside the loop. Uneven waits make\n'
        '// uneven cycles; together: makes every dot wait for the last one.\n'
        'for (final (i, dot) in dotLift.indexed)\n'
        '  dot([\n'
        '    .to(0, motion: land),\n'
        '    .loop([\n'
        '      .hold(stagger * i),\n'
        '      .to(lift, motion: bounce),\n'
        '      .to(0, motion: bounce),\n'
        '    ]$together),\n'
        '  ]),';
  }

  void _setInStep(bool value) {
    setState(() => _inStep = value);
    _syncCode();
  }

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    return _SceneLayout(
      subject: TrackBuilder(
        debugLabel: 'Typing dots',
        animations: [
          for (final (i, dot) in _dotLift.indexed)
            dot([
              // Lands from wherever the switch caught it, then loops.
              const .to(0, motion: _land),
              .loop([
                .hold(_dotStagger * i),
                const .to(_dotLiftHeight, motion: _bounce),
                const .to(0, motion: _bounce),
              ], together: _inStep ? #typing : null),
            ]),
        ],
        builder: (context, values, _) => SizedBox(
          height: 40,
          child: Row(
            mainAxisSize: .min,
            children: [
              for (final (i, dot) in _dotLift.indexed) ...[
                if (i > 0) const SizedBox(width: 10),
                Transform.translate(
                  offset: Offset(0, -values(dot)),
                  child: Container(
                    width: 14,
                    height: 14,
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
      controls: CoilSwitch(
        value: _inStep,
        onChanged: _setInStep,
        label: const Text('together: #typing'),
      ),
      notice: _inStep
          ? 'The wave keeps its shape: each cycle waits for the last dot.'
          : 'Each dot loops on its own clock, so the wave drifts apart.',
    );
  }
}

// ---------------------------------------------------------------------------
// 4. Slide to unlock: one track for the looping hint, the drag and the release
// ---------------------------------------------------------------------------

enum _Hint { rest, nudge }

const _thumbSize = 48.0;
const _trackPadding = 4.0;
const _nudgeDistance = 28.0;
const _thumbSpring = Motion.cupertino(
  duration: Duration(milliseconds: 420),
  bounce: 0.2,
);

class _SlideScene extends StatefulWidget {
  const _SlideScene({required this.code});

  final ValueNotifier<String> code;

  @override
  State<_SlideScene> createState() => _SlideSceneState();
}

class _SlideSceneState extends State<_SlideScene>
    with SingleTickerProviderStateMixin {
  late final _controller = PhaseTrackController<_Hint>(
    vsync: this,
    debugLabel: 'Slide to unlock',
  );

  /// How far the thumb is from the start of the track. The only source of
  /// truth for the thumb, whether the hint, a drag or a release moves it.
  final _thumbX = Track<double>(.single, initial: 0, debugLabel: 'Thumb X');

  late final _hint = TrackPhaseTimeline<_Hint>({
    // Springs home with whatever velocity the thumb has, then pauses.
    .rest: [
      _thumbX([
        const .to(0, motion: _thumbSpring),
        const .hold(Duration(milliseconds: 1200)),
      ]),
    ],
    .nudge: [
      _thumbX([const .to(_nudgeDistance, motion: _thumbSpring, until: .ended)]),
    ],
  }, loop: .loop);

  /// How far the thumb can travel in the current layout.
  double _travel = 0;

  @override
  void initState() {
    super.initState();
    widget.code.value =
        '// Idle: the hint loops. Drag: set() the same track, tracking velocity.\n'
        'hint = TrackPhaseTimeline({\n'
        '  .rest: [thumbX([.to(0, motion: spring), .hold(1200ms)])],\n'
        '  .nudge: [thumbX([.to(28, motion: spring, until: .ended)])],\n'
        '}, loop: .loop);\n'
        'controller.playPhases(hint);\n'
        'onUpdate: controller.set([thumbX.value(x + dx)]),\n'
        '// Release: the hint itself springs home with the fling, then pauses.\n'
        'onEnd: unlocked\n'
        '    ? controller.animate([thumbX([.to(travel), .hold(900ms)])])\n'
        '        .then((_) => controller.playPhases(hint))\n'
        '    : controller.playPhases(hint),';
    _controller.playPhases(_hint);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _drag(DragUpdateDetails details) {
    final x = _controller.value(_thumbX) + details.delta.dx;
    _controller.set([_thumbX.value(x.clamp(0.0, _travel))]);
  }

  void _release([DragEndDetails? _]) {
    if (_travel > 0 && _controller.value(_thumbX) >= _travel * 0.75) {
      _controller
          .animate([
            _thumbX([
              .to(_travel, motion: _thumbSpring),
              const .hold(Duration(milliseconds: 900)),
            ]),
          ])
          // A new drag cancels this, and the hint stays put.
          .orCancel
          .then((_) => _controller.playPhases(_hint), onError: (_) {});
    } else {
      _controller.playPhases(_hint);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final text = CoilTheme.textOf(context);
    return _SceneLayout(
      subject: LayoutBuilder(
        builder: (context, constraints) {
          final width = math.min(300.0, constraints.maxWidth);
          _travel = math.max(0, width - _thumbSize - _trackPadding * 2);
          return Container(
            width: width,
            height: _thumbSize + _trackPadding * 2,
            padding: const .all(_trackPadding),
            decoration: ShapeDecoration(
              color: palette.surface,
              shape: StadiumBorder(side: BorderSide(color: palette.border)),
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final x = _controller.value(_thumbX);
                final progress = _travel > 0
                    ? (x / _travel).clamp(0.0, 1.0)
                    : 0.0;
                return Stack(
                  alignment: .centerLeft,
                  children: [
                    Center(
                      child: Opacity(
                        opacity: 1 - progress,
                        child: Padding(
                          padding: const .only(left: _thumbSize / 2),
                          child: Text(
                            'Slide to unlock',
                            maxLines: 1,
                            overflow: .ellipsis,
                            style: text.muted.caption.copyWith(
                              fontWeight: text.emphasis,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Transform.translate(
                      offset: Offset(x.clamp(-8.0, _travel + 8), 0),
                      child: GrabDetector(
                        onUpdate: _drag,
                        onEnd: _release,
                        onCancel: _release,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.grab,
                          child: Container(
                            width: _thumbSize,
                            height: _thumbSize,
                            decoration: BoxDecoration(
                              color: palette.text,
                              shape: BoxShape.circle,
                            ),
                            alignment: .center,
                            child: IconTheme(
                              data: IconThemeData(
                                size: 20,
                                color: palette.canvas,
                              ),
                              child: const GlyphIcon(Glyph.arrowRight),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
      controls: const SizedBox.shrink(),
      notice:
          'Grab the thumb mid-hint, then fling it: one track, so nothing '
          'snaps.',
    );
  }
}
