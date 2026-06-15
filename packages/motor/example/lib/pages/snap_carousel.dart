import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/widgets/example_scaffold.dart';

/// A fling carousel that snaps to the nearest card.
///
/// On release, [FrictionMotion.project] predicts where the flick would coast to
/// from the gesture velocity — then we round that to the nearest card and let a
/// spring carry the same velocity into the snap. No scroll physics required.
class SnapCarouselPage extends StatefulWidget {
  const SnapCarouselPage({super.key});
  static const routeName = 'Snap Carousel';

  @override
  State<SnapCarouselPage> createState() => _SnapCarouselPageState();
}

class _SnapCarouselPageState extends State<SnapCarouselPage>
    with TickerProviderStateMixin {
  static const _count = 6;
  static const _cardWidth = 168.0;
  static const _gap = 18.0;
  static const _extent = _cardWidth + _gap;
  static const _friction = FrictionMotion(drag: 0.2);

  late final SingleMotionController _offset;

  @override
  void initState() {
    super.initState();
    _offset = SingleMotionController(
      motion: const CupertinoMotion(),
      vsync: this,
      initialValue: 0,
    );
  }

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  double get _maxOffset => (_count - 1) * _extent;

  int get _index => (_offset.value / _extent).round().clamp(0, _count - 1);

  void _onDragUpdate(DragUpdateDetails d) {
    _offset.value = (_offset.value - d.delta.dx)
        .clamp(0.0, _maxOffset)
        .toDouble();
  }

  void _onDragEnd(DragEndDetails d) {
    final velocity = -d.velocity.pixelsPerSecond.dx;
    final projected = _friction.project(
      from: _offset.value,
      velocity: velocity,
      converter: MotionConverter.single,
    );
    final target = (projected / _extent).round().clamp(0, _count - 1) * _extent;
    _offset.animateTo(target.toDouble(), withVelocity: velocity);
  }

  @override
  Widget build(BuildContext context) {
    return ExamplePage(
      title: SnapCarouselPage.routeName,
      description:
          'Flick the row and let go. FrictionMotion.project turns the release '
          'velocity into a predicted resting point, which we round to the '
          'closest card before springing into place.',
      child: SizedBox(
        height: 320,
        child: Stage(
          glow: false,
          padding: EdgeInsets.zero,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: _onDragUpdate,
            onHorizontalDragEnd: _onDragEnd,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final leading = (constraints.maxWidth - _cardWidth) / 2;
                return AnimatedBuilder(
                  animation: _offset,
                  builder: (context, _) {
                    return Stack(
                      children: [
                        for (var i = 0; i < _count; i++)
                          _positioned(i, leading),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 16,
                          child: _Dots(count: _count, index: _index),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _positioned(int i, double leading) {
    final dx = leading + i * _extent - _offset.value;
    final distance =
        ((leading + i * _extent - _offset.value - leading) / _extent)
            .abs()
            .clamp(0.0, 1.0);
    final scale = 1 - distance * 0.12;
    return Positioned(
      left: dx,
      top: 36,
      bottom: 56,
      width: _cardWidth,
      child: Transform.scale(
        scale: scale,
        child: _Card(index: i, focused: i == _index),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.index, required this.focused});
  final int index;
  final bool focused;

  static const _titles = [
    'Aurora',
    'Basalt',
    'Cinder',
    'Drift',
    'Ember',
    'Frost',
  ];

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.surfaceSolid,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: focused ? t.borderStrong : t.border),
        boxShadow: focused ? t.softShadow : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              (index + 1).toString().padLeft(2, '0'),
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontFamilyFallback: const ['monospace', 'Menlo'],
                fontSize: 13,
                color: t.textTertiary,
              ),
            ),
            Text(
              _titles[index],
              style: TextStyle(
                fontFamily: 'Archivo',
                fontSize: 26,
                fontWeight: FontWeight.w300,
                letterSpacing: -0.6,
                color: t.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});
  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == index ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == index ? t.textPrimary : t.borderStrong,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}
