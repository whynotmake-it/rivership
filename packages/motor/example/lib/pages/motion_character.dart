import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/widgets/example_scaffold.dart';
import 'package:motor_example/widgets/spring_visualizer.dart';

/// Arc page 6. One spring model expresses many personalities — smooth, playful,
/// snappy, underdamped — by changing two numbers. Tap a column to launch it;
/// tap again mid-flight and the velocity carries through.
class MotionCharacterPage extends StatelessWidget {
  const MotionCharacterPage({super.key});
  static const routeName = 'Motion Character';

  @override
  Widget build(BuildContext context) {
    return ExamplePage(
      title: routeName,
      description:
          'The same model, many feelings. These columns use ready-made motions '
          'from both design systems — CupertinoMotion and MaterialSpringMotion. '
          'Tap to launch, and tap again mid-flight to feel the momentum carry.',
      child: SizedBox(
        height: 420,
        child: Surface(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          child: Row(
            children: const [
              Expanded(
                child: _CharacterColumn(
                  family: 'Cupertino',
                  label: 'Smooth',
                  caption: '.smooth()',
                  motion: CupertinoMotion.smooth(),
                ),
              ),
              Expanded(
                child: _CharacterColumn(
                  family: 'Cupertino',
                  label: 'Bouncy',
                  caption: '.bouncy()',
                  motion: CupertinoMotion.bouncy(),
                ),
              ),
              Expanded(
                child: _CharacterColumn(
                  family: 'Material',
                  label: 'Standard',
                  caption: '.standardSpatial\nDefault()',
                  motion: MaterialSpringMotion.standardSpatialDefault(),
                ),
              ),
              Expanded(
                child: _CharacterColumn(
                  family: 'Material',
                  label: 'Expressive',
                  caption: '.expressiveSpatial\nDefault()',
                  motion: MaterialSpringMotion.expressiveSpatialDefault(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CharacterColumn extends StatefulWidget {
  const _CharacterColumn({
    required this.family,
    required this.label,
    required this.caption,
    required this.motion,
  });

  final String family;
  final String label;
  final String caption;
  final Motion motion;

  @override
  State<_CharacterColumn> createState() => _CharacterColumnState();
}

class _CharacterColumnState extends State<_CharacterColumn>
    with SingleTickerProviderStateMixin {
  late final SingleMotionController _controller = SingleMotionController(
    motion: widget.motion,
    vsync: this,
    initialValue: 0,
  );
  bool _up = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _launch() {
    setState(() => _up = !_up);
    _controller.animateTo(_up ? 1 : 0);
  }

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          Text(
            widget.family.toUpperCase(),
            style: TextStyle(
              color: t.textTertiary,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            widget.label,
            style: TextStyle(
              color: t.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.caption,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: t.textTertiary,
              fontSize: 9,
              height: 1.3,
              fontFamily: 'JetBrains Mono',
              fontFamilyFallback: const ['monospace', 'Menlo'],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _launch,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final h = constraints.maxHeight;
                  const ball = 36.0;
                  final bottomY = h - ball / 2 - 6;
                  final topY = ball / 2 + 6;
                  return AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      final value = _controller.value;
                      final ballY = bottomY + (topY - bottomY) * value;
                      final centerY = h / 2;
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: SpringPainter(
                                start: Offset(0, bottomY - centerY),
                                end: Offset(0, ballY - centerY),
                                color: ExampleTheme.spectrumRed
                                    .withValues(alpha: .7),
                                coils: 10,
                                thickness: 16,
                                minVisibleLength: 20,
                                minFullLength: 120,
                              ),
                            ),
                          ),
                          Transform.translate(
                            offset: Offset(0, ballY - centerY),
                            child: Container(
                              width: ball,
                              height: ball,
                              decoration: BoxDecoration(
                                color: t.textPrimary,
                                shape: BoxShape.circle,
                                boxShadow: t.hairlineShadow,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
