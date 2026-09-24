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
  LogoOption('echo', 'One ball, three after-images.', _echo),
  LogoOption(
    'settle',
    'One ball, after-images above and below: a spring.',
    _settle,
  ),
  LogoOption('follow', 'A small ball follows a big one.', _follow),
  LogoOption('lift', 'One ball, one after-image, like the sheet logo.', _lift),
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

/// A ball moving toward [heading], trailed by [images] after-images: the back
/// edge of a ghost of the ball, drawn like the stupid_simple_sheet motion arc
/// (round caps, half the ball's radius thick). Each ghost sits [step] farther
/// behind and fades.
void _ball(
  Canvas canvas,
  Offset center,
  double radius,
  Color color, {
  required double heading,
  int images = 1,
  double spread = math.pi * .5,
  double? step,
  double? ghost,
  Color? lineColor,
}) {
  canvas.drawCircle(center, radius, _fill(color));
  for (var i = 1; i <= images; i++) {
    canvas.drawArc(
      _circle(
        center - Offset.fromDirection(heading, (step ?? radius * .8) * i),
        ghost ?? radius,
      ),
      heading + math.pi - spread / 2,
      spread,
      false,
      _stroke(
        (lineColor ?? color).withValues(alpha: 1 - (i - 1) * .32),
        radius * .5,
      ),
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
      Offset(x * s, .6 * s),
      radius * s,
      p.accent,
      heading: _down,
      spread: math.pi * 1.2,
      step: .08 * s,
      ghost: arch * s,
      lineColor: p.text,
    );
  }
}

void _yinYang(Canvas canvas, double s, Palette p) {
  final center = Offset(s / 2, s / 2);
  final orbit = .2 * s;
  final radius = .1 * s;
  const step = .42;
  for (final (start, color) in [(-.3, p.accent), (math.pi - .3, p.text)]) {
    for (var i = 2; i >= 1; i--) {
      final angle = start - step * i;
      final ghost = center + Offset.fromDirection(angle, orbit);
      const spread = math.pi * .5;
      canvas.drawArc(
        _circle(ghost, radius),
        angle - math.pi / 2 - spread / 2,
        spread,
        false,
        _stroke(color.withValues(alpha: 1 - (i - 1) * .32), radius * .5),
      );
    }
    canvas.drawCircle(
      center + Offset.fromDirection(start, orbit),
      radius,
      _fill(color),
    );
  }
}

void _echo(Canvas canvas, double s, Palette p) {
  _ball(
    canvas,
    Offset(.58 * s, .42 * s),
    .13 * s,
    p.accent,
    heading: -math.pi / 4,
    images: 3,
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
      images: 2,
    );
  }
}

void _follow(Canvas canvas, double s, Palette p) {
  const heading = -math.pi / 4;
  _ball(canvas, Offset(.3 * s, .7 * s), .075 * s, p.text, heading: heading);
  _ball(
    canvas,
    Offset(.64 * s, .36 * s),
    .115 * s,
    p.accent,
    heading: heading,
    images: 2,
  );
}

void _lift(Canvas canvas, double s, Palette p) {
  _ball(canvas, Offset(s / 2, .44 * s), .14 * s, p.accent, heading: _up);
}
