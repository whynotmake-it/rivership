import 'package:flutter/widgets.dart';

/// A [SliverChildBuilderDelegate] that estimates the children it hasn't built
/// from a stable average.
///
/// `SliverList`'s default estimate multiplies the average extent of the
/// children currently built by the number not built. With rows of different
/// heights that average changes on nearly every frame, and over thousands of
/// unbuilt rows (all the history above a `TurnScrollView`'s center) that
/// swings the scroll extent by thousands of pixels: the scrollbar thumb
/// jumps backwards and changes size while you scroll. [slotExtent] comes
/// from every item measured so far instead, so it barely moves.
class TurnChildDelegate extends SliverChildBuilderDelegate {
  /// Creates the delegate.
  TurnChildDelegate(
    super.builder, {
    required int super.childCount,
    required this.slotExtent,
    super.findChildIndexCallback,
  });

  /// The estimated extent of one unbuilt child, spacing included.
  final double Function() slotExtent;

  @override
  double? estimateMaxScrollOffset(
    int firstIndex,
    int lastIndex,
    double leadingScrollOffset,
    double trailingScrollOffset,
  ) {
    final count = childCount!;
    if (lastIndex >= count - 1) return trailingScrollOffset;
    return trailingScrollOffset + (count - 1 - lastIndex) * slotExtent();
  }
}

/// Finds the index of the item with identity [id] among [count] items.
///
/// Items rarely move far between builds (an insert or removal shifts a whole
/// tail by one), so this probes next to [hint] before falling back to a scan
/// from the end. That keeps `findChildIndexCallback` cheap for every mounted
/// child after a mid-list change, instead of O(n) each.
int indexOfItemId({
  required int count,
  required Object Function(int index) itemId,
  required Object id,
  int? hint,
}) {
  if (count == 0) return -1;
  if (hint != null) {
    for (var distance = 0; distance <= _hintWindow; distance++) {
      for (final candidate
          in distance == 0 ? [hint] : [hint + distance, hint - distance]) {
        if (candidate >= 0 && candidate < count && itemId(candidate) == id) {
          return candidate;
        }
      }
    }
  }
  for (var i = count - 1; i >= 0; i--) {
    if (itemId(i) == id) return i;
  }
  return -1;
}

const _hintWindow = 8;
