import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/toggle_group/toggle_group_style.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// A horizontal row of toggles whose selected items merge into one block: a
/// multi-select segmented control.
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
      child: CoilChoiceGroup(
        count: options.length,
        axis: Axis.horizontal,
        selected: CoilChoiceGroup.selectedIndexes(options, values),
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
              : () => onChanged!(CoilChoiceGroup.toggled(values, item.value));
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
