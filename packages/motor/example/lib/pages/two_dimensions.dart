import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/widgets/example_scaffold.dart';

/// Arc page 5. Real interactions aren't one-dimensional. A single `Offset`
/// track runs an independent spring per axis and preserves velocity per-axis,
/// so a flung card springs home along a natural curved path — something a
/// curve, locked to one timeline, can't express.
class TwoDimensionsPage extends StatefulWidget {
  const TwoDimensionsPage({super.key});
  static const routeName = 'More Than One Dimension';

  @override
  State<TwoDimensionsPage> createState() => _TwoDimensionsPageState();
}

class _TwoDimensionsPageState extends State<TwoDimensionsPage>
    with TickerProviderStateMixin {
  late final _controller = TrackController(vsync: this);
  final _pos = Track(.offset, initial: Offset.zero, motion: .bouncySpring());

  final ValueNotifier<List<Offset>> _path = ValueNotifier(const []);
  Offset? _letGo;
  bool _independent = false;

  static const _single = CupertinoMotion.smooth(
    duration: Duration(milliseconds: 650),
    extraBounce: .1,
  );
  static const _perDimension = [
    CupertinoMotion.snappy(),
    CupertinoMotion.bouncy(extraBounce: .35),
  ];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_record);
  }

  @override
  void dispose() {
    _controller.removeListener(_record);
    _controller.dispose();
    _path.dispose();
    super.dispose();
  }

  void _record() {
    final next = [..._path.value, _controller.value(_pos)];
    _path.value = next.length > 200 ? next.sublist(next.length - 200) : next;
  }

  void _onPanStart(DragStartDetails _) {
    _controller.stop(canceled: true);
    _path.value = const [];
    setState(() => _letGo = null);
  }

  void _onPanUpdate(DragUpdateDetails d, Size field) {
    final limit = field.shortestSide / 2 - 40;
    final next = _controller.value(_pos) + d.delta;
    final clamped = Offset(
      next.dx.clamp(-limit, limit),
      next.dy.clamp(-limit, limit),
    );
    _controller.set([_pos.value(clamped)]);
  }

  void _onPanEnd(DragEndDetails d) {
    setState(() => _letGo = _controller.value<Offset>(_pos));
    final velocity = d.velocity.pixelsPerSecond;
    _controller.animate([
      if (_independent)
        _pos.to(Offset.zero, motionPerDimension: _perDimension, withVelocity: velocity)
      else
        _pos.to(Offset.zero, motion: _single, withVelocity: velocity),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return ExamplePage(
      title: TwoDimensionsPage.routeName,
      description:
          'Fling the card around the field — it springs back to center carrying '
          'the speed and direction you released. Toggle independent axes to give '
          'X and Y different springs, and watch the two dimensions settle on '
          'their own clocks.',
      action: Row(
        children: [
          CupertinoSwitch(
            value: _independent,
            activeTrackColor: t.textPrimary,
            onChanged: (v) => setState(() => _independent = v),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              'Independent axes — a different spring per axis',
              style: TextStyle(color: t.textSecondary, fontSize: 14),
            ),
          ),
        ],
      ),
      child: SizedBox(
        height: 360,
        child: Stage(
          label: 'Drag & fling the card',
          padding: EdgeInsets.zero,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final field = constraints.biggest;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: _onPanStart,
                onPanUpdate: (d) => _onPanUpdate(d, field),
                onPanEnd: _onPanEnd,
                child: SizedBox.expand(
                  child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(child: CustomPaint(painter: _Crosshair(t))),
                    ValueListenableBuilder<List<Offset>>(
                      valueListenable: _path,
                      builder: (context, path, _) => Positioned.fill(
                        child: TrajectoryLine(
                          points: [
                            for (final p in path)
                              Offset(
                                0.5 + p.dx / field.width,
                                0.5 + p.dy / field.height,
                              ),
                          ],
                          gradient: ExampleTheme.spectrum,
                          thickness: 3,
                        ),
                      ),
                    ),
                    if (_letGo case final letGo?)
                      Transform.translate(
                        offset: letGo,
                        child: Icon(
                          CupertinoIcons.smallcircle_circle,
                          size: 24,
                          color: t.textTertiary,
                        ),
                      ),
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) => Transform.translate(
                        offset: _controller.value(_pos),
                        child: child,
                      ),
                      child: const _Card(),
                    ),
                  ],
                ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card();

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Container(
      width: 76,
      height: 92,
      decoration: BoxDecoration(
        color: t.surfaceSolid,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.border),
        boxShadow: t.softShadow,
      ),
      child: Icon(CupertinoIcons.doc_fill, color: t.textTertiary, size: 30),
    );
  }
}

class _Crosshair extends CustomPainter {
  _Crosshair(this.t);
  final ExampleTheme t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..color = t.border
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), paint);
    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), paint);
    canvas.drawCircle(
      center,
      52,
      Paint()
        ..color = t.border
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_Crosshair oldDelegate) => t != oldDelegate.t;
}
