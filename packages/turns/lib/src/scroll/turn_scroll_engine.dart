import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'package:motor/motor.dart';
import 'package:turns/src/scroll/turn_scroll_controller.dart';
import 'package:turns/src/scroll/turn_scroll_motion.dart';
import 'package:turns/src/scroll/turn_scroll_notification.dart';
import 'package:turns/src/scroll/turn_sliver.dart';

/// What the scroll position is holding on to while content and insets change.
///
/// One of these is current at a time (see [TurnScrollEngineMixin.anchor]) and
/// is resolved in one place, [TurnScrollEngineMixin.adjustPixelsOnDimensions],
/// every time the scrollable's dimensions are applied.
@internal
sealed class TurnViewAnchor {
  const TurnViewAnchor();
}

/// Nothing is held: the offset stays where the user left it, apart from
/// keeping content glued above a moving bottom inset.
@internal
final class FreeAnchor extends TurnViewAnchor {
  /// Creates the free anchor.
  const FreeAnchor();
}

/// The bottom: the offset follows `maxScrollExtent`.
///
/// While [settling] (the first layout, or after a teleport) the extent is
/// still being measured, so the view jumps to the bottom for a few passes
/// until it is exact. Afterwards the anchor is dropped, or, when the view
/// follows the bottom, kept so growth at the bottom stays in view.
@internal
final class BottomAnchor extends TurnViewAnchor {
  /// Creates a bottom anchor.
  BottomAnchor({required this.settling});

  /// Whether the bottom extent is still being measured.
  bool settling;

  /// Number of passes spent settling.
  int passes = 0;
}

/// A pinned turn: its prompt flies to the anchor position once, then stays
/// there while earlier content changes, until the user scrolls.
@internal
final class PinAnchor extends TurnViewAnchor {
  /// Creates a pin anchor for the item [id].
  PinAnchor(this.id);

  /// Identity of the pinned item.
  final Object id;

  /// Whether the flight to the anchor position has not started yet.
  bool flightPending = true;

  /// Number of times the flight was postponed for lack of dimensions.
  int retries = 0;
}

/// An item at an alignment in the usable viewport, kept until the view has
/// measured enough to place it exactly (an initial open, or after a teleport).
@internal
final class ItemAnchor extends TurnViewAnchor {
  /// Creates an item anchor.
  const ItemAnchor(this.id, this.alignment);

  /// Identity of the item.
  final Object id;

  /// Usable-viewport alignment, `0.0` top to `1.0` bottom.
  final double alignment;
}

/// Shared scroll engine mixin backing `TurnScrollView` and
/// `CustomTurnScrollView` so controller lifecycle, Motor spring pinning,
/// keyboard inset anchoring, item extent tracking, and `TurnScrollScope`
/// wiring are never duplicated.
///
/// Every member is internal to this package, even those the public state
/// classes expose by mixing this in.
@internal
mixin TurnScrollEngineMixin<T extends StatefulWidget>
    on State<T>, FixedTickerProviderStateMixin<T>
    implements TurnScrollDelegate {
  static const int _maxPinRetries = 6;

  TurnScrollController? _ownController;

  /// Effective scroll controller (caller-supplied or internally owned).
  TurnScrollController get turnController =>
      widgetController ?? (_ownController ??= TurnScrollController());

  /// Caller-supplied controller from the widget.
  TurnScrollController? get widgetController;

  /// Active pinned item id from the widget.
  Object? get widgetPinnedId;

  /// Distance threshold for `isAwayFromBottom`.
  double get widgetJumpThreshold;

  /// Optional custom Motor spring motion for automatic/programmatic scroll
  /// flights (`pinnedId`, `scrollTo`, `scrollToBottom`).
  Motion? get widgetAutoScrollMotion;

  /// Effective [TurnAnchorConfig] used when computing [pinTargetOffset].
  TurnAnchorConfig get effectiveAnchorConfig =>
      activeTurnStage?.anchorConfig ?? TurnAnchorConfig.standard;

  /// Optional content padding.
  EdgeInsetsGeometry? get widgetPadding;

  /// Whether the bottom extent is exact: the last item is laid out, so
  /// `maxScrollExtent` no longer depends on estimates.
  bool hasExactBottomExtent();

  /// Where an [ItemAnchor] wants the offset to be, or `null` when the item is
  /// unknown (the anchor is then dropped).
  double? resolveItemAnchor(
    ItemAnchor anchor, {
    required double minScrollExtent,
    required double maxScrollExtent,
    required double viewportDimension,
  }) => null;

  /// Pixels to add to the offset because the viewport's center moved (taken,
  /// so it applies once).
  double takePendingCenterShift() => 0;

  /// Whether [id] can currently be pinned by this view.
  bool canPinId(Object id) => true;

  /// Extra top clearance above items occupied by an overlay (such as a sticky
  /// section header pill) that is not part of `getOffsetToReveal` obstruction.
  double get extraTopObstruction => 0;

  /// Active [RenderSliverTurnStage] registered via [TurnScrollScope].
  RenderSliverTurnStage? activeTurnStage;

  /// Measured main-axis extents for every item laid out via [TurnScrollItem].
  final extents = <Object, double>{};

  /// Currently attached item render boxes.
  final mountedBoxes = <Object, RenderBox>{};

  TurnViewAnchor _anchor = const FreeAnchor();

  /// What the view is currently holding on to.
  TurnViewAnchor get anchor => _anchor;

  /// Replaces the current [anchor].
  void setAnchor(TurnViewAnchor next, {bool sync = true}) {
    _anchor = next;
    if (!sync) return;
    turnController.updatePinActive(active: next is PinAnchor);
    syncAutoScrolling();
  }

  /// Whether the current [widgetPinnedId] still owns auto-pinning (cleared
  /// immediately on any user scroll).
  bool get pinnedActive => _anchor is PinAnchor;

  /// Whether the view keeps the bottom in view as content grows while the
  /// user is at the bottom.
  bool get widgetFollowBottom;

  /// Monotonic counter invalidating in-flight async navigation coroutines.
  int navEpoch = 0;

  /// The [navEpoch] of a flight to the bottom, set by `scrollToBottom` when it
  /// starts one. While that flight runs, the content stays glued above a
  /// moving bottom inset (a keyboard opening or closing), like a view at rest.
  int? bottomFlightEpoch;
  int? _activeNavigationEpoch;

  /// How many passes a bottom anchor may spend settling.
  int get maxBottomSettlePasses;

  /// Distance from the bottom within which the user counts as at the bottom.
  static const bottomTolerance = 2.0;

  /// Effective clearances resolved from MediaQuery + [widgetPadding].
  double effectiveTop = 0;

  /// Effective bottom clearance (max(safe.bottom, viewInsets.bottom) + bottom).
  double effectiveBottom = 0;

  /// Effective left clearance.
  double effectiveLeft = 0;

  /// Effective right clearance.
  double effectiveRight = 0;

  /// Previous usable bottom coordinate (`viewportExtent - effectiveBottom`)
  /// used to keep content glued above a rising/falling keyboard.
  double? lastUsableBottom;

  /// Current trailing empty space reserved by the active
  /// [RenderSliverTurnStage].
  double get reservedTrailingSpace =>
      activeTurnStage?.reservedTrailingSpace ?? 0;

  /// Attached [TurnScrollPosition], if any.
  TurnScrollPosition? get turnPosition {
    final positions = turnController.positions;
    if (positions.isEmpty) return null;
    if (positions.length == 1) {
      final pos = positions.first;
      return pos is TurnScrollPosition ? pos : null;
    }
    for (final pos in positions) {
      if (pos is TurnScrollPosition && identical(pos.delegate, this)) {
        return pos;
      }
    }
    return null;
  }

  /// Resolved Motor motion for automatic/programmatic scroll flights
  /// (`pinnedId`, `scrollTo`, and `scrollToBottom`).
  Motion get resolvedMotion =>
      widgetAutoScrollMotion ?? defaultTurnAutoScrollMotion;

  /// Running sum of [extents] values, kept in step by [onItemLayout] and
  /// [clearExtents] so [meanExtent] stays O(1) on long timelines.
  double _extentSum = 0;

  /// Mean measured item extent across all observed items.
  ///
  /// O(1): offset estimates call this once per unmeasured item, so a linear
  /// scan here would turn a 3,000-item jump estimate quadratic.
  double get meanExtent {
    if (extents.isEmpty) return 72;
    return _extentSum / extents.length;
  }

  /// Forgets all measured item extents.
  void clearExtents() {
    extents.clear();
    _extentSum = 0;
  }

  /// Initializes controller attachment and initial pin state.
  void initEngine() {
    turnController.attachDelegate(this);
    final pin = widgetPinnedId;
    if (pin != null && canPinId(pin)) {
      setAnchor(PinAnchor(pin));
      schedulePinScroll();
    } else {
      turnController.updatePinActive(active: false);
    }
    syncAutoScrolling();
  }

  /// Reconciles controller swapping during `didUpdateWidget`.
  void updateEngineController(TurnScrollController? oldController) {
    if (oldController != widgetController) {
      (oldController ?? _ownController)
        ?..updatePinActive(active: false)
        ..updateAutoScrolling(active: false)
        ..detachDelegate(this);
      if (widgetController != null) {
        _ownController?.dispose();
        _ownController = null;
      }
      turnController
        ..attachDelegate(this)
        ..updatePinActive(active: pinnedActive)
        ..updateAutoScrolling(active: isAutoScrolling);
    }
  }

  /// Reconciles [widgetPinnedId] transitions during `didUpdateWidget`.
  void updateEnginePinnedId(Object? oldPinnedId) {
    if (widgetPinnedId == oldPinnedId) return;
    final pin = widgetPinnedId;
    if (pin != null && canPinId(pin)) {
      setAnchor(PinAnchor(pin));
      schedulePinScroll();
    } else {
      final pos = turnPosition;
      final wasAtBottom =
          pos != null &&
          pos.hasPixels &&
          pos.hasContentDimensions &&
          (pos.maxScrollExtent - pos.pixels) <= bottomTolerance;
      // Clearing the pin at the bottom stays at the bottom, whatever the
      // reserved space gives back.
      setAnchor(
        oldPinnedId != null && wasAtBottom
            ? BottomAnchor(settling: true)
            : const FreeAnchor(),
      );
      navEpoch++;
    }
  }

  /// Reconciles [widgetFollowBottom] changes during `didUpdateWidget`.
  void updateEngineFollowBottom({required bool wasFollowing}) {
    if (widgetFollowBottom == wasFollowing) return;
    final current = _anchor;
    if (widgetFollowBottom) {
      _armFollowBottomIfAtBottom();
    } else if (current is BottomAnchor && !current.settling) {
      setAnchor(const FreeAnchor());
    }
  }

  void _armFollowBottomIfAtBottom() {
    if (!widgetFollowBottom ||
        _anchor is! FreeAnchor ||
        _activeNavigationEpoch != null) {
      return;
    }
    final pos = turnPosition;
    if (pos == null || !pos.hasPixels || !pos.hasContentDimensions) return;
    if ((pos.maxScrollExtent - pos.pixels).abs() <= bottomTolerance) {
      setAnchor(BottomAnchor(settling: false));
    }
  }

  /// Cleans up controller attachment and render object references.
  void disposeEngine() {
    turnController
      ..updateBottomDistance(0, threshold: widgetJumpThreshold)
      ..updatePinActive(active: false)
      ..updateAutoScrolling(active: false)
      ..detachDelegate(this);
    _ownController?.dispose();
    mountedBoxes.clear();
    activeTurnStage = null;
  }

  var _inProgrammaticJump = false;

  /// Whether this view is currently executing a programmatic scroll flight
  /// (`scrollTo`, `scrollToBottom`, active `pinnedId` scroll, or initial
  /// bottom positioning).
  bool get isAutoScrolling {
    final current = _anchor;
    return _activeNavigationEpoch != null ||
        (current is BottomAnchor && current.settling) ||
        (current is PinAnchor && current.flightPending) ||
        (turnPosition?.isTrackingTarget ?? false);
  }

  /// Whether this view is currently driven by programmatic scrolling
  /// (`scrollTo`, `scrollToBottom`, pin animation, initial positioning, or
  /// synchronous programmatic jumps).
  bool get isProgrammaticScroll => _inProgrammaticJump || isAutoScrolling;

  /// Synchronizes [TurnScrollController.isAutoScrolling] with
  /// [isAutoScrolling].
  void syncAutoScrolling() {
    turnController.updateAutoScrolling(active: isAutoScrolling);
  }

  /// Marks an async multi-pass programmatic navigation identified by [epoch]
  /// as active so [TurnScrollController.isAutoScrolling] stays `true` across
  /// inter-pass frames.
  void beginNavigation(int epoch) {
    _activeNavigationEpoch = epoch;
    syncAutoScrolling();
  }

  /// Ends an async multi-pass programmatic navigation if [epoch] is still
  /// active.
  void endNavigation(int epoch) {
    if (_activeNavigationEpoch != epoch) return;
    _activeNavigationEpoch = null;
    syncAutoScrolling();
    // A flight that ended at the bottom may have come to rest before it was
    // over as far as the engine is concerned.
    _armFollowBottomIfAtBottom();
  }

  /// Performs a programmatic `jumpTo` so any resulting [TurnScrollNotification]
  /// reports `isProgrammatic: true`.
  void programmaticJumpTo(TurnScrollPosition pos, double value) {
    _inProgrammaticJump = true;
    try {
      pos.internalJumpTo(value);
    } finally {
      _inProgrammaticJump = false;
    }
  }

  /// Wraps [child] to dispatch a [TurnScrollNotification] alongside Flutter's
  /// standard scroll notifications:
  ///
  /// - on every [ScrollUpdateNotification];
  /// - on every [OverscrollNotification] (a drag against a clamped edge, where
  ///   the offset itself does not move);
  /// - on every [ScrollMetricsNotification] (the content or viewport changed
  ///   size without scrolling, for example a first page that is shorter than
  ///   the viewport and so can never be scrolled to its edge).
  ///
  /// The notification is dispatched from this state's own context, above this
  /// listener, so it never reaches it again. Notifications from scrollables
  /// nested in an item (a horizontal code block) are not turned into one.
  Widget wrapWithTurnNotification(Widget child) =>
      NotificationListener<Notification>(
        onNotification: (notification) {
          final ScrollMetrics metrics;
          switch (notification) {
            case ScrollUpdateNotification(depth: 0):
              metrics = notification.metrics;
            case OverscrollNotification(depth: 0):
              metrics = notification.metrics;
            case ScrollMetricsNotification(depth: 0):
              metrics = notification.metrics;
            default:
              return false;
          }
          TurnScrollNotification(
            metrics: metrics,
            context: context,
            leadingExtent: math.max<double>(0, metrics.extentBefore),
            trailingExtent: math.max<double>(0, metrics.extentAfter),
            isProgrammatic: isProgrammaticScroll,
            isPinActive: pinnedActive,
          ).dispatch(context);
          return false;
        },
        child: child,
      );

  /// Resolves [effectiveTop], [effectiveBottom], [effectiveLeft], and
  /// [effectiveRight] from [MediaQuery] and [widgetPadding].
  ///
  /// When [applyTopPadding] is `false`, `MediaQuery.paddingOf(context).top` is
  /// omitted while explicit `padding.top` is preserved. When
  /// [applyBottomPadding] is `false`, `MediaQuery.paddingOf(context).bottom`
  /// and `MediaQuery.viewInsetsOf(context).bottom` are omitted while explicit
  /// `padding.bottom` is preserved.
  void resolveClearances(
    BuildContext context, {
    bool applyTopPadding = true,
    bool applyBottomPadding = true,
  }) {
    final safe = MediaQuery.paddingOf(context);
    final insets = MediaQuery.viewInsetsOf(context);
    final contentPadding =
        widgetPadding?.resolve(Directionality.of(context)) ?? EdgeInsets.zero;

    effectiveTop = (applyTopPadding ? safe.top : 0) + contentPadding.top;
    effectiveBottom =
        (applyBottomPadding ? math.max(safe.bottom, insets.bottom) : 0) +
        contentPadding.bottom;
    effectiveLeft = safe.left + contentPadding.left;
    effectiveRight = safe.right + contentPadding.right;
  }

  /// The mounted, laid-out box of item [id], or `null` when it is not
  /// mounted (or only kept alive offscreen, where its offsets are stale).
  RenderBox? mountedBoxFor(Object id) {
    final box = mountedBoxes[id];
    if (box == null ||
        !box.attached ||
        !box.hasSize ||
        isKeptAliveOffscreen(box)) {
      return null;
    }
    return box;
  }

  /// [mountedBoxFor] with the item's measured extent, for
  /// [RenderSliverTurnStage.anchorBoxOf].
  ({RenderBox box, double extent})? anchorFor(Object id) {
    final box = mountedBoxFor(id);
    final extent = extents[id];
    return box == null || extent == null ? null : (box: box, extent: extent);
  }

  /// Callback passed to [TurnScrollScope.onItemLayout].
  void onItemLayout(Object id, double extent, RenderBox box) {
    _extentSum += extent - (extents[id] ?? 0);
    extents[id] = extent;
    mountedBoxes[id] = box;
  }

  /// Callback passed to [TurnScrollScope.onItemDetach].
  void onItemDetach(Object id, RenderBox box) {
    if (identical(mountedBoxes[id], box)) {
      mountedBoxes.remove(id);
    }
  }

  /// Callback passed to [TurnScrollScope.onTurnStageAttach].
  // Passed as a callback tear-off to TurnScrollScope.
  // ignore: use_setters_to_change_properties
  void onTurnStageAttach(RenderSliverTurnStage stage) {
    activeTurnStage = stage;
  }

  /// Callback passed to [TurnScrollScope.onTurnStageDetach].
  void onTurnStageDetach(RenderSliverTurnStage stage) {
    if (identical(activeTurnStage, stage)) {
      activeTurnStage = null;
    }
  }

  /// Schedules a post-frame flight of the current pin anchor to its resting
  /// position.
  void schedulePinScroll() {
    final pin = _anchor;
    if (pin is! PinAnchor) return;
    pin.flightPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(_anchor, pin) || !pin.flightPending) return;
      _runPinScroll(pin);
    });
  }

  void _runPinScroll(PinAnchor pin) {
    final pos = turnPosition;
    if (pos == null || !pos.hasContentDimensions || !pos.hasPixels) {
      if (++pin.retries <= _maxPinRetries) {
        schedulePinScroll();
      } else {
        pin.flightPending = false;
        syncAutoScrolling();
      }
      return;
    }
    pin
      ..flightPending = false
      ..retries = 0;
    final target = pinTargetOffset() ?? pos.maxScrollExtent;
    final animate = !MediaQuery.disableAnimationsOf(context);
    if (!animate) {
      if ((pos.pixels - target).abs() > 0.5) programmaticJumpTo(pos, target);
      syncAutoScrolling();
      return;
    }
    unawaited(
      pos.animateToTarget(
        motion: resolvedMotion,
        vsync: this,
        resolveTarget: () {
          if (!mounted || !identical(_anchor, pin)) return null;
          return pinTargetOffset() ?? pos.maxScrollExtent;
        },
      ),
    );
    if (!pos.isTrackingTarget) {
      syncAutoScrolling();
    }
  }

  /// Computes the total pinned obstruction (e.g. pinned `SliverAppBar` and
  /// `SliverPersistentHeader`s) that Flutter's `getOffsetToReveal` already
  /// accounts for above [target] (either a [RenderBox] or a [RenderSliver]).
  double pinnedObstructionFor(RenderObject target) {
    var obstruction = 0.0;
    RenderObject? node = target;
    while (node != null && node is! RenderViewportBase) {
      if (node is RenderSliver &&
          node.constraints.growthDirection == GrowthDirection.forward) {
        final parentData = node.parentData;
        if (parentData is ContainerParentDataMixin<RenderSliver>) {
          var prev = parentData.previousSibling;
          while (prev != null) {
            obstruction += prev.geometry?.maxScrollObstructionExtent ?? 0;
            final prevData = prev.parentData;
            prev = prevData is ContainerParentDataMixin<RenderSliver>
                ? prevData.previousSibling
                : null;
          }
        }
      }
      node = node.parent;
    }
    return obstruction;
  }

  /// The pin offset from what the turn stage measured in its last layout.
  ///
  /// Reads no render box sizes, so it is safe to call while the viewport is
  /// applying its dimensions (mid-layout), unlike a reveal offset. Only
  /// available when the stage wraps the item list (`SliverTurnReserve`).
  double? _measuredPinTarget(Object pinnedId, TurnScrollPosition pos) {
    final stage = activeTurnStage;
    final extent = extents[pinnedId];
    if (stage == null ||
        extent == null ||
        !stage.attached ||
        stage.anchorBoxOf == null ||
        stage.anchorId != pinnedId ||
        !stage.anchorMeasured) {
      return null;
    }
    final viewport = stage.parent;
    if (viewport is! RenderViewport) return null;
    final obstruction = pinnedObstructionFor(stage);
    final topInset = math.max(effectiveTop + extraTopObstruction, obstruction);
    final usable = math.max<double>(
      0,
      pos.viewportDimension - topInset - effectiveBottom,
    );
    final minExtent = RenderSliverTurnStage.computeMinExtent(
      usableExtent: usable,
      anchorExtent: extent,
      anchorConfig: effectiveAnchorConfig,
    );
    final itemTop = viewport.scrollOffsetOf(stage, stage.anchorOffset);
    return (itemTop + (minExtent - usable) - topInset).clamp(
      pos.minScrollExtent,
      pos.maxScrollExtent,
    );
  }

  /// Computes the ideal scroll offset to pin [widgetPinnedId] inside the usable
  /// viewport.
  double? pinTargetOffset() {
    final pinnedId = widgetPinnedId;
    final pos = turnPosition;
    if (pinnedId == null ||
        pos == null ||
        !pos.hasViewportDimension ||
        !pos.hasContentDimensions) {
      return null;
    }
    final measured = _measuredPinTarget(pinnedId, pos);
    if (measured != null) return measured;
    final box = mountedBoxes[pinnedId];
    if (box == null ||
        !box.attached ||
        !box.hasSize ||
        isKeptAliveOffscreen(box)) {
      return null;
    }
    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport == null) return null;

    final obstruction = pinnedObstructionFor(box);
    final topInset = math.max(effectiveTop + extraTopObstruction, obstruction);
    final usable = math.max<double>(
      0,
      pos.viewportDimension - topInset - effectiveBottom,
    );
    final hU = box.size.height;
    final minExtent = RenderSliverTurnStage.computeMinExtent(
      usableExtent: usable,
      anchorExtent: hU,
      anchorConfig: effectiveAnchorConfig,
    );
    final anchorFromTop = minExtent - usable;
    final itemTop = viewport.getOffsetToReveal(box, 0).offset;
    return (itemTop + anchorFromTop - (topInset - obstruction)).clamp(
      pos.minScrollExtent,
      pos.maxScrollExtent,
    );
  }

  /// Whether [box] is kept alive offscreen in a sliver adaptor's keep-alive
  /// bucket (where `getOffsetToReveal` would be stale).
  bool isKeptAliveOffscreen(RenderBox box) {
    RenderObject? node = box;
    while (node != null) {
      final parentData = node.parentData;
      if (parentData is SliverMultiBoxAdaptorParentData) {
        return parentData.keptAlive;
      }
      if (node is RenderSliver) return false;
      node = node.parent;
    }
    return false;
  }

  /// Returns the exact scroll offset to align the mounted item [id] at
  /// [alignment] (`0.0` top .. `1.0` bottom) within the usable viewport, or
  /// `null` if [id] is not currently mounted on screen/cache.
  double? exactOffsetFor(
    Object id, {
    required double alignment,
    required double minScrollExtent,
    required double maxScrollExtent,
    required double viewportDimension,
  }) {
    final box = mountedBoxes[id];
    if (box == null ||
        !box.attached ||
        !box.hasSize ||
        isKeptAliveOffscreen(box)) {
      return null;
    }
    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport == null) return null;
    final obstruction = pinnedObstructionFor(box);
    final topInset = math.max(effectiveTop + extraTopObstruction, obstruction);
    final usable = math.max<double>(
      0,
      viewportDimension - topInset - effectiveBottom,
    );
    final itemTop = viewport.getOffsetToReveal(box, 0).offset;
    final raw =
        itemTop -
        (topInset - obstruction) -
        alignment * (usable - box.size.height);
    return raw.clamp(minScrollExtent, maxScrollExtent);
  }

  @override
  double? adjustPixelsOnDimensions({
    required double pixels,
    required double minScrollExtent,
    required double maxScrollExtent,
    required double viewportDimension,
    double? previousMaxScrollExtent,
  }) {
    final usableBottom = viewportDimension - effectiveBottom;
    final prevUsableBottom = lastUsableBottom;
    lastUsableBottom = usableBottom;
    final centerShift = takePendingCenterShift();
    final pos = turnPosition;

    // The one place the current anchor decides where the offset goes.
    switch (_anchor) {
      case final ItemAnchor item:
        final target = resolveItemAnchor(
          item,
          minScrollExtent: minScrollExtent,
          maxScrollExtent: maxScrollExtent,
          viewportDimension: viewportDimension,
        );
        if (target != null) return target;
        setAnchor(const FreeAnchor(), sync: false);
      case final BottomAnchor bottom:
        if (bottom.settling) {
          bottom.passes++;
          if (hasExactBottomExtent() ||
              maxScrollExtent <= minScrollExtent ||
              bottom.passes >= maxBottomSettlePasses) {
            bottom.settling = false;
            if (!widgetFollowBottom) {
              setAnchor(const FreeAnchor(), sync: false);
            }
          }
        }
        return maxScrollExtent;
      case final PinAnchor pin:
        // Once the flight has settled the pinned item holds its place while
        // content around it changes.
        if (!pin.flightPending && pos != null && !pos.isTrackingTarget) {
          final target = _measuredPinTarget(pin.id, pos);
          if (target != null) return target;
        }
      case FreeAnchor():
        break;
    }

    final wasAtMax =
        previousMaxScrollExtent != null &&
        pixels >= previousMaxScrollExtent - bottomTolerance;
    return applyBottomEdgeDelta(
      nextPixels: pixels + centerShift,
      shifted: centerShift != 0,
      wasAtMax: wasAtMax,
      prevUsableBottom: prevUsableBottom,
      usableBottom: usableBottom,
      minScrollExtent: minScrollExtent,
      maxScrollExtent: maxScrollExtent,
    );
  }

  /// Applies keyboard/bottom-edge inset anchoring for a free (unanchored)
  /// view.
  ///
  /// A view that was at the bottom stays at the bottom when the inset moves.
  double? applyBottomEdgeDelta({
    required double nextPixels,
    required bool shifted,
    required bool wasAtMax,
    required double? prevUsableBottom,
    required double usableBottom,
    required double minScrollExtent,
    required double maxScrollExtent,
  }) {
    if (prevUsableBottom == null) {
      return shifted
          ? nextPixels.clamp(minScrollExtent, maxScrollExtent)
          : null;
    }
    final bottomEdgeDelta = prevUsableBottom - usableBottom;
    if (bottomEdgeDelta.abs() <= 0.5) {
      return shifted
          ? nextPixels.clamp(minScrollExtent, maxScrollExtent)
          : null;
    }

    final pos = turnPosition;
    // A view resting on its top edge (opened at the top, or scrolled all the
    // way up) keeps its top when the bottom inset changes: shifting would
    // scroll the reader away from what they are looking at.
    final atTop =
        nextPixels <= minScrollExtent + 0.5 &&
        maxScrollExtent > minScrollExtent;
    final current = _anchor;
    // A flight to an item or a pin aims at a place measured from the top, so
    // the inset leaves it alone. A flight to the bottom moves with the inset:
    // its target does, and what is on screen should not come apart from the
    // composer while the keyboard moves under it.
    final flyingToBottom = bottomFlightEpoch == navEpoch;
    if (atTop ||
        (current is PinAnchor && current.flightPending) ||
        (pos != null && pos.isTrackingTarget && !flyingToBottom)) {
      return shifted
          ? nextPixels.clamp(minScrollExtent, maxScrollExtent)
          : null;
    }

    // At the bottom before, at the bottom after: with trailing space reserved
    // for a pinned turn the maximum does not move by the inset, so shifting by
    // the inset would carry the reader away from the bottom.
    if (wasAtMax) return maxScrollExtent;

    return (nextPixels + bottomEdgeDelta).clamp(
      minScrollExtent,
      maxScrollExtent,
    );
  }

  /// Everything above the bottom clearance, in scroll offset terms: what
  /// `maxScrollExtent` leaves once the bottom inset is taken out. A flight
  /// that freezes this (rather than `maxScrollExtent`) still lands at the true
  /// bottom when the inset changes mid-flight.
  double contentEndOf(TurnScrollPosition pos) =>
      pos.maxScrollExtent + pos.viewportDimension - effectiveBottom;

  /// The offset of the bottom for a [contentEnd] from [contentEndOf], with the
  /// bottom clearance as it is now.
  double bottomOffsetFor(TurnScrollPosition pos, double contentEnd) =>
      contentEnd + effectiveBottom - pos.viewportDimension;

  /// Waits for the end of the next frame.
  Future<void> nextFrame() {
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future;
  }

  /// Releases whatever the view was holding on to and invalidates pending
  /// navigation, without syncing [TurnScrollController.isAutoScrolling] yet.
  void resetAutoScrollState() {
    setAnchor(const FreeAnchor(), sync: false);
    turnController.updatePinActive(active: false);
    _activeNavigationEpoch = null;
    navEpoch++;
  }

  @override
  void onUserScroll() {
    resetAutoScrollState();
    syncAutoScrolling();
  }

  @override
  void onScrollIdle() => _armFollowBottomIfAtBottom();

  @override
  void onMetricsChanged(double pixels, double maxScrollExtent) {
    turnController
      ..updateBottomDistance(
        maxScrollExtent - pixels,
        threshold: widgetJumpThreshold,
      )
      ..updateAutoScrolling(active: isAutoScrolling);
  }
}
