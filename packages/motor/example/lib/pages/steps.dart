import 'package:example_design/example_design.dart';
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
const _collapseAt = Duration(milliseconds: 2400);
const _fadeAt = Duration(milliseconds: 1700);
const _fade = CurvedMotion(Duration(milliseconds: 220));
const _collapse = CurvedMotion(
  Duration(milliseconds: 450),
  Curves.easeInOutCubic,
);

class _StepsPageState extends State<StepsPage>
    with SingleTickerProviderStateMixin {
  late final _island = TrackController(vsync: this, debugLabel: 'Notification');

  final _width = Track<double>(
    .single,
    initial: _compact.width,
    debugLabel: 'Width',
  );
  final _height = Track<double>(
    .single,
    initial: _compact.height,
    debugLabel: 'Height',
  );
  final _content = Track<double>(.single, initial: 0, debugLabel: 'Content');
  final _bell = Track<double>(
    .single,
    initial: 0,
    motion: .curved(Duration(milliseconds: 120), Curves.easeInOut),
    debugLabel: 'Bell',
  );

  // A step after a spring starts once the spring has fully settled, well
  // after it looks done, and .at stretches its motion over the gap before it.
  // So the moments that must line up are pairs of .at keyframes on curves:
  // stay until one time, then move until the next.
  late final _ping = TrackTimeline([
    for (final (track, size) in [
      (_width, _expanded.width),
      (_height, _expanded.height),
    ])
      track([
        .to(size, motion: .bouncySpring(extraBounce: .1)),
        .at(_collapseAt - _collapse.duration, size, motion: _collapse),
        .at(
          _collapseAt,
          track == _width ? _compact.width : _compact.height,
          motion: _collapse,
        ),
      ]),
    _content([
      .hold(const Duration(milliseconds: 160)),
      .to(1, motion: .smoothSpring()),
      .at(_fadeAt, 1, motion: _fade),
      .at(_fadeAt + _fade.duration, 0, motion: _fade),
    ]),
    _bell([
      .hold(const Duration(milliseconds: 260)),
      for (final (index, angle) in const [.45, -.4, .3, -.2, 0.0].indexed)
        .at(Duration(milliseconds: 380 + 120 * index), angle),
    ]),
  ]);

  @override
  void dispose() {
    _island.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return ChapterPage(
      chapter: chapterNamed('Steps'),
      lead:
          'Each track runs a list of steps: grow, hold, wiggle, fade. The '
          'wiggle, fade and collapse are .at keyframes, so they land exactly '
          'on time. Ping again mid-way and it picks up from where it is.',
      code: 'content([.to(1), .at(fadeAt, 1), .at(fadeAt + fade, 0)])',
      below: LiveTimeline(
        controller: _island,
        lanes: {
          _width: 'width',
          _height: 'height',
          _content: 'content',
          _bell: 'bell',
        },
      ),
      stageHeight: 300,
      stage: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 22, 28, 0),
            child: Row(
              children: [
                Text(
                  '9:41',
                  style: archivo(15, weight: 600, color: t.textPrimary),
                ),
                const Spacer(),
                Icon(CupertinoIcons.wifi, size: 16, color: t.textPrimary),
                const SizedBox(width: 6),
                Icon(
                  CupertinoIcons.battery_full,
                  size: 20,
                  color: t.textPrimary,
                ),
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
                  size: Size(_island.value(_width), _island.value(_height)),
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
                onTap: () => _island.play(_ping),
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
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF050506),
        borderRadius: BorderRadius.circular(size.height / 2),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: (size.width - _expanded.width) / 2,
            top: (size.height - _expanded.height) / 2,
            width: _expanded.width,
            height: _expanded.height,
            child: Reveal(
              progress: content,
              offset: const Offset(0, 8),
              blur: 12,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Transform.rotate(
                      angle: bell,
                      alignment: Alignment.topCenter,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              ExampleTheme.spectrumRed,
                              ExampleTheme.marigold,
                            ],
                          ),
                        ),
                        child: const Icon(
                          CupertinoIcons.bell_fill,
                          color: white,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'motor 2.0 is here',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: archivo(16, weight: 600, color: white),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tracks, steps and timelines.',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: archivo(
                              13,
                              color: white.withValues(alpha: .6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'now',
                      style: archivo(12, color: white.withValues(alpha: .5)),
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
