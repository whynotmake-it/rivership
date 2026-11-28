import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:turns/src/scroll/turn_child_delegate.dart';
import 'package:turns/src/scroll/turn_extent_estimator.dart';
import 'package:turns/src/scroll/turn_sliver.dart';

/// Drop-in indexed sliver list for `CustomTurnScrollView` that automatically
/// wraps each item in [TurnScrollItem] and registers with [TurnScrollScope].
///
/// Registering each list's [RenderSliver], [itemCount], [itemId], and
/// [itemSpacing] allows `CustomTurnScrollView` to support offscreen
/// `controller.scrollTo(anyId)` across multiple [SliverTurnList]s separated by
/// `SliverAppBar`, `SliverMainAxisGroup`, or `SliverPersistentHeader`, as well
/// as exact `scrollToBottom()` verification.
class SliverTurnList extends StatefulWidget {
  /// Creates an indexed turn sliver list.
  const SliverTurnList({
    required this.itemCount,
    required this.itemId,
    required this.itemBuilder,
    this.itemSpacing = 0,
    super.key,
  }) : assert(itemCount >= 0, 'itemCount must be non-negative'),
       assert(itemSpacing >= 0, 'itemSpacing must be non-negative');

  /// Total number of items in this sliver list.
  final int itemCount;

  /// Stable, cheap identity for the item at `index`.
  final Object Function(int index) itemId;

  /// Builds the item widget at `index`.
  final IndexedWidgetBuilder itemBuilder;

  /// Vertical spacing inserted between consecutive items.
  final double itemSpacing;

  @override
  State<SliverTurnList> createState() => _SliverTurnListState();
}

class _SliverTurnListState extends State<SliverTurnList>
    implements TurnListRegistration {
  final _listKey = GlobalKey(debugLabel: 'SliverTurnList');
  final _indexHints = <Object, int>{};
  final _estimator = TurnExtentEstimator();
  TurnScrollScope? _scope;
  ({int count, Object? first, Object? last, double spacing})? _signature;
  void Function(TurnListRegistration list)? _detachCallback;

  @override
  RenderSliverMultiBoxAdaptor? get renderSliver {
    final obj = _listKey.currentContext?.findRenderObject();
    return obj is RenderSliverMultiBoxAdaptor ? obj : null;
  }

  @override
  int get itemCount => widget.itemCount;

  @override
  Object itemId(int index) => widget.itemId(index);

  @override
  double get itemSpacing => widget.itemSpacing;

  @override
  int indexOfId(Object id) => indexOfItemId(
    count: widget.itemCount,
    itemId: widget.itemId,
    id: id,
    hint: _indexHints[id],
  );

  @override
  double estimateExtent(int from, int to) {
    final estimator = _estimator;
    if (estimator.isStale) {
      final extentOf = _scope?.extentOf;
      estimator.rebuild(
        count: widget.itemCount,
        itemId: widget.itemId,
        spacing: widget.itemSpacing,
        extentOf: (id) => extentOf?.call(id),
      );
    }
    // Until this list has measured anything, borrow the view's mean.
    estimator.fallbackItemExtent = _scope?.meanItemExtent?.call() ?? 72;
    return estimator.rangeExtent(from, to);
  }

  void _recordExtent(Object id, double extent) {
    if (_estimator.isStale) return;
    final index = _indexHints[id];
    if (index == null ||
        index >= widget.itemCount ||
        widget.itemId(index) != id) {
      _estimator.markStale();
      return;
    }
    _estimator.setItemExtent(index, extent);
  }

  void _syncSignature() {
    final count = widget.itemCount;
    final next = (
      count: count,
      first: count == 0 ? null : widget.itemId(0),
      last: count == 0 ? null : widget.itemId(count - 1),
      spacing: widget.itemSpacing,
    );
    if (_signature != next) {
      _signature = next;
      _estimator.markStale();
    }
  }

  @override
  void didUpdateWidget(SliverTurnList oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSignature();
  }

  @override
  bool get reachedEnd {
    final count = widget.itemCount;
    if (count <= 0) return true;
    final sliver = renderSliver;
    if (sliver == null || !sliver.attached) return false;
    final last = sliver.lastChild;
    if (last == null) return false;
    return sliver.indexOf(last) == count - 1;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = _scope = TurnScrollScope.maybeOf(context);
    _syncSignature();
    final nextDetach = scope?.onListDetach;
    if (_detachCallback != nextDetach) {
      _detachCallback?.call(this);
      _detachCallback = nextDetach;
      scope?.onListAttach?.call(this);
    }
  }

  @override
  void dispose() {
    _detachCallback?.call(this);
    _detachCallback = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = widget.itemSpacing;
    final count = widget.itemCount;
    final scope = TurnScrollScope.maybeOf(context);
    return SliverList(
      key: _listKey,
      delegate: TurnChildDelegate(
        unbuiltExtent: estimateExtent,
        findChildIndexCallback: (key) {
          if (key is! ValueKey<Object>) return null;
          final index = indexOfId(key.value);
          return index < 0 ? null : index;
        },
        (context, index) {
          final id = widget.itemId(index);
          _indexHints[id] = index;
          var child = widget.itemBuilder(context, index);
          if (scope != null) {
            // Observes the item like a TurnScrollItem, and also records the
            // extent for this list's own estimate.
            child = TurnItemExtentObserver(
              itemId: id,
              onLayout: (id, extent, box) {
                scope.onItemLayout(id, extent, box);
                _recordExtent(id, extent);
              },
              onDetach: scope.onItemDetach,
              child: child,
            );
          }
          if (spacing > 0 && index < count - 1) {
            child = Padding(
              padding: EdgeInsets.only(bottom: spacing),
              child: child,
            );
          }
          return KeyedSubtree(key: ValueKey(id), child: child);
        },
        childCount: count,
      ),
    );
  }
}
