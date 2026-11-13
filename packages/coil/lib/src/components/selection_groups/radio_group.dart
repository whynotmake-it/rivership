import 'dart:ui' show SemanticsRole;

import 'package:coil/foundation.dart';
import 'package:coil/src/components/selection_groups/choice_group.dart';
import 'package:coil/src/components/selection_groups/radio_group_style.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// A vertical list of mutually exclusive rows.
///
/// * One selected fill glides between rows on `standard`; hover is the
///   gliding highlight.
/// * The selected row is the one tab stop (the first row when nothing is
///   selected). The arrow keys, Home and End move focus *and* select, with
///   wrapping; disabled rows are skipped.
/// * The selected row's label turns semibold foreground, its circle's
///   border clears and its dot fills in (scale 0.3 → 1 on `quick`, out on
///   `fadeExit`).
/// * Labels wrap and grow their row. Use a select past seven options.
class CoilRadioGroup<T> extends StatelessWidget {
  /// Creates a radio group.
  const CoilRadioGroup({
    required this.options,
    required this.value,
    required this.onChanged,
    super.key,
    this.size,
    this.motion,
    this.style,
    this.semanticLabel,
  });

  /// The rows: each option's [CoilOption.child] or `Text(label)`.
  final List<CoilOption<T>> options;

  /// The value of the selected row. A value no option has selects none.
  final T? value;

  /// Called with the value of the row to select. Null disables the group.
  final ValueChanged<T>? onChanged;

  /// Pins the group to one size step.
  final CoilSize? size;

  /// Overrides the theme's motion tokens.
  final CoilMotion? motion;

  /// Overrides for this group's look, on top of the theme's
  /// [CoilRadioGroupStyle] and the defaults.
  final CoilRadioGroupStyle? style;

  /// Names the group for assistive technology.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final sizes = CoilTheme.metricsOf(context, size: size);
    final tokens = CoilTheme.motionOf(context, override: motion);
    final look = CoilRadioGroupStyle.fallback(
      theme,
      sizes,
    ).merge(CoilTheme.styleOf<CoilRadioGroupStyle>(context)).merge(style);
    final selected = options.indexWhere((o) => o.value == value);
    bool enabled(int i) => onChanged != null && options[i].enabled;

    return Semantics(
      container: true,
      label: semanticLabel,
      role: SemanticsRole.radioGroup,
      child: ChoiceGroup(
        count: options.length,
        mergeSelection: false,
        selected: {if (selected >= 0) selected},
        tabStop: selected >= 0 && enabled(selected) ? selected : null,
        selectionColor: look.selection!,
        highlightColor: look.highlight!,
        radius: look.radius!,
        motion: tokens,
        isEnabled: enabled,
        // Arrows move focus; landing on a row selects it.
        onFocusMoved: (i) {
          if (enabled(i) && i != selected) onChanged!(options[i].value);
        },
        itemBuilder: (context, i, node, states) {
          final option = options[i];
          final checked = i == selected;
          final onPressed = enabled(i) ? () => onChanged!(option.value) : null;
          return Semantics(
            container: true,
            inMutuallyExclusiveGroup: true,
            checked: checked,
            enabled: onPressed != null,
            label: option.child == null ? null : option.label,
            child: ChoiceRow(
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
              leading: (s) => _Radio(
                selected: checked,
                hovered: s.contains(WidgetState.hovered),
                look: look,
                sizes: sizes,
                motion: tokens,
              ),
              label: option.child ?? Text(option.label),
            ),
          );
        },
      ),
    );
  }
}

/// The circle: a 1.5 px border (clear when selected) and a dot.
class _Radio extends StatelessWidget {
  const _Radio({
    required this.selected,
    required this.hovered,
    required this.look,
    required this.sizes,
    required this.motion,
  });

  final bool selected;
  final bool hovered;
  final CoilRadioGroupStyle look;
  final CoilMetrics sizes;
  final CoilMotion motion;

  @override
  Widget build(BuildContext context) {
    // Like the checkbox, the circle grows with text.
    final box = MediaQuery.textScalerOf(context).scale(sizes.checkboxSize);
    final border = hovered
        ? look.radioBorderHover!
        : selected
        ? look.radioBorder!.withValues(alpha: 0)
        : look.radioBorder!;
    return MotionBuilder<Color>(
      value: border,
      converter: MotionConverter.colorRgb,
      motion: motion.fade,
      debugLabel: 'CoilRadioGroup border',
      builder: (context, color, child) => DecoratedBox(
        decoration: ShapeDecoration(
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(box / 2),
            side: BorderSide(color: color, width: 1.5),
          ),
        ),
        child: SizedBox.square(dimension: box, child: child),
      ),
      child: Center(
        child: SingleMotionBuilder(
          value: selected ? 1 : 0,
          motion: selected ? motion.quick : motion.fadeExit,
          debugLabel: 'CoilRadioGroup dot',
          builder: (context, progress, _) {
            final dot = box / 2;
            return Opacity(
              opacity: progress.clamp(0, 1),
              child: Transform.scale(
                scale: 0.3 + 0.7 * progress,
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: look.dot,
                    shape: RoundedSuperellipseBorder(
                      borderRadius: BorderRadius.circular(dot / 2),
                    ),
                  ),
                  child: SizedBox.square(dimension: dot),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
