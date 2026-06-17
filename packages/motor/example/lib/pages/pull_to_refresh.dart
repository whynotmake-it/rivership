import 'dart:math' as math;

import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/widgets/example_scaffold.dart';

/// Pull-to-refresh built straight from physics. Dragging stretches the header
/// against rubber-band resistance and spins the indicator; on release a
/// [FrictionMotion.project] predicts where the throw would coast and decides
/// commit vs cancel, then the content springs back carrying the release
/// velocity.
class PullToRefreshPage extends StatefulWidget {
  const PullToRefreshPage({super.key});
  static const routeName = 'Pull to Refresh';

  @override
  State<PullToRefreshPage> createState() => _PullToRefreshPageState();
}

const _threshold = 72.0;
const _refreshHeight = 64.0;
const _maxPull = 170.0;

class _PullToRefreshPageState extends State<PullToRefreshPage>
    with TickerProviderStateMixin {
  late final _controller = TrackController(vsync: this);
  final _pull = Track<double>(.single, initial: 0);
  final _spin = Track<double>(.single, initial: 0);

  static const _friction = FrictionMotion(drag: 0.002, constantDeceleration: 220);

  bool _refreshing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (_refreshing) return;
    final current = _controller.value(_pull);
    // Rubber-band: the further you pull, the more it resists.
    final resistance = 1 - (current / _maxPull).clamp(0.0, 1.0) * 0.6;
    final next = (current + d.delta.dy * resistance).clamp(0.0, _maxPull);
    _controller.set([_pull.value(next), _spin.value(next / 28)]);
  }

  void _onDragEnd(DragEndDetails d) {
    if (_refreshing) return;
    final velocity = d.velocity.pixelsPerSecond.dy;
    final projected = _friction.project(
      from: _controller.value(_pull),
      velocity: velocity,
      converter: .single,
    );
    if (projected >= _threshold) {
      _startRefresh();
    } else {
      _controller.animate([
        _pull.to(0, motion: .smoothSpring(), withVelocity: velocity),
      ]);
    }
  }

  void _startRefresh() {
    setState(() => _refreshing = true);
    _controller.animate([_pull.to(_refreshHeight, motion: .snappySpring())]);
    // Spin continuously through the "loading" window, then settle back.
    _controller
        .animate([
          _spin.to(
            _controller.value(_spin) + math.pi * 8,
            motion: const CurvedMotion(
              Duration(milliseconds: 1200),
              Curves.linear,
            ),
          ),
        ])
        .whenComplete(() {
          if (!mounted) return;
          setState(() => _refreshing = false);
          _controller.animate([_pull.to(0, motion: .smoothSpring())]);
        });
  }

  @override
  Widget build(BuildContext context) {
    return ExamplePage(
      title: PullToRefreshPage.routeName,
      description:
          'Drag the list down and let go. The header stretches with rubber-band '
          'resistance; on release, a friction projection decides whether your '
          'throw clears the threshold — commit and it refreshes, fall short and '
          'it springs straight back.',
      child: SizedBox(
        height: 440,
        child: Stage(
          padding: EdgeInsets.zero,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: _onDragUpdate,
            onVerticalDragEnd: _onDragEnd,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final pull = _controller.value(_pull).clamp(0.0, _maxPull);
                final spin = _controller.value(_spin);
                final progress = _refreshing
                    ? 1.0
                    : (pull / _threshold).clamp(0.0, 1.0);
                return Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: pull,
                      child: Center(
                        child: Opacity(
                          opacity: (pull / 32).clamp(0.0, 1.0),
                          child: Transform.rotate(
                            angle: spin,
                            child: SizedBox(
                              width: 26,
                              height: 26,
                              child: CustomPaint(
                                painter: _Spinner(
                                  progress: progress,
                                  color: ExampleTheme.of(context).textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Transform.translate(
                      offset: Offset(0, pull),
                      child: const _List(),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List();

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Container(
      color: t.surfaceSolid,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Updates',
            style: TextStyle(
              fontFamily: 'Archivo',
              fontSize: 24,
              fontWeight: FontWeight.w300,
              letterSpacing: -0.6,
              color: t.textPrimary,
            ),
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < 5; i++) ...[
            _Row(emphasis: i == 0),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({this.emphasis = false});
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: t.fog, shape: BoxShape.circle),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: emphasis ? 180 : 130,
                height: 10,
                decoration: BoxDecoration(
                  color: t.fog,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 96,
                height: 8,
                decoration: BoxDecoration(
                  color: t.fog,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Spinner extends CustomPainter {
  _Spinner({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(2);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * (0.1 + 0.65 * progress),
      false,
      Paint()
        ..color = color
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_Spinner oldDelegate) =>
      progress != oldDelegate.progress || color != oldDelegate.color;
}
