import 'dart:math' as math;

import 'package:flutter/gestures.dart';
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
/// [TurnScrollController.scrollToBottom] convergence.
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
    this.autoScrollMotion,
    this.physics,
    this.scrollCacheExtent,
    this.followBottom = false,
    this.clipBehavior = Clip.hardEdge,
    this.keyboardDismissBehavior,
    this.dragStartBehavior = DragStartBehavior.start,
  });

  /// Slivers placed inside the viewport.
  final List<Widget> slivers;

  /// Optional `Viewport.center` key.
  ///
  /// Note that [CustomTurnScrollView] is primarily forward-oriented: offscreen
  /// `SliverTurnList` estimation assumes slivers grow in
  /// `GrowthDirection.forward`. Use `TurnScrollView` for bidirectional
  /// `Viewport(center:)` timelines with O(1) deep-link opening and `0.0px`
  /// prepend pagination.
  final Key? center;

  /// Identity of the active turn's anchor item, or `null` when no turn is
  /// pinned.
  final Object? pinnedId;

  /// Optional controller exposing [TurnScrollController.scrollToBottom],
  /// [TurnScrollController.scrollTo], [TurnScrollController.isAwayFromBottom],
  /// [TurnScrollController.distanceFromBottom],
  /// [TurnScrollController.isPinActive], and
  /// [TurnScrollController.isAutoScrolling].
  final TurnScrollController? controller;

  /// Content padding added on top of `MediaQuery.paddingOf(context)` and
  /// `MediaQuery.viewInsetsOf(context).bottom`.
  final EdgeInsetsGeometry? padding;

  /// Whether to include `MediaQuery.paddingOf(context).top` and insert an
  /// automatic top clearance spacer sliver above [slivers].
  ///
  /// Set `false` when placing a `SliverAppBar(pinned: true)` as the first
  /// sliver or when an outer header already consumed the top safe-area inset.
  final bool applyTopPadding;

  /// Whether to include `max(MediaQuery.paddingOf(context).bottom,
  /// MediaQuery.viewInsetsOf(context).bottom)` in the bottom clearance.
  ///
  /// Explicit `padding.bottom` is always preserved in both
  /// [TurnScrollScope.bottomClearance] and the trailing clearance spacer.
  final bool applyBottomPadding;

  /// Whether a fresh scroll view opens scrolled to the bottom (when [pinnedId]
  /// is `null`).
  final bool initialAtBottom;

  /// Distance above the bottom at which [TurnScrollController.isAwayFromBottom]
  /// becomes `true`.
  final double jumpThreshold;

  /// Motor spring used for automatic and programmatic scroll flights
  /// (`pinnedId`, `scrollTo`, and `scrollToBottom`).
  ///
  /// This controls only automatic scroll animations and never affects user drag
  /// [physics]. Under `MediaQuery.disableAnimationsOf(context)`, all
  /// transitions jump instantaneously.
  final Motion? autoScrollMotion;

  /// Optional custom scroll physics.
  final ScrollPhysics? physics;

  /// Optional viewport cache extent.
  final ScrollCacheExtent? scrollCacheExtent;

  /// Whether the view stays at the bottom when the user is at the bottom and
  /// the content grows or shrinks.
  ///
  /// Any scroll by the user releases it; coming to rest at the bottom again
  /// re-arms it. Defaults to `false`.
  final bool followBottom;

  /// How the scroll view clips its content (see
  /// [CustomScrollView.clipBehavior]).
  final Clip clipBehavior;

  /// How a drag dismisses the keyboard (see
  /// [CustomScrollView.keyboardDismissBehavior]); `null` leaves it to the
  /// ambient [ScrollConfiguration].
  final ScrollViewKeyboardDismissBehavior? keyboardDismissBehavior;

  /// How a drag gesture is recognized (see
  /// [CustomScrollView.dragStartBehavior]).
  final DragStartBehavior dragStartBehavior;

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
  bool get widgetFollowBottom => widget.followBottom;

  @override
  int get maxBottomSettlePasses => _maxInitialPasses;

  @override
  double get widgetJumpThreshold => widget.jumpThreshold;

  @override
  Motion? get widgetAutoScrollMotion => widget.autoScrollMotion;

  @override
  EdgeInsetsGeometry? get widgetPadding => widget.padding;

  @override
  void initState() {
    super.initState();
    if (widget.initialAtBottom && widget.pinnedId == null) {
      setAnchor(BottomAnchor(settling: true), sync: false);
    }
    initEngine();
  }

  @override
  void didUpdateWidget(CustomTurnScrollView oldWidget) {
    super.didUpdateWidget(oldWidget);
    updateEngineController(oldWidget.controller);
    updateEnginePinnedId(oldWidget.pinnedId);
    updateEngineFollowBottom(wasFollowing: oldWidget.followBottom);
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

  @override
  bool hasExactBottomExtent() {
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
        itemOffsetInSliver = math.max(
          0,
          firstLayoutOffset -
              targetList.estimateExtent(targetIndex, firstIndex),
        );
      } else if (targetIndex > lastIndex) {
        final lastLayoutOffset =
            (lastChild.parentData! as SliverMultiBoxAdaptorParentData)
                .layoutOffset ??
            0;
        final lastExtent = sliver.constraints.axis == Axis.vertical
            ? lastChild.size.height
            : lastChild.size.width;
        itemOffsetInSliver =
            lastLayoutOffset +
            lastExtent +
            targetList.estimateExtent(lastIndex + 1, targetIndex);
      } else {
        // Should normally be mounted, fall back to an estimate from the top.
        itemOffsetInSliver = targetList.estimateExtent(0, targetIndex);
      }
    } else {
      itemOffsetInSliver = targetList.estimateExtent(0, targetIndex);
    }

    final estHeight = estItemExtent(targetIndex);
    final obstruction = pinnedObstructionFor(sliver);
    final topInset = math.max(effectiveTop, obstruction);
    final usable = math.max<double>(
      0,
      viewportDimension - topInset - effectiveBottom,
    );
    return sliverStart +
        itemOffsetInSliver -
        topInset -
        alignment * (usable - estHeight);
  }

  @override
  Future<bool> scrollToBottom({required bool animate, Motion? motion}) async {
    final pos = turnPosition;
    if (pos == null || !pos.hasContentDimensions) return false;

    resetAutoScrollState();
    final epoch = navEpoch;
    final shouldAnimate = animate && !MediaQuery.disableAnimationsOf(context);
    final flightMotion = motion ?? resolvedMotion;

    if (hasExactBottomExtent() &&
        (pos.maxScrollExtent - pos.pixels).abs() <= 0.5) {
      syncAutoScrolling();
      return true;
    }

    beginNavigation(epoch);
    try {
      if (!shouldAnimate) {
        for (var pass = 0; pass < _maxConvergencePasses; pass++) {
          final prevMax = pos.maxScrollExtent;
          if ((pos.maxScrollExtent - pos.pixels).abs() > 0.5) {
            programmaticJumpTo(pos, pos.maxScrollExtent);
          }
          if (hasExactBottomExtent()) return true;
          await nextFrame();
          if (!mounted || epoch != navEpoch || !pos.hasContentDimensions) {
            return false;
          }
          if (hasExactBottomExtent() &&
              (pos.maxScrollExtent - pos.pixels).abs() <= 0.5) {
            return true;
          }
          if ((pos.maxScrollExtent - prevMax).abs() <= 0.5 &&
              (pos.maxScrollExtent - pos.pixels).abs() <= 0.5) {
            return true;
          }
        }
        return mounted && epoch == navEpoch;
      }

      // Freeze where the content ends, not the offset, so a bottom inset that
      // is still growing counts when the flight lands.
      double? frozenContentEnd;
      if (hasExactBottomExtent()) {
        frozenContentEnd = contentEndOf(pos);
      }

      for (var pass = 0; pass < _maxConvergencePasses; pass++) {
        final arrived = await pos.animateToTarget(
          motion: flightMotion,
          vsync: this,
          resolveTarget: () {
            if (!mounted || epoch != navEpoch || !pos.hasContentDimensions) {
              return null;
            }
            if (frozenContentEnd == null && hasExactBottomExtent()) {
              frozenContentEnd = contentEndOf(pos);
            }
            if (frozenContentEnd case final end?) {
              return bottomOffsetFor(pos, end);
            }
            return pos.maxScrollExtent;
          },
        );
        if (!arrived ||
            !mounted ||
            epoch != navEpoch ||
            !pos.hasContentDimensions) {
          return false;
        }
        if (frozenContentEnd != null || hasExactBottomExtent()) return true;
        final prevMax = pos.maxScrollExtent;
        await nextFrame();
        if (!mounted || epoch != navEpoch || !pos.hasContentDimensions) {
          return false;
        }
        if ((pos.maxScrollExtent - prevMax).abs() <= 0.5 &&
            (pos.maxScrollExtent - pos.pixels).abs() <= 1) {
          return true;
        }
      }
      return mounted && epoch == navEpoch;
    } finally {
      endNavigation(epoch);
    }
  }

  @override
  Future<bool> scrollTo(
    Object itemId, {
    required double alignment,
    required bool animate,
    Motion? motion,
  }) async {
    final pos = turnPosition;
    if (pos == null || !pos.hasContentDimensions) return false;

    resetAutoScrollState();
    final epoch = navEpoch;
    final shouldAnimate = animate && !MediaQuery.disableAnimationsOf(context);
    final flightMotion = motion ?? resolvedMotion;
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

    if (resolveOffset() == null) {
      syncAutoScrolling();
      return false;
    }

    final initialExact = exact();
    if (initialExact != null && (initialExact - pos.pixels).abs() <= 0.5) {
      syncAutoScrolling();
      return true;
    }

    beginNavigation(epoch);
    try {
      if (!shouldAnimate) {
        for (var pass = 0; pass < _maxConvergencePasses; pass++) {
          final ex = exact();
          if (ex != null) {
            if ((ex - pos.pixels).abs() > 0.5) programmaticJumpTo(pos, ex);
            return true;
          }
          final target = resolveOffset();
          if (target == null) return false;
          final prevPixels = pos.pixels;
          final prevMax = pos.maxScrollExtent;
          if ((target - prevPixels).abs() > 0.5) {
            programmaticJumpTo(pos, target);
          }
          await nextFrame();
          if (!mounted || epoch != navEpoch || !pos.hasContentDimensions) {
            return false;
          }
          final afterExact = exact();
          if (afterExact != null) {
            if ((afterExact - pos.pixels).abs() > 0.5) {
              programmaticJumpTo(pos, afterExact);
            }
            return true;
          }
          if ((pos.pixels - prevPixels).abs() <= 0.5 &&
              (pos.maxScrollExtent - prevMax).abs() <= 0.5) {
            return exact() != null;
          }
        }
        return mounted && epoch == navEpoch && exact() != null;
      }

      for (var pass = 0; pass < _maxConvergencePasses; pass++) {
        final arrived = await pos.animateToTarget(
          motion: flightMotion,
          vsync: this,
          resolveTarget: () {
            if (!mounted || epoch != navEpoch || !pos.hasContentDimensions) {
              return null;
            }
            return resolveOffset();
          },
        );
        if (!arrived ||
            !mounted ||
            epoch != navEpoch ||
            !pos.hasContentDimensions) {
          return false;
        }
        final ex = exact();
        if (ex != null && (ex - pos.pixels).abs() <= 1.5) return true;
        final prevMax = pos.maxScrollExtent;
        await nextFrame();
        if (!mounted || epoch != navEpoch || !pos.hasContentDimensions) {
          return false;
        }
        final afterEx = exact();
        if (afterEx != null && (afterEx - pos.pixels).abs() <= 1.5) return true;
        final nextTarget = resolveOffset();
        if (nextTarget == null) return false;
        if ((nextTarget - pos.pixels).abs() <= 1 &&
            (pos.maxScrollExtent - prevMax).abs() <= 0.5) {
          return afterEx != null;
        }
      }
      return mounted && epoch == navEpoch;
    } finally {
      endNavigation(epoch);
    }
  }

  // A method tear-off compares equal across builds, so the scope doesn't
  // notify on every build.
  double _meanItemExtent() => meanExtent;

  double? _extentOf(Object id) => extents[id];

  @override
  Widget build(BuildContext context) {
    resolveClearances(
      context,
      applyTopPadding: widget.applyTopPadding,
      applyBottomPadding: widget.applyBottomPadding,
    );

    final slivers = <Widget>[
      if (widget.applyTopPadding && effectiveTop > 0)
        SliverToBoxAdapter(child: SizedBox(height: effectiveTop)),
      ...widget.slivers,
      if (effectiveBottom > 0)
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
      meanItemExtent: _meanItemExtent,
      extentOf: _extentOf,
      child: wrapWithTurnNotification(
        CustomScrollView(
          controller: turnController,
          center: widget.center,
          physics: widget.physics,
          scrollCacheExtent: widget.scrollCacheExtent,
          clipBehavior: widget.clipBehavior,
          keyboardDismissBehavior: widget.keyboardDismissBehavior,
          dragStartBehavior: widget.dragStartBehavior,
          slivers: slivers,
        ),
      ),
    );
  }
}
