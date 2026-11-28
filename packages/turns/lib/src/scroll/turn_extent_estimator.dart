import 'dart:math' as math;

/// Estimates the scroll extent of runs of items that are not built, from what
/// has been measured so far.
///
/// An item measured before counts for its real height (plus its section
/// header, if it starts a section, and the spacing after it); only items never
/// measured use the mean of the measured ones. Every consumer asks this one
/// object: the sliver delegates (extent of the unbuilt rest of a list), offset
/// estimates for jumps, and the bottom of the list.
///
/// A run of any length is answered in O(log n), and a new measurement is
/// recorded in O(log n), because the measured sums live in Fenwick trees
/// rather than being summed by walking the items on every layout. Only a
/// change of the item set (a prepend, an insert, a removal, a new thread)
/// rebuilds the trees, once, in O(n) at the next query.
class TurnExtentEstimator {
  /// Creates an estimator that falls back to [fallbackItemExtent] until
  /// anything has been measured.
  TurnExtentEstimator({
    this.fallbackItemExtent = 72,
    this.fallbackHeaderExtent = 32,
  });

  /// Item extent assumed before anything is measured.
  double fallbackItemExtent;

  /// Section header extent assumed before any header is measured.
  final double fallbackHeaderExtent;

  var _count = 0;
  var _spacing = 0.0;
  var _headerSpacing = 0.0;
  var _stale = true;

  late _Fenwick _itemSum = _Fenwick(0);
  late _Fenwick _itemCount = _Fenwick(0);
  late _Fenwick _headerSum = _Fenwick(0);
  late _Fenwick _headerCount = _Fenwick(0);

  /// Prefix counts of section starts: `_starts[i]` is how many of the items
  /// before `i` start a section.
  var _starts = <int>[0];
  var _itemMeasured = <double?>[];
  var _headerMeasured = <double?>[];

  /// Marks the item set as changed: the next query rebuilds from the owner.
  void markStale() => _stale = true;

  /// Whether the next query will rebuild.
  bool get isStale => _stale;

  /// Number of items the estimator was last built for.
  int get count => _count;

  /// Rebuilds from the owner's measurements.
  ///
  /// [extentOf] and [headerExtentOf] return what was measured for an item id
  /// (or `null`); [isSectionStart] says which items carry a header.
  void rebuild({
    required int count,
    required Object Function(int index) itemId,
    required double spacing,
    required double? Function(Object id) extentOf,
    double? Function(Object id)? headerExtentOf,
    bool Function(int index)? isSectionStart,
    double headerSpacing = 0,
  }) {
    _count = count;
    _spacing = spacing;
    _headerSpacing = headerSpacing;
    _itemSum = _Fenwick(count);
    _itemCount = _Fenwick(count);
    _headerSum = _Fenwick(count);
    _headerCount = _Fenwick(count);
    _itemMeasured = List<double?>.filled(count, null);
    _headerMeasured = List<double?>.filled(count, null);
    _starts = List<int>.filled(count + 1, 0);
    for (var i = 0; i < count; i++) {
      final id = itemId(i);
      final start = isSectionStart?.call(i) ?? false;
      _starts[i + 1] = _starts[i] + (start ? 1 : 0);
      if (extentOf(id) case final extent?) {
        _itemMeasured[i] = extent;
        _itemSum.add(i, extent);
        _itemCount.add(i, 1);
      }
      final header = start ? headerExtentOf?.call(id) : null;
      if (header != null) {
        _headerMeasured[i] = header;
        _headerSum.add(i, header);
        _headerCount.add(i, 1);
      }
    }
    _stale = false;
  }

  /// Records a measured item extent. Returns whether it changed anything.
  bool setItemExtent(int index, double extent) {
    if (_stale || index < 0 || index >= _count) return false;
    final before = _itemMeasured[index];
    if (before == extent) return false;
    _itemMeasured[index] = extent;
    _itemSum.add(index, extent - (before ?? 0));
    if (before == null) _itemCount.add(index, 1);
    return true;
  }

  /// Records a measured section header extent. Returns whether it changed
  /// anything.
  bool setHeaderExtent(int index, double extent) {
    if (_stale || index < 0 || index >= _count) return false;
    final before = _headerMeasured[index];
    if (before == extent) return false;
    _headerMeasured[index] = extent;
    _headerSum.add(index, extent - (before ?? 0));
    if (before == null) _headerCount.add(index, 1);
    return true;
  }

  /// Mean of the measured item extents.
  double get meanItemExtent {
    final n = _itemCount.total;
    return n == 0 ? fallbackItemExtent : _itemSum.total / n;
  }

  /// Mean of the measured section header extents.
  double get meanHeaderExtent {
    final n = _headerCount.total;
    return n == 0 ? fallbackHeaderExtent : _headerSum.total / n;
  }

  /// The extent of the item at [index]: measured, or the mean.
  double itemExtentAt(int index) =>
      (index >= 0 && index < _count ? _itemMeasured[index] : null) ??
      meanItemExtent;

  /// What the section header above the item at [index] adds (header plus the
  /// gap below it), or `0` when the item starts no section.
  double headerExtraAt(int index) {
    if (index < 0 || index >= _count || _starts[index + 1] == _starts[index]) {
      return 0;
    }
    return (_headerMeasured[index] ?? meanHeaderExtent) + _headerSpacing;
  }

  /// The scroll extent of the items `[from, to)`: each item's header (if it
  /// starts a section), its own extent and the spacing after it.
  double rangeExtent(int from, int to) {
    final start = from.clamp(0, _count);
    final end = to.clamp(start, _count);
    final n = end - start;
    if (n == 0) return 0;
    final measured = _itemCount.range(start, end);
    final extents =
        _itemSum.range(start, end) + (n - measured) * meanItemExtent;
    final starts = _starts[end] - _starts[start];
    var headers = 0.0;
    if (starts > 0) {
      final measuredHeaders = _headerCount.range(start, end);
      headers =
          _headerSum.range(start, end) +
          (starts - measuredHeaders) * meanHeaderExtent +
          starts * _headerSpacing;
    }
    return extents + headers + n * _spacing;
  }
}

/// A Fenwick (binary indexed) tree over doubles: point updates and prefix
/// sums in O(log n).
class _Fenwick {
  _Fenwick(int size) : _tree = List<double>.filled(size + 1, 0);

  final List<double> _tree;
  double total = 0;

  void add(int index, double delta) {
    total += delta;
    for (var i = index + 1; i < _tree.length; i += i & -i) {
      _tree[i] += delta;
    }
  }

  double _prefix(int end) {
    var sum = 0.0;
    for (var i = math.min(end, _tree.length - 1); i > 0; i -= i & -i) {
      sum += _tree[i];
    }
    return sum;
  }

  /// Sum over `[from, to)`.
  double range(int from, int to) => _prefix(to) - _prefix(from);
}
