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
