// RenderObjects keep fields behind setters that mark layout dirty.
// ignore_for_file: prefer_initializing_formals

import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

/// Registration handle connecting a `SliverTurnList` to its enclosing
/// [TurnScrollScope] so offscreen `scrollTo` and exact `scrollToBottom` work
/// across multiple sliver lists.
@internal
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

  /// The estimated scroll extent of the items `[from, to)` (measured heights
  /// where known, the mean elsewhere, spacing included).
  double estimateExtent(int from, int to);
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
    this.meanItemExtent,
    this.extentOf,
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

  /// The mean extent of every item measured so far, for estimating items
  /// not yet built (stable while scrolling, unlike the built window's).
  final double Function()? meanItemExtent;

  /// The extent measured for an item id, or `null` if it was never measured.
  final double? Function(Object id)? extentOf;

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
      onListDetach != oldWidget.onListDetach ||
      meanItemExtent != oldWidget.meanItemExtent ||
      extentOf != oldWidget.extentOf;
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

/// Configures how [SliverTurnStage] positions a pinned anchor item within the
/// usable viewport and how much trailing room it reserves below the anchor.
///
/// Let `V` be the usable viewport height
/// (`viewportMainAxisExtent - topClearance - bottomClearance`) and `H_u` be the
/// anchor item's height:
/// - `base = V * (1.0 - alignment)` places the anchor's top edge at
///   `topClearance + V * alignment`.
/// - When [minTrailingFraction] is non-null, the reserved stage extent is
///   `max(base, H_u + V * minTrailingFraction)`, so a tall anchor scrolls
///   upward as needed to leave at least `V * minTrailingFraction` clear below
///   its bottom edge for the reply.
/// - When [minTrailingFraction] is `null`, the reserved extent is always
///   `base` so the anchor rests at [alignment] regardless of height.
@immutable
final class TurnAnchorConfig {
  /// Creates a turn anchor configuration.
  const TurnAnchorConfig({
    this.alignment = 0,
    this.minTrailingFraction,
  }) : assert(
         alignment >= 0.0 && alignment <= 1.0,
         'alignment must be in [0.0, 1.0]',
       ),
       assert(
         minTrailingFraction == null ||
             (minTrailingFraction >= 0.0 && minTrailingFraction <= 1.0),
         'minTrailingFraction must be null or in [0.0, 1.0]',
       );

  /// Standard chat pinning: aligns short anchors to top clearance (`0.0`) and
  /// scrolls tall anchors upward so at least 50% of the usable viewport
  /// remains clear below the anchor for the reply.
  static const standard = TurnAnchorConfig(minTrailingFraction: 0.5);

  /// Pins every anchor flush to top clearance (`0.0`) regardless of its
  /// height, with no minimum trailing floor.
  static const top = TurnAnchorConfig();

  static const _keep = Object();

  /// Target resting alignment of the anchor's top edge inside the usable
  /// viewport (`0.0` = top clearance, `0.5` = middle, `1.0` = bottom).
  final double alignment;

  /// Optional minimum fraction of the usable viewport height kept clear below
  /// the anchor's bottom edge (`[0.0, 1.0]`).
  ///
  /// When `null`, no trailing floor is enforced and the anchor always rests at
  /// [alignment].
  final double? minTrailingFraction;

  /// Returns a copy of this configuration with the given fields replaced.
  ///
  /// Pass `minTrailingFraction: null` to explicitly clear the trailing floor.
  TurnAnchorConfig copyWith({
    double? alignment,
    Object? minTrailingFraction = _keep,
  }) => TurnAnchorConfig(
    alignment: alignment ?? this.alignment,
    minTrailingFraction: identical(minTrailingFraction, _keep)
        ? this.minTrailingFraction
        : minTrailingFraction as double?,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TurnAnchorConfig &&
          other.alignment == alignment &&
          other.minTrailingFraction == minTrailingFraction;

  @override
  int get hashCode => Object.hash(alignment, minTrailingFraction);

  @override
  String toString() =>
      'TurnAnchorConfig(alignment: $alignment, '
      'minTrailingFraction: $minTrailingFraction)';
}

/// A sliver that lays out the active turn's anchor item, the items following
/// it, and an optional trailing sliver (such as a status row) in a single
/// layout pass, while reserving enough trailing scroll extent to pin the anchor
/// item cleanly inside the usable viewport.
///
/// Let `V = viewportMainAxisExtent - topClearance - bottomClearance` and let
/// `H_u` be the anchor item's height (`anchor.geometry.scrollExtent`). The
/// reserved minimum extent is computed by
/// [RenderSliverTurnStage.computeMinExtent] from [anchorConfig]:
/// - `base = V * (1.0 - anchorConfig.alignment)`
/// - If `anchorConfig.minTrailingFraction` is `null`: `minExtent = base`.
/// - Otherwise:
///   `minExtent = max(base, H_u + V * anchorConfig.minTrailingFraction)`.
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
    this.anchorConfig = TurnAnchorConfig.standard,
    Widget? tailSliver,
    super.key,
  }) : super(children: [anchorSliver, afterSliver, ?tailSliver]);

  /// Viewport top clearance (safe area + content top padding) where a pinned
  /// anchor at `alignment: 0.0` rests. Defaults to
  /// [TurnScrollScope.topClearance].
  final double? topClearance;

  /// Viewport bottom clearance (safe area / keyboard + content bottom padding).
  /// Defaults to [TurnScrollScope.bottomClearance].
  final double? bottomClearance;

  /// Controls where the pinned anchor rests within the usable viewport and how
  /// much trailing space is preserved below tall anchors.
  ///
  /// Defaults to [TurnAnchorConfig.standard].
  final TurnAnchorConfig anchorConfig;

  @override
  RenderSliverTurnStage createRenderObject(BuildContext context) {
    final scope = TurnScrollScope.maybeOf(context);
    return RenderSliverTurnStage(
      topClearance: topClearance ?? scope?.topClearance ?? 0,
      bottomClearance: bottomClearance ?? scope?.bottomClearance ?? 0,
      anchorConfig: anchorConfig,
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
      ..anchorConfig = anchorConfig
      ..onAttach = scope?.onTurnStageAttach
      ..onDetach = scope?.onTurnStageDetach;
  }
}

/// Resolves the mounted, laid-out box of the item with the given id and its
/// measured main-axis extent, or `null` when it is not mounted.
///
/// The extent is passed along because a box's size may not be read from
/// another object's layout.
typedef TurnAnchorBoxResolver =
    ({RenderBox box, double extent})? Function(Object id);

/// Lays out the whole item list of a `TurnScrollView` (and its tail sliver) and
/// reserves blank scroll extent after it, so the pinned turn can rest at its
/// anchor position without anything moving.
///
/// Unlike [SliverTurnStage], the anchor is not a child: it is one of the items
/// of the list inside [children], found through [anchorBoxOf]. Pinning or
/// unpinning therefore never changes which sliver an item lives in, and no
/// item is remounted.
///
/// The reserve is `max(0, minExtent - (contentEnd - anchorTop))`, where
/// `minExtent` comes from [RenderSliverTurnStage.computeMinExtent]. It is
/// computed in the same layout pass as the list. This is one sliver around
/// the list, not a sibling after it, because a sibling is skipped when its own
/// constraints are unchanged, even though the anchor moved or resized (for
/// example one item growing while another shrinks). Layout dirtiness of the
/// list propagates to its parent, so the reserve is always recomputed when
/// the anchor can have changed.
@internal
class SliverTurnReserve extends MultiChildRenderObjectWidget {
  /// Creates a reserve around [children] (the item list and an optional tail).
  const SliverTurnReserve({
    required super.children,
    required this.anchorBoxOf,
    this.anchorId,
    this.anchorConfig = TurnAnchorConfig.standard,
    super.key,
  });

  /// Identity of the pinned anchor item, or `null` when nothing is pinned
  /// (nothing is reserved).
  final Object? anchorId;

  /// Finds the mounted box of the anchor item.
  final TurnAnchorBoxResolver anchorBoxOf;

  /// Where the anchor rests and how much room is kept below it.
  final TurnAnchorConfig anchorConfig;

  @override
  RenderSliverTurnStage createRenderObject(BuildContext context) {
    final scope = TurnScrollScope.maybeOf(context);
    return RenderSliverTurnStage(
      topClearance: scope?.topClearance ?? 0,
      bottomClearance: scope?.bottomClearance ?? 0,
      anchorConfig: anchorConfig,
      anchorBoxOf: anchorBoxOf,
      anchorId: anchorId,
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
      ..topClearance = scope?.topClearance ?? 0
      ..bottomClearance = scope?.bottomClearance ?? 0
      ..anchorConfig = anchorConfig
      ..anchorBoxOf = anchorBoxOf
      ..anchorId = anchorId
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
    TurnAnchorConfig anchorConfig = TurnAnchorConfig.standard,
    this.onAttach,
    this.onDetach,
    this.anchorBoxOf,
    Object? anchorId,
  }) : _topClearance = topClearance,
       _bottomClearance = bottomClearance,
       _anchorConfig = anchorConfig,
       _anchorId = anchorId;

  /// Computes the minimum reserved scroll extent for a turn stage given
  /// [usableExtent], [anchorExtent], and [anchorConfig].
  static double computeMinExtent({
    required double usableExtent,
    required double anchorExtent,
    TurnAnchorConfig anchorConfig = TurnAnchorConfig.standard,
  }) {
    final base = usableExtent * (1.0 - anchorConfig.alignment);
    final minTrailing = anchorConfig.minTrailingFraction;
    return minTrailing == null
        ? base
        : math.max(base, anchorExtent + usableExtent * minTrailing);
  }

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

  TurnAnchorConfig _anchorConfig;

  /// Anchor positioning and trailing-room configuration for this turn stage.
  TurnAnchorConfig get anchorConfig => _anchorConfig;

  set anchorConfig(TurnAnchorConfig value) {
    if (_anchorConfig == value) return;
    _anchorConfig = value;
    markNeedsLayout();
  }

  /// Finds the mounted box of the pinned item when this sliver wraps the item
  /// list ([SliverTurnReserve]). When `null`, the first child is the anchor
  /// ([SliverTurnStage]).
  @internal
  TurnAnchorBoxResolver? anchorBoxOf;

  Object? _anchorId;

  /// Identity of the anchor item when this sliver wraps the item list.
  @internal
  Object? get anchorId => _anchorId;

  set anchorId(Object? value) {
    if (_anchorId == value) return;
    _anchorId = value;
    _reserved = 0;
    _anchorOffset = 0;
    _actualContentExtent = 0;
    _minExtent = 0;
    markNeedsLayout();
  }

  double _actualContentExtent = 0;

  /// Last computed height of the turn: from the anchor's top to the end of
  /// the content, before applying [minExtent].
  double get actualContentExtent => _actualContentExtent;

  double _minExtent = 0;

  /// Last computed reserved minimum extent for this turn.
  double get minExtent => _minExtent;

  double _anchorOffset = 0;

  /// Where the anchor's top sits from the leading edge of this sliver, in
  /// scroll offset terms: `0` for a [SliverTurnStage], whose first child is
  /// the anchor.
  double get anchorOffset => _anchorOffset;

  var _anchorMeasured = false;

  /// Whether the anchor was mounted and measured in the last layout, so
  /// [anchorOffset] is current.
  @internal
  bool get anchorMeasured => _anchorMeasured;

  double _reserved = 0;

  /// Current trailing empty space reserved below the turn's content.
  ///
  /// While the anchor is not mounted (scrolled far out of the cache) the last
  /// value is kept.
  double get reservedTrailingSpace => _reserved;

  /// Measures the anchor item's top (from this sliver's leading edge) and
  /// height, or `null` when it is not mounted and laid out.
  ///
  /// The top is the top of the item's own box, below any inline section
  /// header that shares its list entry. Works in the same layout pass as the
  /// list: the list is laid out before this is called.
  ({double top, double height})? _measureAnchor() {
    final id = _anchorId;
    final resolve = anchorBoxOf;
    if (id == null || resolve == null) return null;
    final anchor = resolve(id);
    if (anchor == null) return null;
    final box = anchor.box;
    if (!box.attached || !box.hasSize) return null;
    RenderObject entry = box;
    while (entry.parent != null && entry.parent is! RenderSliver) {
      entry = entry.parent!;
    }
    final list = entry.parent;
    final parentData = entry.parentData;
    if (list is! RenderSliverMultiBoxAdaptor ||
        parentData is! SliverMultiBoxAdaptorParentData ||
        parentData.keptAlive ||
        parentData.layoutOffset == null ||
        entry is! RenderBox ||
        !_isDescendantOfThis(list)) {
      return null;
    }
    final inEntry = MatrixUtils.transformPoint(
      box.getTransformTo(entry),
      Offset.zero,
    );
    final within = constraints.axis == Axis.vertical ? inEntry.dy : inEntry.dx;
    final top =
        list.constraints.precedingScrollExtent +
        parentData.layoutOffset! +
        within -
        constraints.precedingScrollExtent;
    return (top: top, height: anchor.extent);
  }

  bool _isDescendantOfThis(RenderObject node) {
    RenderObject? current = node;
    while (current != null) {
      if (identical(current, this)) return true;
      current = current.parent;
    }
    return false;
  }

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

    _anchorMeasured = false;
    if (anchorBoxOf == null) {
      // The first child is the anchor and starts this sliver.
      _anchorOffset = 0;
      _actualContentExtent = offset;
      _minExtent = computeMinExtent(
        usableExtent: usable,
        anchorExtent: anchorExtent,
        anchorConfig: _anchorConfig,
      );
      _reserved = math.max(0, _minExtent - _actualContentExtent);
    } else if (_anchorId == null) {
      _anchorOffset = 0;
      _actualContentExtent = offset;
      _minExtent = 0;
      _reserved = 0;
    } else if (_measureAnchor() case final anchor?) {
      _anchorMeasured = true;
      _anchorOffset = anchor.top;
      _actualContentExtent = offset - anchor.top;
      _minExtent = computeMinExtent(
        usableExtent: usable,
        anchorExtent: anchor.height,
        anchorConfig: _anchorConfig,
      );
      _reserved = math.max(0, _minExtent - _actualContentExtent);
    }
    // Otherwise the anchor is not mounted: the last reserve stays.
    final totalScrollExtent = offset + _reserved;

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
@internal
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
@internal
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
