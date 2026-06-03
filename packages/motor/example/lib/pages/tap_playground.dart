import 'dart:math' as math;

import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/widgets/example_scaffold.dart';

const _routeName = 'Tap Playground';

final _orbAlignment = Track<Alignment>(.alignment, origin: Alignment.center);
final _orbScale = Track<double>(.single, origin: 1);
final _orbRotation = Track<double>(.single, origin: 0);
final _orbTint = Track<Color>(.colorRgb, origin: Color(0xFF34C759));

class TapPlaygroundPage extends StatefulWidget {
  const TapPlaygroundPage({super.key});
  static const routeName = _routeName;

  @override
  State<TapPlaygroundPage> createState() => _TapPlaygroundPageState();
}

class _TapPlaygroundPageState extends State<TapPlaygroundPage>
    with SingleTickerProviderStateMixin {
  late final TrackController _controller;
  var _taps = 0;

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

  @override
  Widget build(BuildContext context) {
    return ExamplePage(
      title: _routeName,
      description:
          'TrackController can play timelines imperatively. Tap to launch a '
          'full multi-track animation, or drag to redirect only the alignment '
          'while scale, rotation, and color continue independently.',
      action: CupertinoButton.tinted(
        onPressed: _reset,
        child: const Text('Reset'),
      ),
      child: SizedBox(
        height: 420,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) {
                _moveOrb(details.localPosition, constraints.biggest);
              },
              onPanUpdate: (details) {
                _dragOrb(details.localPosition, constraints.biggest);
              },
              child: ListenableBuilder(
                listenable: _controller,
                builder: (context, child) {
                  final value = _controller.value;
                  final alignment = value(_orbAlignment);
                  final scale = value(_orbScale);
                  final rotation = value(_orbRotation);
                  final tint = value(_orbTint);

                  return Stage(
                    label: 'Tap or drag',
                    child: Align(
                      alignment: alignment,
                      child: Transform.rotate(
                        angle: rotation,
                        child: Transform.scale(
                          scale: scale,
                          child: _Orb(color: tint, count: _taps),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  TrackTimeline _orbAnimations(int taps, Alignment alignment) {
    final t = ExampleTheme.of(context);
    final palette = [
      t.accentGreen,
      t.accentBlue,
      t.accentPurple,
      t.accentOrange,
    ];

    return TrackTimeline([
      _orbAlignment.to(
        alignment,
        motion: .bouncySpring(
          duration: Duration(milliseconds: 800),
          extraBounce: .02,
        ),
      ),
      _orbScale([
        .to(
          1.18,
          motion: .snappySpring(
            duration: Duration(milliseconds: 180),
            extraBounce: .08,
          ),
        ),
        .to(1, motion: .bouncySpring(duration: Duration(milliseconds: 340))),
      ]),
      _orbRotation.to(
        taps * math.pi / 10,
        motion: .smoothSpring(duration: Duration(milliseconds: 420)),
      ),
      _orbTint.to(
        palette[taps % palette.length],
        motion: .smoothSpring(duration: Duration(milliseconds: 300)),
      ),
    ]);
  }

  Alignment _alignmentFrom(Offset position, Size size) {
    return Alignment(
      (position.dx / size.width).clamp(0, 1) * 2 - 1,
      (position.dy / size.height).clamp(0, 1) * 2 - 1,
    );
  }

  void _moveOrb(Offset position, Size size) {
    final nextTap = _taps + 1;
    setState(() => _taps = nextTap);
    _controller.play(_orbAnimations(nextTap, _alignmentFrom(position, size)));
  }

  void _dragOrb(Offset position, Size size) {
    _controller.animate([
      _orbAlignment.to(
        _alignmentFrom(position, size),
        motion: const Motion.bouncySpring(
          duration: Duration(milliseconds: 500),
        ),
      ),
    ]);
  }

  void _reset() {
    setState(() => _taps = 0);
    _controller.play(_orbAnimations(0, Alignment.center));
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.color, required this.count});

  final Color color;
  final int count;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: .38),
            blurRadius: 48,
            spreadRadius: 8,
          ),
        ],
      ),
      child: SizedBox(
        width: 118,
        height: 118,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.sparkles, color: t.canvas, size: 28),
            const SizedBox(height: 8),
            Text(
              '$count',
              style: TextStyle(
                color: t.canvas,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
