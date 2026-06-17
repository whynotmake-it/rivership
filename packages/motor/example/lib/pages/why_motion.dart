import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/widgets/example_scaffold.dart';

/// Arc page 1. A state change with no motion is a jump cut your eye can't
/// follow; the same change animated lets you keep your place. Fire both at once
/// and the contrast is visceral.
class WhyMotionPage extends StatefulWidget {
  const WhyMotionPage({super.key});
  static const routeName = 'Why Motion?';

  @override
  State<WhyMotionPage> createState() => _WhyMotionPageState();
}

class _WhyMotionPageState extends State<WhyMotionPage>
    with TickerProviderStateMixin {
  late final _instant = TrackController(vsync: this);
  late final _animated = TrackController(vsync: this);
  final _instantPos = Track(.single, initial: 0.0);
  final _animatedPos = Track(.single, initial: 0.0);

  static const _motion = CurvedMotion(
    Duration(milliseconds: 480),
    Curves.easeInOut,
  );

  bool _on = false;

  @override
  void dispose() {
    _instant.dispose();
    _animated.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _on = !_on);
    final target = _on ? 1.0 : 0.0;
    _instant.set([_instantPos.value(target)]);
    _animated.animate([_animatedPos.to(target, motion: _motion)]);
  }

  @override
  Widget build(BuildContext context) {
    return ExamplePage(
      title: WhyMotionPage.routeName,
      description:
          'The same change, two ways. One snaps to its new state; the other '
          'animates there. Tap "Toggle both" and watch which one your eye can '
          'actually follow — motion is how a user keeps their place.',
      action: Align(
        alignment: Alignment.centerLeft,
        child: NeutralButton(onPressed: _toggle, child: const Text('Toggle both')),
      ),
      child: Surface(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
        child: Column(
          children: [
            _Panel(
              controller: _instant,
              track: _instantPos,
              label: 'Instant',
              codeHint: 'controller.set([pos.value(target)])',
            ),
            Container(height: 0.5, color: ExampleTheme.of(context).border),
            _Panel(
              controller: _animated,
              track: _animatedPos,
              label: 'Animated',
              codeHint: 'controller.animate([pos.to(target)])',
            ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.controller,
    required this.track,
    required this.label,
    required this.codeHint,
  });

  final TrackController controller;
  final Track<double> track;
  final String label;
  final String codeHint;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: t.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              const dot = 28.0;
              return SizedBox(
                height: dot,
                child: AnimatedBuilder(
                  animation: controller,
                  builder: (context, _) {
                    final value = controller.value(track).clamp(0.0, 1.0);
                    return Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        Container(height: 3, color: t.border),
                        Positioned(
                          left: value * (width - dot),
                          child: Container(
                            width: dot,
                            height: dot,
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
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          TakeawayText(codeHint),
        ],
      ),
    );
  }
}
