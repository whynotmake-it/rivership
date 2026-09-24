import 'package:flutter/cupertino.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/chapters.dart';
import 'package:motor_example/widgets/chapter_page.dart';
import 'package:motor_example/widgets/controls.dart';
import 'package:motor_example/widgets/live_timeline.dart';
import 'package:motor_example/widgets/style.dart';

/// Each track plays its own list of steps.
class StepsPage extends StatefulWidget {
  const StepsPage({super.key});

  @override
  State<StepsPage> createState() => _StepsPageState();
}

const _compact = Size(120, 34);
const _expanded = Size(340, 84);
const Motion _fadeIn = .curved(Duration(milliseconds: 220), easeOut);
const Motion _fadeOut = .curved(Duration(milliseconds: 150), easeOut);

class _StepsPageState extends State<StepsPage>
    with SingleTickerProviderStateMixin {
  late final _island = TrackController(vsync: this, debugLabel: 'Notification');

  // One Size track, so width and height move as one.
  final _shape = Track<Size>(.size, initial: _compact, debugLabel: 'Shape');
  final _content = Track<double>(.single, initial: 0, debugLabel: 'Content');
  final _bell = Track<double>(
    .single,
    initial: 0,
    motion: .curved(Duration(milliseconds: 120), Curves.easeInOut),
    debugLabel: 'Bell',
  );

  // Content uses fixed-length curves, so its steps land exactly on time. The
  // shape waits at the barrier until the content has faded, then closes.
  late final _pingTimeline = TrackTimeline([
    _shape([
      .to(
        _expanded,
        motion: .cupertino(duration: Duration(milliseconds: 500), bounce: .2),
      ),
      .sync(token: #faded),
      .to(
        _compact,
        motion: .cupertino(duration: Duration(milliseconds: 400), bounce: .1),
      ),
    ]),
    _content([
      .hold(const Duration(milliseconds: 120)),
      .to(1, motion: _fadeIn),
      .hold(const Duration(milliseconds: 1600)),
      .to(0, motion: _fadeOut),
      .sync(token: #faded),
    ]),
    _bell([
      .hold(const Duration(milliseconds: 260)),
      for (final (index, angle) in const [.45, -.4, .3, -.2, 0.0].indexed)
        .at(Duration(milliseconds: 380 + 120 * index), angle),
    ]),
  ]);

  final _code = ValueNotifier(
    '// Ping to play the timeline.\n'
    'shape([.to(open), .sync(token: #faded), .to(closed)])',
  );

  @override
  void dispose() {
    _island.dispose();
    _code.dispose();
    super.dispose();
  }

  void _ping() {
    final size = _island.value(_shape);
    _code.value = size == _compact
        ? '// Plays every track\'s steps from the start.\n'
              'island.play(ping);'
        : '// Played again from where it is, '
              'Size(${size.width.round()}, ${size.height.round()}).\n'
              'island.play(ping);';
    _island.play(_pingTimeline);
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return ChapterPage(
      chapter: chapterNamed('Steps'),
      lead:
          'The shape is one Size track, so width and height move as one. The '
          'content fades in once it opens; the shape waits at a barrier until '
          'the content has faded, then closes. Ping again mid-way and it picks '
          'up from where it is.',
      code: _code,
      below: LiveTimeline(
        controller: _island,
        lanes: {_shape: 'shape', _content: 'content', _bell: 'bell'},
      ),
      stageHeight: 300,
      stage: Stack(
        children: [
          Padding(
            padding: const .fromLTRB(28, 22, 28, 0),
            child: Row(
              children: [
                Text('9:41', style: mono(13, weight: 600, color: p.text)),
                const Spacer(),
                Icon(CupertinoIcons.wifi, size: 16, color: p.text),
                const SizedBox(width: 6),
                Icon(CupertinoIcons.battery_full, size: 20, color: p.text),
              ],
            ),
          ),
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedBuilder(
                animation: _island,
                builder: (context, _) => _Island(
                  size: _island.value(_shape),
                  content: _island.value(_content),
                  bell: _island.value(_bell),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: PillButton(
                label: 'Ping',
                icon: CupertinoIcons.bell,
                filled: true,
                onTap: _ping,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Island extends StatelessWidget {
  const _Island({
    required this.size,
    required this.content,
    required this.bell,
  });

  final Size size;
  final double content;
  final double bell;

  @override
  Widget build(BuildContext context) {
    const white = CupertinoColors.white;
    return Container(
      width: size.width,
      height: size.height,
      clipBehavior: .antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF000000),
        borderRadius: .circular(size.height / 2),
      ),
      child: Stack(
        clipBehavior: .none,
        children: [
          Positioned(
            left: (size.width - _expanded.width) / 2,
            top: (size.height - _expanded.height) / 2,
            width: _expanded.width,
            height: _expanded.height,
            child: Reveal(
              progress: content,
              offset: const Offset(0, 4),
              child: Padding(
                padding: const .symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Transform.rotate(
                      angle: bell,
                      alignment: .topCenter,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: .circle,
                          color: Palette.dark.accent,
                        ),
                        child: Icon(
                          CupertinoIcons.bell_fill,
                          color: Palette.dark.onAccent,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: .center,
                        crossAxisAlignment: .start,
                        children: [
                          Text(
                            'motor 2.0 is here',
                            maxLines: 1,
                            overflow: .ellipsis,
                            style: archivo(16, weight: 600, color: white),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tracks, steps and timelines.',
                            maxLines: 1,
                            overflow: .ellipsis,
                            style: archivo(
                              13,
                              color: white.withValues(alpha: .6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'NOW',
                      style: mono(11, color: white.withValues(alpha: .5)),
                    ),
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
