import 'dart:math' as math;

import 'package:coil/table.dart';
import 'package:flutter/foundation.dart';

/// The state of a data table, without any UI: which [rows] match the
/// [query], how they're sorted, which are selected, and which page shows.
///
/// [view] is what a table shows. Use it with `CoilDataTable`, or drive your
/// own table with it.
class CoilDataTableController<T> extends ChangeNotifier {
  /// Creates a controller over [rows].
  ///
  /// [matches] decides whether a row matches the search text; without it
  /// nothing is filtered. A [pageSize] of 0 shows every row on one page.
  CoilDataTableController({
    required this._rows,
    this.matches,
    this._pageSize = 0,
  }) {
    _update();
  }

  /// Whether a row matches the lower-cased search text.
  final bool Function(T row, String query)? matches;

  /// The data, unsorted and unfiltered.
  List<T> get rows => _rows;
  List<T> _rows;
  set rows(List<T> value) {
    _rows = value;
    _selected.retainWhere(value.contains);
    _update();
  }

  /// The search text.
  String get query => _query;
  String _query = '';
  set query(String value) {
    if (value == _query) return;
    _query = value;
    _page = 0;
    _update();
  }

  /// The sort key's column, or null when unsorted.
  int? get sortColumn => _sortColumn;
  int? _sortColumn;

  /// The sort order of [sortColumn].
  CoilSortDirection get sortDirection => _sortDirection;
  CoilSortDirection _sortDirection = CoilSortDirection.ascending;
  Comparator<T>? _compare;

  /// Sorts by [column] with [compare]: ascending first, then descending on
  /// a second call for the same column.
  void sortBy(int column, Comparator<T> compare) {
    _sortDirection =
        _sortColumn == column && _sortDirection == CoilSortDirection.ascending
        ? CoilSortDirection.descending
        : CoilSortDirection.ascending;
    _sortColumn = column;
    _compare = compare;
    _update();
  }

  /// The selected rows.
  Set<T> get selected => Set.unmodifiable(_selected);
  final Set<T> _selected = {};
  set selected(Set<T> value) {
    _selected
      ..clear()
      ..addAll(value);
    notifyListeners();
  }

  /// How many rows a page holds; 0 for one page.
  int get pageSize => _pageSize;
  int _pageSize;
  set pageSize(int value) {
    _pageSize = value;
    _page = 0;
    _update();
  }

  /// The page shown, from 0.
  int get page => _page;
  int _page = 0;
  set page(int value) {
    final clamped = value.clamp(0, pageCount - 1);
    if (clamped == _page) return;
    _page = clamped;
    _update();
  }

  /// How many pages the matching rows fill; at least 1.
  int get pageCount =>
      _pageSize <= 0 ? 1 : math.max(1, (_matching.length / _pageSize).ceil());

  /// The rows that match [query], sorted.
  List<T> get matching => _matching;
  List<T> _matching = const [];

  /// The rows on [page].
  List<T> get view => _view;
  List<T> _view = const [];

  void _update() {
    final q = _query.trim().toLowerCase();
    final match = matches;
    final rows = [
      for (final row in _rows)
        if (q.isEmpty || match == null || match(row, q)) row,
    ];
    if (_compare case final compare?) {
      rows.sort(
        _sortDirection == CoilSortDirection.ascending
            ? compare
            : (a, b) => compare(b, a),
      );
    }
    _matching = rows;
    _page = _page.clamp(0, pageCount - 1);
    _view = _pageSize <= 0
        ? rows
        : rows.sublist(
            _page * _pageSize,
            math.min(rows.length, (_page + 1) * _pageSize),
          );
    notifyListeners();
  }
}
