// MotorInspectionScope is part of motor's experimental inspection API.
// ignore_for_file: experimental_member_use

import 'package:flutter/cupertino.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';
import 'package:motor_example/widgets/style.dart';

/// Shrinks [child] a little while pressed, on a spring.
///
/// Every button makes one small controller, so they're grouped together in
/// the devtools.
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
      behavior: .opaque,
      onTapDown: (_) => _press(true),
      onTapUp: (_) => _press(false),
      onTapCancel: () => _press(false),
      onTap: widget.onTap,
      child: MotorInspectionScope(
        group: 'Button press',
        child: SingleMotionBuilder(
          value: _pressed ? .97 : 1,
          motion: const .snappySpring(),
          debugLabel: 'Press feedback',
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: widget.child,
        ),
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
    final p = Palette.of(context);
    return Container(
      padding: const .all(2),
      decoration: BoxDecoration(
        color: p.control,
        borderRadius: .circular(radius),
      ),
      child: Row(
        mainAxisSize: .min,
        children: [
          for (final (index, option) in options.indexed)
            GestureDetector(
              onTap: () => onSelect(index),
              child: Container(
                padding: const .symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: index == selected ? p.surface : null,
                  borderRadius: .circular(radius),
                ),
                child: Text(
                  option.toUpperCase(),
                  style: mono(
                    11,
                    weight: 500,
                    spacing: .5,
                    color: index == selected ? p.text : p.textTertiary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A compact button. [filled] ones use the accent.
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
    final p = Palette.of(context);
    final foreground = filled ? p.onAccent : p.text;
    return PressScale(
      onTap: onTap,
      child: Container(
        padding: .fromLTRB(icon == null ? 12 : 10, 8, 12, 8),
        decoration: BoxDecoration(
          color: filled ? p.accent : p.surface,
          borderRadius: .circular(radius),
          border: filled ? null : Border.all(color: p.borderStrong),
        ),
        child: Row(
          mainAxisSize: .min,
          children: [
            if (icon case final icon?) ...[
              Icon(icon, size: 14, color: foreground),
              const SizedBox(width: 6),
            ],
            Text(
              label.toUpperCase(),
              style: mono(11.5, weight: 560, spacing: .5, color: foreground),
            ),
          ],
        ),
      ),
    );
  }
}
