import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:springster/springster.dart';

class FlipCardExample extends StatelessWidget {
  const FlipCardExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flipper Sample'),
      ),
      body: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Spring - based'),
              const SizedBox(height: 16),
              _FlipCardWithSpring(),
            ],
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Curve - based'),
              const SizedBox(height: 16),
              _FlipCardWithCurve(),
            ],
          ),
        ],
      ),
    );
  }
}

class _FlipCardWithSpring extends StatefulWidget {
  const _FlipCardWithSpring({Key? key}) : super(key: key);

  @override
  State<_FlipCardWithSpring> createState() => _FlipCardWithSpringState();
}

class _FlipCardWithSpringState extends State<_FlipCardWithSpring> {
  bool _isFlipped = false;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _isFlipped = !_isFlipped;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SpringBuilder(
      spring: SimpleSpring.bouncy.copyWith(durationSeconds: .7, bounce: 0.4),
      value: _isFlipped ? 1 : 0,
      builder: (context, value, child) => _FlipCard(animationValue: value),
    );
  }
}

class _FlipCardWithCurve extends StatefulWidget {
  const _FlipCardWithCurve({Key? key}) : super(key: key);

  @override
  State<_FlipCardWithCurve> createState() => _FlipCardWithCurveState();
}

class _FlipCardWithCurveState extends State<_FlipCardWithCurve>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  Timer? _timer;

  bool _isFlipped = false;

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

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _isFlipped = !_isFlipped;
      if (_isFlipped) {
        _controller.forward(from: 0.0);
      } else {
        _controller.reverse(from: 1.0);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
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
    final angle = pi * animationValue;
    Widget cardFace;
    if (angle <= pi / 2) {
      cardFace = ColorFiltered(
        colorFilter: ColorFilter.mode(
          Colors.white.withValues(alpha: (animationValue * 1.5).clamp(0, 1)),
          BlendMode.lighten,
        ),
        child: Image.network(
          'https://i.imgur.com/g5q6h7V.png',
          fit: BoxFit.cover,
        ),
      );
    } else {
      cardFace = Transform(
        alignment: Alignment.center,
        transform: Matrix4.rotationX(pi),
        child: Image.network(
          'https://i.imgur.com/3bTXwhT.png',
          fit: BoxFit.cover,
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
