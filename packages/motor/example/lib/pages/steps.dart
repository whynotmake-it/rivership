import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/chapters.dart';
import 'package:motor_example/widgets/chapter_page.dart';
import 'package:motor_example/widgets/icons.dart';
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
const _fadeIn = Motion.curved(Duration(milliseconds: 220), easeOut);
const _fadeOut = Motion.curved(Duration(milliseconds: 150), easeOut);

class _StepsPageState extends State<StepsPage>
    with SingleTickerProviderStateMixin {
  late final _island = TrackController(vsync: this, debugLabel: 'Notification');

  // One Size track, so width and height move as one.
  final _shape = Track<Size>(.size, initial: _compact, debugLabel: 'Shape');
  final _content = Track<double>(.single, initial: 0, debugLabel: 'Content');
  final _bell = Track<double>(
    .single,
    initial: 0,
    motion: .curved(Duration(milliseconds: 80), Curves.easeInOut),
    debugLabel: 'Bell',
  );

  // Content uses fixed-length curves, so its steps land exactly on time. The
  // shape waits at the barrier until the content has faded, then closes.
  late final List<TrackAnimation> _pingPlan = [
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
      .hold(const Duration(milliseconds: 220)),
      for (final (index, angle) in const [.35, -.3, .2, -.1, 0.0].indexed)
        .at(Duration(milliseconds: 300 + 80 * index), angle),
    ]),
  ];

  // The plan above, as it reads.
  static const _pingCode =
      'island.animate([\n'
      '  shape([\n'
      '    .to(expanded, motion: .cupertino(duration: Duration(milliseconds: 500), bounce: .2)),\n'
      '    .sync(token: #faded),\n'
      '    .to(compact, motion: .cupertino(duration: Duration(milliseconds: 400), bounce: .1)),\n'
      '  ]),\n'
      '  content([\n'
      '    .hold(Duration(milliseconds: 120)),\n'
      '    .to(1, motion: .curved(Duration(milliseconds: 220), easeOut)),\n'
      '    .hold(Duration(milliseconds: 1600)),\n'
      '    .to(0, motion: .curved(Duration(milliseconds: 150), easeOut)),\n'
      '    .sync(token: #faded),\n'
      '  ]),\n'
      '  bell([\n'
      '    .hold(Duration(milliseconds: 220)),\n'
      '    for (final (i, angle) in [.35, -.3, .2, -.1, 0.0].indexed)\n'
      '      .at(Duration(milliseconds: 300 + 80 * i), angle),\n'
      '  ]),\n'
      ']);\n'
      '// const easeOut = Cubic(.23, 1, .32, 1);';

  final _code = ValueNotifier('// Ping to play the steps.\n$_pingCode');

  @override
  void dispose() {
    _island.dispose();
    _code.dispose();
    super.dispose();
  }

  void _ping() {
    final size = _island.value(_shape);
    _code.value = size == _compact
        ? '// Plays every track\'s steps from the start.\n$_pingCode'
        : '// Played again from where it is, '
              'Size(${size.width.round()}, ${size.height.round()}).\n'
              '$_pingCode';
    _island.animate(_pingPlan);
  }

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final text = CoilTheme.textOf(context);
    return ChapterPage(
      chapter: chapterNamed('Steps'),
      lead:
          'Each track runs its own list of steps, and each step can use a '
          'different motion. The island opens on a spring, the content fades '
          'on curves, and the bell swings on .at keyframes that land exactly '
          'on time. The shape waits at a sync barrier until the content has '
          'faded, then closes. Ping again mid-way and it picks up from where '
          'it is.',
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
                Text(
                  '9:41',
                  style: text.caption
                      .copyWith(fontWeight: text.emphasis)
                      .tabular,
                ),
                const Spacer(),
                IconTheme(
                  data: IconThemeData(color: colors.foreground, size: 16),
                  child: const Row(
                    children: [
                      GlyphIcon(Glyph.wifi),
                      SizedBox(width: 6),
                      GlyphIcon(Glyph.batteryFull),
                    ],
                  ),
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
              child: CoilButton(
                leading: const GlyphIcon(Glyph.bell),
                onPressed: _ping,
                child: const Text('Ping'),
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
    final colors = CoilTheme.of(context).colors;
    final text = CoilTheme.textOf(context);
    final radius = BorderRadius.circular(
      (size.height / 2).clamp(0, CoilTheme.radiiOf(context).container * 1.5),
    );
    return Container(
      width: size.width,
      height: size.height,
      clipBehavior: .antiAlias,
      decoration: ShapeDecoration(
        color: colors.foreground,
        shape: RoundedSuperellipseBorder(borderRadius: radius),
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
                padding: const .fromLTRB(26, 0, 28, 0),
                child: Row(
                  children: [
                    // A bell swings from near its top.
                    Transform.rotate(
                      angle: bell,
                      alignment: const Alignment(0, -.8),
                      child: IconTheme(
                        data: IconThemeData(color: colors.background),
                        child: const GlyphIcon(Glyph.bellRing, size: 24),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        mainAxisSize: .min,
                        crossAxisAlignment: .start,
                        children: [
                          Row(
                            crossAxisAlignment: .baseline,
                            textBaseline: .alphabetic,
                            children: [
                              Expanded(
                                child: Text(
                                  'motor 2.0 is here',
                                  maxLines: 1,
                                  overflow: .ellipsis,
                                  style: text.body
                                      .copyWith(fontWeight: text.emphasis)
                                      .copyWith(color: colors.background),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'now',
                                style: text.caption.copyWith(
                                  color: colors.background.withValues(
                                    alpha: .6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tracks, steps and timelines.',
                            maxLines: 1,
                            overflow: .ellipsis,
                            style: text.caption.copyWith(
                              color: colors.background.withValues(alpha: .75),
                            ),
                          ),
                        ],
                      ),
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
