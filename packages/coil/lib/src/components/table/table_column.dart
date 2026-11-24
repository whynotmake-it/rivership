/// @docImport 'package:coil/foundation.dart';
/// @docImport 'package:coil/table.dart';
library;

import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// Sort ordering for a [CoilTableColumn].
enum CoilSortDirection {
  /// Smallest first.
  ascending,

  /// Largest first.
  descending,
}

/// One column of a [CoilTable]: its header and how to build its cells.
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
    this.semanticLabel,
    this.width,
    this.flex = 1,
    this.minWidth = 96,
    this.alignment = AlignmentDirectional.centerStart,
    this.sort,
    this.onSort,
    this.sortIndicator,
  });

  /// The header, usually a [Text].
  ///
  /// Screen readers read it as the column's name.
  final Widget label;

  /// Names the column for screen readers when [label] can't, such as an
  /// icon-only header.
  final String? semanticLabel;

  /// Builds this column's cell for a row.
  final Widget Function(BuildContext context, T row) cellBuilder;

  /// A fixed width, padding included.
  ///
  /// When null, makes the column flexible.
  final double? width;

  /// The column's share of the free width, when flexible.
  final int flex;

  /// The narrowest a flexible column gets, padding included.
  final double minWidth;

  /// Where the header and the cells sit in the column.
  ///
  /// Use [AlignmentDirectional.centerEnd] for numbers.
  final AlignmentGeometry alignment;

  /// The order the column is sorted in, or null when it isn't the sort key.
  final CoilSortDirection? sort;

  /// Makes the header pressable to sort by this column.
  ///
  /// The table doesn't sort automatically: sort [CoilTable.rows] and update
  /// [sort].
  final VoidCallback? onSort;

  /// Replaces the chevron that shows [sort] in the header
  /// ([CoilIcons.chevronUp] ascending, [CoilIcons.chevronDown] descending).
  ///
  /// Shown only while [sort] is set, colored and sized by the header's
  /// [IconTheme].
  final Widget? sortIndicator;
}

/// Accessibility labels announced by screen readers for a [CoilTable].
///
/// Defaults to English.
@immutable
class CoilTableLabels {
  /// Creates the labels.
  const CoilTableLabels({
    this.sortedAscendingLabel = 'Sorted ascending',
    this.sortedDescendingLabel = 'Sorted descending',
  });

  /// The value of a column header sorted [CoilSortDirection.ascending].
  final String sortedAscendingLabel;

  /// The value of a column header sorted [CoilSortDirection.descending].
  final String sortedDescendingLabel;

  @override
  bool operator ==(Object other) =>
      other is CoilTableLabels &&
      other.sortedAscendingLabel == sortedAscendingLabel &&
      other.sortedDescendingLabel == sortedDescendingLabel;

  @override
  int get hashCode => Object.hash(sortedAscendingLabel, sortedDescendingLabel);
}

/// The animated parts of a [CoilTable].
///
/// Use these as keys of [CoilTable.motions] or [CoilTableStyle.motions].
final class CoilTableTrack<T extends Object> extends Track<T> {
  CoilTableTrack._(super.converter, {required String super.debugLabel});

  /// The row highlight gliding under a hovering pointer.
  ///
  /// Defaults to [CoilMotion.quick].
  static final highlight = CoilTableTrack<Rect>._(
    .rect,
    debugLabel: 'CoilTable.highlight',
  );

  /// The block behind selected rows, as it moves, merges, and splits.
  ///
  /// Defaults to [CoilMotion.standard].
  static final selection = CoilTableTrack<Rect>._(
    .rect,
    debugLabel: 'CoilTable.selection',
  );

  /// The keyboard focus ring moving between rows.
  ///
  /// Defaults to [CoilMotion.quick].
  static final ring = CoilTableTrack<Rect>._(
    .rect,
    debugLabel: 'CoilTable.ring',
  );

  /// The fill behind a sortable header cell.
  ///
  /// Defaults to [CoilMotion.fade].
  static final headerFill = CoilTableTrack<Color>._(
    .colorRgb,
    debugLabel: 'CoilTable.headerFill',
  );

  /// The header label color.
  ///
  /// Defaults to [CoilMotion.fade].
  static final headerLabel = CoilTableTrack<Color>._(
    .colorRgb,
    debugLabel: 'CoilTable.headerLabel',
  );

  /// The fill under a finger pressing a row.
  ///
  /// Defaults to [CoilMotion.fade] in and [CoilMotion.fadeExit] out; an
  /// override applies to both.
  static final rowPress = CoilTableTrack<Color>._(
    .colorRgb,
    debugLabel: 'CoilTable.rowPress',
  );

  /// The hairline under a row, hiding where fills touch it.
  ///
  /// Defaults to [CoilMotion.fade] in and [CoilMotion.fadeExit] out; an
  /// override applies to both.
  static final rule = CoilTableTrack<Color>._(
    .colorRgb,
    debugLabel: 'CoilTable.rule',
  );

  /// The body label color.
  ///
  /// Defaults to [CoilMotion.fade].
  static final rowLabel = CoilTableTrack<Color>._(
    .colorRgb,
    debugLabel: 'CoilTable.rowLabel',
  );
}
