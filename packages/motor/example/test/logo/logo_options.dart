import 'dart:math' as math;
import 'dart:ui';

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
  LogoOption('m', 'Two balls drop along the arches of an "m".', _m),
  LogoOption('yin-yang', 'Two balls chase each other around a ring.', _yinYang),
  LogoOption('bounce', 'One ball bounces twice; its path is an "m".', _bounce),
  LogoOption('spring', 'A ball settles at the end of a spring.', _spring),
  LogoOption('merge', 'A curve and a spring arrive as one ball.', _merge),
  LogoOption('dash', 'A ball with plain speed lines.', _dash),
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

/// A filled trail along [path] that widens from [from] to [to].
Path _trail(Path path, {required double from, required double to}) {
  final left = <Offset>[];
  final right = <Offset>[];
  final metric = path.computeMetrics().first;
  const steps = 160;
  for (var i = 0; i <= steps; i++) {
    final tangent = metric.getTangentForOffset(metric.length * i / steps)!;
    final normal = Offset(-tangent.vector.dy, tangent.vector.dx);
    final half = lerpDouble(from, to, i / steps)! / 2;
    left.add(tangent.position + normal * half);
    right.add(tangent.position - normal * half);
  }
  return Path.combine(
    .union,
    Path()..addPolygon([...left, ...right.reversed], true),
    Path()..addOval(_circle(metric.getTangentForOffset(0)!.position, from / 2)),
  );
}

/// A path through [at] from t = 0 to t = 1.
Path _curve(Offset Function(double t) at) {
  final path = Path()..moveTo(at(0).dx, at(0).dy);
  for (var i = 1; i <= 200; i++) {
    final point = at(i / 200);
    path.lineTo(point.dx, point.dy);
  }
  return path;
}

Rect _circle(Offset center, double radius) =>
    Rect.fromCircle(center: center, radius: radius);

void _m(Canvas canvas, double s, Palette p) {
  final arch = .13 * s;
  final top = .44 * s;
  final bottom = .68 * s;
  final ball = .082 * s;
  final stems = [.5 * s - 2 * arch, .5 * s, .5 * s + 2 * arch];
  for (var i = 0; i < 2; i++) {
    final from = stems[i];
    final to = stems[i + 1];
    final path = Path()..moveTo(from, i == 0 ? bottom : top);
    if (i == 0) path.lineTo(from, top);
    path
      ..arcTo(_circle(Offset(from + arch, top), arch), math.pi, math.pi, false)
      ..lineTo(to, bottom);
    canvas
      ..drawPath(_trail(path, from: .03 * s, to: .064 * s), _fill(p.text))
      ..drawCircle(Offset(to, bottom), ball, _fill(p.accent));
  }
}

void _bounce(Canvas canvas, double s, Palette p) {
  final ground = .7 * s;
  final height = .26 * s;
  const contacts = [.2, .5, .8];
  final path = Path()
    ..moveTo(.17 * s, ground - height * 1.2)
    ..quadraticBezierTo(.19 * s, ground - height * .6, contacts[0] * s, ground);
  for (var i = 0; i < 2; i++) {
    final from = contacts[i] * s;
    final to = contacts[i + 1] * s;
    path.quadraticBezierTo((from + to) / 2, ground - height * 2, to, ground);
  }
  canvas
    ..drawPath(_trail(path, from: .025 * s, to: .065 * s), _fill(p.text))
    ..drawCircle(
      Offset(contacts[1] * s, ground),
      .06 * s,
      _fill(Color.alphaBlend(p.accent.withValues(alpha: .4), p.surface)),
    )
    ..drawCircle(Offset(contacts[2] * s, ground), .085 * s, _fill(p.accent));
}

void _yinYang(Canvas canvas, double s, Palette p) {
  final radius = .28 * s;
  final center = Offset(s / 2, s / 2);
  for (final (start, color) in [(-.25, p.accent), (.75, p.text)]) {
    final path = Path()
      ..addArc(_circle(center, radius), start * math.pi, .7 * math.pi);
    final angle = (start + .8) * math.pi;
    canvas
      ..drawPath(_trail(path, from: .02 * s, to: .065 * s), _fill(color))
      ..drawCircle(
        center + Offset(math.cos(angle), math.sin(angle)) * radius,
        .09 * s,
        _fill(color),
      );
  }
}

double _springResponse(double t, {double damping = .28, double omega = 11}) {
  final damped = omega * math.sqrt(1 - damping * damping);
  return 1 -
      math.exp(-damping * omega * t) *
          (math.cos(damped * t) +
              damping * omega / damped * math.sin(damped * t));
}

void _spring(Canvas canvas, double s, Palette p) {
  final start = Offset(.2 * s, .72 * s);
  final end = Offset(.72 * s, .36 * s);
  Offset at(double t) => Offset(
    lerpDouble(start.dx, end.dx, t)!,
    lerpDouble(start.dy, end.dy, _springResponse(t))!,
  );

  canvas
    ..drawPath(_trail(_curve(at), from: .02 * s, to: .065 * s), _fill(p.text))
    ..drawCircle(end, .095 * s, _fill(p.accent));
}

void _merge(Canvas canvas, double s, Palette p) {
  final end = Offset(.74 * s, .5 * s);
  final ease = Cubic(.65, 0, .35, 1);
  Offset curve(double t) => Offset(
    lerpDouble(.2 * s, end.dx, t)!,
    lerpDouble(.26 * s, end.dy, ease.transform(t))!,
  );
  Offset spring(double t) => Offset(
    lerpDouble(.2 * s, end.dx, t)!,
    lerpDouble(.74 * s, end.dy, _springResponse(t, damping: .42, omega: 9))!,
  );
  for (final at in [curve, spring]) {
    canvas.drawPath(
      _trail(_curve(at), from: .02 * s, to: .055 * s),
      _fill(p.text),
    );
  }
  canvas.drawCircle(end, .095 * s, _fill(p.accent));
}

void _dash(Canvas canvas, double s, Palette p) {
  final ball = .1 * s;
  final center = Offset(.66 * s, .4 * s);
  final direction = Offset.fromDirection(-math.pi / 6);
  final side = Offset(-direction.dy, direction.dx);
  final paint = _stroke(p.text, .055 * s);
  for (final (offset, length) in [(-1.0, .16), (0.0, .3), (1.0, .2)]) {
    final start =
        center - direction * (ball + .07 * s) + side * offset * .1 * s;
    canvas.drawLine(start, start - direction * length * s, paint);
  }
  canvas.drawCircle(center, ball, _fill(p.accent));
}
