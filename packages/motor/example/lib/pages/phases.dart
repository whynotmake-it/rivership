import 'dart:ui' show lerpDouble;

import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/chapters.dart';
import 'package:motor_example/widgets/chapter_page.dart';
import 'package:motor_example/widgets/controls.dart';
import 'package:motor_example/widgets/live_timeline.dart';
import 'package:motor_example/widgets/style.dart';

/// Named states, and motor animating every track between them.
class PhasesPage extends StatefulWidget {
  const PhasesPage({super.key});

  @override
  State<PhasesPage> createState() => _PhasesPageState();
}

enum _Player { mini, card, full }

const _rest = Duration(milliseconds: 700);
const _fadeOut = CupertinoMotion.snappy(duration: Duration(milliseconds: 200));
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
  _Player.mini: (
    frame: Size(220, 60),
    radius: 30.0,
    art: Rect.fromLTWH(10, 10, 40, 40),
    inline: 1.0,
    stacked: 0.0,
  ),
  _Player.card: (
    frame: Size(320, 136),
    radius: 28.0,
    art: Rect.fromLTWH(16, 16, 104, 104),
    inline: 1.0,
    stacked: 0.0,
  ),
  _Player.full: (
    frame: Size(320, 404),
    radius: 36.0,
    art: Rect.fromLTWH(24, 24, 272, 236),
    inline: 0.0,
    stacked: 1.0,
  ),
};

class _PhasesPageState extends State<PhasesPage>
    with SingleTickerProviderStateMixin {
  late final _player = PhaseTrackController<_Player>(
    vsync: this,
    debugLabel: 'Now playing',
  );

  final _frame = Track<Size>(
    .size,
    initial: _looks[_Player.mini]!.frame,
    motion: .bouncySpring(duration: Duration(milliseconds: 600)),
    debugLabel: 'Frame',
  );
  final _radius = Track<double>(
    .single,
    initial: 30,
    motion: .smoothSpring(),
    debugLabel: 'Radius',
  );
  final _art = Track<Rect>(
    .rect,
    initial: _looks[_Player.mini]!.art,
    motion: .smoothSpring(duration: Duration(milliseconds: 650)),
    debugLabel: 'Artwork',
  );
  final _inline = Track<double>(
    .single,
    initial: 1,
    motion: .smoothSpring(),
    debugLabel: 'Inline text',
  );
  final _stacked = Track<double>(
    .single,
    initial: 0,
    motion: .smoothSpring(duration: Duration(milliseconds: 700)),
    debugLabel: 'Full text',
  );

  late final _phases = TrackPhaseTimeline<_Player>({
    for (final MapEntry(key: phase, value: look) in _looks.entries)
      phase: [
        _frame.to(look.frame),
        _radius.to(look.radius),
        _art.to(look.art),
        _fade(_inline, look.inline),
        _fade(_stacked, look.stacked),
      ],
  }, phaseLoop: .pingPong);

  var _phase = _Player.mini;
  var _autoplay = false;
  var _dragged = 0.0;

  // Text that appears waits for the rest of the phase; text that goes leaves
  // quickly.
  static TrackAnimation<double> _fade(Track<double> track, double to) =>
      to == 1 ? track([.to(1), .hold(_rest)]) : track.to(0, motion: _fadeOut);

  @override
  void initState() {
    super.initState();
    _player.setTimeline(_phases, onTransition: _onTransition);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _onTransition(PhaseTransition<_Player> transition) {
    if (mounted) setState(() => _phase = transition.phase);
  }

  void _goTo(_Player phase) {
    setState(() {
      _phase = phase;
      _autoplay = false;
    });
    _player.goToPhase(phase);
  }

  void _toggleAutoplay() {
    setState(() => _autoplay = !_autoplay);
    if (_autoplay) {
      _player.playPhases(_phases, atPhase: _phase, onTransition: _onTransition);
    } else {
      _player.goToPhase(_phase);
    }
  }

  // Where the player is between phases: 0 is mini, 1 card, 2 full.
  double get _progress {
    final height = _player.value(_frame).height;
    final (mini, card, full) = (
      _looks[_Player.mini]!.frame.height,
      _looks[_Player.card]!.frame.height,
      _looks[_Player.full]!.frame.height,
    );
    return height <= card
        ? (height - mini) / (card - mini)
        : 1 + (height - card) / (full - card);
  }

  void _grab(DragStartDetails _) {
    // Take over from whatever the player was doing, autoplay included.
    _player.stop(canceled: true);
    _dragged = _progress.clamp(0, 2);
  }

  void _drag(DragUpdateDetails details) {
    _dragged += details.delta.dy / _dragPerPhase;
    // Past either end, the player follows the finger reluctantly.
    final progress = _dragged < 0
        ? _dragged * .3
        : _dragged > 2
        ? 2 + (_dragged - 2) * .3
        : _dragged;
    final index = progress.floor().clamp(0, 1);
    final from = _looks[_Player.values[index]]!;
    final to = _looks[_Player.values[index + 1]]!;
    final t = progress - index;
    _player.set([
      _frame.value(Size.lerp(from.frame, to.frame, t)!),
      _radius.value(lerpDouble(from.radius, to.radius, t)!),
      _art.value(Rect.lerp(from.art, to.art, t)!),
      _inline.value(lerpDouble(from.inline, to.inline, t)!.clamp(0, 1)),
      _stacked.value(lerpDouble(from.stacked, to.stacked, t)!.clamp(0, 1)),
    ]);
    final nearest = _Player.values[progress.round().clamp(0, 2)];
    if (nearest != _phase) setState(() => _phase = nearest);
  }

  void _release(DragEndDetails details) {
    final speed = details.velocity.pixelsPerSecond.dy / _dragPerPhase;
    final landing = (_dragged + speed * .25).round().clamp(0, 2);
    final phase = _Player.values[landing];
    setState(() => _phase = phase);
    // The tracks keep the velocity the drag gave them. Autoplay picks up
    // from the phase the player lands in.
    if (_autoplay) {
      _player.playPhases(_phases, atPhase: phase, onTransition: _onTransition);
    } else {
      _player.goToPhase(phase);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChapterPage(
      chapter: chapterNamed('Phases'),
      lead:
          'Mini, card and full are phases: named values for every track. Drag '
          'the player up or down, even during autoplay. Your finger sets every '
          'track; let go and the nearest phase takes over at your speed, and '
          'autoplay carries on from there.',
      code: 'player..set(dragged)..goToPhase(nearest);',
      below: LiveTimeline(
        controller: _player,
        lanes: {
          _frame: 'frame',
          _radius: 'radius',
          _art: 'artwork',
          _inline: 'inline',
          _stacked: 'full text',
        },
      ),
      stageHeight: 520,
      stage: Stack(
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
                child: AnimatedBuilder(
                  animation: _player,
                  builder: (context, _) {
                    final value = _player.value;
                    return _NowPlaying(
                      frame: value(_frame),
                      radius: value(_radius),
                      art: value(_art),
                      inline: value(_inline),
                      stacked: value(_stacked),
                    );
                  },
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Choice(
                      options: const ['Mini', 'Card', 'Full'],
                      selected: _phase.index,
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
      ),
    );
  }
}

class _NowPlaying extends StatelessWidget {
  const _NowPlaying({
    required this.frame,
    required this.radius,
    required this.art,
    required this.inline,
    required this.stacked,
  });

  final Size frame;
  final double radius;
  final Rect art;
  final double inline;
  final double stacked;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    // The artist line only fits once the frame is tall enough.
    final roomy = ((frame.height - 60) / 60).clamp(0.0, 1.0);
    return Container(
      width: frame.width,
      height: frame.height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: t.surfaceSolid,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: t.border),
        boxShadow: t.softShadow,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fromRect(
            rect: art,
            child: _Artwork(size: art.width),
          ),
          Positioned(
            left: art.right + 14,
            top: art.top,
            width: 170,
            height: art.height,
            child: Reveal(
              progress: inline,
              offset: const Offset(-12, 0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Slow Motion',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.title.copyWith(fontSize: 16),
                  ),
                  ClipRect(
                    child: Align(
                      alignment: Alignment.topLeft,
                      heightFactor: roomy,
                      child: Opacity(
                        opacity: roomy,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
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
          Positioned(
            left: 24,
            right: 24,
            top: art.bottom + 20,
            child: Reveal(
              progress: stacked,
              offset: const Offset(0, 24),
              blur: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Slow Motion', style: t.title.copyWith(fontSize: 22)),
                  const SizedBox(height: 2),
                  Text('The Springs', style: t.body),
                  const SizedBox(height: 16),
                  const _Progress(width: 272),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (final icon in [
                        CupertinoIcons.backward_fill,
                        CupertinoIcons.pause_fill,
                        CupertinoIcons.forward_fill,
                      ])
                        Icon(icon, size: 26, color: t.textPrimary),
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
  const _Artwork({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * .16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ExampleTheme.marigold,
            ExampleTheme.spectrumRed,
            ExampleTheme.roseQuartz,
          ],
        ),
      ),
      child: Icon(
        CupertinoIcons.music_note_2,
        color: CupertinoColors.white.withValues(alpha: .9),
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
    final t = ExampleTheme.of(context);
    return Container(
      width: width,
      height: 4,
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: t.pebble,
        borderRadius: BorderRadius.circular(2),
      ),
      child: Container(
        width: width * .38,
        decoration: BoxDecoration(
          color: t.textPrimary,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
