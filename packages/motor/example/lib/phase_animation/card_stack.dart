import 'package:flutter/cupertino.dart';
import 'package:motor/motor.dart';

class CardStack extends StatefulWidget {
  const CardStack({super.key});

  @override
  State<CardStack> createState() => _CardStackState();
}

class _CardStackState extends State<CardStack> {
  late final List<String> _cards = [
    '3',
    '2',
    '1',
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        for (final (index, text) in _cards.indexed)
          Center(
            key: ValueKey(text),
            child: _DragCardExample(
                index: _cards.length - 1 - index,
                child: Text(text),
                onDismiss: () => _removeCard(index)),
          ),
      ],
    );
  }

  void _removeCard(int index) {
    setState(() {
      final card = _cards.removeAt(index);
      _cards.insert(0, card);
    });
  }
}

enum DragCardPhase {
  idle,
  clearing,
  dismissing,
}

class _DragCardExample extends StatefulWidget {
  const _DragCardExample({
    required this.index,
    required this.child,
    required this.onDismiss,
  });

  final int index;

  final Widget child;

  final VoidCallback onDismiss;

  @override
  State<_DragCardExample> createState() => _DragCardExampleState();
}

class _DragCardExampleState extends State<_DragCardExample>
    with SingleTickerProviderStateMixin {
  late final phaseController = SequenceMotionController<DragCardPhase, Offset>(
    motion: Motion.bouncySpring(),
    vsync: this,
    converter: OffsetMotionConverter(),
    initialValue: Offset.zero,
  );

  static const cardSize = 200.0;
  static const dismissThreshold = 30.0;

  Offset? getClearanceOffset(Offset offset, Velocity velocity) {
    final minDistance = cardSize * 1.5;
    final vector = switch (velocity.pixelsPerSecond) {
      Offset.zero => offset.normalized,
      final v => v.normalized,
    };

    final remainingDistance = minDistance - offset.distance;

    if (remainingDistance <= 0) {
      return null;
    }

    return offset + vector * remainingDistance;
  }

  MotionSequence<DragCardPhase, Offset> buildReturn(
      Offset offset, Velocity velocity) {
    final clearance = getClearanceOffset(offset, velocity);

    return MotionSequence.statesWithMotions({
      DragCardPhase.idle: (offset, Motion.none()),
      if (clearance != null)
        DragCardPhase.clearing: (
          clearance,
          // Only use the very beginning of the spring way before it settles
          Motion.smoothSpring().subExtent(extent: .1),
        ),
      DragCardPhase.dismissing: (
        Offset.zero,
        Motion.smoothSpring(),
      ),
    });
  }

  @override
  void dispose() {
    phaseController.dispose();
    super.dispose();
  }

  void _onPanEnd(DragEndDetails details) {
    if (phaseController.value.distance > dismissThreshold) {
      phaseController.playSequence(
        buildReturn(phaseController.value, details.velocity),
        onPhaseChanged: (phase) {
          // We wait until the flight back to tell the stack to resort
          if (phase == DragCardPhase.dismissing) {
            widget.onDismiss();
          }
        },
        withVelocity: details.velocity.pixelsPerSecond,
      );
    } else {
      phaseController.animateTo(Offset.zero);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanEnd: _onPanEnd,
      onPanCancel: () => phaseController.animateTo(Offset.zero),
      onPanUpdate: (details) {
        phaseController.value += details.delta;
      },
      child: Center(
        child: AnimatedBuilder(
          animation: phaseController,
          builder: (context, child) {
            return Transform.translate(
              offset: phaseController.value,
              child: SizedBox.square(
                dimension: _DragCardExampleState.cardSize,
                child: child,
              ),
            );
          },
          child: _DistanceBuilder(
            index: widget.index,
            child: Container(
              decoration: ShapeDecoration(
                shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(16)),
                color: CupertinoTheme.of(context).primaryColor,
              ),
              child: Center(child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}

class _DistanceBuilder extends StatelessWidget {
  const _DistanceBuilder({
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = CupertinoTheme.of(context).scaffoldBackgroundColor;
    return SingleMotionBuilder(
      value: index.toDouble(),
      motion: Motion.cupertino(),
      builder: (context, value, child) => Transform.translate(
        offset: Offset(0, value * -20),
        child: Transform.scale(
          scale: 1 - value * .1,
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(
              backgroundColor.withValues(alpha: value * .2),
              BlendMode.srcATop,
            ),
            child: child,
          ),
        ),
      ),
      child: child,
    );
  }
}

extension on Offset {
  Offset get normalized {
    final length = distance;
    if (length == 0) return this;
    return this / length;
  }
}
