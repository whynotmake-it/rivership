// RenderObjects keep fields behind setters that mark layout dirty.
// ignore_for_file: prefer_initializing_formals

import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Registration handle connecting a `SliverTurnList` to its enclosing
/// [TurnScrollScope] so offscreen `scrollTo` and exact `jumpToBottom` work
/// across multiple sliver lists.
abstract interface class TurnListRegistration {
  /// The underlying sliver multi-box adaptor render object, if attached.
  RenderSliverMultiBoxAdaptor? get renderSliver;

  /// Total number of items in this list.
  int get itemCount;

  /// Stable identity for the item at [index].
  Object itemId(int index);

  /// Spacing between consecutive items in this list.
  double get itemSpacing;

  /// Returns the index of [id] in this list, or `-1` if absent.
  int indexOfId(Object id);

  /// Whether the last item of this list is currently laid out in the sliver.
  bool get reachedEnd;
}

/// Ambient layout clearances and item-registration callbacks provided by
/// `TurnScrollView` and `CustomTurnScrollView` to descendant [SliverTurnStage],
/// `SliverTurnList`, and [TurnScrollItem] widgets.
class TurnScrollScope extends InheritedWidget {
  /// Creates a turn scroll scope.
  const TurnScrollScope({
    required this.topClearance,
    required this.bottomClearance,
    required this.onItemLayout,
    required this.onItemDetach,
    required this.onTurnStageAttach,
    required this.onTurnStageDetach,
    required super.child,
    this.onListAttach,
    this.onListDetach,
    super.key,
  });

  /// Effective top clearance (safe area + top content padding).
  final double topClearance;

  /// Effective bottom clearance (max(safe area, keyboard inset) + bottom
  /// padding).
  final double bottomClearance;

  /// Registers a laid-out item's height and [RenderBox].
  final void Function(Object id, double extent, RenderBox box) onItemLayout;

  /// Unregisters a detached item's [RenderBox].
  final void Function(Object id, RenderBox box) onItemDetach;

  /// Registers an active [RenderSliverTurnStage] with its enclosing view.
  final void Function(RenderSliverTurnStage stage) onTurnStageAttach;

  /// Unregisters a detached [RenderSliverTurnStage].
  final void Function(RenderSliverTurnStage stage) onTurnStageDetach;

  /// Optional callback registering an indexed `SliverTurnList`.
  final void Function(TurnListRegistration list)? onListAttach;

  /// Optional callback unregistering an indexed `SliverTurnList`.
  final void Function(TurnListRegistration list)? onListDetach;

  /// Returns the nearest [TurnScrollScope], if any.
  static TurnScrollScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TurnScrollScope>();

  @override
  bool updateShouldNotify(TurnScrollScope oldWidget) =>
      topClearance != oldWidget.topClearance ||
      bottomClearance != oldWidget.bottomClearance ||
      onItemLayout != oldWidget.onItemLayout ||
      onItemDetach != oldWidget.onItemDetach ||
      onTurnStageAttach != oldWidget.onTurnStageAttach ||
      onTurnStageDetach != oldWidget.onTurnStageDetach ||
      onListAttach != oldWidget.onListAttach ||
      onListDetach != oldWidget.onListDetach;
}

/// Marks an item inside any sliver of a `TurnScrollView` or
/// `CustomTurnScrollView` with a stable [id] so
/// `TurnScrollController.scrollTo`, `pinnedId`, and extent caching work across
/// arbitrary slivers (`SliverList`, `SliverTurnList`, `SliverMainAxisGroup`,
/// [SliverTurnStage], etc.).
class TurnScrollItem extends StatelessWidget {
  /// Creates an identifiable scroll item.
  const TurnScrollItem({
    required this.id,
    required this.child,
    super.key,
  });

  /// Stable identity for this item.
  final Object id;

  /// The item widget.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scope = TurnScrollScope.maybeOf(context);
    if (scope == null) return child;
    return TurnItemExtentObserver(
      itemId: id,
      onLayout: scope.onItemLayout,
      onDetach: scope.onItemDetach,
      child: child,
    );
  }
}

/// A sliver that lays out the active turn's anchor item, the items following
/// it, and an optional trailing sliver (such as a status row) in a single
/// layout pass, while reserving enough trailing scroll extent to pin the anchor
/// item cleanly inside the usable viewport.
///
/// Let `V = viewportMainAxisExtent - topClearance - bottomClearance` and let
/// `H_u` be the anchor item's height (`anchor.geometry.scrollExtent`):
/// - Short anchor (`H_u <= V / 2`): reserves `minExtent = V`, so scrolling to
///   `maxScrollExtent` places the anchor's top at `topClearance`.
/// - Tall anchor (`H_u > V / 2`): reserves `minExtent = H_u + V / 2`, so
///   scrolling to `maxScrollExtent` places the anchor's bottom at
///   `topClearance + V / 2`.
///
/// The reported `scrollExtent` is `max(minExtent, actualContentExtent)`, so
/// `maxScrollExtent` stays completely constant while the reply grows inside
/// the reserved space and grows monotonically once it overflows.
///
/// Inside a `TurnScrollView` or `CustomTurnScrollView`, [topClearance] and
/// [bottomClearance] default to the ambient [TurnScrollScope] values and can be
/// omitted.
class SliverTurnStage extends MultiChildRenderObjectWidget {
  /// Creates a turn stage wrapping [anchorSliver], [afterSliver], and an
  /// optional [tailSliver] painted directly after [afterSliver].
  SliverTurnStage({
    required Widget anchorSliver,
    required Widget afterSliver,
    this.topClearance,
    this.bottomClearance,
    Widget? tailSliver,
    super.key,
  }) : super(children: [anchorSliver, afterSliver, ?tailSliver]);

  /// Viewport top clearance (safe area + content top padding) where a pinned
  /// short anchor item should rest. Defaults to [TurnScrollScope.topClearance].
  final double? topClearance;

  /// Viewport bottom clearance (safe area / keyboard + content bottom padding).
  /// Defaults to [TurnScrollScope.bottomClearance].
  final double? bottomClearance;

  @override
  RenderSliverTurnStage createRenderObject(BuildContext context) {
    final scope = TurnScrollScope.maybeOf(context);
    return RenderSliverTurnStage(
      topClearance: topClearance ?? scope?.topClearance ?? 0,
      bottomClearance: bottomClearance ?? scope?.bottomClearance ?? 0,
      onAttach: scope?.onTurnStageAttach,
      onDetach: scope?.onTurnStageDetach,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderSliverTurnStage renderObject,
  ) {
    final scope = TurnScrollScope.maybeOf(context);
    renderObject
      ..topClearance = topClearance ?? scope?.topClearance ?? 0
      ..bottomClearance = bottomClearance ?? scope?.bottomClearance ?? 0
      ..onAttach = scope?.onTurnStageAttach
      ..onDetach = scope?.onTurnStageDetach;
  }
}

class _TurnSliverParentData extends SliverPhysicalParentData
    with ContainerParentDataMixin<RenderSliver> {
  double layoutOffset = 0;
}

/// Render object for [SliverTurnStage].
class RenderSliverTurnStage extends RenderSliver
    with
        ContainerRenderObjectMixin<RenderSliver, _TurnSliverParentData>,
        RenderSliverHelpers {
  /// Creates the render sliver.
  RenderSliverTurnStage({
    required double topClearance,
    required double bottomClearance,
    this.onAttach,
    this.onDetach,
  }) : _topClearance = topClearance,
       _bottomClearance = bottomClearance;

  /// Called when this stage attaches to the pipeline.
  void Function(RenderSliverTurnStage stage)? onAttach;

  /// Called when this stage detaches from the pipeline.
  void Function(RenderSliverTurnStage stage)? onDetach;

  double _topClearance;

  /// Viewport top clearance.
  double get topClearance => _topClearance;

  set topClearance(double value) {
    if (_topClearance == value) return;
    _topClearance = value;
    markNeedsLayout();
  }

  double _bottomClearance;

  /// Viewport bottom clearance.
  double get bottomClearance => _bottomClearance;

  set bottomClearance(double value) {
    if (_bottomClearance == value) return;
    _bottomClearance = value;
    markNeedsLayout();
  }

  double _actualContentExtent = 0;

  /// Last computed actual content height (anchor + after + tail) before
  /// applying [minExtent].
  double get actualContentExtent => _actualContentExtent;

  double _minExtent = 0;

  /// Last computed reserved minimum extent for this turn.
  double get minExtent => _minExtent;

  /// Current trailing empty space reserved below the turn's content.
  double get reservedTrailingSpace =>
      math.max(0, _minExtent - _actualContentExtent);

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    onAttach?.call(this);
  }

  @override
  void detach() {
    onDetach?.call(this);
    super.detach();
  }

  @override
  void setupParentData(RenderObject child) {
    if (child.parentData is! _TurnSliverParentData) {
      child.parentData = _TurnSliverParentData();
    }
  }

  @override
  void performLayout() {
    final constraints = this.constraints;
    assert(
      constraints.growthDirection == GrowthDirection.forward,
      'SliverTurnStage only supports forward growth direction.',
    );
    final usable = math.max<double>(
      0,
      constraints.viewportMainAxisExtent - _topClearance - _bottomClearance,
    );

    var offset = 0.0;
    var anchorExtent = 0.0;
    var maxPaintExtent = 0.0;
    var childHasVisualOverflow = false;
    var childIndex = 0;

    final cacheStartInParent =
        constraints.scrollOffset + constraints.cacheOrigin;
    final cacheEndInParent =
        cacheStartInParent + constraints.remainingCacheExtent;

    var child = firstChild;
    while (child != null) {
      final beforeOffsetPaintExtent = calculatePaintOffset(
        constraints,
        from: 0,
        to: offset,
      );
      final childScrollOffset = math.max<double>(
        0,
        constraints.scrollOffset - offset,
      );
      final childOverlap = math.max<double>(
        0,
        constraints.overlap - beforeOffsetPaintExtent,
      );
      final childRemainingPaintExtent = math.max<double>(
        0,
        constraints.remainingPaintExtent - beforeOffsetPaintExtent,
      );

      final childCacheStart = math.max<double>(0, cacheStartInParent - offset);
      final childCacheOrigin = math.min<double>(
        0,
        childCacheStart - childScrollOffset,
      );
      final childCacheEnd = math.max(
        childCacheStart,
        cacheEndInParent - offset,
      );
      final childRemainingCacheExtent = math.max(
        childRemainingPaintExtent,
        childCacheEnd - childCacheStart,
      );

      child.layout(
        constraints.copyWith(
          scrollOffset: childScrollOffset,
          overlap: childOverlap,
          precedingScrollExtent: constraints.precedingScrollExtent + offset,
          remainingPaintExtent: childRemainingPaintExtent,
          cacheOrigin: childCacheOrigin,
          remainingCacheExtent: childRemainingCacheExtent,
        ),
        parentUsesSize: true,
      );

      final childGeometry = child.geometry!;
      if (childGeometry.scrollOffsetCorrection != null) {
        geometry = SliverGeometry(
          scrollOffsetCorrection: childGeometry.scrollOffsetCorrection,
        );
        return;
      }

      final parentData = child.parentData! as _TurnSliverParentData
        ..layoutOffset = offset
        ..paintOffset = switch (constraints.axis) {
          Axis.vertical => Offset(0, beforeOffsetPaintExtent),
          Axis.horizontal => Offset(beforeOffsetPaintExtent, 0),
        };

      if (childIndex == 0) {
        anchorExtent = childGeometry.scrollExtent;
      }
      offset += childGeometry.scrollExtent;
      maxPaintExtent += childGeometry.maxPaintExtent;
      childHasVisualOverflow =
          childHasVisualOverflow || childGeometry.hasVisualOverflow;

      child = parentData.nextSibling;
      childIndex++;
    }

    _actualContentExtent = offset;
    _minExtent =
        anchorExtent <= usable * 0.5 ? usable : anchorExtent + usable * 0.5;
    final totalScrollExtent = math.max(_minExtent, _actualContentExtent);

    final paintExtent = math.min(
      calculatePaintOffset(constraints, from: 0, to: totalScrollExtent),
      constraints.remainingPaintExtent,
    );
    final rawCacheExtent = calculateCacheOffset(
      constraints,
      from: 0,
      to: totalScrollExtent,
    );
    final cacheExtent = math.max(
      paintExtent,
      math.min(rawCacheExtent, constraints.remainingCacheExtent),
    );
    final totalMaxPaintExtent = math.max(totalScrollExtent, maxPaintExtent);

    geometry = SliverGeometry(
      scrollExtent: totalScrollExtent,
      paintExtent: paintExtent,
      maxPaintExtent: totalMaxPaintExtent,
      cacheExtent: cacheExtent,
      hasVisualOverflow:
          childHasVisualOverflow ||
          totalScrollExtent > constraints.remainingPaintExtent ||
          constraints.scrollOffset > 0,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    var child = firstChild;
    while (child != null) {
      final parentData = child.parentData! as _TurnSliverParentData;
      if (child.geometry!.visible) {
        context.paintChild(child, offset + parentData.paintOffset);
      }
      child = parentData.nextSibling;
    }
  }

  @override
  bool hitTestChildren(
    SliverHitTestResult result, {
    required double mainAxisPosition,
    required double crossAxisPosition,
  }) {
    var child = lastChild;
    while (child != null) {
      final parentData = child.parentData! as _TurnSliverParentData;
      if (child.geometry!.hitTestExtent > 0) {
        final childPos = childMainAxisPosition(child);
        final isHit = result.addWithAxisOffset(
          paintOffset: parentData.paintOffset,
          mainAxisOffset: childPos,
          crossAxisOffset: 0,
          mainAxisPosition: mainAxisPosition,
          crossAxisPosition: crossAxisPosition,
          hitTest: child.hitTest,
        );
        if (isHit) return true;
      }
      child = parentData.previousSibling;
    }
    return false;
  }

  @override
  double childMainAxisPosition(RenderSliver child) {
    final parentData = child.parentData! as _TurnSliverParentData;
    return switch (constraints.axis) {
      Axis.vertical => parentData.paintOffset.dy,
      Axis.horizontal => parentData.paintOffset.dx,
    };
  }

  @override
  double childScrollOffset(RenderSliver child) =>
      (child.parentData! as _TurnSliverParentData).layoutOffset;

  @override
  void applyPaintTransform(RenderSliver child, Matrix4 transform) {
    (child.parentData! as _TurnSliverParentData).applyPaintTransform(transform);
  }
}

/// Reports a list item's laid-out main-axis extent and mounted [RenderBox]
/// directly during layout, with zero `GlobalKey`s or post-frame callbacks.
class TurnItemExtentObserver extends SingleChildRenderObjectWidget {
  /// Creates an observer for item [itemId].
  const TurnItemExtentObserver({
    required this.itemId,
    required this.onLayout,
    required this.onDetach,
    required super.child,
    super.key,
  });

  /// Stable identity of the observed item.
  final Object itemId;

  /// Called during layout with the item's height and [RenderBox].
  final void Function(Object id, double extent, RenderBox box) onLayout;

  /// Called when the item's [RenderBox] detaches from the render tree.
  final void Function(Object id, RenderBox box) onDetach;

  @override
  RenderTurnItemExtentObserver createRenderObject(BuildContext context) =>
      RenderTurnItemExtentObserver(
        itemId: itemId,
        onLayout: onLayout,
        onDetach: onDetach,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderTurnItemExtentObserver renderObject,
  ) {
    renderObject
      ..itemId = itemId
      ..onLayout = onLayout
      ..onDetach = onDetach;
  }
}

/// Render proxy box for [TurnItemExtentObserver].
class RenderTurnItemExtentObserver extends RenderProxyBox {
  /// Creates the proxy box.
  RenderTurnItemExtentObserver({
    required Object itemId,
    required this.onLayout,
    required this.onDetach,
  }) : _itemId = itemId;

  Object _itemId;

  /// Stable identity of the observed item.
  Object get itemId => _itemId;

  set itemId(Object value) {
    if (_itemId == value) return;
    if (attached) onDetach(_itemId, this);
    _itemId = value;
    markNeedsLayout();
  }

  /// Called during layout with the item's height and [RenderBox].
  void Function(Object id, double extent, RenderBox box) onLayout;

  /// Called when this box detaches from the render tree.
  void Function(Object id, RenderBox box) onDetach;

  @override
  void performLayout() {
    super.performLayout();
    onLayout(_itemId, size.height, this);
  }

  @override
  void detach() {
    onDetach(_itemId, this);
    super.detach();
  }
}
