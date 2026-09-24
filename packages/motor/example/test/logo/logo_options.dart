import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:motor_example/widgets/style.dart';

/// A candidate motor logo, painted into a square of side `size`.
class LogoOption {
  const LogoOption(this.name, this.description, this.paint);

  final String name;
  final String description;
  final void Function(Canvas canvas, double size, Palette palette) paint;
}

const logoOptions = [
  LogoOption('m', 'Two balls drop out of the two arches of an "m".', _m),
  LogoOption('yin-yang', 'Two balls circle in opposite directions.', _yinYang),
  LogoOption('echo', 'One ball, three arcs.', _echo),
  LogoOption('settle', 'One ball, arcs above and below: a spring.', _settle),
  LogoOption('follow', 'A small ball follows a big one.', _follow),
  LogoOption('lift', 'The sheet logo\'s ball and arc.', _lift),
];

/// The logo on a tilted tile, like the stupid_simple_sheet logo.
class LogoTile extends StatelessWidget {
  const LogoTile({
    required this.option,
    required this.palette,
    this.size = 224,
    super.key,
  });

  final LogoOption option;
  final Palette palette;
  final double size;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: .05,
    child: DecoratedBox(
      decoration: ShapeDecoration(
        color: palette.surface,
        shape: RoundedSuperellipseBorder(
          borderRadius: .circular(size * .29),
          side: BorderSide(color: palette.border, width: size / 112),
        ),
        shadows: [
          BoxShadow(
            color: const Color(
              0xFF000000,
            ).withValues(alpha: palette == Palette.dark ? .5 : .08),
            blurRadius: size * .07,
            offset: Offset(0, size * .036),
          ),
        ],
      ),
      child: CustomPaint(
        size: .square(size),
        painter: _LogoPainter(option, palette),
      ),
    ),
  );
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.option, this.palette);

  final LogoOption option;
  final Palette palette;

  @override
  void paint(Canvas canvas, Size size) =>
      option.paint(canvas, size.width, palette);

  @override
  bool shouldRepaint(_LogoPainter oldDelegate) =>
      option != oldDelegate.option || palette != oldDelegate.palette;
}

Paint _fill(Color color) => Paint()..color = color;

Paint _stroke(Color color, double width) => Paint()
  ..color = color
  ..style = .stroke
  ..strokeWidth = width
  ..strokeCap = .round
  ..strokeJoin = .round;

Rect _circle(Offset center, double radius) =>
    Rect.fromCircle(center: center, radius: radius);

/// A ball moving toward [heading] with the stupid_simple_sheet motion arc
/// behind it: concentric, round-capped, half the ball's radius thick, at 1.5
/// radii plus a third of its thickness, sweeping [spread]. Further arcs repeat
/// outward at the same spacing, keep the same length, and fade.
void _ball(
  Canvas canvas,
  Offset center,
  double radius,
  Color color, {
  required double heading,
  int arcs = 1,
  double spread = math.pi * .3,
  Color? arcColor,
}) {
  final weight = radius / 2;
  final first = radius * 1.5 + weight / 3;
  final spacing = first - weight / 2 - radius + weight;
  canvas.drawCircle(center, radius, _fill(color));
  for (var i = 0; i < arcs; i++) {
    final arcRadius = first + spacing * i;
    final sweep = spread * first / arcRadius;
    canvas.drawArc(
      _circle(center, arcRadius),
      heading + math.pi - sweep / 2,
      sweep,
      false,
      _stroke((arcColor ?? color).withValues(alpha: 1 - i * .32), weight),
    );
  }
}

const _up = -math.pi / 2;
const _down = math.pi / 2;

void _m(Canvas canvas, double s, Palette p) {
  const radius = .085;
  const arch = radius * 1.5 + radius / 6;
  for (final x in [.5 - arch, .5 + arch]) {
    _ball(
      canvas,
      Offset(x * s, .56 * s),
      radius * s,
      p.accent,
      heading: _down,
      spread: math.pi,
      arcColor: p.text,
    );
  }
}

void _yinYang(Canvas canvas, double s, Palette p) {
  final center = Offset(s / 2, s / 2);
  for (final (angle, color) in [(-.3, p.accent), (math.pi - .3, p.text)]) {
    _ball(
      canvas,
      center + Offset.fromDirection(angle, .19 * s),
      .1 * s,
      color,
      heading: angle + math.pi / 2,
      arcs: 2,
    );
  }
}

void _echo(Canvas canvas, double s, Palette p) {
  _ball(
    canvas,
    Offset(.58 * s, .42 * s),
    .12 * s,
    p.accent,
    heading: -math.pi / 4,
    arcs: 3,
  );
}

void _settle(Canvas canvas, double s, Palette p) {
  for (final heading in [_up, _down]) {
    _ball(
      canvas,
      Offset(s / 2, s / 2),
      .12 * s,
      p.accent,
      heading: heading,
      arcs: 2,
    );
  }
}

void _follow(Canvas canvas, double s, Palette p) {
  const heading = -math.pi / 4;
  _ball(canvas, Offset(.3 * s, .7 * s), .075 * s, p.text, heading: heading);
  _ball(
    canvas,
    Offset(.63 * s, .37 * s),
    .11 * s,
    p.accent,
    heading: heading,
    arcs: 2,
  );
}

void _lift(Canvas canvas, double s, Palette p) {
  _ball(canvas, Offset(s / 2, .44 * s), .14 * s, p.accent, heading: _up);
}
