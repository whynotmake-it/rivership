import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/widgets/example_scaffold.dart';

const _routeName = 'Motion Padding';

class MotionPaddingPage extends StatefulWidget {
  const MotionPaddingPage({super.key});
  static const routeName = _routeName;

  @override
  State<MotionPaddingPage> createState() => _MotionPaddingPageState();
}

class _MotionPaddingPageState extends State<MotionPaddingPage> {
  bool _expanded = false;

  EdgeInsets get _padding => _expanded
      ? EdgeInsets.zero
      : const EdgeInsets.fromLTRB(48, 32, 16, 64);

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);

    return ExamplePage(
      title: _routeName,
      description:
          'MotionPadding animates padding changes with spring physics. '
          'Toggle the state to see each side animate independently with '
          'a bouncy spring.',
      action: Row(
        children: [
          IconBadge(
            icon: CupertinoIcons.arrow_up_left_arrow_down_right,
            color: t.accentPurple,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow('MOTION PADDING', color: t.accentPurple),
                const SizedBox(height: 4),
                Text(
                  _expanded ? 'Collapsed — 0 on all sides' : 'Expanded — asymmetric',
                  style: TextStyle(
                    color: t.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: t.accentPurple.withValues(alpha: .15),
            borderRadius: BorderRadius.circular(12),
            onPressed: () => setState(() => _expanded = !_expanded),
            child: Text(
              _expanded ? 'Expand' : 'Collapse',
              style: TextStyle(
                color: t.accentPurple,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
      child: Surface(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: SizedBox(
            height: 320,
            child: MotionPadding(
              motion: CupertinoMotion.bouncy(extraBounce: .1),
              padding: _padding,
              child: _InnerBox(padding: _padding),
            ),
          ),
        ),
      ),
    );
  }
}

class _InnerBox extends StatelessWidget {
  const _InnerBox({required this.padding});

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.accentPurple.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: t.accentPurple.withValues(alpha: .32),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.arrow_up_left_arrow_down_right,
              color: t.accentPurple,
              size: 28,
            ),
            const SizedBox(height: 12),
            Text(
              'MotionPadding',
              style: TextStyle(
                color: t.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'L:${padding.left.toInt()}  T:${padding.top.toInt()}  '
              'R:${padding.right.toInt()}  B:${padding.bottom.toInt()}',
              style: TextStyle(
                color: t.textTertiary,
                fontSize: 13,
                fontFamily: 'Menlo',
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
