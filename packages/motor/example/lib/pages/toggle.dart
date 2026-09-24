import 'dart:math' as math;

import 'package:example_design/example_design.dart';
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

class _TogglePageState extends State<TogglePage>
    with SingleTickerProviderStateMixin {
  late final _toggle = TrackController(vsync: this, debugLabel: 'Toggle');

  final _thumb = Track<double>(
    .single,
    initial: 0,
    motion: .bouncySpring(extraBounce: .1),
    debugLabel: 'Thumb',
  );
  final _stretch = Track<double>(
    .single,
    initial: 0,
    motion: .snappySpring(),
    debugLabel: 'Stretch',
  );
  final _tint = Track<Color>(
    .colorRgb,
    initial: const Color(0xFFD9D9DE),
    motion: .smoothSpring(),
    debugLabel: 'Tint',
  );

  var _on = false;

  @override
  void dispose() {
    _toggle.dispose();
    super.dispose();
  }

  void _press(bool down) => _toggle.animate([_stretch.to(down ? 1 : 0)]);

  void _switch(bool on) {
    setState(() => _on = on);
    _toggle.animate([
      _thumb.to(on ? 1 : 0),
      _stretch.to(0),
      _tint.to(on ? ExampleTheme.signalBlue : const Color(0xFFD9D9DE)),
    ]);
  }

  void _drag(DragUpdateDetails details) {
    final thumb = _toggle.value(_thumb) + details.delta.dx / _travel;
    _toggle.set([_thumb.value(thumb.clamp(-.1, 1.1))]);
  }

  void _release(DragEndDetails _) {
    // set() tracked the drag's velocity; the thumb keeps it into the spring.
    final speed = _toggle.velocity(_thumb);
    final thumb = _toggle.value(_thumb);
    _switch(speed.abs() > 2 ? speed > 0 : thumb > .5);
  }

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return ChapterPage(
      chapter: chapterNamed('Toggle'),
      lead:
          'One controller, three tracks: where the thumb is, how much it '
          'squishes while you hold it, and the tint. Tap it, or drag it and '
          'let go. The spring takes over from your finger.',
      code: 'toggle.animate([thumb.to(1), stretch.to(0), tint.to(blue)]);',
      below: LiveTimeline(
        controller: _toggle,
        lanes: {_thumb: 'thumb', _stretch: 'stretch', _tint: 'tint'},
      ),
      stageHeight: 380,
      stage: Column(
        mainAxisAlignment: MainAxisAlignment.center,
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
                stretch: _toggle.value(_stretch),
                tint: _toggle.value(_tint),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text('tap or drag', style: t.caption),
          const SizedBox(height: 48),
          const _Heart(),
          const SizedBox(height: 14),
          Text('tap', style: t.caption),
        ],
      ),
    );
  }
}

class _Switch extends StatelessWidget {
  const _Switch({
    required this.thumb,
    required this.stretch,
    required this.tint,
  });

  final double thumb;
  final double stretch;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    final knobWidth = _knob + 18 * stretch;
    return Container(
      width: _width,
      height: _height,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(_height / 2),
      ),
      child: Stack(
        children: [
          Positioned(
            // Stretching grows the knob away from the side it rests on.
            left: thumb * _travel - (knobWidth - _knob) * thumb.clamp(0, 1),
            top: 0,
            bottom: 0,
            width: knobWidth,
            child: Container(
              decoration: BoxDecoration(
                color: CupertinoColors.white,
                borderRadius: BorderRadius.circular(_knob / 2),
                boxShadow: t.softShadow,
              ),
              child: Transform.rotate(
                angle: thumb * math.pi,
                child: Icon(
                  thumb > .5
                      ? CupertinoIcons.moon_fill
                      : CupertinoIcons.sun_max_fill,
                  size: 26,
                  color: Color.lerp(
                    ExampleTheme.marigold,
                    ExampleTheme.signalBlue,
                    thumb.clamp(0, 1),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A like button: a squeeze on press, a pop and a burst on release.
class _Heart extends StatefulWidget {
  const _Heart();

  @override
  State<_Heart> createState() => _HeartState();
}

class _HeartState extends State<_Heart> with SingleTickerProviderStateMixin {
  late final _like = TrackController(vsync: this, debugLabel: 'Like');

  final _scale = Track<double>(
    .single,
    initial: 1,
    motion: .bouncySpring(extraBounce: .3),
    debugLabel: 'Scale',
  );
  final _burst = Track<double>(.single, initial: 0, debugLabel: 'Burst');

  var _liked = false;

  @override
  void dispose() {
    _like.dispose();
    super.dispose();
  }

  void _release() {
    setState(() => _liked = !_liked);
    _like.animate([
      if (_liked) ...[
        _scale([
          .at(
            const Duration(milliseconds: 140),
            1.45,
            motion: .curved(Duration(milliseconds: 140), Curves.easeOut),
          ),
          .to(1),
        ]),
        _burst.to(
          1,
          from: 0,
          motion: .curved(Duration(milliseconds: 520), Curves.easeOut),
        ),
      ] else
        _scale.to(1, motion: .interactiveSpring()),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return GestureDetector(
      onTapDown: (_) =>
          _like.animate([_scale.to(.8, motion: .interactiveSpring())]),
      onTapCancel: () => _like.animate([_scale.to(1)]),
      onTapUp: (_) => _release(),
      child: AnimatedBuilder(
        animation: _like,
        builder: (context, _) {
          final burst = _like.value(_burst);
          return SizedBox.square(
            dimension: 96,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (burst > 0 && burst < 1)
                  for (var i = 0; i < 8; i++)
                    Transform.translate(
                      offset: Offset.fromDirection(
                        i / 8 * 2 * math.pi,
                        20 + burst * 26,
                      ),
                      child: Container(
                        width: 7 * (1 - burst * .5),
                        height: 7 * (1 - burst * .5),
                        decoration: BoxDecoration(
                          color: trackColors[i % trackColors.length].withValues(
                            alpha: 1 - burst,
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                Transform.scale(
                  scale: _like.value<double>(_scale),
                  child: Icon(
                    _liked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                    size: 48,
                    color: _liked ? ExampleTheme.spectrumRed : t.textTertiary,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
