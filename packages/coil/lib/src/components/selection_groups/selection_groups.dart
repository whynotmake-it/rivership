import 'package:coil/checkbox.dart';
import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/selection_groups/checkbox_group_style.dart';
import 'package:coil/src/components/selection_groups/choice_group.dart';
import 'package:coil/src/components/selection_groups/toggle_group_style.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// A vertical list of checkable rows (`registry/radix/checkbox-group.tsx`).
///
/// * Checked rows that touch share one rounded background
///   ([CoilSelectionPainter]); checking the row between two runs merges
///   them, unchecking a row inside a run splits it.
/// * The fluid hover highlight glides over the rows on top of that.
/// * Each row is a tab stop. Up and Down move focus with wrapping, Home and
///   End jump, Space or Enter toggles, and one ring travels with keyboard
///   focus.
/// * Labels wrap and grow their row.
/// * On touch the merged blocks are the only selection mark, and a finger
///   shows a press fill.
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

  void _toggle(T value) {
    final next = {...values};
    if (!next.remove(value)) next.add(value);
    onChanged?.call(next);
  }

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
      child: ChoiceGroup(
        count: options.length,
        // Every row is a tab stop; the arrows still move between them.
        singleTabStop: false,
        selected: {
          for (final (i, option) in options.indexed)
            if (values.contains(option.value)) i,
        },
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
              : () => _toggle(option.value);
          return Semantics(
            container: true,
            checked: checked,
            enabled: onPressed != null,
            // The Text already names the row; a custom child needs it.
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
              // The row owns interaction; the box mirrors its states
              // (hovering the row darkens the box's border).
              leading: (_) => CoilCheckbox(
                value: checked,
                onChanged: onPressed == null ? null : (_) {},
                statesController: states,
                motion: motion,
                // The row is the target, so the box doesn't pad itself.
                tapTargetSize: CoilTapTargetSize.shrinkWrap,
              ),
              label: option.child ?? Text(option.label),
            ),
          );
        },
      ),
    );
  }
}

/// A horizontal row of toggles whose selected items merge into one shape:
/// a multi-select segmented control.
///
/// Left and Right (following the text direction) move focus, Home and End
/// jump, Space or Enter toggles, and the segments keep one tab stop.
class CoilToggleGroup<T> extends StatelessWidget {
  /// Creates a toggle group.
  const CoilToggleGroup({
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
  /// [CoilToggleGroupStyle] and the defaults.
  final CoilToggleGroupStyle? style;

  /// The toggles: each option's [CoilOption.child] or `Text(label)`.
  final List<CoilOption<T>> options;

  /// The values of the selected toggles.
  final Set<T> values;

  /// Called with the new set of selected values. Null disables the group.
  final ValueChanged<Set<T>>? onChanged;

  /// Pins the group to one size step.
  final CoilSize? size;

  /// Overrides the theme's motion tokens.
  final CoilMotion? motion;

  /// Names the group for assistive technology.
  final String? semanticLabel;

  void _toggle(T value) {
    final next = {...values};
    if (!next.remove(value)) next.add(value);
    onChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final sizes = CoilTheme.metricsOf(context, size: size);
    final tokens = CoilTheme.motionOf(context, override: motion);
    final look = CoilToggleGroupStyle.fallback(
      theme,
      sizes,
    ).merge(CoilTheme.styleOf<CoilToggleGroupStyle>(context)).merge(style);
    final touch = sizes.tier == CoilTier.touch;
    return Semantics(
      container: true,
      label: semanticLabel,
      child: ChoiceGroup(
        count: options.length,
        axis: Axis.horizontal,
        selected: {
          for (final (i, option) in options.indexed)
            if (values.contains(option.value)) i,
        },
        selectionColor: look.selection!,
        highlightColor: look.highlight!,
        radius: look.radius!,
        motion: tokens,
        isEnabled: (i) => onChanged != null && options[i].enabled,
        itemBuilder: (context, i, node, states) {
          final item = options[i];
          final selected = values.contains(item.value);
          final onPressed = onChanged == null || !item.enabled
              ? null
              : () => _toggle(item.value);
          return Semantics(
            container: true,
            toggled: selected,
            selected: selected,
            enabled: onPressed != null,
            label: item.child == null ? null : item.label,
            child: Opacity(
              opacity: onPressed == null ? (touch ? 0.4 : 0.5) : 1,
              child: CoilInteraction(
                onPressed: onPressed,
                focusNode: node,
                statesController: states,
                minHitTarget: sizes.minHitTarget,
                builder: (context, s, _) {
                  final pressing =
                      s.contains(WidgetState.pressed) &&
                      !s.contains(WidgetState.hovered);
                  final color = look.label!.resolve({
                    // Touch segments rest at full foreground.
                    if (selected || touch) WidgetState.selected,
                    if (s.contains(WidgetState.hovered) ||
                        s.contains(WidgetState.focused))
                      WidgetState.hovered,
                  })!;
                  return MotionBuilder<Color>(
                    value: pressing
                        ? look.selection!
                        : look.selection!.withValues(alpha: 0),
                    converter: MotionConverter.colorRgb,
                    motion: pressing ? tokens.fade : tokens.fadeExit,
                    debugLabel: 'CoilToggleGroup press',
                    builder: (context, fill, child) => DecoratedBox(
                      decoration: ShapeDecoration(
                        color: fill,
                        shape: RoundedSuperellipseBorder(
                          borderRadius: BorderRadius.circular(look.radius!),
                        ),
                      ),
                      child: child,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: sizes.controlHeight,
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: sizes.controlPaddingX,
                          vertical: sizes.controlPaddingY(sizes.body),
                        ),
                        child: Center(
                          widthFactor: 1,
                          heightFactor: 1,
                          child: MotionBuilder<Color>(
                            value: color,
                            motion: tokens.fade,
                            converter: .colorRgb,
                            builder: (context, color, child) =>
                                DefaultTextStyle(
                                  style: look.textStyle!.copyWith(
                                    color: color,
                                  ),
                                  maxLines: 1,
                                  softWrap: false,
                                  child: IconTheme(
                                    data: IconThemeData(
                                      size: sizes.iconSize,
                                      applyTextScaling: true,
                                      color: color,
                                    ),
                                    child: child!,
                                  ),
                                ),
                            child: item.child ?? Text(item.label),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
