import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:turns/src/scroll/turn_child_delegate.dart';
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
  int indexOfId(Object id) {
    final count = widget.itemCount;
    for (var i = count - 1; i >= 0; i--) {
      if (widget.itemId(i) == id) return i;
    }
    return -1;
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
    final scope = TurnScrollScope.maybeOf(context);
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
    final mean = TurnScrollScope.maybeOf(context)?.meanItemExtent;
    return SliverList(
      key: _listKey,
      delegate: TurnChildDelegate(
        slotExtent: () => (mean?.call() ?? 72) + spacing,
        (context, index) {
          final id = widget.itemId(index);
          Widget child = TurnScrollItem(
            id: id,
            child: widget.itemBuilder(context, index),
          );
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
