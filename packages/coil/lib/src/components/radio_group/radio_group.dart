import 'dart:ui' show SemanticsRole;

import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/radio_group/radio_group_style.dart';
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
      child: CoilChoiceGroup(
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
              leading: (states) => CoilRadioIndicator(
                selected: checked,
                states: states,
                size: size,
                motion: motion,
                style: style,
              ),
              label: option.child ?? Text(option.label),
            ),
          );
        },
      ),
    );
  }
}

/// The circle of a radio: a 1.5 px border (clear when selected) and a dot,
/// with no interaction of its own.
///
/// [states] drives the border; only `hovered` is read. Use it inside a row
/// that is already the tap target, as [CoilRadioGroup] does. The circle
/// grows with the text scale. The dot scales in from 0.3 on `quick` and
/// fades out on `fadeExit`.
class CoilRadioIndicator extends StatelessWidget {
  /// Creates a radio indicator.
  const CoilRadioIndicator({
    required this.selected,
    required this.states,
    super.key,
    this.size,
    this.motion,
    this.style,
  });

  /// Whether the dot shows.
  final bool selected;

  /// The states the border reacts to.
  final Set<WidgetState> states;

  /// Pins the circle to one size step. Null follows [CoilAdaptiveScope].
  final CoilSize? size;

  /// Overrides the theme's motion tokens for this instance.
  final CoilMotion? motion;

  /// Overrides for this indicator's look, on top of the theme's
  /// [CoilRadioGroupStyle] and the defaults.
  final CoilRadioGroupStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final sizes = CoilTheme.metricsOf(context, size: size);
    final tokens = CoilTheme.motionOf(context, override: motion);
    final look = CoilRadioGroupStyle.fallback(
      theme,
      sizes,
    ).merge(CoilTheme.styleOf<CoilRadioGroupStyle>(context)).merge(style);
    final box = MediaQuery.textScalerOf(context).scale(sizes.checkboxSize);
    final border = states.contains(WidgetState.hovered)
        ? look.radioBorderHover!
        : selected
        ? look.radioBorder!.withValues(alpha: 0)
        : look.radioBorder!;
    return MotionBuilder<Color>(
      value: border,
      converter: MotionConverter.colorRgb,
      motion: tokens.fade,
      debugLabel: 'CoilRadioIndicator border',
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
          motion: selected ? tokens.quick : tokens.fadeExit,
          debugLabel: 'CoilRadioIndicator dot',
          builder: (context, progress, _) => Opacity(
            opacity: progress.clamp(0, 1),
            child: Transform.scale(
              scale: 0.3 + 0.7 * progress,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: look.dot,
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(box / 4),
                  ),
                ),
                child: SizedBox.square(dimension: box / 2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
