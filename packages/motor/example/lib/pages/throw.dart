import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/chapters.dart';
import 'package:motor_example/widgets/chapter_page.dart';
import 'package:motor_example/widgets/style.dart';

/// A fling's velocity carries into the spring that settles it, per axis.
class ThrowPage extends StatefulWidget {
  const ThrowPage({super.key});

  @override
  State<ThrowPage> createState() => _ThrowPageState();
}

const _size = Size(148, 92);
const _inset = 14.0;
const _friction = FrictionMotion(drag: .0012, constantDeceleration: 180);

class _ThrowPageState extends State<ThrowPage>
    with SingleTickerProviderStateMixin {
  late final _window = MotionController<Offset>(
    motion: const .bouncySpring(duration: Duration(milliseconds: 600)),
    vsync: this,
    converter: .offset,
    initialValue: const Offset(_inset, _inset),
    debugLabel: 'Picture in picture',
  );
  var _stage = Size.zero;
  var _dragging = false;

  @override
  void dispose() {
    _window.dispose();
    super.dispose();
  }

  List<Offset> get _corners {
    final right = _stage.width - _size.width - _inset;
    final bottom = _stage.height - _size.height - _inset;
    return [
      const Offset(_inset, _inset),
      Offset(right, _inset),
      Offset(_inset, bottom),
      Offset(right, bottom),
    ];
  }

  void _release(DragEndDetails details) {
    setState(() => _dragging = false);
    final fling = details.velocity.pixelsPerSecond;
    final landing = _friction.project(
      from: _window.value,
      velocity: fling,
      converter: .offset,
    );
    final corner = _corners.reduce(
      (a, b) => (a - landing).distance < (b - landing).distance ? a : b,
    );
    _window.animateTo(corner, withVelocity: fling);
  }

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return ChapterPage(
      chapter: chapterNamed('Throw'),
      lead:
          'Throw the window. Motor projects where the throw would coast, picks '
          'the nearest corner, and hands the release velocity to the spring. '
          'Each axis keeps its own speed, so diagonal throws curve naturally.',
      code: 'window.animateTo(corner, withVelocity: fling);',
      stageHeight: 440,
      stage: LayoutBuilder(
        builder: (context, constraints) {
          _stage = constraints.biggest;
          return Stack(
            children: [
              for (final corner in _corners)
                Positioned(
                  left: corner.dx,
                  top: corner.dy,
                  child: Container(
                    width: _size.width,
                    height: _size.height,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: t.borderStrong),
                    ),
                  ),
                ),
              Center(child: Text('Throw it anywhere', style: t.caption)),
              AnimatedBuilder(
                animation: _window,
                builder: (context, child) {
                  final velocity = _window.velocity;
                  return Positioned(
                    left: _window.value.dx,
                    top: _window.value.dy,
                    child: GestureDetector(
                      onPanStart: (_) => setState(() => _dragging = true),
                      onPanUpdate: (details) =>
                          _window.value = _window.value + details.delta,
                      onPanEnd: _release,
                      child: Transform.rotate(
                        angle: (velocity.dx / 9000).clamp(-.12, .12),
                        child: Transform.scale(
                          scale: _dragging ? 1.04 : 1,
                          child: Blur(
                            sigma: motionBlur(velocity),
                            child: child!,
                          ),
                        ),
                      ),
                    ),
                  );
                },
                child: const _Video(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Video extends StatelessWidget {
  const _Video();

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Container(
      width: _size.width,
      height: _size.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ExampleTheme.signalBlue, ExampleTheme.roseQuartz],
        ),
        boxShadow: t.softShadow,
      ),
      child: Stack(
        children: [
          const Center(
            child: Icon(
              CupertinoIcons.play_fill,
              color: CupertinoColors.white,
              size: 26,
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 10,
            child: Container(
              height: 3,
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: CupertinoColors.white.withValues(alpha: .3),
                borderRadius: BorderRadius.circular(2),
              ),
              child: FractionallySizedBox(
                widthFactor: .4,
                child: Container(color: CupertinoColors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
