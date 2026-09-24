import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:motor_example/widgets/style.dart';

/// Shrinks [child] a little while pressed.
///
/// A plain [AnimatedScale], so every button doesn't add a controller to the
/// devtools list.
class PressScale extends StatefulWidget {
  const PressScale({required this.child, this.onTap, super.key});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  var _pressed = false;

  void _press(bool value) => setState(() => _pressed = value);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _press(true),
      onTapUp: (_) => _press(false),
      onTapCancel: () => _press(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? .96 : 1,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

/// A small segmented control.
class Choice extends StatelessWidget {
  const Choice({
    required this.options,
    required this.selected,
    required this.onSelect,
    super.key,
  });

  final List<String> options;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: t.pebble,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (index, option) in options.indexed)
            GestureDetector(
              onTap: () => onSelect(index),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: index == selected ? t.surfaceSolid : null,
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: index == selected ? t.hairlineShadow : null,
                ),
                child: Text(
                  option,
                  style: archivo(
                    12.5,
                    weight: 560,
                    color: index == selected ? t.textPrimary : t.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A compact pill button.
class PillButton extends StatelessWidget {
  const PillButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.filled = false,
    super.key,
  });

  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    final foreground = filled ? t.canvas : t.textPrimary;
    return PressScale(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.fromLTRB(icon == null ? 16 : 12, 9, 16, 9),
        decoration: BoxDecoration(
          color: filled ? t.textPrimary : t.surfaceSolid,
          borderRadius: BorderRadius.circular(99),
          border: filled ? null : Border.all(color: t.border),
          boxShadow: t.hairlineShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon case final icon?) ...[
              Icon(icon, size: 15, color: foreground),
              const SizedBox(width: 6),
            ],
            Text(label, style: archivo(13, weight: 560, color: foreground)),
          ],
        ),
      ),
    );
  }
}
