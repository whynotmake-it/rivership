import 'dart:ui';

import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/widgets/example_scaffold.dart';

class TitleSlidePage extends StatefulWidget {
  const TitleSlidePage({super.key});
  static const routeName = 'Title Slide';

  @override
  State<TitleSlidePage> createState() => _TitleSlidePageState();
}

class _TitleSlidePageState extends State<TitleSlidePage> {
  int _restartKey = 0;

  @override
  Widget build(BuildContext context) {
    return ExamplePage(
      title: TitleSlidePage.routeName,
      description:
          'A variable font animated per letter. Each glyph staggers in with '
          'animated weight and width — hover a letter to push its weight '
          'further. A natural fit for a featherweight type system.',
      action: Align(
        alignment: Alignment.centerLeft,
        child: NeutralButton(
          onPressed: () => setState(() => _restartKey++),
          child: const Text('Replay'),
        ),
      ),
      child: Surface(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Center(
          child: _StaggeredTitle(restartKey: _restartKey),
        ),
      ),
    );
  }
}

class _StaggeredTitle extends StatelessWidget {
  const _StaggeredTitle({required this.restartKey});

  final int restartKey;

  static const _word = 'Motor';

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < _word.length; i++)
          _AnimatedLetter(
            letter: _word[i],
            delay: Duration(milliseconds: 100 * i),
            restartKey: restartKey,
          ),
      ],
    );
  }
}

class _AnimatedLetter extends StatefulWidget {
  const _AnimatedLetter({
    required this.letter,
    required this.delay,
    required this.restartKey,
  });

  final String letter;
  final Duration delay;
  final int restartKey;

  @override
  State<_AnimatedLetter> createState() => _AnimatedLetterState();
}

class _AnimatedLetterState extends State<_AnimatedLetter>
    with TickerProviderStateMixin {
  late SingleMotionController _controller;
  bool _isHovering = false;
  int _targetWeight = 4;

  @override
  void initState() {
    super.initState();
    _controller = SingleMotionController(
      motion: const CupertinoMotion.bouncy(),
      vsync: this,
      initialValue: 0,
    );
    _startAnimation();
  }

  @override
  void didUpdateWidget(_AnimatedLetter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.restartKey != oldWidget.restartKey) {
      _controller.value = 0;
      _startAnimation();
    }
  }

  void _startAnimation() {
    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.animateTo(1.0);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() {
        _isHovering = true;
        _targetWeight = 8;
      }),
      onExit: (_) => setState(() {
        _isHovering = false;
        _targetWeight = 4;
      }),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final v = _controller.value.clamp(0.0, 1.0);
          final weightIndex = _isHovering
              ? _targetWeight.toDouble()
              : lerpDouble(0, 4, v)!;
          final width = lerpDouble(75, 100, v)!;
          final opacity = v;

          return Text(
            widget.letter,
            style: TextStyle(
              fontFamily: 'Archivo',
              fontSize: 64,
              fontWeight: FontWeight.values[weightIndex.round().clamp(0, 8)],
              fontVariations: [
                FontVariation('wght', (weightIndex * 100 + 100).clamp(100, 900)),
                FontVariation('wdth', width),
              ],
              color: t.textPrimary.withValues(alpha: opacity),
              height: 1,
            ),
          );
        },
      ),
    );
  }
}
