import 'package:fluid_functionalism/src/components/checkbox.dart';
import 'package:fluid_functionalism/src/foundation/fluid_motion.dart';
import 'package:fluid_functionalism/src/foundation/fluid_sizes.dart';
import 'package:fluid_functionalism/src/foundation/fluid_theme.dart';
import 'package:fluid_functionalism/src/primitives/fluid_hover.dart';
import 'package:fluid_functionalism/src/primitives/fluid_pressable.dart';
import 'package:fluid_functionalism/src/primitives/fluid_selection.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// A vertical list of checkable rows (`registry/radix/checkbox-group.tsx`).
///
/// Checked rows that touch share one rounded background
/// ([FluidSelectionBackground]); checking the row between two runs merges
/// them, unchecking a row inside a run splits it. The fluid hover highlight
/// glides over the rows on top of that.
class FluidCheckboxGroup extends StatelessWidget {
  /// Creates a checkbox group.
  const FluidCheckboxGroup({
    required this.options,
    required this.values,
    required this.onChanged,
    super.key,
    this.density,
    this.motion,
  });

  /// The row labels.
  final List<Widget> options;

  /// The checked rows.
  final Set<int> values;

  /// Called with the new set of checked rows. Null disables the group.
  final ValueChanged<Set<int>>? onChanged;

  /// Pins the group to one size step.
  final FluidDensity? density;

  /// Overrides the theme's motion tokens.
  final FluidMotionThemeData? motion;

  void _toggle(int i) {
    final next = {...values};
    if (!next.remove(i)) next.add(i);
    onChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluidTheme.of(context);
    final sizes = FluidTheme.sizesOf(context, density: density);
    return FluidHoverRegion(
      backgroundBuilder: (context, state) => Stack(
        children: [
          FluidSelectionBackground(
            selected: values,
            rects: state.isMeasured ? state.rects : const {},
            motion: motion,
          ),
          FluidHoverRegion.defaultHighlight(context, state),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, option) in options.indexed)
            FluidHoverItem(
              index: i,
              child: _CheckRow(
                checked: values.contains(i),
                sizes: sizes,
                onPressed: onChanged == null ? null : () => _toggle(i),
                label: option,
                textColor: theme.colors.foreground,
              ),
            ),
        ],
      ),
    );
  }
}

class _CheckRow extends StatefulWidget {
  const _CheckRow({
    required this.checked,
    required this.sizes,
    required this.onPressed,
    required this.label,
    required this.textColor,
  });

  final bool checked;
  final FluidSizes sizes;
  final VoidCallback? onPressed;
  final Widget label;
  final Color textColor;

  @override
  State<_CheckRow> createState() => _CheckRowState();
}

class _CheckRowState extends State<_CheckRow> {
  final _states = WidgetStatesController();

  @override
  void dispose() {
    _states.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sizes = widget.sizes;
    final theme = FluidTheme.of(context);
    return Semantics(
      container: true,
      checked: widget.checked,
      child: FluidPressable(
        onPressed: widget.onPressed,
        statesController: _states,
        minHitTarget: sizes.minHitTarget,
        builder: (context, states, _) => ConstrainedBox(
          constraints: BoxConstraints(minHeight: sizes.controlHeight),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: sizes.itemPaddingX,
              vertical: sizes.controlPaddingY(sizes.body),
            ),
            child: Row(
              spacing: sizes.gap,
              children: [
                // The row owns interaction; the box mirrors its states
                // (hovering the row darkens the box's border, as on web).
                ExcludeFocus(
                  child: IgnorePointer(
                    child: ExcludeSemantics(
                      child: FluidCheckbox(
                        value: widget.checked,
                        onChanged: widget.onPressed == null ? null : (_) {},
                        statesController: _states,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: DefaultTextStyle(
                    style: theme.typography.style(
                      sizes.body,
                      color: widget.textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    child: widget.label,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A horizontal row of toggles whose selected items merge into one shape:
/// a multi-select segmented control.
class FluidToggleGroup extends StatelessWidget {
  /// Creates a toggle group.
  const FluidToggleGroup({
    required this.items,
    required this.selected,
    required this.onChanged,
    super.key,
    this.density,
    this.motion,
  });

  /// The toggle labels.
  final List<Widget> items;

  /// The selected toggles.
  final Set<int> selected;

  /// Called with the new selection. Null disables the group.
  final ValueChanged<Set<int>>? onChanged;

  /// Pins the group to one size step.
  final FluidDensity? density;

  /// Overrides the theme's motion tokens.
  final FluidMotionThemeData? motion;

  void _toggle(int i) {
    final next = {...selected};
    if (!next.remove(i)) next.add(i);
    onChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluidTheme.of(context);
    final colors = theme.colors;
    final sizes = FluidTheme.sizesOf(context, density: density);
    final tokens = FluidTheme.motionOf(context, override: motion);
    return FluidHoverRegion(
      axis: FluidHoverAxis.x,
      backgroundBuilder: (context, state) => Stack(
        children: [
          FluidSelectionBackground(
            selected: selected,
            rects: state.isMeasured ? state.rects : const {},
            axis: Axis.horizontal,
            motion: motion,
          ),
          FluidHoverRegion.defaultHighlight(context, state),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, item) in items.indexed)
            FluidHoverItem(
              index: i,
              child: Semantics(
                container: true,
                toggled: selected.contains(i),
                child: FluidPressable(
                  onPressed: onChanged == null ? null : () => _toggle(i),
                  minHitTarget: sizes.minHitTarget,
                  builder: (context, states, _) => ConstrainedBox(
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
                          value:
                              selected.contains(i) ||
                                  states.contains(WidgetState.hovered)
                              ? colors.foreground
                              : colors.mutedForeground,
                          motion: tokens.color,
                          converter: .colorRgb,
                          builder: (context, color, child) => DefaultTextStyle(
                            style: theme.typography.style(
                              sizes.body,
                              color: color,
                            ),
                            maxLines: 1,
                            softWrap: false,
                            child: child!,
                          ),
                          child: item,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
