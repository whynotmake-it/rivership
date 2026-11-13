import 'dart:ui' show SemanticsRole;

import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/table/table_column.dart';
import 'package:coil/src/components/table/table_style.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// The motions a body row animates on, resolved from its tracks.
typedef TableRowMotions = ({
  Motion press,
  Motion pressExit,
  Motion rule,
  Motion ruleExit,
  Motion label,
});

/// One body row. It draws only its label colors, its rule and its own
/// press fill on touch; the table's layer paints the highlight and the
/// selection underneath.
class TableBodyRow<T> extends StatefulWidget {
  /// Creates a body row.
  const TableBodyRow({
    required this.index,
    required this.row,
    required this.columns,
    required this.widths,
    required this.selected,
    required this.nextSelected,
    required this.last,
    required this.metrics,
    required this.style,
    required this.motions,
    required this.onPressed,
    super.key,
  });

  /// The row's position, as the hover region knows it.
  final int index;

  /// The row's data.
  final T row;

  /// The columns.
  final List<CoilTableColumn<T>> columns;

  /// The resolved column widths.
  final List<double> widths;

  /// Whether the row is selected.
  final bool selected;

  /// Whether the next row is selected, so the rule between them hides.
  final bool nextSelected;

  /// Whether this is the last row, which has no rule.
  final bool last;

  /// The table's metrics.
  final CoilMetrics metrics;

  /// The table's resolved style.
  final CoilTableStyle style;

  /// The row's motions.
  final TableRowMotions motions;

  /// Called on a tap; null makes the row inert.
  final VoidCallback? onPressed;

  @override
  State<TableBodyRow<T>> createState() => _TableBodyRowState<T>();
}

class _TableBodyRowState<T> extends State<TableBodyRow<T>> {
  final _states = WidgetStatesController();

  @override
  void dispose() {
    _states.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TableBodyRow(:index, :metrics, :style, :motions) = widget;
    final lit = CoilHoverRegion.maybeOf(context)?.activeIndex;
    final color = style.cellLabel!.resolve({
      if (lit == index) WidgetState.hovered,
      if (widget.selected) WidgetState.selected,
    })!;
    // The rule hides where a fill touches it, so fills read as one shape.
    final ruleHidden =
        widget.last ||
        lit == index ||
        lit == index + 1 ||
        widget.selected ||
        widget.nextSelected;
    final radius = BorderRadius.circular(style.radius!);

    return Semantics(
      container: true,
      role: SemanticsRole.row,
      selected: widget.onPressed == null ? null : widget.selected,
      onTap: widget.onPressed,
      child: CoilInteractionDetector(
        states: _states,
        enabled: widget.onPressed != null,
        onTap: widget.onPressed,
        cursor: widget.onPressed != null
            ? SystemMouseCursors.click
            : MouseCursor.defer,
        excludeFromSemantics: true,
        child: ListenableBuilder(
          listenable: _states,
          builder: (context, child) {
            final states = _states.value;
            final pressed = states.contains(WidgetState.pressed);
            return MotionBuilder<Color>(
              // A finger pressing a row gets a fill that ends with the
              // press; hovering pointers already show the highlight.
              value: pressed && !states.contains(WidgetState.hovered)
                  ? style.pressedFill!
                  : style.pressedFill!.withValues(alpha: 0),
              converter: MotionConverter.colorRgb,
              motion: pressed ? motions.press : motions.pressExit,
              debugLabel: 'CoilTable row press',
              builder: (context, fill, child) => DecoratedBox(
                decoration: ShapeDecoration(
                  color: fill,
                  shape: RoundedSuperellipseBorder(borderRadius: radius),
                ),
                child: child,
              ),
              child: child,
            );
          },
          child: MotionBuilder<Color>(
            value: ruleHidden ? style.rule!.withValues(alpha: 0) : style.rule!,
            converter: MotionConverter.colorRgb,
            motion: ruleHidden ? motions.ruleExit : motions.rule,
            debugLabel: 'CoilTable rule',
            builder: (context, rule, child) => DecoratedBox(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: rule)),
              ),
              child: child,
            ),
            child: MotionBuilder<Color>(
              value: color,
              converter: MotionConverter.colorRgb,
              motion: motions.label,
              debugLabel: 'CoilTable row label',
              builder: (context, color, _) => IconTheme(
                data: IconThemeData(
                  size: metrics.iconSize,
                  applyTextScaling: true,
                  color: color,
                ),
                child: DefaultTextStyle(
                  style: style.cellStyle!.copyWith(color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  child: Row(
                    children: [
                      for (final (i, column) in widget.columns.indexed)
                        SizedBox(
                          width: widget.widths[i],
                          child: Semantics(
                            container: true,
                            role: SemanticsRole.cell,
                            child: _CellFrame(
                              metrics: metrics,
                              child: Align(
                                alignment: column.alignment,
                                heightFactor: 1,
                                child: column.cellBuilder(context, widget.row),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The empty state: [child] centered over [rows] rows' height, as one row
/// with one cell for assistive technology. Each row is framed like a body
/// row around one line of [CoilTableStyle.cellStyle], so the height follows
/// the text scale as real rows do.
class TableEmptyRow extends StatelessWidget {
  /// Creates the empty state.
  const TableEmptyRow({
    required this.rows,
    required this.metrics,
    required this.style,
    required this.child,
    super.key,
  });

  /// How many rows of height to hold.
  final int rows;

  /// The table's metrics.
  final CoilMetrics metrics;

  /// The table's resolved style.
  final CoilTableStyle style;

  /// What to show; nothing when null.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      role: SemanticsRole.row,
      child: Semantics(
        container: true,
        role: SemanticsRole.cell,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < rows; i++)
                  _CellFrame(
                    metrics: metrics,
                    child: CoilLineBox(
                      style: style.cellStyle!,
                      child: const SizedBox.shrink(),
                    ),
                  ),
              ],
            ),
            DefaultTextStyle(
              style: style.cellStyle!.copyWith(
                color: CoilTheme.of(context).colors.mutedForeground,
              ),
              textAlign: TextAlign.center,
              child: child ?? const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

/// A body cell's box: at least a control tall, padded like a control
/// around body text.
class _CellFrame extends StatelessWidget {
  const _CellFrame({required this.metrics, required this.child});

  final CoilMetrics metrics;
  final Widget child;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(minHeight: metrics.controlHeight),
    child: Padding(
      padding: EdgeInsets.symmetric(
        horizontal: metrics.controlPaddingX,
        vertical: metrics.controlPaddingY(metrics.body),
      ),
      child: child,
    ),
  );
}
