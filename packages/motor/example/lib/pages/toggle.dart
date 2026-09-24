import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/chapters.dart';
import 'package:motor_example/widgets/chapter_page.dart';
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
    'toggle.animate([thumb.to(1), squish.to(0), tint.to(1)]);',
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
              'toggle.animate([squish.to(1)]);'
        : 'toggle.animate([squish.to(0)]);';
    _toggle.animate([_squish.to(down ? 1 : 0)]);
  }

  void _switch(bool on, {String why = 'Tapped'}) {
    setState(() => _on = on);
    final to = on ? 1.0 : 0.0;
    _code.value =
        '// $why: every track springs to its target.\n'
        'toggle.animate([thumb.to(${to.round()}), squish.to(0), '
        'tint.to(${to.round()})]);';
    _toggle.animate([_thumb.to(to), _squish.to(0), _tint.to(to)]);
  }

  void _drag(DragUpdateDetails details) {
    final thumb = (_toggle.value(_thumb) + details.delta.dx / _travel).clamp(
      -.15,
      1.15,
    );
    _code.value =
        '// Dragging: set() follows your finger and tracks its speed.\n'
        'toggle.set([thumb.value(${thumb.toStringAsFixed(2)})]);';
    _toggle.set([_thumb.value(thumb)]);
  }

  void _release(DragEndDetails _) {
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
        'like.animate([scale.to(.85)]);';
    _like.animate([
      _scale.to(
        .85,
        motion: .snappySpring(duration: Duration(milliseconds: 150)),
      ),
    ]);
  }

  void _releaseHeart() {
    setState(() => _liked = !_liked);
    if (!_liked) {
      _code.value = '// Unliked.\nlike.animate([scale.to(1)]);';
      _like.animate([_scale.to(1)]);
      return;
    }
    _code.value =
        '// Liked: the scale pops on a keyframe, the burst plays once.\n'
        'like.animate([\n'
        '  scale([.at(Duration(milliseconds: 120), 1.3), .to(1)]),\n'
        '  burst.to(1, from: 0),\n'
        ']);';
    _like.animate([
      _scale([
        .at(
          const Duration(milliseconds: 120),
          1.3,
          motion: .curved(Duration(milliseconds: 120), easeOut),
        ),
        .to(1),
      ]),
      _burst.to(
        1,
        from: 0,
        motion: .curved(Duration(milliseconds: 450), easeOut),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return ChapterPage(
      chapter: chapterNamed('Toggle'),
      lead:
          'The switch and the heart each have their own controller. Drag the '
          'switch and let go: set() follows your finger, then animate() takes '
          'over at the speed you left it at. The code and timeline show '
          'whichever you touched last.',
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
          GestureDetector(
            onTapDown: (_) => _press(true),
            onTapCancel: () => _press(false),
            onTap: () => _switch(!_on),
            onHorizontalDragStart: (_) => _press(true),
            onHorizontalDragUpdate: _drag,
            onHorizontalDragEnd: _release,
            child: AnimatedBuilder(
              animation: _toggle,
              builder: (context, _) => _Switch(
                thumb: _toggle.value(_thumb),
                squish: _toggle.value(_squish),
                tint: _toggle.value(_tint),
              ),
            ),
          ),
          const SizedBox(height: 64),
          GestureDetector(
            onTapDown: (_) => _pressHeart(),
            onTapCancel: () => _like.animate([_scale.to(1)]),
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
    final p = Palette.of(context);
    final at = thumb.clamp(0.0, 1.0);
    // Past either end the thumb presses against the wall instead of leaving
    // the track.
    final press = (thumb - at).abs() * _knob;
    final width = _knob + 18 * squish - press;
    final height = _knob + press * .5;
    return Container(
      width: _width,
      height: _height,
      padding: const .all(6),
      decoration: BoxDecoration(
        color: Color.lerp(p.control, p.accent, tint.clamp(0, 1)),
        borderRadius: .circular(_height / 2),
      ),
      child: Stack(
        clipBehavior: .none,
        children: [
          Positioned(
            left: at * (_travel + _knob - width),
            top: (_knob - height) / 2,
            width: width,
            height: height,
            child: Container(
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: .circular(_knob / 2),
              ),
              child: Stack(
                alignment: .center,
                children: [
                  _Icon(
                    CupertinoIcons.sun_max_fill,
                    shown: 1 - at,
                    turn: -at,
                    color: p.textSecondary,
                  ),
                  _Icon(
                    CupertinoIcons.moon_fill,
                    shown: at,
                    turn: 1 - at,
                    color: p.accent,
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

/// One of the knob's icons, fading, turning and blurring into the other.
class _Icon extends StatelessWidget {
  const _Icon(
    this.icon, {
    required this.shown,
    required this.turn,
    required this.color,
  });

  final IconData icon;
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
            child: Icon(icon, size: 26, color: color),
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
    final p = Palette.of(context);
    return SizedBox.square(
      dimension: 96,
      child: Stack(
        alignment: .center,
        children: [
          if (burst > 0 && burst < 1)
            for (var i = 0; i < 8; i++)
              Transform.translate(
                offset: .fromDirection(i / 8 * 2 * math.pi, 22 + burst * 22),
                child: Container(
                  width: 5,
                  height: 5,
                  color: p.accent.withValues(alpha: 1 - burst),
                ),
              ),
          Transform.scale(
            scale: scale,
            child: Icon(
              liked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
              size: 44,
              color: liked ? p.accent : p.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
