import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:motor/motor.dart';

final ValueNotifier<bool> active = ValueNotifier(true);

final ValueNotifier<bool> isFlipped = ValueNotifier(false);

class FlipCardExample extends StatefulWidget {
  const FlipCardExample({super.key});

  static const name = 'Flip Card';
  static const path = 'flip-card';

  @override
  State<FlipCardExample> createState() => _FlipCardExampleState();
}

class _FlipCardExampleState extends State<FlipCardExample> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        isFlipped.value = !isFlipped.value;
      });
    });
  }

  void _flipEarly() {
    if (_timer != null) {
      _timer?.cancel();
      _startTimer();
    }

    setState(() {
      isFlipped.value = !isFlipped.value;
    });
  }

  void _toggleTimer() {
    active.value = !active.value;
    if (_timer == null) {
      setState(() {
        _startTimer();
      });
    } else {
      _timer?.cancel();
      setState(() {
        _timer = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Flipper Sample'),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 16,
              children: [
                CupertinoButton.filled(
                  onPressed: _flipEarly,
                  child: const Text('Flip Early'),
                ),
                CupertinoButton.tinted(
                  color: _timer == null
                      ? CupertinoColors.systemGreen
                      : CupertinoColors.systemRed,
                  onPressed: _toggleTimer,
                  child: Text(_timer == null ? 'Start' : 'Stop'),
                ),
              ],
            ),
            ListenableBuilder(
                listenable: Listenable.merge([active, isFlipped]),
                builder: (context, child) {
                  return Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Spring - based'),
                            const SizedBox(height: 16),
                            _FlipCardWithSpring(
                              isFlipped: isFlipped.value,
                              active: active.value,
                            ),
                          ],
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Curve - based'),
                            const SizedBox(height: 16),
                            _FlipCardWithCurve(
                              isFlipped: isFlipped.value,
                              active: active.value,
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class _FlipCardWithSpring extends StatefulWidget {
  const _FlipCardWithSpring({
    Key? key,
    required this.isFlipped,
    required this.active,
  }) : super(key: key);

  final bool isFlipped;

  final bool active;

  @override
  State<_FlipCardWithSpring> createState() => _FlipCardWithSpringState();
}

class _FlipCardWithSpringState extends State<_FlipCardWithSpring>
    with SingleTickerProviderStateMixin {
  late final MotionController<double> _controller;

  @override
  void initState() {
    super.initState();

    _controller = SingleMotionController(
      vsync: this,
      motion: const CupertinoMotion.bouncy(),
    );
  }

  @override
  void didUpdateWidget(covariant _FlipCardWithSpring oldWidget) {
    if ((oldWidget.isFlipped != widget.isFlipped ||
            oldWidget.active != widget.active) &&
        widget.active) {
      _controller.animateTo(widget.isFlipped ? 1 : 0);
    }
    if (oldWidget.active != widget.active) {
      if (!widget.active) {
        _controller.stop();
      }
    }

    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) => _FlipCard(animationValue: _controller.value),
    );
  }
}

class _FlipCardWithCurve extends StatefulWidget {
  const _FlipCardWithCurve({
    Key? key,
    required this.isFlipped,
    required this.active,
  }) : super(key: key);

  final bool isFlipped;

  final bool active;

  @override
  State<_FlipCardWithCurve> createState() => _FlipCardWithCurveState();
}

class _FlipCardWithCurveState extends State<_FlipCardWithCurve>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutBack,
    );
  }

  @override
  void didUpdateWidget(covariant _FlipCardWithCurve oldWidget) {
    if ((oldWidget.isFlipped != widget.isFlipped ||
            oldWidget.active != widget.active) &&
        widget.active) {
      _controller.animateTo(widget.isFlipped ? 1 : 0);
    }
    if (oldWidget.active != widget.active) {
      if (!widget.active) {
        _controller.stop();
      }
    }

    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, child) => _FlipCard(animationValue: _animation.value),
    );
  }
}

class _FlipCard extends StatelessWidget {
  const _FlipCard({Key? key, required this.animationValue}) : super(key: key);

  final double animationValue;

  @override
  Widget build(BuildContext context) {
    const size = Size(200, 300);

    final angle = pi * animationValue;
    Widget cardFace;
    if (angle <= pi / 2) {
      cardFace = SizedBox.fromSize(
        size: size,
        child: Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: const Center(
            child: Text('Front'),
          ),
        ),
      );
    } else {
      cardFace = Transform(
        alignment: Alignment.center,
        transform: Matrix4.rotationX(pi),
        child: SizedBox.fromSize(
          size: size,
          child: Card(
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            child: const Center(
              child: FlutterLogo(size: 100),
            ),
          ),
        ),
      );
    }

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001)
        ..rotateX(angle),
      child: cardFace,
    );
  }
}
