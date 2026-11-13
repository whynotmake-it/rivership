import 'package:coil/checkbox.dart';
import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/selection_groups/checkbox_group_style.dart';
import 'package:coil/src/components/selection_groups/toggle_group_style.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// A vertical list of checkable rows (`registry/radix/checkbox-group.tsx`).
///
/// Checked rows that touch share one rounded background
/// ([CoilSelectionPainter]); checking the row between two runs merges
/// them, unchecking a row inside a run splits it. The fluid hover highlight
/// glides over the rows on top of that.
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

  void _toggle(T value) {
    final next = {...values};
    if (!next.remove(value)) next.add(value);
    onChanged?.call(next);
  }

  /// The indexes of the selected options, for the merged blocks.
  Set<int> get _selectedIndexes => {
    for (final (i, option) in options.indexed)
      if (values.contains(option.value)) i,
  };

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final sizes = CoilTheme.metricsOf(context, size: size);
    final look = CoilCheckboxGroupStyle.fallback(
      theme,
      sizes,
    ).merge(CoilTheme.styleOf<CoilCheckboxGroupStyle>(context)).merge(style);
    return _SelectionRegion(
      selected: _selectedIndexes,
      motion: motion,
      selection: look.selection!,
      highlight: look.highlight!,
      radius: look.radius!,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, option) in options.indexed)
            CoilHoverItem(
              index: i,
              enabled: option.enabled,
              child: _CheckRow(
                checked: values.contains(option.value),
                sizes: sizes,
                onPressed: onChanged == null || !option.enabled
                    ? null
                    : () => _toggle(option.value),
                label: option.child ?? Text(option.label),
                // The Text already names the row; a custom child needs it.
                semanticLabel: option.child == null ? null : option.label,
                textStyle: look.textStyle!.copyWith(
                  color: look.label!.resolve({
                    if (values.contains(option.value)) WidgetState.selected,
                  }),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CheckRow extends StatefulWidget {
  const _CheckRow({
    required this.semanticLabel,
    required this.checked,
    required this.sizes,
    required this.onPressed,
    required this.label,
    required this.textStyle,
  });

  final String? semanticLabel;
  final bool checked;
  final CoilMetrics sizes;
  final VoidCallback? onPressed;
  final Widget label;
  final TextStyle textStyle;

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
    return Semantics(
      container: true,
      checked: widget.checked,
      label: widget.semanticLabel,
      child: CoilInteraction(
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
                      child: CoilCheckbox(
                        value: widget.checked,
                        onChanged: widget.onPressed == null ? null : (_) {},
                        statesController: _states,
                        // The row is the target, so the box doesn't pad
                        // itself to 44 (that made touch rows 68 tall).
                        tapTargetSize: CoilTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: DefaultTextStyle(
                    style: widget.textStyle,
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

  void _toggle(T value) {
    final next = {...values};
    if (!next.remove(value)) next.add(value);
    onChanged?.call(next);
  }

  /// The indexes of the selected options, for the merged blocks.
  Set<int> get _selectedIndexes => {
    for (final (i, option) in options.indexed)
      if (values.contains(option.value)) i,
  };

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final sizes = CoilTheme.metricsOf(context, size: size);
    final tokens = CoilTheme.motionOf(context, override: motion);
    final look = CoilToggleGroupStyle.fallback(
      theme,
      sizes,
    ).merge(CoilTheme.styleOf<CoilToggleGroupStyle>(context)).merge(style);
    return _SelectionRegion(
      selected: _selectedIndexes,
      axis: Axis.horizontal,
      motion: motion,
      selection: look.selection!,
      highlight: look.highlight!,
      radius: look.radius!,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, item) in options.indexed)
            CoilHoverItem(
              index: i,
              enabled: item.enabled,
              child: Semantics(
                container: true,
                toggled: values.contains(item.value),
                label: item.child == null ? null : item.label,
                child: CoilInteraction(
                  onPressed: onChanged == null || !item.enabled
                      ? null
                      : () => _toggle(item.value),
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
                          value: look.label!.resolve({
                            if (values.contains(item.value))
                              WidgetState.selected,
                            if (states.contains(WidgetState.hovered))
                              WidgetState.hovered,
                          })!,
                          motion: tokens.fade,
                          converter: .colorRgb,
                          builder: (context, color, child) => DefaultTextStyle(
                            style: look.textStyle!.copyWith(color: color),
                            maxLines: 1,
                            softWrap: false,
                            child: child!,
                          ),
                          child: item.child ?? Text(item.label),
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

/// A hover region whose items also paint merged selection blocks behind the
/// hover highlight, both on the region's `CoilMotionLayer`.
class _SelectionRegion extends StatefulWidget {
  const _SelectionRegion({
    required this.selected,
    required this.motion,
    required this.selection,
    required this.highlight,
    required this.radius,
    required this.child,
    this.axis = Axis.vertical,
  });

  final Set<int> selected;
  final CoilMotion? motion;
  final Color selection;
  final Color highlight;
  final double radius;
  final Axis axis;
  final Widget child;

  @override
  State<_SelectionRegion> createState() => _SelectionRegionState();
}

class _SelectionRegionState extends State<_SelectionRegion>
    with TickerProviderStateMixin {
  late final _selection = CoilSelectionPainter(vsync: this);

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _selection.update(
      selected: widget.selected,
      axis: widget.axis,
      color: widget.selection,
      radius: widget.radius,
      motion: CoilTheme.motionOf(context, override: widget.motion),
    );
    return CoilHoverRegion(
      axis: widget.axis == Axis.vertical ? CoilHoverAxis.y : CoilHoverAxis.x,
      background: [_selection],
      highlightColor: widget.highlight,
      highlightRadius: widget.radius,
      child: widget.child,
    );
  }
}
