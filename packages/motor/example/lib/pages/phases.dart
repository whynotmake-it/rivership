import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/cupertino.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/chapters.dart';
import 'package:motor_example/widgets/chapter_page.dart';
import 'package:motor_example/widgets/controls.dart';
import 'package:motor_example/widgets/style.dart';

/// Named states, and motor animating every track between them.
class PhasesPage extends StatefulWidget {
  const PhasesPage({super.key});

  @override
  State<PhasesPage> createState() => _PhasesPageState();
}

enum _Player { mini, card, full }

const _rest = Duration(milliseconds: 700);
// The shape's tracks share one spring, so the frame and artwork move as one.
const _move = Motion.cupertino(
  duration: Duration(milliseconds: 320),
  bounce: .1,
);
const _fadeIn = Motion.curved(Duration(milliseconds: 220), easeOut);
const _fadeOut = Motion.curved(Duration(milliseconds: 120), easeOut);
// Pixels of drag from one phase to the next.
const _dragPerPhase = 170.0;

typedef _Look = ({
  Size frame,
  double radius,
  Rect art,
  double inline,
  double stacked,
});

const Map<_Player, _Look> _looks = {
  .mini: (
    frame: Size(220, 60),
    radius: 30.0,
    art: .fromLTWH(10, 10, 40, 40),
    inline: 1.0,
    stacked: 0.0,
  ),
  .card: (
    frame: Size(320, 136),
    radius: 10.0,
    art: .fromLTWH(16, 16, 104, 104),
    inline: 1.0,
    stacked: 0.0,
  ),
  .full: (
    frame: Size(320, 404),
    radius: 12.0,
    art: .fromLTWH(24, 24, 272, 236),
    inline: 0.0,
    stacked: 1.0,
  ),
};

class _PhasesPageState extends State<PhasesPage> {
  final _frame = Track<Size>(
    .size,
    initial: _looks[_Player.mini]!.frame,
    motion: _move,
    debugLabel: 'Frame',
  );
  final _radius = Track<double>(
    .single,
    initial: _looks[_Player.mini]!.radius,
    motion: _move,
    debugLabel: 'Radius',
  );
  final _art = Track<Rect>(
    .rect,
    initial: _looks[_Player.mini]!.art,
    motion: _move,
    debugLabel: 'Artwork',
  );
  final _inline = Track<double>(.single, initial: 1, debugLabel: 'Inline text');
  final _stacked = Track<double>(.single, initial: 0, debugLabel: 'Full text');

  late var _phases = _timeline();

  TrackPhaseTimeline<_Player> _timeline([
    List<TrackValue> initialValues = const [],
  ]) => TrackPhaseTimeline(
    {
      for (final MapEntry(key: phase, value: look) in _looks.entries)
        phase: [
          _frame([.to(look.frame)]),
          _radius([.to(look.radius)]),
          _art([.to(look.art)]),
          _fade(_inline, look.inline),
          _fade(_stacked, look.stacked),
        ],
    },
    loop: .pingPong,
    initialValues: initialValues,
  );

  final _code = ValueNotifier(
    '// Tap a phase, drag the player, or autoplay.\n'
    'PhaseTrackBuilder(currentPhase: .mini, timeline: phases, ...)',
  );

  // The phase the builder goes to, and the one it is at or heading to.
  var _phase = _Player.mini;
  var _shown = _Player.mini;
  var _autoplay = false;

  // Where the finger has put the player while dragging: 0 is mini, 1 card,
  // 2 full. Null when not dragging.
  double? _dragged;
  var _handoffs = 0;

  // The builder's live values, to start a drag from where the player is.
  TrackValueReader? _live;

  // Text that goes leaves at once. Text that comes waits for the shape to
  // make room, then fades in and rests before autoplay moves on.
  static TrackAnimation<double> _fade(Track<double> track, double to) => to == 1
      ? track([
          .hold(const Duration(milliseconds: 150)),
          .to(1, motion: _fadeIn),
          .hold(_rest),
        ])
      : track([.to(0, motion: _fadeOut)]);

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _goTo(_Player phase) {
    setState(() {
      _phase = phase;
      _autoplay = false;
    });
    _code.value =
        '// Every track animates from where it is to its value in ${phase.name}.\n'
        'PhaseTrackBuilder(currentPhase: .${phase.name}, timeline: phases, ...)';
  }

  void _toggleAutoplay() {
    setState(() {
      _autoplay = !_autoplay;
      _phase = _shown;
    });
    _code.value = _autoplay
        ? '// Walks through the phases and back. Each waits for every track.\n'
              'PhaseTrackBuilder(\n'
              '  currentPhase: .${_phase.name},\n'
              '  playing: true,\n'
              '  timeline: phases,\n'
              '  ...\n'
              ')'
        : 'PhaseTrackBuilder(currentPhase: .${_phase.name}, timeline: phases, ...)';
  }

  // Past either end the player follows the finger with growing resistance,
  // and never more than a quarter of a phase.
  static double _resist(double past) => .25 * .3 * past / (.25 + .3 * past);

  static double _resisted(double dragged) => dragged < 0
      ? -_resist(-dragged)
      : dragged > 2
      ? 2 + _resist(dragged - 2)
      : dragged;

  // The two phases [progress] is between, and how far it is from the first.
  static (_Look, _Look, double) _between(double progress) {
    final index = progress.floor().clamp(0, 1);
    return (
      _looks[_Player.values[index]]!,
      _looks[_Player.values[index + 1]]!,
      progress - index,
    );
  }

  static _Look _lookAt(double progress) {
    final (from, to, t) = _between(progress);
    return (
      frame: Size.lerp(from.frame, to.frame, t)!,
      radius: lerpDouble(from.radius, to.radius, t)!,
      art: Rect.lerp(from.art, to.art, t)!,
      inline: lerpDouble(from.inline, to.inline, t)!.clamp(0, 1),
      stacked: lerpDouble(from.stacked, to.stacked, t)!.clamp(0, 1),
    );
  }

  void _grab(DragStartDetails _) {
    // Where the player is between phases, from its height.
    final height = _live!(_frame).height;
    final (mini, card, full) = (
      _looks[_Player.mini]!.frame.height,
      _looks[_Player.card]!.frame.height,
      _looks[_Player.full]!.frame.height,
    );
    final progress = height <= card
        ? (height - mini) / (card - mini)
        : 1 + (height - card) / (full - card);
    // The builder rests while the finger drives, autoplay included.
    setState(() => _dragged = progress.clamp(0, 2));
  }

  void _drag(DragUpdateDetails details) {
    setState(() => _dragged = _dragged! + details.delta.dy / _dragPerPhase);
    final frame = _lookAt(_resisted(_dragged!)).frame;
    _code.value =
        '// Dragging: the builder rests while the finger sets the look.\n'
        'PhaseTrackBuilder(active: false, ...)\n'
        '_NowPlaying(frame: Size(${frame.width.round()}, '
        '${frame.height.round()}), radius…, art…, text…)';
  }

  void _release(DragEndDetails details) {
    // A drag the page's scroll took over before it started.
    final dragged = _dragged;
    if (dragged == null) return;
    final progress = _resisted(dragged);
    // Phases per second, and so each track's speed between the two phases.
    final speed = details.velocity.pixelsPerSecond.dy / _dragPerPhase;
    final (from, to, _) = _between(progress);
    final look = _lookAt(progress);
    final landing = _Player.values[(dragged + speed * .25).round().clamp(0, 2)];
    final frameSpeed = Size(
      (to.frame.width - from.frame.width) * speed,
      (to.frame.height - from.frame.height) * speed,
    );
    setState(() {
      _dragged = null;
      _phase = landing;
      // A timeline that starts where the drag left every track, at the
      // drag's speed. A new restartTrigger applies its initialValues, and
      // the builder heads for the landing phase, or autoplays from it.
      _phases = _timeline([
        _frame.value(look.frame, velocity: frameSpeed),
        _radius.value(look.radius, velocity: (to.radius - from.radius) * speed),
        _art.value(
          look.art,
          velocity: Rect.fromLTRB(
            (to.art.left - from.art.left) * speed,
            (to.art.top - from.art.top) * speed,
            (to.art.right - from.art.right) * speed,
            (to.art.bottom - from.art.bottom) * speed,
          ),
        ),
        _inline.value(look.inline),
        _stacked.value(look.stacked),
      ]);
      _handoffs++;
    });
    _code.value =
        '// Let go: the nearest phase takes over, at your speed.\n'
        'PhaseTrackBuilder(\n'
        '  currentPhase: .${landing.name},\n'
        '${_autoplay ? '  playing: true,\n' : ''}'
        '  timeline: TrackPhaseTimeline(phases, initialValues: [\n'
        '    frame.value(Size(${look.frame.width.round()}, '
        '${look.frame.height.round()}), '
        'velocity: Size(${frameSpeed.width.round()}, ${frameSpeed.height.round()})),\n'
        '    radius…, art…, text…\n'
        '  ]),\n'
        '  restartTrigger: ++handoffs, // applies initialValues\n'
        ')';
  }

  @override
  Widget build(BuildContext context) {
    return ChapterPage(
      chapter: chapterNamed('Phases'),
      lead:
          'Mini, card and full are phases. Each lists a value for every '
          'track. Tap one, autoplay, or drag the player. On release the '
          'nearest phase takes over at your speed.',
      code: _code,
      stageHeight: 520,
      // PhaseTrackBuilder has no set(), so it can't follow a finger. While
      // dragging it rests (active: false) and the drag draws the player;
      // on release, restartTrigger hands the drag's values and speed back
      // through the timeline's initialValues.
      stage: PhaseTrackBuilder<_Player>(
        debugLabel: 'Now playing',
        timeline: _phases,
        currentPhase: _phase,
        playing: _autoplay,
        active: _dragged == null,
        restartTrigger: _handoffs,
        onTransition: (transition) => _shown = transition.phase,
        builder: (context, value, phase, _) {
          _live = value;
          final dragged = _dragged;
          final look = dragged == null
              ? (
                  frame: value(_frame),
                  radius: value(_radius),
                  art: value(_art),
                  inline: value(_inline),
                  stacked: value(_stacked),
                )
              : _lookAt(_resisted(dragged));
          final selected = dragged == null
              ? phase
              : _Player.values[_resisted(dragged).round().clamp(0, 2)];
          return Stack(
            children: [
              Positioned(
                top: 24,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    onVerticalDragStart: _grab,
                    onVerticalDragUpdate: _drag,
                    onVerticalDragEnd: _release,
                    onVerticalDragCancel: () => _release(DragEndDetails()),
                    child: _NowPlaying(look),
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Row(
                  mainAxisAlignment: .spaceBetween,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: .scaleDown,
                        alignment: .centerLeft,
                        child: Choice(
                          options: const ['Mini', 'Card', 'Full'],
                          selected: selected.index,
                          onSelect: (index) => _goTo(_Player.values[index]),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    PillButton(
                      label: _autoplay ? 'Stop' : 'Autoplay',
                      icon: _autoplay
                          ? CupertinoIcons.pause_fill
                          : CupertinoIcons.play_fill,
                      filled: _autoplay,
                      onTap: _toggleAutoplay,
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

class _NowPlaying extends StatelessWidget {
  const _NowPlaying(this.look);

  final _Look look;

  @override
  Widget build(BuildContext context) {
    final t = Palette.of(context);
    final _Look(:radius, :inline, :stacked) = look;
    // A hard fling can make the springs overshoot past zero.
    final frame = Size(
      math.max(0, look.frame.width),
      math.max(0, look.frame.height),
    );
    final art = Rect.fromLTWH(
      look.art.left,
      look.art.top,
      math.max(0, look.art.width),
      math.max(0, look.art.height),
    );
    // The artist line only fits once the frame is tall enough.
    final roomy = ((frame.height - 60) / 60).clamp(0.0, 1.0);
    return Container(
      width: frame.width,
      height: frame.height,
      clipBehavior: .antiAlias,
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: .circular(radius),
        border: Border.all(color: t.border),
      ),
      child: Stack(
        clipBehavior: .none,
        children: [
          Positioned.fromRect(
            rect: art,
            // Concentric with the frame: its radius less the inset.
            child: _Artwork(
              size: art.width,
              radius: (radius - art.left).clamp(0, art.width / 2),
            ),
          ),
          // The text keeps its own height, centred on the artwork, which is
          // shorter than the text while its spring overshoots.
          Positioned(
            left: art.right + 14,
            top: art.center.dy,
            width: 170,
            child: FractionalTranslation(
              translation: const Offset(0, -.5),
              child: Reveal(
                progress: inline,
                offset: const Offset(-6, 0),
                child: Column(
                  mainAxisSize: .min,
                  crossAxisAlignment: .start,
                  children: [
                    Text(
                      'Slow Motion',
                      maxLines: 1,
                      overflow: .ellipsis,
                      style: t.title.copyWith(fontSize: 16),
                    ),
                    ClipRect(
                      child: Align(
                        alignment: .topLeft,
                        heightFactor: roomy,
                        child: Opacity(
                          opacity: roomy,
                          child: Column(
                            crossAxisAlignment: .start,
                            children: [
                              Text('The Springs', style: t.caption),
                              const SizedBox(height: 12),
                              const _Progress(width: 150),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            top: art.bottom + 20,
            child: Reveal(
              progress: stacked,
              offset: const Offset(0, 8),
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  Text('Slow Motion', style: t.title.copyWith(fontSize: 22)),
                  const SizedBox(height: 2),
                  Text('The Springs', style: t.body),
                  const SizedBox(height: 16),
                  const _Progress(width: 272),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: .spaceEvenly,
                    children: [
                      for (final icon in [
                        CupertinoIcons.backward_fill,
                        CupertinoIcons.pause_fill,
                        CupertinoIcons.forward_fill,
                      ])
                        Icon(icon, size: 26, color: t.text),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork({required this.size, required this.radius});

  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: p.accent,
        borderRadius: .circular(radius),
      ),
      child: Icon(
        CupertinoIcons.music_note_2,
        color: p.onAccent,
        size: size * .4,
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    final t = Palette.of(context);
    return Container(
      width: width,
      height: 4,
      alignment: .centerLeft,
      decoration: BoxDecoration(color: t.control, borderRadius: .circular(2)),
      child: Container(
        width: width * .38,
        decoration: BoxDecoration(color: t.text, borderRadius: .circular(2)),
      ),
    );
  }
}
