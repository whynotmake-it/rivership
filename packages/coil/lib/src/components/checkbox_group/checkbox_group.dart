import 'package:coil/checkbox.dart';
import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/checkbox_group/checkbox_group_style.dart';
import 'package:flutter/widgets.dart';

/// A vertical list of checkable rows.
///
/// Checked rows that touch share one background block. Checking the row
/// between two blocks merges them; unchecking a row inside a block splits
/// it. The hover highlight glides over the rows, and one focus ring travels
/// with the keyboard.
///
/// Every row is a tab stop. Up and Down move focus with wrapping, Home and
/// End jump, and Space or Enter toggles. Labels wrap and grow their row. On
/// touch the blocks are the only selection mark, and a finger shows a press
/// fill.
class CoilCheckboxGroup<T> extends StatelessWidget {
  /// Creates a checkbox group.
  const CoilCheckboxGroup({
    required this.options,
    required this.values,
    required this.onChanged,
    super.key,
    this.size,
    this.motion,
    this.style,
    this.semanticLabel,
  });

  /// Overrides for this group's look, on top of the theme's
  /// [CoilCheckboxGroupStyle] and the defaults.
  final CoilCheckboxGroupStyle? style;

  /// The rows: each option's [CoilOption.child] or `Text(label)`.
  final List<CoilOption<T>> options;

  /// The values of the checked rows.
  final Set<T> values;

  /// Called with the new set of checked values. Null disables the group.
  final ValueChanged<Set<T>>? onChanged;

  /// Pins the group to one size step.
  final CoilSize? size;

  /// Overrides the theme's motion tokens.
  final CoilMotion? motion;

  /// Names the group for assistive technology.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final sizes = CoilTheme.metricsOf(context, size: size);
    final tokens = CoilTheme.motionOf(context, override: motion);
    final look = CoilCheckboxGroupStyle.fallback(
      theme,
      sizes,
    ).merge(CoilTheme.styleOf<CoilCheckboxGroupStyle>(context)).merge(style);
    return Semantics(
      container: true,
      label: semanticLabel,
      child: CoilChoiceGroup(
        count: options.length,
        // Every row is a tab stop; the arrows still move between them.
        singleTabStop: false,
        selected: CoilChoiceGroup.selectedIndexes(options, values),
        selectionColor: look.selection!,
        highlightColor: look.highlight!,
        radius: look.radius!,
        motion: tokens,
        isEnabled: (i) => onChanged != null && options[i].enabled,
        itemBuilder: (context, i, node, states) {
          final option = options[i];
          final checked = values.contains(option.value);
          final onPressed = onChanged == null || !option.enabled
              ? null
              : () => onChanged!(CoilChoiceGroup.toggled(values, option.value));
          return Semantics(
            container: true,
            checked: checked,
            enabled: onPressed != null,
            // The Text already names the row; a custom child needs it.
            label: option.child == null ? null : option.label,
            child: CoilChoiceRow(
              selected: checked,
              metrics: sizes,
              motion: tokens,
              textStyle: look.textStyle!,
              labelColor: look.label!,
              pressFill: look.selection!,
              radius: look.radius!,
              focusNode: node,
              statesController: states,
              onPressed: onPressed,
              leading: (states) => CoilCheckboxIndicator(
                value: checked,
                states: states,
                motion: motion,
              ),
              label: option.child ?? Text(option.label),
            ),
          );
        },
      ),
    );
  }
}
