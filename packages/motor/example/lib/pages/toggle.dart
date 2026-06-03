import 'dart:math' as math;

import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/widgets/example_scaffold.dart';

/// Small interactive controls that feel alive — a springy switch, a like
/// button that pops, and an icon that rotates between states. Each is a single
/// motion controller toggling between targets.
class TogglePage extends StatelessWidget {
  const TogglePage({super.key});
  static const routeName = 'Toggle';

  @override
  Widget build(BuildContext context) {
    return ExamplePage(
      title: routeName,
      description:
          'Interactive state, the easy way. Each control animates a single '
          'value with a bouncy spring, so taps feel springy and responsive '
          'without any tweens or curves to hand-tune.',
      child: Surface(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
        child: Column(
          children: const [
            _Row(label: 'Spring switch', child: _SpringSwitch()),
            _Divider(),
            _Row(label: 'Like', child: _LikeButton()),
            _Divider(),
            _Row(label: 'Reveal', child: _RotateToggle()),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: t.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Container(height: 0.5, color: t.border);
  }
}

class _SpringSwitch extends StatefulWidget {
  const _SpringSwitch();
  @override
  State<_SpringSwitch> createState() => _SpringSwitchState();
}

class _SpringSwitchState extends State<_SpringSwitch>
    with TickerProviderStateMixin {
  late final _c = TrackController(vsync: this);
  late final _value = Track(
    .single,
    origin: 0.0,
    motion: MaterialSpringMotion.expressiveEffectsFast(),
  );
  late final _thumbScale = Track(
    .single,
    origin: 1.0,
    motion: .snappySpring(duration: Duration(milliseconds: 100)),
  );

  bool _on = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _on = !_on);
    _c.animate([_value.to(_on ? 1 : 0)]);
  }

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    const w = 58.0;
    const h = 34.0;
    const thumb = 26.0;
    return GestureDetector(
      onTap: _toggle,
      onTapDown: (_) => _c.animate([_thumbScale.to(.8)]),
      onTapUp: (_) => _c.animate([_thumbScale.to(1)]),
      onTapCancel: () => _c.animate([_thumbScale.to(1)]),
      child: ValueListenableBuilder(
        valueListenable: _c,
        builder: (context, v, _) {
          final clamped = v(_value).clamp(0.0, 1.0);
          final scale = v(_thumbScale);
          return Container(
            width: w,
            height: h,
            decoration: BoxDecoration(
              color: Color.lerp(t.pebble, t.textPrimary, clamped),
              borderRadius: BorderRadius.circular(h / 2),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 4 + v(_value).clamp(0.0, 1.05) * (w - thumb - 8),
                  top: (h - thumb) / 2,
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      width: thumb,
                      height: thumb,
                      decoration: BoxDecoration(
                        color: t.surfaceSolid,
                        shape: BoxShape.circle,
                        boxShadow: t.hairlineShadow,
                      ),
                    ),
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

class _LikeButton extends StatefulWidget {
  const _LikeButton();
  @override
  State<_LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<_LikeButton>
    with TickerProviderStateMixin {
  // One TrackController plays single-track timelines: a press scales the track
  // down, and the release plays the pop. Because the controller carries the
  // track's velocity into each new timeline, releasing mid-press redirects
  // smoothly instead of snapping — Motor's continuity in a tiny gesture.
  late final TrackController _controller;
  bool _liked = false;

  // A single scale track. Its default motion is the bouncy spring that gives the
  // release its pop.
  final _likeScale = Track<double>(
    .single,
    origin: 1,
    motion: .bouncySpring(extraBounce: .3),
  );

  late final _thumbColor = Track(
    .colorRgb,
    origin: _desiredThumbColor,
    motion: .snappySpring(duration: Duration(milliseconds: 100)),
  );

  Color get _desiredThumbColor =>
      _liked ? Colors.redAccent : ExampleTheme.of(context).textTertiary;

  @override
  void initState() {
    super.initState();
    _controller = TrackController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _release() {
    setState(() => _liked = !_liked);

    _controller.animate([_thumbColor.to(_desiredThumbColor)]);

    if (_liked) {
      _controller.animate([
        _likeScale([
          .at(
            Duration(milliseconds: 150),
            1.5,
            motion: .bouncySpring().trimmed(fromEnd: .5),
          ),
          .to(1),
        ]),
      ]);
    } else {
      _controller.animate([_likeScale.to(1, motion: .interactiveSpring())]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.animate([
        _likeScale.to(.8, motion: .interactiveSpring()),
      ]),
      onTapUp: (_) => _release(),
      onTapCancel: () =>
          _controller.animate([_likeScale.to(1, motion: .interactiveSpring())]),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Transform.scale(
          scale: _controller.value<double>(_likeScale),
          child: Icon(
            _liked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
            size: 28,
            color: _controller.value<Color>(_thumbColor),
          ),
        ),
      ),
    );
  }
}

class _RotateToggle extends StatefulWidget {
  const _RotateToggle();
  @override
  State<_RotateToggle> createState() => _RotateToggleState();
}

class _RotateToggleState extends State<_RotateToggle>
    with TickerProviderStateMixin {
  late final SingleMotionController _c;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _c = SingleMotionController(
      motion: const CupertinoMotion.snappy(),
      vsync: this,
      initialValue: 0,
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    _c.animateTo(_open ? 1 : 0);
  }

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return GestureDetector(
      onTap: _toggle,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: t.fog, shape: BoxShape.circle),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Transform.rotate(
            angle: _c.value * math.pi / 4,
            child: Icon(CupertinoIcons.add, size: 22, color: t.textPrimary),
          ),
        ),
      ),
    );
  }
}
