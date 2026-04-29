import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/widgets/example_scaffold.dart';

const _routeName = '2D Redirection';

class TwoDRedirectionPage extends StatefulWidget {
  const TwoDRedirectionPage({super.key});
  static const routeName = _routeName;

  @override
  State<TwoDRedirectionPage> createState() => _TwoDRedirectionPageState();
}

class _TwoDRedirectionPageState extends State<TwoDRedirectionPage> {
  Offset _target = Offset.zero;
  bool _hasTarget = false;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);

    return ExamplePage(
      title: _routeName,
      description:
          'VelocityMotionBuilder tracks position and velocity together. '
          'The orb follows your tap with spring physics and squash-stretches '
          'along its velocity direction.',
      action: Row(
        children: [
          IconBadge(
            icon: CupertinoIcons.scope,
            color: t.accentGreen,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Tap or drag anywhere on the stage',
              style: TextStyle(
                color: t.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          if (_hasTarget)
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => setState(() {
                _target = Offset.zero;
                _hasTarget = false;
              }),
              child: Text(
                'Reset',
                style: TextStyle(
                  color: t.accentGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      child: SizedBox(
        height: 400,
        child: Stage(
          label: 'VELOCITY MOTION',
          child: LayoutBuilder(
            builder: (context, constraints) {
              final center = constraints.biggest.center(Offset.zero);
              return Stack(
                children: [
                  if (_hasTarget)
                    Positioned(
                      left: center.dx + _target.dx - 16,
                      top: center.dy + _target.dy - 16,
                      child: _Crosshair(color: t.textTertiary),
                    ),

                  Center(
                    child: VelocityMotionBuilder(
                      motion: const CupertinoMotion.smooth(),
                      converter: const OffsetMotionConverter(),
                      value: _target,
                      builder: (context, value, velocity, child) {
                        return Transform.translate(
                          offset: value,
                          child: MotionBuilder(
                            motion: const CupertinoMotion.bouncy(),
                            converter: const OffsetMotionConverter(),
                            value: velocity,
                            builder: (context, vel, child) {
                              return Transform.rotate(
                                angle: vel.direction,
                                child: Transform.scale(
                                  scaleX: 1 + vel.distance / 3000,
                                  scaleY: 1 - vel.distance / 6000,
                                  child: child,
                                ),
                              );
                            },
                            child: child,
                          ),
                        );
                      },
                      child: const _Orb(),
                    ),
                  ),

                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (d) => _setPosition(d.localPosition, center),
                      onPanUpdate: (d) => _setPosition(d.localPosition, center),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _setPosition(Offset local, Offset center) {
    setState(() {
      _target = local - center;
      _hasTarget = true;
    });
  }
}

class _Orb extends StatelessWidget {
  const _Orb();

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: t.accentGreen.withValues(alpha: .18),
        border: Border.all(color: t.accentGreen, width: 3),
        boxShadow: [
          BoxShadow(
            color: t.accentGreen.withValues(alpha: .24),
            blurRadius: 32,
            spreadRadius: 4,
          ),
        ],
      ),
      child: const SizedBox.square(dimension: 72),
    );
  }
}

class _Crosshair extends StatelessWidget {
  const _Crosshair({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 32,
      child: CustomPaint(painter: _CrosshairPainter(color: color)),
    );
  }
}

class _CrosshairPainter extends CustomPainter {
  _CrosshairPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..color = color.withValues(alpha: .6)
      ..strokeWidth = 1;

    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), paint);
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), paint);
    canvas.drawCircle(center, 4, paint..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(covariant _CrosshairPainter oldDelegate) =>
      color != oldDelegate.color;
}
