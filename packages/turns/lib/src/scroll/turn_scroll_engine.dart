import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:turns/src/scroll/turn_scroll_controller.dart';
import 'package:turns/src/scroll/turn_scroll_motion.dart';
import 'package:turns/src/scroll/turn_scroll_notification.dart';
import 'package:turns/src/scroll/turn_sliver.dart';

/// Shared scroll engine mixin backing `TurnScrollView` and
/// `CustomTurnScrollView` so controller lifecycle, Motor spring pinning,
/// keyboard inset anchoring, item extent tracking, and `TurnScrollScope`
/// wiring are never duplicated.
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
  /// flights (`pinnedId`, `scrollTo`, `jumpToBottom`).
  Motion? get widgetAutoScrollMotion;

  /// Effective [TurnAnchorConfig] used when computing [pinTargetOffset].
  TurnAnchorConfig get effectiveAnchorConfig =>
      activeTurnStage?.anchorConfig ?? TurnAnchorConfig.standard;

  /// Optional content padding.
  EdgeInsetsGeometry? get widgetPadding;

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

  /// Whether the current [widgetPinnedId] still owns auto-pinning (cleared
  /// immediately on any user scroll).
  bool pinnedActive = false;

  /// Pending pin animation queued for after the new pinned item's first layout.
  bool pendingPinScroll = false;

  /// Monotonic counter invalidating superseded post-frame pin callbacks.
  int pinEpoch = 0;
  var _pinRetries = 0;

  /// Monotonic counter invalidating in-flight async navigation coroutines.
  int navEpoch = 0;

  /// Whether the first layout should open scrolled to the bottom.
  bool needsInitialBottomJump = false;

  /// Number of initial bottom-jump passes attempted so far.
  int initialBottomPasses = 0;

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
    if (!turnController.hasClients) return null;
    final pos = turnController.position;
    return pos is TurnScrollPosition ? pos : null;
  }

  /// Resolved Motor motion for automatic/programmatic scroll flights
  /// (`pinnedId`, `scrollTo`, and `jumpToBottom`).
  Motion get resolvedMotion =>
      widgetAutoScrollMotion ?? defaultTurnAutoScrollMotion;

  /// Mean measured item extent across all observed items.
  double get meanExtent {
    if (extents.isEmpty) return 72;
    var sum = 0.0;
    for (final v in extents.values) {
      sum += v;
    }
    return sum / extents.length;
  }

  void _setPinnedActive({required bool active}) {
    pinnedActive = active;
    turnController.updatePinActive(active: active);
  }

  /// Initializes controller attachment and initial pin state.
  void initEngine() {
    turnController.attachDelegate(this);
    final pin = widgetPinnedId;
    if (pin != null && canPinId(pin)) {
      _setPinnedActive(active: true);
      pendingPinScroll = true;
      schedulePinScroll();
    } else {
      turnController.updatePinActive(active: false);
    }
  }

  /// Reconciles controller swapping during `didUpdateWidget`.
  void updateEngineController(TurnScrollController? oldController) {
    if (oldController != widgetController) {
      (oldController ?? _ownController)
        ?..updatePinActive(active: false)
        ..detachDelegate(this);
      if (widgetController != null) {
        _ownController?.dispose();
        _ownController = null;
      }
      turnController
        ..attachDelegate(this)
        ..updatePinActive(active: pinnedActive);
    }
  }

  /// Reconciles [widgetPinnedId] transitions during `didUpdateWidget`.
  void updateEnginePinnedId(
    Object? oldPinnedId, {
    VoidCallback? onPinActivated,
  }) {
    if (widgetPinnedId == oldPinnedId) return;
    final pin = widgetPinnedId;
    if (pin != null && canPinId(pin)) {
      _setPinnedActive(active: true);
      pendingPinScroll = true;
      _pinRetries = 0;
      needsInitialBottomJump = false;
      onPinActivated?.call();
      schedulePinScroll();
    } else {
      final pos = turnPosition;
      final wasAtBottom =
          pos != null &&
          pos.hasPixels &&
          pos.hasContentDimensions &&
          (pos.maxScrollExtent - pos.pixels) <= 2;
      _setPinnedActive(active: false);
      pendingPinScroll = false;
      pinEpoch++;
      if (oldPinnedId != null && wasAtBottom) {
        needsInitialBottomJump = true;
        initialBottomPasses = 0;
      }
    }
  }

  /// Cleans up controller attachment and render object references.
  void disposeEngine() {
    turnController
      ..updateBottomDistance(0, threshold: widgetJumpThreshold)
      ..updatePinActive(active: false)
      ..detachDelegate(this);
    _ownController?.dispose();
    mountedBoxes.clear();
    activeTurnStage = null;
  }

  var _inProgrammaticJump = false;

  /// Whether this view is currently driven by programmatic scrolling
  /// (`scrollTo`, `jumpToBottom`, pin animation, or initial positioning).
  bool get isProgrammaticScroll =>
      _inProgrammaticJump ||
      needsInitialBottomJump ||
      pendingPinScroll ||
      (turnPosition?.isTrackingTarget ?? false);

  /// Performs a programmatic `jumpTo` so any resulting [TurnScrollNotification]
  /// reports `isProgrammatic: true`.
  void programmaticJumpTo(TurnScrollPosition pos, double value) {
    _inProgrammaticJump = true;
    try {
      pos.jumpTo(value);
    } finally {
      _inProgrammaticJump = false;
    }
  }

  /// Wraps [child] to dispatch a [TurnScrollNotification] alongside Flutter's
  /// standard [ScrollUpdateNotification] on every scroll update.
  Widget wrapWithTurnNotification(Widget child) =>
      NotificationListener<ScrollUpdateNotification>(
        onNotification: (notification) {
          final metrics = notification.metrics;
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

  /// Callback passed to [TurnScrollScope.onItemLayout].
  void onItemLayout(Object id, double extent, RenderBox box) {
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

  /// Schedules a post-frame pin scroll for [widgetPinnedId].
  void schedulePinScroll() {
    final epoch = ++pinEpoch;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || epoch != pinEpoch || !pinnedActive || !pendingPinScroll) {
        return;
      }
      _runPinScroll();
    });
  }

  void _runPinScroll() {
    final pos = turnPosition;
    if (pos == null || !pos.hasContentDimensions || !pos.hasPixels) {
      if (++_pinRetries <= _maxPinRetries) {
        schedulePinScroll();
      } else {
        pendingPinScroll = false;
      }
      return;
    }
    pendingPinScroll = false;
    _pinRetries = 0;
    final target = pinTargetOffset() ?? pos.maxScrollExtent;
    final animate = !MediaQuery.disableAnimationsOf(context);
    if (!animate) {
      if ((pos.pixels - target).abs() > 0.5) programmaticJumpTo(pos, target);
      return;
    }
    final pinnedId = widgetPinnedId;
    unawaited(
      pos.animateToTarget(
        motion: resolvedMotion,
        vsync: this,
        resolveTarget: () {
          if (!mounted || !pinnedActive || widgetPinnedId != pinnedId) {
            return null;
          }
          return pinTargetOffset() ?? pos.maxScrollExtent;
        },
      ),
    );
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

  /// Applies keyboard/bottom-edge inset anchoring after subclass-specific
  /// dimension adjustments.
  double? applyBottomEdgeDelta({
    required double nextPixels,
    required bool shifted,
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
    if (pendingPinScroll || (pos != null && pos.isTrackingTarget)) {
      return shifted
          ? nextPixels.clamp(minScrollExtent, maxScrollExtent)
          : null;
    }

    if (pinnedActive) {
      final turnStage = activeTurnStage;
      if (turnStage != null &&
          turnStage.attached &&
          turnStage.reservedTrailingSpace > 0.5) {
        return maxScrollExtent;
      }
    }

    return (nextPixels + bottomEdgeDelta).clamp(
      minScrollExtent,
      maxScrollExtent,
    );
  }

  /// Waits for the end of the next frame.
  Future<void> nextFrame() {
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future;
  }

  @override
  void onUserScroll() {
    _setPinnedActive(active: false);
    pendingPinScroll = false;
    needsInitialBottomJump = false;
    pinEpoch++;
    navEpoch++;
  }

  @override
  void onMetricsChanged(double pixels, double maxScrollExtent) {
    turnController.updateBottomDistance(
      maxScrollExtent - pixels,
      threshold: widgetJumpThreshold,
    );
  }
}
