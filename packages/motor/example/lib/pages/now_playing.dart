import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/widgets/example_scaffold.dart';

enum _PlayerPhase { mini, full }

final _art = Track<Rect>(
  .rect,
  origin: Rect.zero,
  motion: .smoothSpring(duration: Duration(milliseconds: 560)),
);
final _radius = Track<double>(
  .single,
  origin: 12,
  motion: .smoothSpring(duration: Duration(milliseconds: 520)),
);
final _full = Track<double>(
  .single,
  origin: 0,
  motion: .smoothSpring(duration: Duration(milliseconds: 420)),
);
final _mini = Track<double>(
  .single,
  origin: 1,
  motion: .smoothSpring(duration: Duration(milliseconds: 380)),
);

/// A mini-player that expands into a full player. Album art bounds, corner
/// radius, and the two control layouts are independent tracks that meet at each
/// phase, so the whole thing morphs as one coherent motion.
class NowPlayingPage extends StatefulWidget {
  const NowPlayingPage({super.key});
  static const routeName = 'Now Playing';

  @override
  State<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends State<NowPlayingPage> {
  var _phase = _PlayerPhase.mini;

  void _toggle() => setState(
        () => _phase = _phase == _PlayerPhase.mini
            ? _PlayerPhase.full
            : _PlayerPhase.mini,
      );

  @override
  Widget build(BuildContext context) {
    return ExamplePage(
      title: NowPlayingPage.routeName,
      description:
          'Tap the player to expand it. The album art, its corner radius, and '
          'the two control layouts are separate tracks that settle together at '
          'each phase — the kind of morph that is fiddly to choreograph by '
          'hand.',
      child: SizedBox(
        height: 420,
        child: Surface(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(ExampleTheme.surfaceRadius),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final h = constraints.maxHeight;
                const artSize = 220.0;
                final timeline = TrackPhaseTimeline<_PlayerPhase>({
                  _PlayerPhase.mini: [
                    _art.to(Rect.fromLTWH(16, h - 72, 56, 56)),
                    _radius.to(12),
                    _full.to(0),
                    _mini.to(1),
                  ],
                  _PlayerPhase.full: [
                    _art.to(Rect.fromLTWH((w - artSize) / 2, 36, artSize,
                        artSize)),
                    _radius.to(28),
                    _full.to(1),
                    _mini.to(0),
                  ],
                });
                return GestureDetector(
                  onTap: _toggle,
                  child: PhaseTrackBuilder<_PlayerPhase>(
                    currentPhase: _phase,
                    timeline: timeline,
                    from: [
                      _art.value(Rect.fromLTWH(16, h - 72, 56, 56)),
                      _radius.value(12),
                      _full.value(0),
                      _mini.value(1),
                    ],
                    builder: (context, value, phase, child) {
                      final art = value<Rect>(_art);
                      final radius = value<double>(_radius);
                      final full = value<double>(_full).clamp(0.0, 1.0);
                      final mini = value<double>(_mini).clamp(0.0, 1.0);
                      return Stack(
                        children: [
                          Positioned.fromRect(
                            rect: art,
                            child: _AlbumArt(radius: radius),
                          ),
                          if (mini > 0)
                            Positioned(
                              left: 84,
                              right: 12,
                              top: h - 72,
                              height: 56,
                              child: Opacity(
                                opacity: mini,
                                child: const _MiniControls(),
                              ),
                            ),
                          if (full > 0)
                            Positioned(
                              left: 24,
                              right: 24,
                              top: 36 + artSize + 28,
                              child: Opacity(
                                opacity: full,
                                child: const _FullControls(),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _AlbumArt extends StatelessWidget {
  const _AlbumArt({required this.radius});
  final double radius;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [t.textPrimary, t.textSecondary],
        ),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Center(
        child: Icon(
          CupertinoIcons.music_note_2,
          color: t.surfaceSolid.withValues(alpha: .9),
          size: 22,
        ),
      ),
    );
  }
}

class _MiniControls extends StatelessWidget {
  const _MiniControls();

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Continuum',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: t.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Spring & Curve',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: t.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
        Icon(CupertinoIcons.play_fill, color: t.textPrimary, size: 24),
      ],
    );
  }
}

class _FullControls extends StatelessWidget {
  const _FullControls();

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Column(
      children: [
        Text(
          'Continuum',
          style: TextStyle(
            fontFamily: 'Archivo',
            fontSize: 26,
            fontWeight: FontWeight.w300,
            letterSpacing: -0.6,
            color: t.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Spring & Curve',
          style: TextStyle(color: t.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: t.textPrimary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Container(
                height: 4,
                margin: const EdgeInsets.only(left: 4),
                decoration: BoxDecoration(
                  color: t.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Icon(CupertinoIcons.backward_fill, color: t.textSecondary, size: 28),
            Icon(CupertinoIcons.play_fill, color: t.textPrimary, size: 40),
            Icon(CupertinoIcons.forward_fill, color: t.textSecondary, size: 28),
          ],
        ),
      ],
    );
  }
}
