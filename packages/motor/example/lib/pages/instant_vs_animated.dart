import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/widgets/example_scaffold.dart';
import 'package:motor_example/widgets/phone_frame.dart';

/// Compares an immediate state change with the same change animated by Motor.
class InstantVsAnimatedPage extends StatefulWidget {
  const InstantVsAnimatedPage({super.key});

  static const routeName = 'Instant vs. Animated';

  @override
  State<InstantVsAnimatedPage> createState() => _InstantVsAnimatedPageState();
}

class _InstantVsAnimatedPageState extends State<InstantVsAnimatedPage>
    with SingleTickerProviderStateMixin {
  late final _controller = TrackController(vsync: this);
  final _instantSheet = Track(.single, initial: 0.0);
  final _animatedSheet = Track(.single, initial: 0.0);

  bool _open = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleBoth() {
    setState(() => _open = !_open);
    final target = _open ? 1.0 : 0.0;
    _controller
      ..set([_instantSheet.value(target)])
      ..animate([_animatedSheet.to(target, motion: .smoothSpring())]);
  }

  void _dismiss(Track<double> sheet) {
    if (_controller.value(sheet) <= 0) return;
    if (sheet == _instantSheet) {
      _controller.set([sheet.value(0)]);
    } else {
      _controller.animate([sheet.to(0, motion: .smoothSpring())]);
    }
    if (_controller.value(_instantSheet) <= 0 &&
        _controller.value(_animatedSheet) <= 0) {
      setState(() => _open = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return ExamplePage(
      title: InstantVsAnimatedPage.routeName,
      next: (label: 'The Curve Trap', routeName: 'The Curve Trap'),
      description:
          'Open the same sheet in two phones. The state change is identical; '
          'only the way the interface carries you between states changes.',
      action: Align(
        alignment: Alignment.centerLeft,
        child: CupertinoButton.filled(
          onPressed: _toggleBoth,
          child: Text(_open ? 'Dismiss' : 'Open sheet'),
        ),
      ),
      child: Surface(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final width = (constraints.maxWidth - 16) / 2;
                return AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PhoneComparison(
                        label: 'Instant',
                        width: width,
                        value: _controller.value(_instantSheet),
                        onTap: () => _dismiss(_instantSheet),
                      ),
                      const SizedBox(width: 16),
                      _PhoneComparison(
                        label: 'Animated',
                        width: width,
                        value: _controller.value(_animatedSheet),
                        onTap: () => _dismiss(_animatedSheet),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
            DecoratedBox(
              decoration: BoxDecoration(
                color: t.fog,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: t.border),
              ),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TakeawayText('controller.set([sheet.value(target)])'),
                    SizedBox(height: 6),
                    TakeawayText('controller.animate([sheet.to(target)])'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const TakeawayText(
              'Motion is how a user keeps their place. `set` and `animate` '
              'share the same API surface.',
            ),
          ],
        ),
      ),
    );
  }
}

class _PhoneComparison extends StatelessWidget {
  const _PhoneComparison({
    required this.label,
    required this.width,
    required this.value,
    required this.onTap,
  });

  final String label;
  final double width;
  final double value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: t.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: PhoneFrame(
              width: width,
              child: DemoSheet(value: value),
            ),
          ),
        ],
      ),
    );
  }
}
