import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:turns/src/scroll/turn_scroll_controller.dart';
import 'package:turns/src/scroll/turn_scroll_engine.dart';
import 'package:turns/src/scroll/turn_sliver.dart';

/// A sliver-native turn scroll view accepting arbitrary Flutter slivers
/// (`SliverAppBar`, `SliverMainAxisGroup`, `SliverPersistentHeader`,
/// `SliverTurnList`, [SliverTurnStage], etc.).
///
/// Shares the same Motor-driven scroll engine ([TurnScrollController],
/// [TurnScrollPosition], [TurnScrollScope], [TurnScrollItem], and
/// [SliverTurnStage]) as `TurnScrollView`.
///
/// Use `SliverTurnList` inside [slivers] to enable offscreen
/// [TurnScrollController.scrollTo] across multiple sections and exact
/// [TurnScrollController.jumpToBottom] convergence.
class CustomTurnScrollView extends StatefulWidget {
  /// Creates a sliver-native turn scroll view.
  const CustomTurnScrollView({
    required this.slivers,
    super.key,
    this.center,
    this.pinnedId,
    this.controller,
    this.padding,
    this.applyTopPadding = true,
    this.applyBottomPadding = true,
    this.initialAtBottom = true,
    this.jumpThreshold = 160,
    this.pinMotion,
    this.physics,
    this.scrollCacheExtent,
  });

  /// Slivers placed inside the viewport.
  final List<Widget> slivers;

  /// Optional `Viewport.center` key.
  final Key? center;

  /// Identity of the active turn's anchor item, or `null` when no turn is
  /// pinned.
  final Object? pinnedId;

  /// Optional controller exposing [TurnScrollController.jumpToBottom],
  /// [TurnScrollController.scrollTo], and
  /// [TurnScrollController.isAwayFromBottom].
  final TurnScrollController? controller;

  /// Content padding added on top of `MediaQuery.paddingOf(context)` and
  /// `MediaQuery.viewInsetsOf(context).bottom`.
  final EdgeInsetsGeometry? padding;

  /// Whether to insert an automatic top clearance sliver
  /// (`safe.top + padding.top`). Set `false` when placing a
  /// `SliverAppBar(pinned: true)` as the first sliver.
  final bool applyTopPadding;

  /// Whether to insert an automatic bottom clearance sliver
  /// (`max(safe.bottom, viewInsets.bottom) + padding.bottom`).
  final bool applyBottomPadding;

  /// Whether a fresh scroll view opens scrolled to the bottom (when [pinnedId]
  /// is `null`).
  final bool initialAtBottom;

  /// Distance above the bottom at which [TurnScrollController.isAwayFromBottom]
  /// becomes `true`.
  final double jumpThreshold;

  /// Motor spring used for pin animations, `jumpToBottom`, and `scrollTo`.
  /// Under `MediaQuery.disableAnimationsOf(context)`, all transitions jump
  /// instantaneously.
  final Motion? pinMotion;

  /// Optional custom scroll physics.
  final ScrollPhysics? physics;

  /// Optional viewport cache extent.
  final ScrollCacheExtent? scrollCacheExtent;

  @override
  State<CustomTurnScrollView> createState() => CustomTurnScrollViewState();
}

/// State of [CustomTurnScrollView].
class CustomTurnScrollViewState extends State<CustomTurnScrollView>
    with
        FixedTickerProviderStateMixin<CustomTurnScrollView>,
        TurnScrollEngineMixin<CustomTurnScrollView> {
  static const _maxInitialPasses = 12;
  static const _maxConvergencePasses = 16;

  final _registeredLists = <TurnListRegistration>[];

  @override
  TurnScrollController? get widgetController => widget.controller;

  @override
  Object? get widgetPinnedId => widget.pinnedId;

  @override
  double get widgetJumpThreshold => widget.jumpThreshold;

  @override
  Motion? get widgetPinMotion => widget.pinMotion;

  @override
  EdgeInsetsGeometry? get widgetPadding => widget.padding;

  @override
  void initState() {
    super.initState();
    needsInitialBottomJump = widget.initialAtBottom && widget.pinnedId == null;
    initialBottomPasses = 0;
    initEngine();
  }

  @override
  void didUpdateWidget(CustomTurnScrollView oldWidget) {
    super.didUpdateWidget(oldWidget);
    updateEngineController(oldWidget.controller);
    updateEnginePinnedId(oldWidget.pinnedId);
  }

  @override
  void dispose() {
    _registeredLists.clear();
    disposeEngine();
    super.dispose();
  }

  void _onListAttach(TurnListRegistration list) {
    if (!_registeredLists.contains(list)) {
      _registeredLists.add(list);
    }
  }

  void _onListDetach(TurnListRegistration list) {
    _registeredLists.remove(list);
  }

  bool _hasExactBottomExtent() {
    final turnStage = activeTurnStage;
    if (turnStage != null &&
        turnStage.attached &&
        (turnStage.geometry?.paintExtent ?? 0) <= 0) {
      return false;
    }

    final pos = turnPosition;
    if (pos == null || !pos.hasContentDimensions || !pos.hasViewportDimension) {
      return false;
    }

    // Verify all non-empty registered SliverTurnLists have been laid out, and
    // that the bottom-most non-empty list has reached its last item.
    TurnListRegistration? lastNonEmpty;
    var maxPreceding = double.negativeInfinity;
    for (final list in _registeredLists) {
      if (list.itemCount <= 0) continue;
      final sliver = list.renderSliver;
      if (sliver == null || !sliver.attached) return false;
      final scrollExtent = sliver.geometry?.scrollExtent ?? 0;
      if (scrollExtent <= 0) return false;
      final preceding = sliver.constraints.precedingScrollExtent;
      if (preceding >= maxPreceding) {
        maxPreceding = preceding;
        lastNonEmpty = list;
      }
    }

    if (lastNonEmpty != null && turnStage == null) {
      if (!lastNonEmpty.reachedEnd) return false;
      final lastId = lastNonEmpty.itemId(lastNonEmpty.itemCount - 1);
      final lastBox = mountedBoxes[lastId];
      if (lastBox == null ||
          !lastBox.attached ||
          !lastBox.hasSize ||
          isKeptAliveOffscreen(lastBox)) {
        return false;
      }
    }

    return (pos.maxScrollExtent - pos.pixels) <= pos.viewportDimension;
  }

  double? _estimatedOffsetForRegisteredItem(
    Object itemId, {
    required double alignment,
    required double viewportDimension,
  }) {
    TurnListRegistration? targetList;
    var targetIndex = -1;
    for (final list in _registeredLists) {
      final idx = list.indexOfId(itemId);
      if (idx >= 0) {
        targetList = list;
        targetIndex = idx;
        break;
      }
    }
    if (targetList == null || targetIndex < 0) return null;

    final sliver = targetList.renderSliver;
    if (sliver == null || !sliver.attached) return null;

    double estItemExtent(int index) =>
        extents[targetList!.itemId(index)] ?? meanExtent;

    final spacing = targetList.itemSpacing;
    final sliverStart = sliver.constraints.precedingScrollExtent;
    final firstChild = sliver.firstChild;
    final lastChild = sliver.lastChild;

    double itemOffsetInSliver;
    if (firstChild != null && lastChild != null) {
      final firstIndex = sliver.indexOf(firstChild);
      final lastIndex = sliver.indexOf(lastChild);
      if (targetIndex < firstIndex) {
        final firstLayoutOffset =
            (firstChild.parentData! as SliverMultiBoxAdaptorParentData)
                .layoutOffset ??
            0;
        var offset = firstLayoutOffset;
        for (var i = firstIndex - 1; i >= targetIndex; i--) {
          offset -= estItemExtent(i) + spacing;
        }
        itemOffsetInSliver = math.max(0, offset);
      } else if (targetIndex > lastIndex) {
        final lastLayoutOffset =
            (lastChild.parentData! as SliverMultiBoxAdaptorParentData)
                .layoutOffset ??
            0;
        final lastExtent =
            sliver.constraints.axis == Axis.vertical
                ? lastChild.size.height
                : lastChild.size.width;
        var offset = lastLayoutOffset + lastExtent;
        for (var i = lastIndex + 1; i < targetIndex; i++) {
          offset += estItemExtent(i) + spacing;
        }
        itemOffsetInSliver = offset;
      } else {
        // Should normally be mounted, fall back to linear estimate.
        var offset = 0.0;
        for (var i = 0; i < targetIndex; i++) {
          offset += estItemExtent(i) + spacing;
        }
        itemOffsetInSliver = offset;
      }
    } else {
      var offset = 0.0;
      for (var i = 0; i < targetIndex; i++) {
        offset += estItemExtent(i) + spacing;
      }
      itemOffsetInSliver = offset;
    }

    final estHeight = estItemExtent(targetIndex);
    final usable = math.max(
      0,
      viewportDimension - effectiveTop - effectiveBottom,
    );
    return sliverStart +
        itemOffsetInSliver -
        effectiveTop -
        alignment * (usable - estHeight);
  }

  @override
  double? adjustPixelsOnDimensions({
    required double pixels,
    required double minScrollExtent,
    required double maxScrollExtent,
    required double viewportDimension,
  }) {
    final usableBottom = viewportDimension - effectiveBottom;
    final prevUsableBottom = lastUsableBottom;
    lastUsableBottom = usableBottom;

    if (needsInitialBottomJump) {
      initialBottomPasses++;
      if (_hasExactBottomExtent() ||
          maxScrollExtent <= minScrollExtent ||
          initialBottomPasses >= _maxInitialPasses) {
        needsInitialBottomJump = false;
      }
      return maxScrollExtent;
    }

    return applyBottomEdgeDelta(
      nextPixels: pixels,
      shifted: false,
      prevUsableBottom: prevUsableBottom,
      usableBottom: usableBottom,
      minScrollExtent: minScrollExtent,
      maxScrollExtent: maxScrollExtent,
    );
  }

  @override
  Future<void> jumpToBottom({required bool animate}) async {
    final pos = turnPosition;
    if (pos == null || !pos.hasContentDimensions) return;

    onUserScroll();
    final epoch = navEpoch;
    final shouldAnimate = animate && !MediaQuery.disableAnimationsOf(context);

    if (!shouldAnimate) {
      for (var pass = 0; pass < _maxConvergencePasses; pass++) {
        final prevMax = pos.maxScrollExtent;
        if ((pos.maxScrollExtent - pos.pixels).abs() > 0.5) {
          pos.jumpTo(pos.maxScrollExtent);
        }
        if (_hasExactBottomExtent()) return;
        await nextFrame();
        if (!mounted || epoch != navEpoch || !pos.hasContentDimensions) return;
        if (_hasExactBottomExtent() &&
            (pos.maxScrollExtent - pos.pixels).abs() <= 0.5) {
          return;
        }
        if ((pos.maxScrollExtent - prevMax).abs() <= 0.5 &&
            (pos.maxScrollExtent - pos.pixels).abs() <= 0.5) {
          return;
        }
      }
      return;
    }

    double? frozenTarget;
    if (_hasExactBottomExtent()) {
      frozenTarget = pos.maxScrollExtent;
    }

    for (var pass = 0; pass < _maxConvergencePasses; pass++) {
      await pos.animateToTarget(
        motion: resolvedMotion,
        vsync: this,
        resolveTarget: () {
          if (!mounted || epoch != navEpoch || !pos.hasContentDimensions) {
            return null;
          }
          if (frozenTarget != null) return frozenTarget;
          if (_hasExactBottomExtent()) {
            return frozenTarget = pos.maxScrollExtent;
          }
          return pos.maxScrollExtent;
        },
      );
      if (!mounted || epoch != navEpoch || !pos.hasContentDimensions) return;
      if (frozenTarget != null || _hasExactBottomExtent()) return;
      final prevMax = pos.maxScrollExtent;
      await nextFrame();
      if (!mounted || epoch != navEpoch || !pos.hasContentDimensions) return;
      if ((pos.maxScrollExtent - prevMax).abs() <= 0.5 &&
          (pos.maxScrollExtent - pos.pixels).abs() <= 1) {
        return;
      }
    }
  }

  @override
  Future<void> scrollTo(
    Object itemId, {
    required double alignment,
    required bool animate,
  }) async {
    final pos = turnPosition;
    if (pos == null || !pos.hasContentDimensions) return;

    onUserScroll();
    final epoch = navEpoch;
    final shouldAnimate = animate && !MediaQuery.disableAnimationsOf(context);
    final clampedAlignment = alignment.clamp(0.0, 1.0);

    double? exact() => exactOffsetFor(
      itemId,
      alignment: clampedAlignment,
      minScrollExtent: pos.minScrollExtent,
      maxScrollExtent: pos.maxScrollExtent,
      viewportDimension: pos.viewportDimension,
    );

    double? resolveOffset() {
      final ex = exact();
      if (ex != null) return ex;
      final est = _estimatedOffsetForRegisteredItem(
        itemId,
        alignment: clampedAlignment,
        viewportDimension: pos.viewportDimension,
      );
      return est?.clamp(pos.minScrollExtent, pos.maxScrollExtent);
    }

    if (!shouldAnimate) {
      for (var pass = 0; pass < _maxConvergencePasses; pass++) {
        final ex = exact();
        if (ex != null) {
          if ((ex - pos.pixels).abs() > 0.5) pos.jumpTo(ex);
          return;
        }
        final target = resolveOffset();
        if (target == null) return;
        final prevPixels = pos.pixels;
        final prevMax = pos.maxScrollExtent;
        if ((target - prevPixels).abs() > 0.5) {
          pos.jumpTo(target);
        }
        await nextFrame();
        if (!mounted || epoch != navEpoch || !pos.hasContentDimensions) return;
        final afterExact = exact();
        if (afterExact != null) {
          if ((afterExact - pos.pixels).abs() > 0.5) pos.jumpTo(afterExact);
          return;
        }
        if ((pos.pixels - prevPixels).abs() <= 0.5 &&
            (pos.maxScrollExtent - prevMax).abs() <= 0.5) {
          return;
        }
      }
      return;
    }

    for (var pass = 0; pass < _maxConvergencePasses; pass++) {
      await pos.animateToTarget(
        motion: resolvedMotion,
        vsync: this,
        resolveTarget: () {
          if (!mounted || epoch != navEpoch || !pos.hasContentDimensions) {
            return null;
          }
          return resolveOffset();
        },
      );
      if (!mounted || epoch != navEpoch || !pos.hasContentDimensions) return;
      final ex = exact();
      if (ex != null && (ex - pos.pixels).abs() <= 1.5) return;
      final prevMax = pos.maxScrollExtent;
      await nextFrame();
      if (!mounted || epoch != navEpoch || !pos.hasContentDimensions) return;
      final afterEx = exact();
      if (afterEx != null && (afterEx - pos.pixels).abs() <= 1.5) return;
      final nextTarget = resolveOffset();
      if (nextTarget == null) return;
      if ((nextTarget - pos.pixels).abs() <= 1 &&
          (pos.maxScrollExtent - prevMax).abs() <= 0.5) {
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    resolveClearances(context);

    final slivers = <Widget>[
      if (widget.applyTopPadding && effectiveTop > 0)
        SliverToBoxAdapter(child: SizedBox(height: effectiveTop)),
      ...widget.slivers,
      if (widget.applyBottomPadding && effectiveBottom > 0)
        SliverToBoxAdapter(child: SizedBox(height: effectiveBottom)),
    ];

    return TurnScrollScope(
      topClearance: effectiveTop,
      bottomClearance: effectiveBottom,
      onItemLayout: onItemLayout,
      onItemDetach: onItemDetach,
      onTurnStageAttach: onTurnStageAttach,
      onTurnStageDetach: onTurnStageDetach,
      onListAttach: _onListAttach,
      onListDetach: _onListDetach,
      child: CustomScrollView(
        controller: turnController,
        center: widget.center,
        physics: widget.physics,
        scrollCacheExtent: widget.scrollCacheExtent,
        slivers: slivers,
      ),
    );
  }
}
