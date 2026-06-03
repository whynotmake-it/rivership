import 'dart:ui';

import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/widgets/example_scaffold.dart';

enum _Phase { clearing, dismissing }

final _offset = Track<Offset>(.offset, origin: .zero, motion: .bouncySpring());

class CardStackPage extends StatefulWidget {
  const CardStackPage({super.key});
  static const routeName = 'Card Stack';

  @override
  State<CardStackPage> createState() => _CardStackPageState();
}

class _CardStackPageState extends State<CardStackPage> {
  var _cards = [2, 1, 0];

  void _onDismiss(int index) {
    setState(() {
      final card = _cards.removeAt(index);
      _cards.insert(0, card);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ExamplePage(
      title: CardStackPage.routeName,
      description:
          'Drag the top card to dismiss it. The fling velocity is projected '
          'through a friction sim to decide whether it clears the stack, and '
          'cards behind it spring up to take its place.',
      child: SizedBox(
        height: 420,
        child: Stage(
          label: 'Drag the top card',
          child: Stack(
            children: [
              for (final (i, cardIndex) in _cards.indexed)
                Center(
                  key: ValueKey(cardIndex),
                  child: _DragCard(
                    depth: _cards.length - 1 - i,
                    label: '${cardIndex + 1}',
                    onDismiss: () => _onDismiss(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DragCard extends StatefulWidget {
  const _DragCard({
    required this.depth,
    required this.label,
    required this.onDismiss,
  });

  final int depth;
  final String label;
  final VoidCallback onDismiss;

  @override
  State<_DragCard> createState() => _DragCardState();
}

class _DragCardState extends State<_DragCard>
    with SingleTickerProviderStateMixin {
  late final _controller = PhaseTrackController<_Phase>(
    vsync: this,
    velocityTracking: .off(),
  );

  static const _dismissThreshold = 60.0;

  bool get _isTop => widget.depth == 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final current = _controller.value(_offset) + details.delta;
    _controller.set([_offset.value(current)]);
  }

  void _onPanEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond;
    const friction = FrictionMotion(drag: 0.001, constantDeceleration: 200);
    final current = _controller.value(_offset);
    final settle = friction.project(
      from: current,
      velocity: velocity,
      converter: .offset,
    );
    final settleDistance = settle.distance;

    if (settleDistance > _dismissThreshold) {
      const clearanceDistance = 300.0;
      final target = settleDistance > clearanceDistance
          ? settle
          : (settle / settleDistance) * clearanceDistance;

      final timeline = TrackPhaseTimeline(
        withVelocity: [_offset.value(velocity)],
        {
          _Phase.clearing: [
            _offset.to(target, motion: .smoothSpring().trimmed(fromEnd: .9)),
          ],
          _Phase.dismissing: [_offset.to(Offset.zero)],
        },
      );

      _controller.playPhases(
        timeline,
        onTransition: (transition) {
          if (transition case PhaseTransitioning(to: _Phase.dismissing)) {
            widget.onDismiss();
          }
        },
      );
    } else {
      _controller.play(TrackTimeline([_offset.to(Offset.zero)]));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return SingleMotionBuilder(
      value: widget.depth.toDouble(),
      motion: .smoothSpring(),
      builder: (context, depth, child) {
        return ListenableBuilder(
          listenable: _controller,
          builder: (context, child) {
            final drag = _isTop || _controller.isAnimating
                ? _controller.value(_offset)
                : Offset.zero;
            return Transform.translate(
              offset: drag + Offset(0, -depth * 14),
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: .6 * depth,
                  sigmaY: .6 * depth,
                ),
                child: Transform.scale(scale: 1 - depth * 0.06, child: child),
              ),
            );
          },
          child: child,
        );
      },
      child: GestureDetector(
        onPanUpdate: _isTop ? _onPanUpdate : null,
        onPanEnd: _isTop ? _onPanEnd : null,
        child: Container(
          width: 240,
          height: 160,
          decoration: ShapeDecoration(
            color: t.surfaceSolid,
            shape: RoundedSuperellipseBorder(
              side: BorderSide(color: t.border),
              borderRadius: BorderRadius.circular(26),
            ),
            shadows: t.softShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.label.padLeft(2, '0'),
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontFamilyFallback: const ['monospace', 'Menlo'],
                    fontSize: 13,
                    color: t.textTertiary,
                  ),
                ),
                Container(
                  width: 120,
                  height: 8,
                  decoration: BoxDecoration(
                    color: t.fog,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
