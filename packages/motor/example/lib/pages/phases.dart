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

class _PhasesPageState extends State<PhasesPage>
    with SingleTickerProviderStateMixin {
  late final _player = PhaseTrackController<_Player>(
    vsync: this,
    debugLabel: 'Now playing',
  );

  final _frame = Track<Size>(
    .size,
    initial: const Size(220, 60),
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
    initial: const Rect.fromLTWH(10, 10, 40, 40),
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
    .mini: [
      _frame.to(const Size(220, 60)),
      _radius.to(30),
      _art.to(const Rect.fromLTWH(10, 10, 40, 40)),
      _inline([.to(1), .hold(_rest)]),
      _stacked.to(
        0,
        motion: .snappySpring(duration: Duration(milliseconds: 200)),
      ),
    ],
    .card: [
      _frame.to(const Size(320, 136)),
      _radius.to(28),
      _art.to(const Rect.fromLTWH(16, 16, 104, 104)),
      _inline([.to(1), .hold(_rest)]),
      _stacked.to(
        0,
        motion: .snappySpring(duration: Duration(milliseconds: 200)),
      ),
    ],
    .full: [
      _frame.to(const Size(320, 404)),
      _radius.to(36),
      _art.to(const Rect.fromLTWH(24, 24, 272, 236)),
      _inline.to(
        0,
        motion: .snappySpring(duration: Duration(milliseconds: 200)),
      ),
      _stacked([.to(1), .hold(_rest)]),
    ],
  }, phaseLoop: .pingPong);

  var _phase = _Player.mini;
  var _autoplay = false;

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

  @override
  Widget build(BuildContext context) {
    return ChapterPage(
      chapter: chapterNamed('Phases'),
      lead:
          'Mini, card and full are phases: each names the values its tracks '
          'settle on. Jump to any phase mid-morph, or autoplay. Between phases, '
          'motor waits until every track has arrived.',
      code: 'player.goToPhase(Player.full);',
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
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Row(
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
                const Spacer(),
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
