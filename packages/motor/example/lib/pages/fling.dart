import 'dart:math' as math;

import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/chapters.dart';
import 'package:motor_example/widgets/chapter_page.dart';
import 'package:motor_example/widgets/live_timeline.dart';
import 'package:motor_example/widgets/style.dart';

/// A throw that turns into a sequence the moment you let go.
class FlingPage extends StatefulWidget {
  const FlingPage({super.key});

  @override
  State<FlingPage> createState() => _FlingPageState();
}

const _cities = ['Lisbon', 'Kyoto', 'Oslo', 'Lima'];
const _gradients = [
  [ExampleTheme.signalBlue, ExampleTheme.roseQuartz],
  [ExampleTheme.spectrumRed, ExampleTheme.marigold],
  [Color(0xFF1B1B22), ExampleTheme.signalBlue],
  [ExampleTheme.roseQuartz, ExampleTheme.marigold],
];
// Each card rests at its own slight angle.
const _tilts = [-.05, .04, -.03, .06];
const _coast = FrictionMotion(drag: .004, constantDeceleration: 1200);

class _FlingPageState extends State<FlingPage>
    with SingleTickerProviderStateMixin {
  late final _stack = TrackController(vsync: this, debugLabel: 'Postcards');

  final _offsets = [
    for (final city in _cities)
      Track<Offset>(.offset, initial: Offset.zero, debugLabel: city),
  ];
  final _depths = [
    for (final (index, city) in _cities.indexed)
      Track<double>(
        .single,
        initial: index.toDouble(),
        motion: .smoothSpring(),
        debugLabel: '$city depth',
      ),
  ];

  // Card indices from the top of the stack down.
  final _order = [0, 1, 2, 3];
  // Cards still flying out, drawn above the stack until they turn back.
  final _flying = <int>{};

  @override
  void dispose() {
    _stack.dispose();
    super.dispose();
  }

  int get _top => _order.first;

  void _drag(DragUpdateDetails details) {
    final offset = _offsets[_top];
    _stack.set([offset.value(_stack.value(offset) + details.delta)]);
  }

  void _release(DragEndDetails details) {
    final card = _top;
    final offset = _offsets[card];
    final fling = details.velocity.pixelsPerSecond;
    final from = _stack.value(offset);
    final landing = _coast.project(
      from: from,
      velocity: fling,
      converter: .offset,
    );
    if (landing.distance < 170) {
      _stack.animate([offset.to(Offset.zero, motion: .bouncySpring())]);
      return;
    }
    setState(() {
      _order
        ..remove(card)
        ..add(card);
      _flying.add(card);
    });
    _stack.animate(
      [
        // Keep flying with the throw's speed, then tuck back under the stack.
        offset([
          .free(motion: _coast),
          .to(Offset.zero, motion: .smoothSpring()),
        ], withVelocity: fling),
        for (final (depth, other) in _order.indexed)
          _depths[other].to(depth.toDouble()),
      ],
      // A later throw replaces this callback, so it serves every card.
      onStep: (track, step) {
        final turning = _offsets.indexWhere((offset) => offset == track);
        if (step == 1 && turning >= 0) {
          setState(() => _flying.remove(turning));
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChapterPage(
      chapter: chapterNamed('Fling'),
      lead:
          'Throw the top postcard. Where you let go, motor turns your gesture '
          'into a sequence: coast on with the throw\'s own speed, then spring '
          'back under the stack. A gentle throw just springs back.',
      code: 'card([.free(motion: coast), .to(home)], withVelocity: fling)',
      below: LiveTimeline(
        controller: _stack,
        lanes: {
          for (final (index, city) in _cities.indexed) _offsets[index]: city,
        },
      ),
      stageHeight: 440,
      stage: AnimatedBuilder(
        animation: _stack,
        builder: (context, _) => Stack(
          alignment: Alignment.center,
          children: [
            for (final card in [
              ..._order.reversed.where((card) => !_flying.contains(card)),
              ..._flying,
            ])
              _Postcard(
                key: ValueKey(card),
                index: card,
                offset: _stack.value(_offsets[card]),
                depth: _stack.value(_depths[card]),
                onDrag: card == _top ? _drag : null,
                onRelease: card == _top ? _release : null,
              ),
          ],
        ),
      ),
    );
  }
}

class _Postcard extends StatelessWidget {
  const _Postcard({
    required this.index,
    required this.offset,
    required this.depth,
    required this.onDrag,
    required this.onRelease,
    super.key,
  });

  final int index;
  final Offset offset;
  final double depth;
  final GestureDragUpdateCallback? onDrag;
  final GestureDragEndCallback? onRelease;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    const white = CupertinoColors.white;
    return Transform.translate(
      offset: offset + Offset(0, -depth * 12),
      child: Transform.rotate(
        angle: _tilts[index] + offset.dx / 900,
        child: Transform.scale(
          scale: 1 - depth * .04,
          child: GestureDetector(
            onPanUpdate: onDrag,
            onPanEnd: onRelease,
            child: Container(
              width: 210,
              height: 260,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _gradients[index],
                ),
                border: Border.all(color: white.withValues(alpha: .25)),
                boxShadow: t.softShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'GREETINGS FROM',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.eyebrow.copyWith(
                            color: white.withValues(alpha: .75),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Transform.rotate(
                        angle: math.pi / 12,
                        child: Container(
                          width: 34,
                          height: 40,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: white.withValues(alpha: .8),
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            CupertinoIcons.airplane,
                            size: 16,
                            color: white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    _cities[index],
                    style: archivo(
                      38,
                      weight: 300,
                      width: 118,
                      spacing: -1.2,
                    ).copyWith(color: white),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
