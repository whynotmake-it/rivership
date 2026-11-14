import 'package:coil/button.dart';
import 'package:coil/foundation.dart';
import 'package:coil/input.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/data_table/data_table_controller.dart';
import 'package:coil/table.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// A column of a [CoilDataTable].
@immutable
class CoilDataColumn<T> {
  /// Describes a column.
  const CoilDataColumn({
    required this.label,
    required this.cellBuilder,
    this.semanticLabel,
    this.compare,
    this.width,
    this.flex = 1,
    this.minWidth = 96,
    this.alignment = AlignmentDirectional.centerStart,
  });

  /// The header, usually a [Text].
  final Widget label;

  /// Names the column for screen readers when [label] can't.
  final String? semanticLabel;

  /// Builds this column's cell for a row.
  final Widget Function(BuildContext context, T row) cellBuilder;

  /// Orders two rows by this column; makes the header sort the table.
  final Comparator<T>? compare;

  /// A fixed width, padding included. Null makes the column flexible.
  final double? width;

  /// The column's share of the free width, when flexible.
  final int flex;

  /// The narrowest a flexible column gets.
  final double minWidth;

  /// Where the header and cells sit; centerEnd for numbers.
  final AlignmentGeometry alignment;
}

/// What a [CoilDataTable] shows and announces. The widgets are usually
/// [Text]s the table styles; the `*Label` strings are for screen readers.
/// English by default.
@immutable
class CoilDataTableLabels {
  /// Creates the labels.
  const CoilDataTableLabels({
    this.search = const Text('Search'),
    this.searchLabel = 'Search',
    this.count = _count,
    this.page = _page,
    this.previousPageLabel = 'Previous page',
    this.nextPageLabel = 'Next page',
  });

  /// The search field's placeholder.
  final Widget search;

  /// The search field's name for screen readers.
  final String searchLabel;

  /// The footer's count, like "2 of 40 selected" or "40 rows". It's a live
  /// region, so changes are announced.
  final Widget Function({required int selected, required int total}) count;

  /// The page position, like "Page 2 of 5", from the page number (from 1)
  /// and the page count.
  final Widget Function(int page, int count) page;

  /// The previous-page button's label for screen readers.
  final String previousPageLabel;

  /// The next-page button's label for screen readers.
  final String nextPageLabel;

  static Widget _count({required int selected, required int total}) =>
      Text(selected > 0 ? '$selected of $total selected' : '$total rows');

  static Widget _page(int page, int count) => Text('Page $page of $count');
}

/// A [CoilTable] driven by a [CoilDataTableController]: a search field
/// over it, sortable headers, selection, and a footer with the count and
/// the pages.
///
/// The controller holds the data and its state; this widget only shows it.
class CoilDataTable<T> extends StatelessWidget {
  /// Creates a data table.
  const CoilDataTable({
    required this.controller,
    required this.columns,
    super.key,
    this.searchable = true,
    this.selectable = true,
    this.onRowActivated,
    this.empty,
    this.labels = const CoilDataTableLabels(),
    this.semanticLabel,
  });

  /// The data and its state.
  final CoilDataTableController<T> controller;

  /// The columns, in reading order.
  final List<CoilDataColumn<T>> columns;

  /// Whether a search field shows above the table. It needs the
  /// controller's `matches`.
  final bool searchable;

  /// Whether rows can be selected.
  final bool selectable;

  /// Called when a row is opened with Enter or a tap.
  final ValueChanged<T>? onRowActivated;

  /// Shown when no row matches.
  final Widget? empty;

  /// The texts it shows.
  final CoilDataTableLabels labels;

  /// A name for the table.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final metrics = CoilTheme.metricsOf(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final pages = controller.pageCount;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: metrics.gap * 2,
          children: [
            if (searchable)
              CoilInput(
                placeholder: labels.search,
                semanticLabel: labels.searchLabel,
                autocorrect: false,
                textInputAction: TextInputAction.search,
                onChanged: (text) => controller.query = text,
              ),
            CoilTable<T>(
              rows: controller.view,
              values: controller.selected,
              onChanged: selectable
                  ? (selected) => controller.selected = selected
                  : null,
              onRowActivated: onRowActivated,
              empty: empty,
              semanticLabel: semanticLabel,
              columns: [
                for (final (i, column) in columns.indexed)
                  CoilTableColumn<T>(
                    label: column.label,
                    semanticLabel: column.semanticLabel,
                    cellBuilder: column.cellBuilder,
                    width: column.width,
                    flex: column.flex,
                    minWidth: column.minWidth,
                    alignment: column.alignment,
                    sort: controller.sortColumn == i
                        ? controller.sortDirection
                        : null,
                    onSort: switch (column.compare) {
                      final compare? => () => controller.sortBy(i, compare),
                      null => null,
                    },
                  ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: DefaultTextStyle(
                      style: theme.typography.style(
                        metrics.caption,
                        color: theme.colors.mutedForeground,
                      ),
                      child: labels.count(
                        selected: controller.selected.length,
                        total: controller.matching.length,
                      ),
                    ),
                  ),
                ),
                if (pages > 1) ...[
                  DefaultTextStyle(
                    style: theme.typography.style(
                      metrics.caption,
                      color: theme.colors.mutedForeground,
                    ),
                    child: labels.page(controller.page + 1, pages),
                  ),
                  SizedBox(width: metrics.gap),
                  CoilButton.icon(
                    variant: CoilButtonVariant.ghost,
                    size: CoilSize.compact,
                    onPressed: controller.page > 0
                        ? () => controller.page--
                        : null,
                    semanticLabel: labels.previousPageLabel,
                    icon: const CoilDrawnGlyph(CoilGlyph.chevronStart),
                  ),
                  CoilButton.icon(
                    variant: CoilButtonVariant.ghost,
                    size: CoilSize.compact,
                    onPressed: controller.page < pages - 1
                        ? () => controller.page++
                        : null,
                    semanticLabel: labels.nextPageLabel,
                    icon: const CoilDrawnGlyph(CoilGlyph.chevronEnd),
                  ),
                ],
              ],
            ),
          ],
        );
      },
    );
  }
}
