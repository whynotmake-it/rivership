import 'dart:ui';

import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/widgets/example_scaffold.dart';

enum _Phase { clearing, dismissing }

final _offset = Track<Offset>(.offset, initial: .zero, motion: .bouncySpring());

const _colors = [Color(0xFF0A84FF), Color(0xFF34C759), Color(0xFFBF5AF2)];

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
          'Drag the top card to dismiss it. Velocity tracking makes the '
          'release feel natural. Cards reorder with a spring animation.',
      action: const SizedBox.shrink(),
      child: SizedBox(
        height: 400,
        child: Stage(
          label: 'DRAG CARDS',
          child: Stack(
            children: [
              for (final (i, cardIndex) in _cards.indexed)
                Center(
                  key: ValueKey(cardIndex),
                  child: _DragCard(
                    depth: _cards.length - 1 - i,
                    color: _colors[cardIndex % _colors.length],
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
    required this.color,
    required this.label,
    required this.onDismiss,
  });

  final int depth;
  final Color color;
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
    // Project a target with a friction sim
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
        // We pass the drag velocity from the gesture tracking system
        from: [_offset.value(current, velocity: velocity)],
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
              offset: drag + Offset(0, -depth * 12),
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: .5 * depth,
                  sigmaY: .5 * depth,
                ),
                child: ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    ExampleTheme.of(
                      context,
                    ).surface.withValues(alpha: .2 * depth),
                    BlendMode.srcATop,
                  ),
                  child: Transform.scale(scale: 1 - depth * 0.1, child: child),
                ),
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
          width: 220,
          height: 140,
          decoration: ShapeDecoration(
            color: widget.color,
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
      ),
    );
  }
}
