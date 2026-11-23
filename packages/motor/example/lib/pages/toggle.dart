import 'dart:math' as math;

import 'package:coil/coil.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/chapters.dart';
import 'package:motor_example/widgets/chapter_page.dart';
import 'package:motor_example/widgets/icons.dart';
import 'package:motor_example/widgets/live_timeline.dart';
import 'package:motor_example/widgets/style.dart';

/// One controller animates every part of a control.
class TogglePage extends StatefulWidget {
  const TogglePage({super.key});

  @override
  State<TogglePage> createState() => _TogglePageState();
}

const _width = 136.0;
const _height = 76.0;
const _knob = 64.0;

/// How far past an end a drag can pull the thumb, as a share of its
/// travel; the asymptote of the rubber band.
const _resistance = .2;

const _travel = _width - _knob - 12;

class _TogglePageState extends State<TogglePage> with TickerProviderStateMixin {
  late final _toggle = TrackController(vsync: this, debugLabel: 'Toggle');
  late final _like = TrackController(vsync: this, debugLabel: 'Like');

  final _thumb = Track<double>(
    .single,
    initial: 0,
    motion: .cupertino(duration: Duration(milliseconds: 300), bounce: .2),
    debugLabel: 'Thumb',
  );
  final _squish = Track<double>(
    .single,
    initial: 0,
    motion: .snappySpring(duration: Duration(milliseconds: 150)),
    debugLabel: 'Squish',
  );
  final _tint = Track<double>(
    .single,
    initial: 0,
    motion: .smoothSpring(duration: Duration(milliseconds: 200)),
    debugLabel: 'Tint',
  );
  final _scale = Track<double>(
    .single,
    initial: 1,
    motion: .cupertino(duration: Duration(milliseconds: 300), bounce: .3),
    debugLabel: 'Scale',
  );
  final _burst = Track<double>(.single, initial: 0, debugLabel: 'Burst');

  final _code = ValueNotifier(
    '// Tap the switch, or drag it and let go.\n'
    'toggle.animate([thumb([.to(1)]), squish([.to(0)]), tint([.to(1)])]);',
  );
  var _on = false;
  var _liked = false;
  var _showsLike = false;

  @override
  void dispose() {
    _toggle.dispose();
    _like.dispose();
    _code.dispose();
    super.dispose();
  }

  void _focus({required bool like}) {
    if (_showsLike != like) setState(() => _showsLike = like);
  }

  void _press(bool down) {
    _focus(like: false);
    _code.value = down
        ? '// Pressed: the thumb squishes.\n'
              'toggle.animate([squish([.to(1)])]);'
        : 'toggle.animate([squish([.to(0)])]);';
    _toggle.animate([
      _squish([.to(down ? 1 : 0)]),
    ]);
  }

  void _switch(bool on, {String why = 'Tapped'}) {
    setState(() => _on = on);
    final to = on ? 1.0 : 0.0;
    _code.value =
        '// $why: every track springs to its target.\n'
        'toggle.animate([thumb([.to(${to.round()})]), squish([.to(0)]), '
        'tint([.to(${to.round()})])]);';
    _toggle.animate([
      _thumb([.to(to)]),
      _squish([.to(0)]),
      _tint([.to(to)]),
    ]);
  }

  /// Where the finger would put the thumb, before resistance past the ends.
  double? _finger;

  void _drag(DragUpdateDetails details) {
    final finger = _finger =
        (_finger ?? _toggle.value(_thumb)) + details.delta.dx / _travel;
    // Past either end the thumb resists the finger more and more softly.
    final thumb = finger > 1
        ? 1 + rubberBand(finger - 1, limit: _resistance)
        : finger < 0
        ? -rubberBand(-finger, limit: _resistance)
        : finger;
    _code.value =
        '// Dragging: set() follows your finger and tracks its speed.\n'
        'toggle.set([thumb.value(${thumb.toStringAsFixed(2)})]);';
    _toggle.set([_thumb.value(thumb)]);
  }

  void _release(DragEndDetails _) {
    _finger = null;
    final speed = _toggle.velocity(_thumb);
    final thumb = _toggle.value(_thumb);
    _switch(
      speed.abs() > 2 ? speed > 0 : thumb > .5,
      why:
          'Let go at ${speed.toStringAsFixed(1)}/s. The thumb keeps that '
          'speed',
    );
  }

  void _pressHeart() {
    _focus(like: true);
    _code.value =
        '// Pressed: the heart shrinks.\n'
        'like.animate([\n'
        '  scale([.to(.85, motion: .snappySpring(duration: Duration(milliseconds: 150)))]),\n'
        ']);';
    _like.animate([
      _scale([
        .to(.85, motion: .snappySpring(duration: Duration(milliseconds: 150))),
      ]),
    ]);
  }

  void _releaseHeart() {
    setState(() => _liked = !_liked);
    if (!_liked) {
      _code.value = '// Unliked.\nlike.animate([scale([.to(1)])]);';
      _like.animate([
        _scale([.to(1)]),
      ]);
      return;
    }
    _code.value =
        '// Liked: the scale pops on a keyframe, the burst plays once.\n'
        'like.animate([\n'
        '  scale([\n'
        '    .at(Duration(milliseconds: 120), 1.3,\n'
        '        motion: .curved(Duration(milliseconds: 120), easeOut)),\n'
        '    .to(1),\n'
        '  ]),\n'
        '  burst([.to(1, motion: .curved(Duration(milliseconds: 450), easeOut))],\n'
        '      from: 0),\n'
        ']);\n'
        '// const easeOut = Cubic(.23, 1, .32, 1);';
    _like.animate([
      _scale([
        .at(
          const Duration(milliseconds: 120),
          1.3,
          motion: .curved(Duration(milliseconds: 120), easeOut),
        ),
        .to(1),
      ]),
      _burst([
        .to(1, motion: .curved(Duration(milliseconds: 450), easeOut)),
      ], from: 0),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return ChapterPage(
      chapter: chapterNamed('Toggle'),
      lead:
          'One controller animates the thumb, its squish and the tint. Drag '
          'the switch and let go: set() follows your finger, then animate() '
          'carries on at that speed.',
      code: _code,
      below: _showsLike
          ? LiveTimeline(
              key: const ValueKey('like'),
              controller: _like,
              lanes: {_scale: 'scale', _burst: 'burst'},
            )
          : LiveTimeline(
              key: const ValueKey('toggle'),
              controller: _toggle,
              lanes: {_thumb: 'thumb', _squish: 'squish', _tint: 'tint'},
            ),
      stageHeight: 360,
      stage: Column(
        mainAxisAlignment: .center,
        children: [
          Semantics(
            toggled: _on,
            label: 'Dark mode',
            child: GestureDetector(
              onTapDown: (_) => _press(true),
              onTapCancel: () => _press(false),
              onTap: () => _switch(!_on),
              onHorizontalDragStart: (_) {
                _finger = null;
                _press(true);
              },
              onHorizontalDragUpdate: _drag,
              onHorizontalDragEnd: _release,
              // Lost to a scroll or a tap: let go of the squish.
              onHorizontalDragCancel: () => _toggle.animate([
                _squish([.to(0)]),
              ]),
              child: AnimatedBuilder(
                animation: _toggle,
                builder: (context, _) => _Switch(
                  thumb: _toggle.value(_thumb),
                  squish: _toggle.value(_squish),
                  tint: _toggle.value(_tint),
                ),
              ),
            ),
          ),
          const SizedBox(height: 64),
          Semantics(
            button: true,
            label: 'Like',
            toggled: _liked,
            child: GestureDetector(
              onTapDown: (_) => _pressHeart(),
              onTapCancel: () => _like.animate([
                _scale([.to(1)]),
              ]),
              onTapUp: (_) => _releaseHeart(),
              child: AnimatedBuilder(
                animation: _like,
                builder: (context, _) => _Heart(
                  liked: _liked,
                  scale: _like.value(_scale),
                  burst: _like.value(_burst),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Switch extends StatelessWidget {
  const _Switch({
    required this.thumb,
    required this.squish,
    required this.tint,
  });

  final double thumb;
  final double squish;
  final double tint;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final radii = CoilTheme.radiiOf(context);
    final at = thumb.clamp(0.0, 1.0);
    final width = _knob + 18 * squish;
    // Past either end, by a drag or a spring's overshoot, the whole switch
    // stretches toward that edge and narrows to keep its area. The stretch
    // keeps growing with the overshoot, ever more softly, so a bouncy
    // spring never hits a wall.
    final over = thumb - at;
    final stretch = 1 + rubberBand(over.abs() * .35, limit: .1);
    return Transform(
      alignment: over > 0 ? .centerLeft : .centerRight,
      transform: Matrix4.diagonal3Values(stretch, 1 / stretch, 1),
      child: Container(
        width: _width,
        height: _height,
        padding: const .all(6),
        decoration: ShapeDecoration(
          color: Color.lerp(colors.accent, colors.foreground, tint.clamp(0, 1)),
          shape: RoundedSuperellipseBorder(
            borderRadius: .circular(radii.item * 2),
          ),
        ),
        child: Stack(
          clipBehavior: .none,
          children: [
            Positioned(
              left: at * (_travel + _knob - width),
              top: 0,
              width: width,
              height: _knob,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: colors.surface(4),
                  shadows: colors.shadow(2),
                  shape: RoundedSuperellipseBorder(
                    borderRadius: .circular(radii.item * 2 - 6),
                    side: BorderSide(color: colors.border),
                  ),
                ),
                child: Stack(
                  alignment: .center,
                  children: [
                    _Icon(
                      Glyph.sun,
                      shown: 1 - at,
                      turn: -at,
                      color: colors.mutedForeground,
                    ),
                    _Icon(
                      Glyph.moon,
                      shown: at,
                      turn: 1 - at,
                      color: colors.foreground,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One of the knob's icons, fading, turning and blurring into the other.
class _Icon extends StatelessWidget {
  const _Icon(
    this.icon, {
    required this.shown,
    required this.turn,
    required this.color,
  });

  final Glyph icon;
  final double shown;

  /// How far it is turned away, from -1 to 1, a quarter turn at most.
  final double turn;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final blur = 2.5 * (1 - shown);
    return Opacity(
      opacity: shown,
      child: Transform.rotate(
        angle: turn * math.pi / 2,
        child: Transform.scale(
          scale: .6 + .4 * shown,
          child: Blur(
            sigma: Offset(blur, blur),
            child: IconTheme(
              data: IconThemeData(color: color),
              child: GlyphIcon(icon, size: 26),
            ),
          ),
        ),
      ),
    );
  }
}

class _Heart extends StatelessWidget {
  const _Heart({required this.liked, required this.scale, required this.burst});

  final bool liked;
  final double scale;
  final double burst;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    return SizedBox.square(
      dimension: 96,
      child: Stack(
        alignment: .center,
        children: [
          if (burst > 0 && burst < 1)
            for (var i = 0; i < 8; i++)
              Transform.translate(
                offset: .fromDirection(i / 8 * 2 * math.pi, 22 + burst * 22),
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    shape: const CircleBorder(),
                    color: colors.brand.withValues(alpha: 1 - burst),
                  ),
                  child: const SizedBox.square(dimension: 5),
                ),
              ),
          Transform.scale(
            scale: scale,
            // Lucide has no filled heart: liked is the brand colour.
            child: IconTheme(
              data: IconThemeData(
                color: liked ? colors.brand : colors.mutedForeground,
              ),
              child: const GlyphIcon(Glyph.heart, size: 44),
            ),
          ),
        ],
      ),
    );
  }
}
