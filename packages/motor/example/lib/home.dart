// MotorInspectionScope is part of motor's experimental inspection API.
// ignore_for_file: experimental_member_use

import 'dart:math' as math;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/cupertino.dart';
import 'package:motor/inspection.dart';
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
  // Title, text, the start button, then one per chapter.
  static final _count = 3 + chapters.length;

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
              .hold(Duration(milliseconds: 50 * index)),
              .to(1, motion: .curved(Duration(milliseconds: 300), easeOut)),
            ]),
        ]),
      );
  }

  Widget _reveal(int index, Widget child) {
    final reveal = _entrance.animationOf(_reveals[index]);
    return AnimatedBuilder(
      animation: reveal,
      builder: (context, child) =>
          Reveal(progress: reveal.value, blur: 0, child: child!),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final wide = MediaQuery.sizeOf(context).width > 760;
    final headline = p.display.copyWith(fontSize: wide ? 68 : 46);
    return CupertinoPageScaffold(
      backgroundColor: p.canvas,
      child: DefaultTextStyle(
        style: p.body,
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const .fromLTRB(20, 8, 20, 56),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: wide ? 920 : 600),
                child: Column(
                  crossAxisAlignment: .start,
                  children: [
                    const _Header(),
                    SizedBox(height: wide ? 96 : 56),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: .start,
                            children: [
                              _Headline(
                                size: headline.fontSize!,
                                reveal: (child) => _reveal(0, child),
                              ),
                              const SizedBox(height: 24),
                              _reveal(
                                1,
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 440,
                                  ),
                                  child: Column(
                                    crossAxisAlignment: .start,
                                    children: [
                                      Text(
                                        'Choreography you can interrupt.',
                                        style: p.display.copyWith(
                                          fontSize: wide ? 30 : 24,
                                          height: 1.15,
                                          letterSpacing: -.6,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'Motor plays curves, springs, friction '
                                        'or your own motions across as many '
                                        'properties as you want, and carries '
                                        'on from wherever it is when you tap, '
                                        'drag or scrub.',
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 28),
                              _reveal(2, const _StartButton()),
                            ],
                          ),
                        ),
                        if (wide)
                          _reveal(
                            2,
                            const SizedBox(
                              width: 320,
                              height: 320,
                              child: _Orb(),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: wide ? 96 : 56),
                    Container(height: 1, color: p.border),
                    const SizedBox(height: 20),
                    Text('Examples', style: p.title),
                    const SizedBox(height: 16),
                    _ChapterGrid(
                      columns: wide ? 3 : 2,
                      children: [
                        for (final (index, chapter) in chapters.indexed)
                          _reveal(3 + index, _ChapterCard(chapter)),
                      ],
                    ),
                    const SizedBox(height: 48),
                    Text('motor 2.0 by whynotmake.it', style: p.caption),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 44,
      child: Align(
        alignment: .centerRight,
        child: FittedBox(fit: .scaleDown, child: _DevToolsToggle()),
      ),
    );
  }
}

/// The logo, the animated title and the version.
class _Headline extends StatelessWidget {
  const _Headline({required this.size, required this.reveal});

  final double size;
  final Widget Function(Widget child) reveal;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    // Scales down on windows too narrow for it.
    return FittedBox(
      fit: .scaleDown,
      alignment: .centerLeft,
      child: Row(
        mainAxisSize: .min,
        children: [
          reveal(MotorLogo(size: size * .72)),
          SizedBox(width: size * .24),
          Row(
            mainAxisSize: .min,
            crossAxisAlignment: .baseline,
            textBaseline: .alphabetic,
            children: [
              _Title(size: size),
              SizedBox(width: size * .18),
              reveal(
                Text(
                  '2.0',
                  style: mono(size * .26, weight: 600, color: p.accent),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One letter of the title: how heavy and wide it is, and how far it has
/// still to slide in.
typedef _Letter = ({double weight, double width, double shift});

final _letterConverter = MotionConverter<_Letter>.custom(
  normalize: (letter) => [letter.weight, letter.width, letter.shift],
  denormalize: (values) =>
      (weight: values[0], width: values[1], shift: values[2]),
);

const _Letter _hidden = (weight: 100, width: 62, shift: -40);
const _Letter _resting = (weight: 560, width: 106, shift: 0);
const _Letter _hovered = (weight: 900, width: 118, shift: 0);

/// The title, set in Archivo's weight and width axes. Its letters slide in
/// together and fill out from thin and narrow to bold and wide, one after
/// another. Hover a letter to make it heavier, tap the title to play it again.
class _Title extends StatefulWidget {
  const _Title({required this.size});

  final double size;

  @override
  State<_Title> createState() => _TitleState();
}

class _TitleState extends State<_Title> with SingleTickerProviderStateMixin {
  static const _word = 'Motor';
  static const _slide = Motion.bouncySpring(
    extraBounce: .3,
    duration: Duration(milliseconds: 1000),
  );

  late final _title = TrackController(vsync: this, debugLabel: 'Title');

  // As in the 1.1 example, every letter starts at once, and each one's weight
  // and width spring is 200 ms longer than the one before it, so the letters
  // stagger by settling later rather than by waiting.
  final _letters = [
    for (final (index, letter) in _word.split('').indexed)
      Track<_Letter>.motionPerDimension(
        _letterConverter,
        motionPerDimension: [
          ...List.filled(
            2,
            Motion.bouncySpring(
              extraBounce: .3,
              duration: Duration(milliseconds: 1000 + 200 * index),
            ),
          ),
          _slide,
        ],
        initial: _hidden,
        debugLabel: letter,
      ),
  ];

  @override
  void initState() {
    super.initState();
    _enter();
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _enter() {
    _title
      ..set([for (final letter in _letters) letter.value(_hidden)])
      ..play(
        TrackTimeline([
          for (final letter in _letters) letter([.to(_resting)]),
        ]),
      );
  }

  void _hover(int index, {required bool on}) =>
      _title.animate([_letters[index].to(on ? _hovered : _resting)]);

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return GestureDetector(
      onTap: _enter,
      child: AnimatedBuilder(
        animation: _title,
        builder: (context, _) => Row(
          mainAxisSize: .min,
          crossAxisAlignment: .baseline,
          textBaseline: .alphabetic,
          children: [
            for (final (index, track) in _letters.indexed)
              MouseRegion(
                onEnter: (_) => _hover(index, on: true),
                onExit: (_) => _hover(index, on: false),
                child: _letter(_word[index], _title.value(track), p),
              ),
          ],
        ),
      ),
    );
  }

  Widget _letter(String character, _Letter letter, Palette p) => Opacity(
    opacity: (1 + letter.shift / -_hidden.shift).clamp(0.0, 1.0),
    child: Transform.translate(
      offset: Offset(letter.shift, 0),
      child: Text(
        character,
        style: archivo(
          widget.size,
          weight: letter.weight.clamp(100, 900),
          width: letter.width.clamp(62, 125),
          height: 1.05,
          spacing: -widget.size * .02,
          color: p.text,
        ),
      ),
    ),
  );
}

class _DevToolsToggle extends StatelessWidget {
  const _DevToolsToggle();

  @override
  Widget build(BuildContext context) {
    if (!kMotorDevTools) return const SizedBox.shrink();
    final p = Palette.of(context);
    return ValueListenableBuilder(
      valueListenable: devtoolsVisible,
      builder: (context, visible, _) => Semantics(
        toggled: visible,
        label: 'DevTools',
        child: PressScale(
          onTap: () => devtoolsVisible.value = !visible,
          child: Container(
            height: 32,
            padding: const .fromLTRB(10, 0, 5, 0),
            decoration: BoxDecoration(
              borderRadius: .circular(radius),
              border: Border.all(color: p.border),
            ),
            child: Row(
              mainAxisSize: .min,
              children: [
                Text(
                  'DevTools',
                  style: archivo(13, weight: 500, color: p.text),
                ),
                const SizedBox(width: 10),
                SingleMotionBuilder(
                  value: visible ? 1 : 0,
                  motion: const .snappySpring(),
                  debugLabel: 'DevTools switch',
                  builder: (context, on, _) => Container(
                    width: 34,
                    height: 20,
                    padding: const .all(2),
                    decoration: BoxDecoration(
                      color: Color.lerp(p.control, p.accent, on.clamp(0, 1)),
                      borderRadius: .circular(radius),
                    ),
                    child: Align(
                      alignment: Alignment(on * 2 - 1, 0),
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: p.surface,
                          borderRadius: .circular(radius),
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
    final p = Palette.of(context);
    return PressScale(
      onTap: () => context.navigateTo(NamedRoute(chapters.first.title)),
      child: Container(
        // Centres the ink rather than the boxes: the caps sit low in the
        // line, and the arrow has a little space on its right.
        padding: const .fromLTRB(16, 11, 15, 15),
        decoration: BoxDecoration(
          color: p.accent,
          borderRadius: .circular(radius),
        ),
        child: Row(
          mainAxisSize: .min,
          crossAxisAlignment: .baseline,
          textBaseline: .alphabetic,
          children: [
            Flexible(
              child: Text(
                'Start with ${chapters.first.title}',
                maxLines: 1,
                overflow: .ellipsis,
                style: archivo(14, weight: 560, color: p.onAccent),
              ),
            ),
            const SizedBox(width: 10),
            // The arrow sits high in its font; this centres it on the text.
            Transform.translate(
              offset: const Offset(0, 1.5),
              child: Icon(
                CupertinoIcons.arrow_right,
                size: 15,
                color: p.onAccent,
              ),
            ),
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
        const gap = 16.0;
        final width = ((constraints.maxWidth - gap * (columns - 1)) / columns)
            .clamp(0.0, double.infinity);
        return Wrap(
          spacing: gap,
          runSpacing: gap + 4,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

// Every card rests at its own slight angle, in degrees.
const _tilts = [-1.8, 1.4, -1.1, 2.0, -1.5, 1.2, -1.9];

final _scaleAndTurn = MotionConverter<(double, double)>.custom(
  normalize: (value) => [value.$1, value.$2],
  denormalize: (values) => (values[0], values[1]),
);

/// A chapter card that rests a little crooked, straightens and lifts under
/// the pointer, and squeezes when pressed.
class _ChapterCard extends StatefulWidget {
  const _ChapterCard(this.chapter);

  final Chapter chapter;

  @override
  State<_ChapterCard> createState() => _ChapterCardState();
}

class _ChapterCardState extends State<_ChapterCard> {
  var _hovered = false;
  var _pressed = false;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final index = chapters.indexOf(widget.chapter);
    final calm = _hovered || _pressed;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () => context.navigateTo(NamedRoute(widget.chapter.title)),
        child: MotorInspectionScope(
          group: 'Chapter cards',
          child: MotionBuilder<(double, double)>(
            value: (
              _pressed ? .97 : (_hovered ? 1.02 : 1),
              calm ? 0 : _tilts[index % _tilts.length] * math.pi / 180,
            ),
            motion: const .cupertino(
              duration: Duration(milliseconds: 400),
              bounce: .25,
            ),
            converter: _scaleAndTurn,
            debugLabel: 'Chapter card ${widget.chapter.number}',
            builder: (context, value, child) => Transform.rotate(
              angle: value.$2,
              child: Transform.scale(scale: value.$1, child: child),
            ),
            child: Container(
              padding: const .all(8),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: .circular(radius),
                border: Border.all(color: calm ? p.borderStrong : p.border),
              ),
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  AspectRatio(
                    aspectRatio: 1.35,
                    child: Container(
                      decoration: BoxDecoration(
                        color: p.inset,
                        borderRadius: .circular(radius),
                      ),
                      // Drawn at one size and scaled to fit, so its fixed
                      // shapes never meet a narrow card.
                      child: FractionallySizedBox(
                        widthFactor: .7,
                        heightFactor: .7,
                        child: FittedBox(
                          child: SizedBox(
                            width: 96,
                            height: 64,
                            child: _Glyph(index),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const .fromLTRB(6, 14, 6, 8),
                    child: Column(
                      crossAxisAlignment: .start,
                      children: [
                        Text(widget.chapter.title, style: p.title),
                        const SizedBox(height: 4),
                        Text(
                          widget.chapter.idea,
                          maxLines: 3,
                          overflow: .ellipsis,
                          style: p.body.copyWith(fontSize: 13, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
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
    final p = Palette.of(context);
    Widget box(double w, double h, {Color? color, double r = 2}) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: color ?? p.text,
        borderRadius: .circular(r),
      ),
    );
    final accent = p.accent;
    return Center(
      child: switch (index) {
        // Toggle: a switch, on.
        0 => Container(
          width: 52,
          height: 30,
          padding: const .all(3),
          decoration: BoxDecoration(color: accent, borderRadius: .circular(15)),
          child: Align(
            alignment: .centerRight,
            child: box(24, 24, color: p.surface, r: 12),
          ),
        ),
        // Retarget: an indicator stretched between two tabs.
        1 => Container(
          width: 64,
          height: 22,
          padding: const .all(3),
          decoration: BoxDecoration(
            color: p.control,
            borderRadius: .circular(11),
          ),
          child: Align(
            alignment: const Alignment(.3, 0),
            child: box(30, 16, color: accent, r: 8),
          ),
        ),
        // Card stack: a card thrown off the stack.
        2 => Transform.rotate(
          angle: -.18,
          child: Row(
            mainAxisSize: .min,
            children: [
              for (final alpha in [.15, .3])
                Padding(
                  padding: const .only(right: 3),
                  child: box(6, 30, color: p.text.withValues(alpha: alpha)),
                ),
              box(36, 30, color: accent),
            ],
          ),
        ),
        // Steps: a staircase.
        3 => Row(
          mainAxisSize: .min,
          crossAxisAlignment: .end,
          children: [
            for (final (i, h) in [14.0, 26.0, 38.0].indexed) ...[
              box(12, h, color: i == 2 ? accent : null, r: 3),
              const SizedBox(width: 4),
            ],
          ],
        ),
        // Sync: two lanes meeting at a barrier.
        4 => Row(
          mainAxisSize: .min,
          children: [
            Column(
              mainAxisSize: .min,
              crossAxisAlignment: .end,
              children: [
                box(20, 8, r: 4),
                const SizedBox(height: 8),
                box(36, 8, color: accent, r: 4),
              ],
            ),
            const SizedBox(width: 4),
            box(2, 40, color: p.textTertiary, r: 1),
          ],
        ),
        // Phases: three sizes of one thing.
        5 => Stack(
          alignment: .bottomLeft,
          children: [
            box(52, 44, color: p.control, r: 10),
            box(38, 28, color: p.borderStrong, r: 8),
            box(22, 14, color: accent, r: 7),
          ],
        ),
        // Scrub: a timeline with a playhead.
        _ => SizedBox(
          width: 56,
          height: 40,
          child: Stack(
            alignment: .centerLeft,
            children: [
              Positioned(top: 8, child: box(40, 6, color: p.control, r: 3)),
              Positioned(
                top: 18,
                left: 12,
                child: box(44, 6, color: p.control, r: 3),
              ),
              Positioned(
                top: 28,
                left: 4,
                child: box(30, 6, color: p.control, r: 3),
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

class _OrbState extends State<_Orb> with TickerProviderStateMixin {
  late final _offset = MotionController<Offset>(
    motion: const .bouncySpring(duration: Duration(milliseconds: 700)),
    vsync: this,
    converter: .offset,
    initialValue: .zero,
    debugLabel: 'Home orb',
  )..addListener(_followStretch);

  // How far the ball stretches, and in which direction. A spring follows the
  // raw stretch from the ball's velocity, which is jittery while dragging.
  late final _stretch = MotionController<Offset>(
    motion: const .smoothSpring(duration: Duration(milliseconds: 220)),
    vsync: this,
    converter: .offset,
    initialValue: .zero,
    debugLabel: 'Home orb stretch',
  );

  @override
  void dispose() {
    _offset.dispose();
    _stretch.dispose();
    super.dispose();
  }

  void _followStretch() {
    final velocity = _offset.velocity;
    final amount = (velocity.distance / 5000).clamp(0.0, .3);
    _stretch.animateTo(
      velocity == .zero
          ? .zero
          : Offset.fromDirection(velocity.direction, amount),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Column(
      mainAxisAlignment: .center,
      children: [
        GestureDetector(
          onPanUpdate: (details) =>
              _offset.value = _offset.value + details.delta,
          onPanEnd: (details) => _offset.animateTo(
            .zero,
            withVelocity: details.velocity.pixelsPerSecond,
          ),
          child: AnimatedBuilder(
            animation: Listenable.merge([_offset, _stretch]),
            builder: (context, child) {
              final stretch = _stretch.value;
              final scale = 1 + stretch.distance;
              return Transform.translate(
                offset: _offset.value,
                child: Transform.rotate(
                  angle: stretch.direction,
                  child: Transform.scale(
                    scaleX: scale,
                    scaleY: 1 / scale,
                    child: Transform.rotate(
                      angle: -stretch.direction,
                      child: child,
                    ),
                  ),
                ),
              );
            },
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(color: p.accent, shape: .circle),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text('Grab me, throw me', style: p.caption),
      ],
    );
  }
}
