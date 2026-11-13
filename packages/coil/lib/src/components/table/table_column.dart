import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// The order a sorted column shows.
enum CoilSortDirection {
  /// Smallest first.
  ascending,

  /// Largest first.
  descending,
}

/// One column of a `CoilTable`: its header and how to build its cells.
///
/// Columns are flexible by default and share the table's width by [flex],
/// never narrower than [minWidth]. A [width] makes the column fixed. When
/// the columns can't fit, the table scrolls sideways.
@immutable
class CoilTableColumn<T> {
  /// Creates a column.
  const CoilTableColumn({
    required this.label,
    required this.cellBuilder,
    this.child,
    this.width,
    this.flex = 1,
    this.minWidth = 96,
    this.alignment = AlignmentDirectional.centerStart,
    this.sort,
    this.onSort,
    this.sortIndicator,
  });

  /// The header text, also the column's name for assistive technology.
  final String label;

  /// Replaces the default `Text(label)` in the header.
  final Widget? child;

  /// Builds this column's cell for a row.
  final Widget Function(BuildContext context, T row) cellBuilder;

  /// A fixed width, padding included. Null makes the column flexible.
  final double? width;

  /// The column's share of the free width, when flexible.
  final int flex;

  /// The narrowest a flexible column gets, padding included.
  final double minWidth;

  /// Where the header and the cells sit in the column. Use
  /// [AlignmentDirectional.centerEnd] for numbers.
  final AlignmentGeometry alignment;

  /// The order the column is sorted in, or null when it isn't the sort key.
  final CoilSortDirection? sort;

  /// Makes the header pressable, to sort by this column. The table doesn't
  /// sort: sort `CoilTable.rows` and set [sort].
  final VoidCallback? onSort;

  /// Replaces the chevron that shows [sort] in the header. It shows only
  /// while [sort] is set, colored and sized by the header's `IconTheme`.
  final Widget? sortIndicator;
}

/// The texts a `CoilTable` announces. The defaults are English.
@immutable
class CoilTableLabels {
  /// Creates the labels.
  const CoilTableLabels({
    this.sortedAscending = 'Sorted ascending',
    this.sortedDescending = 'Sorted descending',
  });

  /// The value of a column header sorted [CoilSortDirection.ascending].
  final String sortedAscending;

  /// The value of a column header sorted [CoilSortDirection.descending].
  final String sortedDescending;

  @override
  bool operator ==(Object other) =>
      other is CoilTableLabels &&
      other.sortedAscending == sortedAscending &&
      other.sortedDescending == sortedDescending;

  @override
  int get hashCode => Object.hash(sortedAscending, sortedDescending);
}

/// The animated parts of a `CoilTable`. Use them as keys of
/// `CoilTable.motions` or `CoilThemeData.trackMotions`.
final class CoilTableTrack<T extends Object> extends Track<T> {
  CoilTableTrack._(super.converter, {required String super.debugLabel});

  /// The row highlight gliding under a hovering pointer. Default motion:
  /// `quick`.
  static final highlight = CoilTableTrack<Rect>._(
    .rect,
    debugLabel: 'CoilTable.highlight',
  );

  /// The block behind selected rows, as it moves, merges and splits.
  /// Default motion: `standard`.
  static final selection = CoilTableTrack<Rect>._(
    .rect,
    debugLabel: 'CoilTable.selection',
  );

  /// The keyboard focus ring moving between rows. Default motion: `quick`.
  static final ring = CoilTableTrack<Rect>._(
    .rect,
    debugLabel: 'CoilTable.ring',
  );

  /// The fill behind a sortable header cell. Default motion: `fade`.
  static final headerFill = CoilTableTrack<Color>._(
    .colorRgb,
    debugLabel: 'CoilTable.headerFill',
  );

  /// The header label color. Default motion: `fade`.
  static final headerLabel = CoilTableTrack<Color>._(
    .colorRgb,
    debugLabel: 'CoilTable.headerLabel',
  );

  /// The fill under a finger pressing a row. Default motion: `fade` in,
  /// `fadeExit` out; an override applies to both.
  static final rowPress = CoilTableTrack<Color>._(
    .colorRgb,
    debugLabel: 'CoilTable.rowPress',
  );

  /// The hairline under a row, hiding where fills touch it. Default motion:
  /// `fade` in, `fadeExit` out; an override applies to both.
  static final rule = CoilTableTrack<Color>._(
    .colorRgb,
    debugLabel: 'CoilTable.rule',
  );

  /// The body label color. Default motion: `fade`.
  static final rowLabel = CoilTableTrack<Color>._(
    .colorRgb,
    debugLabel: 'CoilTable.rowLabel',
  );
}
