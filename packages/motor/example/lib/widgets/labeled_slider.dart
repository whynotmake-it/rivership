import 'package:example_design/example_design.dart';
import 'package:flutter/cupertino.dart';

/// A labeled [CupertinoSlider] with a live value readout, themed for the
/// example app.
///
/// Used across the explainer pages to let the reader tune a motion parameter
/// (duration, bounce, …) and feel the effect immediately.
class LabeledSlider extends StatelessWidget {
  const LabeledSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.valueLabel,
    super.key,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  /// An optional pre-formatted readout (e.g. `'480ms'`). Falls back to the raw
  /// value with two decimals.
  final String? valueLabel;

  @override
  Widget build(BuildContext context) {
    final t = ExampleTheme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: TextStyle(
              color: t.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: CupertinoSlider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            activeColor: t.textPrimary,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 56,
          child: Text(
            valueLabel ?? value.toStringAsFixed(2),
            textAlign: TextAlign.right,
            style: TextStyle(
              color: t.textTertiary,
              fontSize: 12,
              fontFamily: 'JetBrains Mono',
              fontFamilyFallback: const ['monospace', 'Menlo'],
            ),
          ),
        ),
      ],
    );
  }
}
