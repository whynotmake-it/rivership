import 'dart:math' as math;
import 'dart:ui' show SemanticsRole;

import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/table/table_column.dart';
import 'package:coil/src/components/table/table_style.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// Resolves [columns] to widths for [available] width: fixed columns take
/// their width, flexible ones share the rest by flex without going under
/// their minimum. When even the minimums don't fit, they get the minimum
/// and the table scrolls.
///
/// This is real layout, from the viewport width rather than measured
/// content. Each flexible column is the equivalent of
/// `MaxColumnWidth(FixedColumnWidth(min), FlexColumnWidth(flex))`.
List<double> tableColumnWidths<T>(
  List<CoilTableColumn<T>> columns,
  double available,
  CoilMetrics metrics,
) {
  final pad = metrics.controlPaddingX * 2;
  final widths = [
    for (final c in columns) c.width ?? math.max(c.minWidth, pad),
  ];
  final flexible = {
    for (final (i, c) in columns.indexed)
      if (c.width == null) i,
  };
  if (!available.isFinite) return widths;
  // Columns pinned at their minimum leave the share; repeat until the
  // others' shares all clear their minimums.
  while (flexible.isNotEmpty) {
    final fixed = [
      for (final (i, w) in widths.indexed)
        if (!flexible.contains(i)) w,
    ].fold<double>(0, (a, b) => a + b);
    final free = available - fixed;
    final flex = flexible.fold(0, (a, i) => a + columns[i].flex);
    final pinned = <int>{};
    for (final i in flexible) {
      final share = flex == 0 ? 0.0 : free * columns[i].flex / flex;
      final minimum = math.max(columns[i].minWidth, pad);
      if (share < minimum) {
        widths[i] = minimum;
        pinned.add(i);
      } else {
        widths[i] = share;
      }
    }
    if (pinned.isEmpty) break;
    flexible.removeAll(pinned);
  }
  return widths;
}

/// The header row: semibold captions, a rule below, sortable cells
/// pressable.
class TableHeaderRow<T> extends StatelessWidget {
  /// Creates the header row.
  const TableHeaderRow({
    required this.columns,
    required this.widths,
    required this.metrics,
    required this.style,
    required this.labels,
    required this.fillMotion,
    required this.labelMotion,
    super.key,
  });

  /// The columns.
  final List<CoilTableColumn<T>> columns;

  /// The resolved column widths.
  final List<double> widths;

  /// The table's metrics.
  final CoilMetrics metrics;

  /// The table's resolved style.
  final CoilTableStyle style;

  /// The sort announcements.
  final CoilTableLabels labels;

  /// The motion of a sortable cell's fill.
  final Motion fillMotion;

  /// The motion of the label color.
  final Motion labelMotion;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      role: SemanticsRole.row,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: style.rule!)),
        ),
        // One row: measuring it lets every header fill reach full height.
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, column) in columns.indexed)
                SizedBox(
                  width: widths[i],
                  child: _HeaderCell(
                    column: column,
                    metrics: metrics,
                    style: style,
                    labels: labels,
                    fillMotion: fillMotion,
                    labelMotion: labelMotion,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({
    required this.column,
    required this.metrics,
    required this.style,
    required this.labels,
    required this.fillMotion,
    required this.labelMotion,
  });

  final CoilTableColumn<Object?> column;
  final CoilMetrics metrics;
  final CoilTableStyle style;
  final CoilTableLabels labels;
  final Motion fillMotion;
  final Motion labelMotion;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(style.radius!);
    final theme = CoilTheme.of(context);
    final onSort = column.onSort;
    return Semantics(
      container: true,
      role: SemanticsRole.columnHeader,
      button: onSort != null,
      enabled: onSort == null ? null : true,
      label: column.semanticLabel,
      value: switch (column.sort) {
        CoilSortDirection.ascending => labels.sortedAscendingLabel,
        CoilSortDirection.descending => labels.sortedDescendingLabel,
        null => null,
      },
      child: onSort == null
          ? _content(const {})
          : CoilInteraction(
              onPressed: onSort,
              builder: (context, states, _) => CoilFocusRing(
                visible: states.contains(WidgetState.focused),
                borderRadius: radius,
                // Inset, inside the table's clip.
                offset: -(style.ringInset! + theme.focusRingWidth),
                child: MotionBuilder<Color>(
                  value: style.headerFill!.resolve(states)!,
                  converter: MotionConverter.colorRgb,
                  motion: fillMotion,
                  debugLabel: 'CoilTable header fill',
                  builder: (context, fill, child) => DecoratedBox(
                    decoration: ShapeDecoration(
                      color: fill,
                      shape: RoundedSuperellipseBorder(borderRadius: radius),
                    ),
                    child: child,
                  ),
                  child: _content(states),
                ),
              ),
            ),
    );
  }

  Widget _content(Set<WidgetState> states) {
    final sort = column.sort;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: metrics.controlHeight),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: metrics.controlPaddingX,
          vertical: metrics.controlPaddingY(metrics.caption),
        ),
        child: Align(
          alignment: column.alignment,
          widthFactor: 1,
          heightFactor: 1,
          child: MotionBuilder<Color>(
            value: style.headerLabel!.resolve(states)!,
            converter: MotionConverter.colorRgb,
            motion: labelMotion,
            debugLabel: 'CoilTable header label',
            builder: (context, color, _) => IconTheme(
              data: IconThemeData(
                size: style.headerIconSize,
                applyTextScaling: true,
                color: color,
              ),
              child: DefaultTextStyle(
                style: style.headerStyle!.copyWith(color: color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: style.sortIndicatorGap!,
                  children: [
                    Flexible(child: column.label),
                    if (sort != null)
                      column.sortIndicator ??
                          CoilDrawnGlyph(switch (sort) {
                            CoilSortDirection.ascending => CoilGlyph.chevronUp,
                            CoilSortDirection.descending =>
                              CoilGlyph.chevronDown,
                          }),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
