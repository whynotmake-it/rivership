import 'dart:math' as math;

import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/widgets/example_scaffold.dart';

/// An expandable FAQ list. Each row reveals its body by spring-animating a
/// height factor, while the chevron rotates on the same motion.
class AccordionPage extends StatefulWidget {
  const AccordionPage({super.key});
  static const routeName = 'Accordion';

  static const _faqs = [
    (
      'What is a Motion?',
      'A Motion describes how a value travels to its target — a spring, a '
          'curve, or a custom simulation. The same widget code works with any '
          'of them.',
    ),
    (
      'Do I need an AnimationController?',
      'No. Motor manages the ticker for you. Builders like SingleMotionBuilder '
          'animate implicitly whenever the target value changes.',
    ),
    (
      'Can motion be interrupted?',
      'Yes — that is the point. Springs preserve velocity when the target '
          'changes mid-flight, so redirected motion stays smooth.',
    ),
    (
      'How do I animate many properties?',
      'Reach for tracks. Each property is its own track with its own steps and '
          'motion, all advancing on a single clock.',
    ),
  ];

  @override
  State<AccordionPage> createState() => _AccordionPageState();
}

class _AccordionPageState extends State<AccordionPage> {
  int? _open = 0;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return ExamplePage(
      title: AccordionPage.routeName,
      description:
          'A classic expandable list. Each row springs its body open by '
          'animating a height factor, and the chevron rotates on the same '
          'value — no explicit duration in sight.',
      child: Surface(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            for (final (i, (q, a)) in AccordionPage._faqs.indexed) ...[
              if (i != 0) Container(height: 1, color: t.border),
              _AccordionItem(
                question: q,
                answer: a,
                open: _open == i,
                onTap: () => setState(() => _open = _open == i ? null : i),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AccordionItem extends StatefulWidget {
  const _AccordionItem({
    required this.question,
    required this.answer,
    required this.open,
    required this.onTap,
  });

  final String question;
  final String answer;
  final bool open;
  final VoidCallback onTap;

  @override
  State<_AccordionItem> createState() => _AccordionItemState();
}

class _AccordionItemState extends State<_AccordionItem>
    with TickerProviderStateMixin {
  late final SingleMotionController _c;

  @override
  void initState() {
    super.initState();
    _c = SingleMotionController(
      motion: const CupertinoMotion.smooth(),
      vsync: this,
      initialValue: widget.open ? 1 : 0,
    );
  }

  @override
  void didUpdateWidget(_AccordionItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open != oldWidget.open) {
      _c.animateTo(widget.open ? 1 : 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final v = _c.value.clamp(0.0, 1.0);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.question,
                          style: TextStyle(
                            color: t.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Transform.rotate(
                        angle: v * math.pi / 2,
                        child: Icon(
                          CupertinoIcons.chevron_right,
                          size: 16,
                          color: t.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                ClipRect(
                  child: Align(
                    alignment: Alignment.topLeft,
                    heightFactor: v,
                    child: Opacity(
                      opacity: v,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 18, right: 24),
                        child: Text(
                          widget.answer,
                          style: TextStyle(
                            color: t.textSecondary,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
