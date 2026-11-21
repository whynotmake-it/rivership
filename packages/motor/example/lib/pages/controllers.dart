import 'package:coil/coil.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/chapters.dart';
import 'package:motor_example/widgets/chapter_page.dart';
import 'package:motor_example/widgets/style.dart';

/// A [BoundedMotionController] driving a fader, with its value, velocity and
/// status live, and calls to try while it moves.
class ControllersPage extends StatefulWidget {
  const ControllersPage({super.key});

  @override
  State<ControllersPage> createState() => _ControllersPageState();
}

const _knob = 28.0;

class _ControllersPageState extends State<ControllersPage>
    with SingleTickerProviderStateMixin {
  late final _fader = BoundedMotionController<double>(
    motion: .smoothSpring(),
    vsync: this,
    converter: .single,
    initialValue: 0,
    lowerBound: 0,
    upperBound: 1,
    debugLabel: 'Fader',
  );
  final _focus = FocusNode(debugLabel: 'Fader knob');

  /// How far the knob's center is from the pointer while dragging.
  var _grab = 0.0;

  final _code = ValueNotifier(
    "// Keeps the knob's speed from your drag.\nfader.animateTo(1);",
  );

  @override
  void dispose() {
    _fader.dispose();
    _focus.dispose();
    _code.dispose();
    super.dispose();
  }

  double _fraction(double x, double width) =>
      ((x - _knob / 2) / (width - _knob)).clamp(0.0, 1.0);

  void _release() {
    final target = _fader.value >= .5 ? 1 : 0;
    _code.value =
        "// Keeps the knob's speed from your drag.\nfader.animateTo($target);";
    // No velocity passed: the speed tracked while dragging carries on.
    _fader.animateTo(target.toDouble());
  }

  void _forward() {
    _code.value = '// Heads for 1 at the speed it has now.\nfader.forward();';
    _fader.forward();
  }

  void _reverse() {
    _code.value = '// Heads for 0 at the speed it has now.\nfader.reverse();';
    _fader.reverse();
  }

  void _playSteps() {
    _code.value =
        '// Plays the steps, then back again, until stopped.\n'
        'fader.play(\n'
        '  [\n'
        '    .to(1),\n'
        '    .hold(Duration(milliseconds: 200)),\n'
        '    .to(0.3, motion: .bouncySpring()),\n'
        '    .to(0.7),\n'
        '  ],\n'
        '  loop: .pingPong,\n'
        ');';
    _fader.play([
      .to(1),
      .hold(const Duration(milliseconds: 200)),
      .to(0.3, motion: .bouncySpring()),
      .to(0.7),
    ], loop: .pingPong);
  }

  void _stop() {
    _code.value =
        '// Settles where it is, using the speed it has left.\nfader.stop();';
    _fader.stop();
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _forward();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _reverse();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final gap = CoilTheme.metricsOf(context).gap;
    return ChapterPage(
      chapter: chapterNamed('Controllers'),
      lead:
          'MotionController is AnimationController for any motion: call it '
          'from code, interrupt it, read its velocity. Drag the knob, or try '
          'the buttons while it moves.',
      code: _code,
      stageHeight: 300,
      stage: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: .stretch,
          children: [
            _readouts(context),
            Expanded(child: _faderTrack(context)),
            Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                _button('Forward', _forward),
                _button('Reverse', _reverse),
                _button('Play steps', _playSteps),
                _button('Stop', _stop),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _button(String label, VoidCallback onPressed) => CoilButton(
    onPressed: onPressed,
    variant: .secondary,
    size: .compact,
    child: Text(label),
  );

  Widget _readouts(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    final style = mono(
      11,
      color: colors.mutedForeground,
    ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    final scaler = MediaQuery.textScalerOf(context);
    // JetBrains Mono's advance is 0.6 em.
    Widget fixed(int chars, String text) => SizedBox(
      width: scaler.scale(11 * .6 * chars),
      child: Text(text, style: style, maxLines: 1, softWrap: false),
    );
    String signed(double value, int digits) {
      final text = value.toStringAsFixed(digits);
      return double.parse(text) == 0 ? text.replaceFirst('-', '') : text;
    }

    return AnimatedBuilder(
      animation: _fader,
      builder: (context, _) => Wrap(
        spacing: 16,
        runSpacing: 4,
        children: [
          fixed(11, 'value ${signed(_fader.value, 2)}'),
          fixed(17, 'velocity ${signed(_fader.velocity, 1)}/s'),
          fixed(16, 'status ${_fader.status.name}'),
        ],
      ),
    );
  }

  Widget _faderTrack(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    return Focus(
      focusNode: _focus,
      onKeyEvent: _key,
      child: Semantics(
        label: 'Fader',
        slider: true,
        onIncrease: _forward,
        onDecrease: _reverse,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            double knobX() => _knob / 2 + _fader.value * (width - _knob);
            return GestureDetector(
              behavior: .opaque,
              dragStartBehavior: .down,
              onHorizontalDragDown: (details) {
                _focus.requestFocus();
                final offset = knobX() - details.localPosition.dx;
                _grab = offset.abs() <= _knob / 2 + 8 ? offset : 0;
              },
              onHorizontalDragUpdate: (details) {
                _fader.value = _fraction(
                  details.localPosition.dx + _grab,
                  width,
                );
              },
              onHorizontalDragEnd: (_) => _release(),
              onHorizontalDragCancel: () {
                if (!_fader.isAnimating) _release();
              },
              child: Center(
                child: SizedBox(
                  height: 56,
                  width: width,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: .none,
                    children: [
                      Positioned.fill(
                        child: Center(
                          child: SizedBox(
                            height: 4,
                            width: double.infinity,
                            child: DecoratedBox(
                              decoration: ShapeDecoration(
                                shape: const RoundedSuperellipseBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(2),
                                  ),
                                ),
                                color: colors.muted,
                              ),
                            ),
                          ),
                        ),
                      ),
                      AnimatedBuilder(
                        animation: _fader,
                        builder: (context, child) => Positioned(
                          left: knobX() - _knob / 2,
                          top: (56 - _knob) / 2,
                          child: child!,
                        ),
                        child: DecoratedBox(
                          decoration: ShapeDecoration(
                            shape: CircleBorder(
                              side: BorderSide(color: colors.border),
                            ),
                            color: colors.surface(4),
                            shadows: colors.shadow(2),
                          ),
                          child: const SizedBox.square(dimension: _knob),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
