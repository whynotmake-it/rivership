import 'package:flutter/cupertino.dart';

/// The editor's dark palette.
abstract final class EditorColors {
  static const canvas = Color(0xFF0C0C0E);
  static const surface = Color(0xFF161619);
  static const raised = Color(0xFF1F1F23);
  static const control = Color(0xFF2A2A2F);
  static const border = Color(0xFF2C2C31);
  static const text = Color(0xFFF4F4F5);
  static const textSecondary = Color(0xFFA1A1AA);
  static const textTertiary = Color(0xFF6B6B74);
  static const accent = Color(0xFFB4FF39);
  static const onAccent = Color(0xFF0C0C0E);

  /// Colors offered for the dots.
  static const swatches = [
    Color(0xFFF4F4F5),
    Color(0xFFB4FF39),
    Color(0xFFFF5C39),
    Color(0xFFFFC53D),
    Color(0xFF3DD9FF),
    Color(0xFF8A7CFF),
    Color(0xFFFF6FD8),
  ];
}

/// Text styles of the editor.
abstract final class EditorText {
  static const title = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: EditorColors.text,
    letterSpacing: -0.2,
  );
  static const label = TextStyle(
    fontSize: 12,
    color: EditorColors.textSecondary,
  );
  static const section = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: EditorColors.textTertiary,
    letterSpacing: 0.8,
  );
  static const value = TextStyle(
    fontSize: 12,
    color: EditorColors.text,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const code = TextStyle(
    fontSize: 12,
    height: 1.45,
    color: EditorColors.text,
    fontFamily: 'JetBrains Mono',
  );
}

/// A titled group of controls.
class Section extends StatelessWidget {
  const Section({required this.title, required this.children, super.key});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title.toUpperCase(), style: EditorText.section),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

/// A slider with a label and its value.
class LabeledSlider extends StatelessWidget {
  const LabeledSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.format,
    this.divisions,
    super.key,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;
  final String Function(double value)? format;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: EditorText.label)),
              Text(
                format?.call(value) ?? value.toStringAsFixed(2),
                style: EditorText.value,
              ),
            ],
          ),
          SizedBox(
            height: 30,
            child: CupertinoSlider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              activeColor: EditorColors.accent,
              thumbColor: EditorColors.text,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

/// A compact button with an icon and an optional label.
class ToolButton extends StatelessWidget {
  const ToolButton({
    required this.onPressed,
    this.icon,
    this.label,
    this.selected = false,
    this.tooltip,
    this.prominent = false,
    super.key,
  });

  final VoidCallback? onPressed;
  final IconData? icon;
  final String? label;
  final bool selected;
  final bool prominent;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final highlighted = selected || prominent;
    final foreground = onPressed == null
        ? EditorColors.textTertiary
        : highlighted
        ? EditorColors.onAccent
        : EditorColors.text;
    final button = GestureDetector(
      onTap: onPressed,
      child: MouseRegion(
        cursor: onPressed == null
            ? MouseCursor.defer
            : SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 32,
          padding: EdgeInsets.symmetric(horizontal: label == null ? 8 : 12),
          decoration: BoxDecoration(
            color: highlighted ? EditorColors.accent : EditorColors.control,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) Icon(icon, size: 16, color: foreground),
              if (icon != null && label != null) const SizedBox(width: 6),
              if (label != null)
                Text(
                  label!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: foreground,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Semantics(label: tooltip, button: true, child: button);
  }
}

/// A row of mutually exclusive options.
class Choice<T> extends StatelessWidget {
  const Choice({
    required this.value,
    required this.options,
    required this.onChanged,
    super.key,
  });

  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final MapEntry(:key, value: label) in options.entries)
            ToolButton(
              label: label,
              selected: key == value,
              onPressed: () => onChanged(key),
            ),
        ],
      ),
    );
  }
}

/// A number with buttons to step it.
class Stepper extends StatelessWidget {
  const Stepper({
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 64,
    super.key,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: EditorText.label)),
          ToolButton(
            icon: CupertinoIcons.minus,
            onPressed: value > min ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: 36,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: EditorText.value,
            ),
          ),
          ToolButton(
            icon: CupertinoIcons.plus,
            onPressed: value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}

/// A rounded panel.
class Panel extends StatelessWidget {
  const Panel({required this.child, this.padding, super.key});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: EditorColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: EditorColors.border),
      ),
      child: child,
    );
  }
}
