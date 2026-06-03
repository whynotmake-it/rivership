import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/widgets/example_scaffold.dart';

/// A floating picture-in-picture window. Drag it anywhere; on release the fling
/// velocity is projected with [FrictionMotion.project] to predict where it
/// would coast, and it snaps to whichever corner is nearest that point.
class PictureInPicturePage extends StatefulWidget {
  const PictureInPicturePage({super.key});
  static const routeName = 'Picture in Picture';

  @override
  State<PictureInPicturePage> createState() => _PictureInPicturePageState();
}

class _PictureInPicturePageState extends State<PictureInPicturePage>
    with TickerProviderStateMixin {
  static const _cardSize = Size(132, 84);
  static const _inset = 12.0;
  static const _friction = FrictionMotion(drag: 0.0012, constantDeceleration: 180);

  MotionController<Offset>? _controller;
  Size _stage = Size.zero;
  bool _dragging = false;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  List<Offset> _corners(Size stage) {
    final maxX = stage.width - _cardSize.width - _inset;
    final maxY = stage.height - _cardSize.height - _inset;
    return [
      const Offset(_inset, _inset),
      Offset(maxX, _inset),
      Offset(_inset, maxY),
      Offset(maxX, maxY),
    ];
  }

  Offset _nearestCorner(Offset point, Size stage) {
    final corners = _corners(stage);
    var best = corners.first;
    var bestDist = double.infinity;
    for (final corner in corners) {
      final d = (corner - point).distanceSquared;
      if (d < bestDist) {
        bestDist = d;
        best = corner;
      }
    }
    return best;
  }

  void _ensureController(Size stage) {
    if (_controller != null && _stage == stage) return;
    _stage = stage;
    _controller?.dispose();
    _controller = MotionController<Offset>(
      motion: const CupertinoMotion.bouncy(),
      vsync: this,
      converter: MotionConverter.offset,
      initialValue: _corners(stage).first,
    );
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final c = _controller!;
    c.value = c.value + d.delta;
  }

  void _onPanEnd(DragEndDetails d) {
    setState(() => _dragging = false);
    final c = _controller!;
    final velocity = d.velocity.pixelsPerSecond;
    final projected = _friction.project(
      from: c.value,
      velocity: velocity,
      converter: MotionConverter.offset,
    );
    c.animateTo(_nearestCorner(projected, _stage), withVelocity: velocity);
  }

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return ExamplePage(
      title: PictureInPicturePage.routeName,
      description:
          'Drag the window and flick it. FrictionMotion.project predicts where '
          'the throw would settle, the nearest corner wins, and the spring '
          'carries the same velocity into the snap.',
      child: SizedBox(
        height: 380,
        child: Surface(
          padding: const EdgeInsets.all(4),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stage = constraints.biggest;
              _ensureController(stage);
              final controller = _controller!;
              return Stack(
                children: [
                  for (final corner in _corners(stage))
                    Positioned(
                      left: corner.dx,
                      top: corner.dy,
                      child: Container(
                        width: _cardSize.width,
                        height: _cardSize.height,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: t.border),
                        ),
                      ),
                    ),
                  AnimatedBuilder(
                    animation: controller,
                    builder: (context, _) => Positioned(
                      left: controller.value.dx,
                      top: controller.value.dy,
                      child: GestureDetector(
                        onPanStart: (_) => setState(() => _dragging = true),
                        onPanUpdate: _onPanUpdate,
                        onPanEnd: _onPanEnd,
                        child: _PipCard(dragging: _dragging, size: _cardSize),
                      ),
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
}

class _PipCard extends StatelessWidget {
  const _PipCard({required this.dragging, required this.size});
  final bool dragging;
  final Size size;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [t.textPrimary, t.textSecondary],
        ),
        boxShadow: dragging ? t.softShadow : t.hairlineShadow,
      ),
      child: Center(
        child: Icon(
          CupertinoIcons.play_fill,
          color: t.surfaceSolid.withValues(alpha: .9),
          size: 26,
        ),
      ),
    );
  }
}
