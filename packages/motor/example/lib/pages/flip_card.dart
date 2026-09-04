import 'dart:async';
import 'dart:math';

import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/widgets/example_scaffold.dart';

class FlipCardPage extends StatefulWidget {
  const FlipCardPage({super.key});
  static const routeName = 'Flip Card';

  @override
  State<FlipCardPage> createState() => _FlipCardPageState();
}

class _FlipCardPageState extends State<FlipCardPage> {
  bool _autoFlip = true;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return ExamplePage(
      title: FlipCardPage.routeName,
      description:
          'The same 3D flip driven by a spring and by a curve. Tap a card to '
          'interrupt it mid-flip — the spring keeps its momentum, the curve '
          'restarts.',
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Auto-flip',
            style: TextStyle(color: t.textSecondary, fontSize: 14),
          ),
          const SizedBox(width: 10),
          CupertinoSwitch(
            value: _autoFlip,
            activeTrackColor: t.textPrimary,
            onChanged: (v) => setState(() => _autoFlip = v),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(child: _SpringFlipCard(autoFlip: _autoFlip)),
          const SizedBox(width: 14),
          Expanded(child: _CurveFlipCard(autoFlip: _autoFlip)),
        ],
      ),
    );
  }
}

class _SpringFlipCard extends StatefulWidget {
  const _SpringFlipCard({required this.autoFlip});
  final bool autoFlip;

  @override
  State<_SpringFlipCard> createState() => _SpringFlipCardState();
}

class _SpringFlipCardState extends State<_SpringFlipCard>
    with TickerProviderStateMixin {
  late final SingleMotionController _controller;
  bool _showFront = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = SingleMotionController(
      motion: const CupertinoMotion.bouncy(),
      vsync: this,
      initialValue: 0,
    )..addListener(() {
        if (mounted) setState(() {});
      });
    _startTimerIfNeeded();
  }

  @override
  void didUpdateWidget(_SpringFlipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.autoFlip != oldWidget.autoFlip) {
      if (widget.autoFlip) {
        _startTimerIfNeeded();
      } else {
        _timer?.cancel();
        _timer = null;
      }
    }
  }

  void _startTimerIfNeeded() {
    if (!widget.autoFlip) return;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _flip());
  }

  void _flip() {
    _showFront = !_showFront;
    _controller.animateTo(_showFront ? 0.0 : 1.0);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _flip,
      child: Column(
        children: [
          _FlipCardTransform(
            progress: _controller.value,
            frontLabel: 'Spring',
            backLabel: 'Bouncy',
          ),
          const SizedBox(height: 10),
          const Pill('CupertinoMotion.bouncy'),
        ],
      ),
    );
  }
}

class _CurveFlipCard extends StatefulWidget {
  const _CurveFlipCard({required this.autoFlip});
  final bool autoFlip;

  @override
  State<_CurveFlipCard> createState() => _CurveFlipCardState();
}

class _CurveFlipCardState extends State<_CurveFlipCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _curved;
  bool _showFront = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..addListener(() {
        if (mounted) setState(() {});
      });
    _curved = CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);
    _startTimerIfNeeded();
  }

  @override
  void didUpdateWidget(_CurveFlipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.autoFlip != oldWidget.autoFlip) {
      if (widget.autoFlip) {
        _startTimerIfNeeded();
      } else {
        _timer?.cancel();
        _timer = null;
      }
    }
  }

  void _startTimerIfNeeded() {
    if (!widget.autoFlip) return;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _flip());
  }

  void _flip() {
    _showFront = !_showFront;
    if (_showFront) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _curved.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _flip,
      child: Column(
        children: [
          _FlipCardTransform(
            progress: _curved.value,
            frontLabel: 'Curve',
            backLabel: 'Eased',
          ),
          const SizedBox(height: 10),
          const Pill('CurvedAnimation'),
        ],
      ),
    );
  }
}

class _FlipCardTransform extends StatelessWidget {
  const _FlipCardTransform({
    required this.progress,
    required this.frontLabel,
    required this.backLabel,
  });

  final double progress;
  final String frontLabel;
  final String backLabel;

  @override
  Widget build(BuildContext context) {
    final angle = progress * pi;
    final showBack = angle > pi / 2;

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001)
        ..rotateX(angle),
      child: showBack
          ? Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..rotateX(pi),
              child: _buildFace(context, backLabel, filled: true),
            )
          : _buildFace(context, frontLabel, filled: false),
    );
  }

  Widget _buildFace(BuildContext context, String label, {required bool filled}) {
    final t = ExampleTheme.of(context);
    return Container(
      height: 170,
      decoration: BoxDecoration(
        color: filled ? t.textPrimary : t.surfaceSolid,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: t.border),
        boxShadow: t.softShadow,
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Archivo',
            color: filled ? t.surfaceSolid : t.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w300,
            letterSpacing: -0.4,
          ),
        ),
      ),
    );
  }
}
