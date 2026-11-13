import 'package:coil/checkbox.dart';
import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// A vertical list of checkable rows (`registry/radix/checkbox-group.tsx`).
///
/// Checked rows that touch share one rounded background
/// ([CoilSelectionPainter]); checking the row between two runs merges
/// them, unchecking a row inside a run splits it. The fluid hover highlight
/// glides over the rows on top of that.
class CoilCheckboxGroup extends StatelessWidget {
  /// Creates a checkbox group.
  const CoilCheckboxGroup({
    required this.children,
    required this.values,
    required this.onChanged,
    super.key,
    this.size,
    this.motion,
  });

  /// The row labels.
  final List<Widget> children;

  /// The checked rows.
  final Set<int> values;

  /// Called with the new set of checked rows. Null disables the group.
  final ValueChanged<Set<int>>? onChanged;

  /// Pins the group to one size step.
  final CoilSize? size;

  /// Overrides the theme's motion tokens.
  final CoilMotion? motion;

  void _toggle(int i) {
    final next = {...values};
    if (!next.remove(i)) next.add(i);
    onChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final sizes = CoilTheme.metricsOf(context, size: size);
    return _SelectionRegion(
      selected: values,
      motion: motion,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, option) in children.indexed)
            CoilHoverItem(
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
  final CoilMetrics sizes;
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
    final theme = CoilTheme.of(context);
    return Semantics(
      container: true,
      checked: widget.checked,
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
class CoilToggleGroup extends StatelessWidget {
  /// Creates a toggle group.
  const CoilToggleGroup({
    required this.children,
    required this.values,
    required this.onChanged,
    super.key,
    this.size,
    this.motion,
  });

  /// The toggle labels.
  final List<Widget> children;

  /// The selected toggles.
  final Set<int> values;

  /// Called with the new selection. Null disables the group.
  final ValueChanged<Set<int>>? onChanged;

  /// Pins the group to one size step.
  final CoilSize? size;

  /// Overrides the theme's motion tokens.
  final CoilMotion? motion;

  void _toggle(int i) {
    final next = {...values};
    if (!next.remove(i)) next.add(i);
    onChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final colors = theme.colors;
    final sizes = CoilTheme.metricsOf(context, size: size);
    final tokens = CoilTheme.motionOf(context, override: motion);
    return _SelectionRegion(
      selected: values,
      axis: Axis.horizontal,
      motion: motion,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, item) in children.indexed)
            CoilHoverItem(
              index: i,
              child: Semantics(
                container: true,
                toggled: values.contains(i),
                child: CoilInteraction(
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
                              values.contains(i) ||
                                  states.contains(WidgetState.hovered)
                              ? colors.foreground
                              : colors.mutedForeground,
                          motion: tokens.fade,
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

/// A hover region whose items also paint merged selection blocks behind the
/// hover highlight, both on the region's `CoilMotionLayer`.
class _SelectionRegion extends StatefulWidget {
  const _SelectionRegion({
    required this.selected,
    required this.motion,
    required this.child,
    this.axis = Axis.vertical,
  });

  final Set<int> selected;
  final CoilMotion? motion;
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
    final theme = CoilTheme.of(context);
    _selection.update(
      selected: widget.selected,
      axis: widget.axis,
      color: theme.colors.active,
      radius: theme.shape.item,
      motion: CoilTheme.motionOf(context, override: widget.motion),
    );
    return CoilHoverRegion(
      axis: widget.axis == Axis.vertical ? CoilHoverAxis.y : CoilHoverAxis.x,
      background: [_selection],
      child: widget.child,
    );
  }
}
