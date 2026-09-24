import 'package:auto_route/auto_route.dart';
import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:motor/motor.dart';
import 'package:motor_devtools/motor_devtools.dart';
import 'package:motor_example/chapters.dart';
import 'package:motor_example/main.dart';
import 'package:motor_example/widgets/controls.dart';
import 'package:motor_example/widgets/motor_logo.dart';
import 'package:motor_example/widgets/style.dart';

/// The gallery's front page: a short pitch and the chapters in order.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  // Hero lines, the start button, then one per chapter.
  static final _count = 4 + chapters.length;

  late final _entrance = TrackController(
    vsync: this,
    debugLabel: 'Home entrance',
  );
  final _reveals = [
    for (var i = 0; i < _count; i++)
      Track<double>(.single, initial: 0, debugLabel: 'Item ${i + 1}'),
  ];

  @override
  void initState() {
    super.initState();
    _enter();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  void _enter() {
    _entrance
      ..set([for (final reveal in _reveals) reveal.value(0)])
      ..play(
        TrackTimeline([
          for (final (index, reveal) in _reveals.indexed)
            reveal([
              .hold(Duration(milliseconds: 70 * index)),
              .to(
                1,
                motion: .smoothSpring(duration: Duration(milliseconds: 700)),
              ),
            ]),
        ]),
      );
  }

  Widget _reveal(int index, Widget child) => AnimatedBuilder(
    animation: _entrance.animationOf(_reveals[index]),
    builder: (context, child) => Reveal(
      progress: _entrance.value(_reveals[index]),
      offset: const Offset(0, 18),
      child: child!,
    ),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    final wide = MediaQuery.sizeOf(context).width > 760;
    return CupertinoPageScaffold(
      backgroundColor: t.canvas,
      child: DefaultTextStyle(
        style: t.body,
        child: Stack(
          children: [
            const Positioned(
              top: -80,
              left: 0,
              right: 0,
              height: 420,
              child: AmbientGlow(opacity: .22),
            ),
            SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 56),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: wide ? 920 : 600),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _Header(),
                        SizedBox(height: wide ? 88 : 56),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  GestureDetector(
                                    onTap: _enter,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _reveal(
                                          0,
                                          Text(
                                            'Motion that',
                                            style: t.display.copyWith(
                                              fontSize: wide ? 76 : 52,
                                            ),
                                          ),
                                        ),
                                        _reveal(
                                          1,
                                          Text(
                                            'keeps up.',
                                            style: t.display.copyWith(
                                              fontSize: wide ? 76 : 52,
                                              color: t.textTertiary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  _reveal(
                                    2,
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 440,
                                      ),
                                      child: const Text(
                                        'Springs that keep their velocity, tracks that '
                                        'wait for each other, timelines you can scrub. '
                                        'Seven short chapters, one idea each.',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 28),
                                  _reveal(3, const _StartButton()),
                                ],
                              ),
                            ),
                            if (wide)
                              _reveal(
                                3,
                                const SizedBox(
                                  width: 340,
                                  height: 340,
                                  child: _Orb(),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: wide ? 88 : 56),
                        Text('CHAPTERS', style: t.eyebrow),
                        const SizedBox(height: 16),
                        _ChapterGrid(
                          columns: wide ? 2 : 1,
                          children: [
                            for (final (index, chapter) in chapters.indexed)
                              _reveal(4 + index, _ChapterCard(chapter)),
                          ],
                        ),
                        const SizedBox(height: 40),
                        Center(
                          child: Text(
                            'motor 2.0 · whynotmake.it',
                            style: t.caption,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          const MotorLogo(size: 28),
          const SizedBox(width: 10),
          Text(
            'motor',
            style: archivo(
              20,
              weight: 560,
              width: 118,
              spacing: -.4,
            ).copyWith(color: t.textPrimary),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: t.borderStrong),
            ),
            child: Text('2.0', style: t.eyebrow.copyWith(letterSpacing: .4)),
          ),
          const Spacer(),
          const _DevToolsToggle(),
        ],
      ),
    );
  }
}

class _DevToolsToggle extends StatelessWidget {
  const _DevToolsToggle();

  @override
  Widget build(BuildContext context) {
    if (!kMotorDevTools) return const SizedBox.shrink();
    final t = ExampleTheme.of(context);
    return ValueListenableBuilder(
      valueListenable: devtoolsEnabled,
      builder: (context, enabled, _) => Semantics(
        toggled: enabled,
        label: 'DevTools',
        child: PressScale(
          onTap: () => devtoolsEnabled.value = !enabled,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
            decoration: BoxDecoration(
              color: t.surfaceSolid,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: t.border),
              boxShadow: t.hairlineShadow,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'DevTools',
                  style: archivo(13, weight: 520, color: t.textPrimary),
                ),
                const SizedBox(width: 10),
                SingleMotionBuilder(
                  value: enabled ? 1 : 0,
                  motion: const .bouncySpring(),
                  debugLabel: 'DevTools switch',
                  builder: (context, on, _) => Container(
                    width: 40,
                    height: 24,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Color.lerp(
                        t.pebble,
                        t.textPrimary,
                        on.clamp(0, 1),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Align(
                      alignment: Alignment(on * 2 - 1, 0),
                      child: Container(
                        width: 18 + 4 * (1 - (on * 2 - 1).abs()),
                        height: 18,
                        decoration: BoxDecoration(
                          color: t.surfaceSolid,
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton();

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return PressScale(
      onTap: () => context.navigateTo(NamedRoute(chapters.first.title)),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 14, 18, 14),
        decoration: BoxDecoration(
          color: t.textPrimary,
          borderRadius: BorderRadius.circular(99),
          boxShadow: t.softShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Start with ${chapters.first.title}',
              style: archivo(15, weight: 540, color: t.canvas),
            ),
            const SizedBox(width: 10),
            Icon(CupertinoIcons.arrow_right, size: 17, color: t.canvas),
          ],
        ),
      ),
    );
  }
}

class _ChapterGrid extends StatelessWidget {
  const _ChapterGrid({required this.columns, required this.children});

  final int columns;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 14.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

class _ChapterCard extends StatelessWidget {
  const _ChapterCard(this.chapter);

  final Chapter chapter;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return PressScale(
      onTap: () => context.navigateTo(NamedRoute(chapter.title)),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: t.surfaceSolid,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: t.border),
          boxShadow: t.hairlineShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: t.fog,
                borderRadius: BorderRadius.circular(18),
              ),
              child: _Glyph(chapters.indexOf(chapter)),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(chapter.number, style: t.eyebrow),
                  const SizedBox(height: 6),
                  Text(chapter.title, style: t.title),
                  const SizedBox(height: 4),
                  Text(
                    chapter.idea,
                    style: t.body.copyWith(fontSize: 14, height: 1.35),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(CupertinoIcons.chevron_right, size: 16, color: t.textTertiary),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

/// A tiny drawing of each chapter's idea.
class _Glyph extends StatelessWidget {
  const _Glyph(this.index);

  final int index;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    Widget box(double w, double h, {Color? color, double r = 6}) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: color ?? t.textPrimary,
        borderRadius: BorderRadius.circular(r),
      ),
    );
    final accent = trackColors[index % trackColors.length];
    return Center(
      child: switch (index) {
        // Retarget: an indicator stretched between two tabs.
        0 => Container(
          width: 64,
          height: 22,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: t.pebble,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Align(
            alignment: const Alignment(.3, 0),
            child: box(30, 16, color: accent, r: 8),
          ),
        ),
        // Throw: a card flying off with a blur trail.
        1 => Transform.rotate(
          angle: -.18,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final alpha in [.15, .3])
                Padding(
                  padding: const EdgeInsets.only(right: 3),
                  child: box(6, 30, color: accent.withValues(alpha: alpha)),
                ),
              box(36, 30, color: accent, r: 8),
            ],
          ),
        ),
        // Tracks: a button becoming a panel.
        2 => Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            box(16, 16, r: 8),
            const SizedBox(width: 6),
            box(34, 44, color: accent, r: 10),
          ],
        ),
        // Steps: a staircase.
        3 => Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final (i, h) in [14.0, 26.0, 38.0].indexed) ...[
              box(12, h, color: i == 2 ? accent : null, r: 3),
              const SizedBox(width: 4),
            ],
          ],
        ),
        // Sync: two lanes meeting at a barrier.
        4 => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                box(20, 8, r: 4),
                const SizedBox(height: 8),
                box(36, 8, color: accent, r: 4),
              ],
            ),
            const SizedBox(width: 4),
            box(2, 40, color: t.textTertiary, r: 1),
          ],
        ),
        // Phases: three sizes of one thing.
        5 => Stack(
          alignment: Alignment.bottomLeft,
          children: [
            box(52, 44, color: t.pebble, r: 10),
            box(38, 28, color: t.borderStrong, r: 8),
            box(22, 14, color: accent, r: 7),
          ],
        ),
        // Scrub: a timeline with a playhead.
        _ => SizedBox(
          width: 56,
          height: 40,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Positioned(top: 8, child: box(40, 6, color: t.pebble, r: 3)),
              Positioned(
                top: 18,
                left: 12,
                child: box(44, 6, color: t.pebble, r: 3),
              ),
              Positioned(
                top: 28,
                left: 4,
                child: box(30, 6, color: t.pebble, r: 3),
              ),
              Positioned(left: 30, child: box(2, 40, color: accent, r: 1)),
            ],
          ),
        ),
      },
    );
  }
}

/// A blob to grab and throw. It springs home with the throw's velocity and
/// stretches along its direction of travel.
class _Orb extends StatefulWidget {
  const _Orb();

  @override
  State<_Orb> createState() => _OrbState();
}

class _OrbState extends State<_Orb> with SingleTickerProviderStateMixin {
  late final _offset = MotionController<Offset>(
    motion: const .bouncySpring(duration: Duration(milliseconds: 700)),
    vsync: this,
    converter: .offset,
    initialValue: Offset.zero,
    debugLabel: 'Home orb',
  );

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onPanUpdate: (details) =>
              _offset.value = _offset.value + details.delta,
          onPanEnd: (details) => _offset.animateTo(
            Offset.zero,
            withVelocity: details.velocity.pixelsPerSecond,
          ),
          child: AnimatedBuilder(
            animation: _offset,
            builder: (context, child) {
              final velocity = _offset.velocity;
              final stretch = 1 + (velocity.distance / 5000).clamp(0.0, .35);
              return Transform.translate(
                offset: _offset.value,
                child: Transform.rotate(
                  angle: velocity.direction,
                  child: Transform.scale(
                    scaleX: stretch,
                    scaleY: 1 / stretch,
                    child: Transform.rotate(
                      angle: -velocity.direction,
                      child: child,
                    ),
                  ),
                ),
              );
            },
            child: Container(
              width: 168,
              height: 168,
              foregroundDecoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(-.35, -.45),
                  radius: .9,
                  colors: [
                    CupertinoColors.white.withValues(alpha: .7),
                    CupertinoColors.white.withValues(alpha: 0),
                  ],
                ),
              ),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const SweepGradient(
                  colors: [
                    ExampleTheme.signalBlue,
                    ExampleTheme.roseQuartz,
                    ExampleTheme.spectrumRed,
                    ExampleTheme.marigold,
                    ExampleTheme.signalBlue,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: ExampleTheme.roseQuartz.withValues(alpha: .35),
                    blurRadius: 60,
                    offset: const Offset(0, 24),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text('grab me, throw me', style: t.caption),
      ],
    );
  }
}
