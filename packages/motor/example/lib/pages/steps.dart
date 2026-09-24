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
  final _content = Track<double>(
    .single,
    initial: 0,
    motion: .smoothSpring(),
    debugLabel: 'Content',
  );
  final _bell = Track<double>(
    .single,
    initial: 0,
    motion: .snappySpring(duration: Duration(milliseconds: 140)),
    debugLabel: 'Bell',
  );

  late final _ping = TrackTimeline([
    // Grow with a bounce, then land back exactly at _collapseAt.
    _width([
      .to(_expanded.width, motion: .bouncySpring()),
      .at(_collapseAt, _compact.width, motion: .smoothSpring()),
    ]),
    _height([
      .to(_expanded.height, motion: .bouncySpring(extraBounce: .1)),
      .at(_collapseAt, _compact.height, motion: .smoothSpring()),
    ]),
    _content([
      .hold(const Duration(milliseconds: 160)),
      .to(1),
      .hold(const Duration(milliseconds: 1100)),
      .to(0, motion: .snappySpring(duration: Duration(milliseconds: 240))),
    ]),
    _bell([
      .hold(const Duration(milliseconds: 260)),
      .to(.45),
      .to(-.4),
      .to(.3),
      .to(-.2),
      .to(0, motion: .bouncySpring()),
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
          'Each track runs a list of steps: grow, hold, wiggle, fade. Width and '
          'height use .at to land back at exactly 2.4 s, whatever their springs '
          'do first. Ping again mid-way and it picks up from where it is.',
      code: 'content([.hold(delay), .to(1), .hold(read), .to(0)])',
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
