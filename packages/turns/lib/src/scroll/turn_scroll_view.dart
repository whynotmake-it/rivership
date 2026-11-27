import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:turns/src/scroll/turn_scroll_controller.dart';
import 'package:turns/src/scroll/turn_scroll_engine.dart';
import 'package:turns/src/scroll/turn_sliver.dart';

/// Signature for building a section header in [TurnScrollView.sectioned].
///
/// Called with `isPinned: false` when building inline section headers that
/// scroll with the timeline, and `isPinned: true` when building the sticky
/// overlay header pinned at top clearance (when
/// [TurnScrollView.stickySectionHeaders] is `true`).
///
/// Use [isPinned] to adapt presentation between inline and pinned states — for
/// example, rendering a hairline divider inline while floating only a shadowed
/// pill when pinned.
// Callback signature intentionally mirrors Flutter sliver/header builders with
// a trailing positional boolean state flag (`isPinned`).
typedef TurnSectionHeaderBuilder<S> =
    // ignore: avoid_positional_boolean_parameters
    Widget Function(BuildContext context, S section, bool isPinned);

/// A first-principles, turn-anchored bidirectional scroll view built for AI
/// chat transcripts, streaming timelines, and messaging feeds.
///
/// Backed by a two-sliver `Viewport(center:)` for O(1) open at bottom or any
/// [initialItemId], `0.0px`-shift prepend pagination with preserved widget
/// `State`, and single-pass [SliverTurnStage] turn pinning.
///
/// Use the unnamed constructor for flat chronological lists, or
/// [TurnScrollView.sectioned] for typed section headers (e.g. date dividers)
/// with optional scroll-synced sticky push-up headers.
///
/// For arbitrary Flutter sliver compositions (`SliverAppBar`,
/// `SliverMainAxisGroup`, `SliverPersistentHeader`), see
/// `CustomTurnScrollView`.
class TurnScrollView<S extends Object> extends StatefulWidget {
  /// Creates a turn-anchored chronological list with O(1) initial positioning
  /// (at bottom or [initialItemId]) and `0.0px`-shift prepend pagination.
  const TurnScrollView({
    required this.itemCount,
    required this.itemId,
    required this.itemBuilder,
    super.key,
    this.pinnedId,
    this.initialItemId,
    this.initialAlignment = 0,
    this.initialAtBottom = true,
    this.leadingSlivers = const [],
    this.tailSliver,
    this.controller,
    this.padding,
    this.applyTopPadding = true,
    this.applyBottomPadding = true,
    this.itemSpacing = 24,
    this.jumpThreshold = 160,
    this.anchorConfig = TurnAnchorConfig.standard,
    this.autoScrollMotion,
    this.physics,
    this.scrollCacheExtent,
  }) : assert(itemCount >= 0, 'itemCount must be non-negative'),
       assert(itemSpacing >= 0, 'itemSpacing must be non-negative'),
       sectionId = null,
       sectionHeaderBuilder = null,
       stickySectionHeaders = false,
       stickyHeaderIgnoresPointer = true,
       sectionHeaderSpacing = 0;

  /// Creates a turn-anchored chronological list grouped into typed sections of
  /// type [S].
  ///
  /// Inline headers render above each section boundary
  /// (`i == 0 || sectionId(i) != sectionId(i - 1)`) outside [TurnScrollItem] so
  /// [TurnScrollController.scrollTo] lands cleanly below the header.
  ///
  /// When [stickySectionHeaders] is `true`, a scroll-synced header overlay pins
  /// at top clearance, derives the active section from the top visible item
  /// (preserving O(1) open at any [initialItemId]), smoothly pushes up as the
  /// next section's inline header approaches, and hides the underlying inline
  /// header with [Visibility.maintain] while pinned so floating pills never
  /// double-render.
  const TurnScrollView.sectioned({
    required this.itemCount,
    required this.itemId,
    required this.itemBuilder,
    required S Function(int index) this.sectionId,
    required TurnSectionHeaderBuilder<S> this.sectionHeaderBuilder,
    super.key,
    this.stickySectionHeaders = true,
    this.stickyHeaderIgnoresPointer = true,
    this.sectionHeaderSpacing = 0,
    this.pinnedId,
    this.initialItemId,
    this.initialAlignment = 0,
    this.initialAtBottom = true,
    this.leadingSlivers = const [],
    this.tailSliver,
    this.controller,
    this.padding,
    this.applyTopPadding = true,
    this.applyBottomPadding = true,
    this.itemSpacing = 24,
    this.jumpThreshold = 160,
    this.anchorConfig = TurnAnchorConfig.standard,
    this.autoScrollMotion,
    this.physics,
    this.scrollCacheExtent,
  }) : assert(itemCount >= 0, 'itemCount must be non-negative'),
       assert(itemSpacing >= 0, 'itemSpacing must be non-negative'),
       assert(
         sectionHeaderSpacing >= 0,
         'sectionHeaderSpacing must be non-negative',
       );

  /// Total number of items in chronological order (oldest first).
  final int itemCount;

  /// Stable, cheap identity for the item at `index`.
  final Object Function(int index) itemId;

  /// Builds the item widget at `index`.
  final IndexedWidgetBuilder itemBuilder;

  /// Optional section key for the item at `index` (set by
  /// [TurnScrollView.sectioned]).
  final S Function(int index)? sectionId;

  /// Builds the inline (`isPinned: false`) and sticky overlay
  /// (`isPinned: true`) header widget for a section (set by
  /// [TurnScrollView.sectioned]).
  ///
  /// When [stickySectionHeaders] is `true`, the sticky overlay is clipped with
  /// [ClipRect] during push-up transitions; floating pills with drop shadows
  /// should include small vertical padding inside the header widget so shadows
  /// are not clipped.
  final TurnSectionHeaderBuilder<S>? sectionHeaderBuilder;

  /// Whether to pin the active section header at the top clearance while
  /// scrolling.
  final bool stickySectionHeaders;

  /// Whether the sticky section header overlay ignores pointer events so touch
  /// drags over floating date pills scroll the underlying list smoothly.
  ///
  /// Defaults to `true`. Set to `false` if section headers contain interactive
  /// controls.
  final bool stickyHeaderIgnoresPointer;

  /// Vertical gap between a section header and the first item in that section.
  final double sectionHeaderSpacing;

  /// Identity of the active turn's anchor item (e.g. the newest user message),
  /// or `null` when no turn is pinned / reserving trailing space.
  final Object? pinnedId;

  /// Optional item identity to open directly on in O(1).
  final Object? initialItemId;

  /// Usable-viewport alignment (`0.0` top .. `1.0` bottom) for [initialItemId].
  final double initialAlignment;

  /// Whether a fresh non-empty list opens scrolled to the bottom (when no
  /// [pinnedId] or [initialItemId] is set).
  final bool initialAtBottom;

  /// Optional full-bleed slivers placed above item `0` (in natural
  /// top-to-bottom order; reverse-growth ordering is handled internally).
  ///
  /// Unlike [tailSliver], [leadingSlivers] are inserted without horizontal
  /// [padding] so full-bleed banners and headers span the full viewport width.
  final List<Widget> leadingSlivers;

  /// Optional trailing sliver rendered directly below the last item, wrapped
  /// in the horizontal content [padding].
  final Widget? tailSliver;

  /// Optional controller exposing [TurnScrollController.jumpToBottom],
  /// [TurnScrollController.scrollTo], [TurnScrollController.isAwayFromBottom],
  /// [TurnScrollController.distanceFromBottom], and
  /// [TurnScrollController.isPinActive].
  final TurnScrollController? controller;

  /// Content padding added on top of `MediaQuery.paddingOf(context)` and
  /// `MediaQuery.viewInsetsOf(context).bottom`.
  final EdgeInsetsGeometry? padding;

  /// Whether to add `MediaQuery.paddingOf(context).top` on top of
  /// `padding.top`.
  ///
  /// Set `false` when an outer scaffold or header already consumed the top
  /// safe-area inset. Explicit `padding.top` is always preserved and kept in
  /// sync between the top spacer, [TurnScrollScope.topClearance], and sticky
  /// section headers.
  final bool applyTopPadding;

  /// Whether to add `max(MediaQuery.paddingOf(context).bottom,
  /// MediaQuery.viewInsetsOf(context).bottom)` on top of `padding.bottom`.
  ///
  /// Set `false` when an outer widget already accounts for bottom safe area or
  /// keyboard insets. Explicit `padding.bottom` (such as a floating composer's
  /// measured height) is always preserved.
  final bool applyBottomPadding;

  /// Vertical spacing between consecutive items.
  final double itemSpacing;

  /// Distance above the bottom at which [TurnScrollController.isAwayFromBottom]
  /// becomes `true`.
  final double jumpThreshold;

  /// Controls where a pinned anchor rests within the usable viewport and how
  /// much trailing space is preserved below tall anchors.
  ///
  /// Forwarded to the internal [SliverTurnStage]. Defaults to
  /// [TurnAnchorConfig.standard].
  final TurnAnchorConfig anchorConfig;

  /// Motor spring used for automatic and programmatic scroll flights
  /// (`pinnedId`, `scrollTo`, and `jumpToBottom`).
  ///
  /// This controls only automatic scroll animations and never affects user drag
  /// [physics]. Under `MediaQuery.disableAnimationsOf(context)`, all
  /// transitions jump instantaneously.
  final Motion? autoScrollMotion;

  /// Optional custom scroll physics.
  final ScrollPhysics? physics;

  /// Optional viewport cache extent.
  final ScrollCacheExtent? scrollCacheExtent;

  bool get _isSectioned => sectionId != null && sectionHeaderBuilder != null;

  @override
  State<TurnScrollView<S>> createState() => TurnScrollViewState<S>();
}

@immutable
class _StickyHeaderState<S extends Object> {
  const _StickyHeaderState({
    this.section,
    this.hiddenHeaderItemId,
    this.pushOffset = 0,
  });

  final S? section;
  final Object? hiddenHeaderItemId;
  final double pushOffset;

  @override
  bool operator ==(Object other) =>
      other is _StickyHeaderState<S> &&
      other.section == section &&
      other.hiddenHeaderItemId == hiddenHeaderItemId &&
      (other.pushOffset - pushOffset).abs() <= 0.25;

  @override
  int get hashCode =>
      Object.hash(section, hiddenHeaderItemId, pushOffset.round());
}

/// State of [TurnScrollView].
class TurnScrollViewState<S extends Object> extends State<TurnScrollView<S>>
    with
        FixedTickerProviderStateMixin<TurnScrollView<S>>,
        TurnScrollEngineMixin<TurnScrollView<S>> {
  static const _initialTailWindow = 12;
  static const _maxInitialPasses = 4;

  final _topKey = GlobalKey(debugLabel: 'TurnScrollView.top');
  final _belowKey = GlobalKey(debugLabel: 'TurnScrollView.below');
  final _belowListKey = GlobalKey(debugLabel: 'TurnScrollView.belowList');
  final _afterListKey = GlobalKey(debugLabel: 'TurnScrollView.afterList');

  /// Split index between above-center (reverse) and below-center (forward)
  /// slivers.
  var _centerIndex = 0;
  Object? _centerItemId;
  var _builtWithAbove = false;

  /// Hint map from item id to its last-built index for O(1) index resolution.
  final _indexHints = <Object, int>{};

  /// Measured inline section header heights keyed by the section's first item
  /// id.
  final _sectionHeaderExtents = <Object, double>{};

  /// Currently attached inline section header boxes keyed by first item id.
  final _mountedSectionHeaders = <Object, RenderBox>{};

  /// Measured height of the active sticky overlay header.
  double _stickyHeaderHeight = 0;

  /// Reactive sticky header state driving the overlay and `Visibility.maintain`
  /// on underlying inline headers.
  final _stickyState = ValueNotifier<_StickyHeaderState<S>>(
    const _StickyHeaderState(),
  );
  var _stickySyncScheduled = false;
  TurnScrollController? _stickyListenedController;

  /// One-shot pixel adjustment applied in [adjustPixelsOnDimensions] when
  /// the viewport center key moves between `_topKey` and `_belowKey` (or items
  /// move across `_centerIndex`) so visible items stay frozen to 0.0px.
  double _pendingCenterShift = 0;

  /// Last measured total scroll extent of [TurnScrollView.leadingSlivers],
  /// used as a fallback if reverse-side leading slivers have not been laid out
  /// yet when computing center shifts or split-0 coordinate estimates.
  double _lastLeadingExtent = 0;

  /// One-shot synchronous pixel offset applied on recenter
  /// (`scrollTo(animate: false)`).
  double? _pendingInstantOffset;
  ({Object id, double alignment})? _pendingInitialAlign;

  @override
  TurnScrollController? get widgetController => widget.controller;

  @override
  Object? get widgetPinnedId => widget.pinnedId;

  @override
  double get widgetJumpThreshold => widget.jumpThreshold;

  @override
  Motion? get widgetAutoScrollMotion => widget.autoScrollMotion;

  @override
  TurnAnchorConfig get effectiveAnchorConfig =>
      activeTurnStage?.anchorConfig ?? widget.anchorConfig;

  @override
  EdgeInsetsGeometry? get widgetPadding => widget.padding;

  @override
  bool canPinId(Object id) => _indexOfId(id) >= 0;

  @override
  double get extraTopObstruction {
    if (!_hasStickyHeaders) return 0;
    final h = _stickyHeaderHeight > 0
        ? _stickyHeaderHeight
        : _meanSectionHeaderExtent;
    return h + widget.sectionHeaderSpacing;
  }

  double get _topSpacer => effectiveTop;

  double get _bottomSpacer => effectiveBottom;

  bool get _hasStickyHeaders =>
      widget._isSectioned && widget.stickySectionHeaders;

  @override
  void initState() {
    super.initState();
    _initCenter(initial: true);
    initEngine();
    _syncStickyListener();
    _seedInitialStickyState();
    if (_hasStickyHeaders) {
      _scheduleStickySync();
    }
  }

  @override
  void didUpdateWidget(TurnScrollView<S> oldWidget) {
    super.didUpdateWidget(oldWidget);
    updateEngineController(oldWidget.controller);
    _syncStickyListener();
    _reconcileCenter(oldWidget);
    updateEnginePinnedId(
      oldWidget.pinnedId,
      onPinActivated: () => _pendingInitialAlign = null,
    );
    if (_hasStickyHeaders) {
      if (widget.itemCount == 0) {
        _setStickyState(const _StickyHeaderState());
      } else {
        _scheduleStickySync();
      }
    } else if (_stickyState.value.section != null ||
        _stickyState.value.hiddenHeaderItemId != null) {
      _setStickyState(const _StickyHeaderState());
    }
  }

  @override
  void dispose() {
    _detachStickyListener();
    _stickyState.dispose();
    _mountedSectionHeaders.clear();
    _indexHints.clear();
    disposeEngine();
    super.dispose();
  }

  void _syncStickyListener() {
    final desired = _hasStickyHeaders ? turnController : null;
    if (identical(_stickyListenedController, desired)) return;
    _detachStickyListener();
    if (desired != null) {
      desired.addListener(_onScrollForSticky);
      _stickyListenedController = desired;
    }
  }

  void _detachStickyListener() {
    _stickyListenedController?.removeListener(_onScrollForSticky);
    _stickyListenedController = null;
  }

  void _seedInitialStickyState() {
    if (!_hasStickyHeaders || widget.itemCount == 0) return;
    final sectionOf = widget.sectionId!;
    if (widget.initialItemId case final initId?) {
      final idx = _indexOfId(initId);
      if (idx >= 0) {
        final hidden = _isSectionStart(idx) && widget.initialAlignment <= 0
            ? initId
            : null;
        _stickyState.value = _StickyHeaderState<S>(
          section: sectionOf(idx),
          hiddenHeaderItemId: hidden,
        );
        return;
      }
    }
    if (!widget.initialAtBottom &&
        widget.pinnedId == null &&
        widget.leadingSlivers.isEmpty) {
      _stickyState.value = _StickyHeaderState<S>(
        section: sectionOf(0),
        hiddenHeaderItemId: widget.itemId(0),
      );
    }
  }

  void _onScrollForSticky() {
    if (!_hasStickyHeaders || !mounted) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      _scheduleStickySync();
      return;
    }
    _syncStickyHeader();
  }

  void _scheduleStickySync() {
    if (_stickySyncScheduled || !_hasStickyHeaders) return;
    _stickySyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _stickySyncScheduled = false;
      if (!mounted || !_hasStickyHeaders) return;
      _syncStickyHeader();
    });
  }

  void _setStickyState(_StickyHeaderState<S> next) {
    if (_stickyState.value == next) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      _scheduleStickySync();
      return;
    }
    _stickyState.value = next;
  }

  bool _isSectionStart(int index) {
    final sectionOf = widget.sectionId;
    if (sectionOf == null || index < 0 || index >= widget.itemCount) {
      return false;
    }
    return index == 0 || sectionOf(index) != sectionOf(index - 1);
  }

  double get _meanSectionHeaderExtent {
    if (_sectionHeaderExtents.isEmpty) return 32;
    var sum = 0.0;
    for (final v in _sectionHeaderExtents.values) {
      sum += v;
    }
    return sum / _sectionHeaderExtents.length;
  }

  double _sectionHeaderExtraFor(int index) {
    if (!_isSectionStart(index)) return 0;
    final id = widget.itemId(index);
    final h = _sectionHeaderExtents[id] ?? _meanSectionHeaderExtent;
    return h + widget.sectionHeaderSpacing;
  }

  void _onSectionHeaderLayout(Object itemId, double height, RenderBox box) {
    _sectionHeaderExtents[itemId] = height;
    _mountedSectionHeaders[itemId] = box;
    if (_hasStickyHeaders) _scheduleStickySync();
  }

  void _onSectionHeaderDetach(Object itemId, RenderBox box) {
    if (identical(_mountedSectionHeaders[itemId], box)) {
      _mountedSectionHeaders.remove(itemId);
    }
  }

  void _onStickyHeaderHeight(double height) {
    if ((_stickyHeaderHeight - height).abs() > 0.25) {
      _stickyHeaderHeight = height;
      if (_hasStickyHeaders) _scheduleStickySync();
    }
  }

  @override
  void onItemLayout(Object id, double extent, RenderBox box) {
    super.onItemLayout(id, extent, box);
    if (_hasStickyHeaders) _scheduleStickySync();
  }

  void _syncStickyHeader() {
    if (!_hasStickyHeaders) return;
    final count = widget.itemCount;
    if (count == 0) {
      _setStickyState(const _StickyHeaderState());
      return;
    }
    final pos = turnPosition;
    if (pos == null || !pos.hasPixels || !pos.hasViewportDimension) return;

    final pixels = pos.pixels;
    final pinY = effectiveTop;
    final sectionOf = widget.sectionId!;

    final entries =
        <({int index, Object id, double slotTop, bool hasHeader})>[];

    for (final MapEntry(key: id, value: box) in mountedBoxes.entries) {
      if (!box.attached || !box.hasSize || isKeptAliveOffscreen(box)) continue;
      final viewport = RenderAbstractViewport.maybeOf(box);
      if (viewport == null) continue;
      final idx = _indexOfId(id, hint: _indexHints[id]);
      if (idx < 0) continue;
      _indexHints[id] = idx;

      final headerBox = _mountedSectionHeaders[id];
      final hasHeader =
          headerBox != null &&
          headerBox.attached &&
          headerBox.hasSize &&
          !isKeptAliveOffscreen(headerBox);
      final leadBox = hasHeader ? headerBox : box;
      final leadViewport = RenderAbstractViewport.maybeOf(leadBox);
      if (leadViewport == null) continue;
      final slotTop =
          leadViewport.getOffsetToReveal(leadBox, 0).offset - pixels;
      entries.add((
        index: idx,
        id: id,
        slotTop: slotTop,
        hasHeader: hasHeader,
      ));
    }

    if (entries.isEmpty) return;
    entries.sort((a, b) => a.index.compareTo(b.index));

    var activePos = -1;
    for (var i = 0; i < entries.length; i++) {
      if (entries[i].slotTop <= pinY + 0.5) {
        activePos = i;
      } else {
        break;
      }
    }

    if (activePos < 0) {
      final first = entries.first;
      if (first.index == 0) {
        // Item 0's inline header sits below topClearance (e.g. leadingSlivers
        // or overscroll pull-down): show no sticky overlay.
        _setStickyState(const _StickyHeaderState());
        return;
      }
      final activeSection = sectionOf(first.index - 1);
      final pushOffset = _computePushOffset(
        entries: entries,
        startFrom: 0,
        pinY: pinY,
        fallbackHeight: _meanSectionHeaderExtent,
      );
      _setStickyState(
        _StickyHeaderState<S>(
          section: activeSection,
          pushOffset: pushOffset,
        ),
      );
      return;
    }

    final activeEntry = entries[activePos];
    final activeSection = sectionOf(activeEntry.index);

    Object? hiddenHeaderItemId;
    for (var i = activePos; i >= 0; i--) {
      final e = entries[i];
      if (sectionOf(e.index) != activeSection) break;
      if (e.hasHeader && e.slotTop <= pinY + 0.5) {
        hiddenHeaderItemId = e.id;
        break;
      }
    }

    final fallbackHeight =
        (hiddenHeaderItemId != null
            ? _sectionHeaderExtents[hiddenHeaderItemId]
            : null) ??
        _meanSectionHeaderExtent;
    final pushOffset = _computePushOffset(
      entries: entries,
      startFrom: activePos + 1,
      pinY: pinY,
      fallbackHeight: fallbackHeight,
    );

    _setStickyState(
      _StickyHeaderState<S>(
        section: activeSection,
        hiddenHeaderItemId: hiddenHeaderItemId,
        pushOffset: pushOffset,
      ),
    );
  }

  double _computePushOffset({
    required List<({int index, Object id, double slotTop, bool hasHeader})>
    entries,
    required int startFrom,
    required double pinY,
    required double fallbackHeight,
  }) {
    for (var i = startFrom; i < entries.length; i++) {
      final e = entries[i];
      if (!e.hasHeader) continue;
      final stickyH = _stickyHeaderHeight > 0
          ? _stickyHeaderHeight
          : fallbackHeight;
      if (e.slotTop < pinY + stickyH) {
        return (e.slotTop - (pinY + stickyH)).clamp(-stickyH, 0);
      }
      return 0;
    }
    return 0;
  }

  void _initCenter({required bool initial}) {
    _pendingCenterShift = 0;
    _pendingInstantOffset = null;
    _pendingInitialAlign = null;
    initialBottomPasses = 0;

    final count = widget.itemCount;
    if (count == 0) {
      _centerIndex = 0;
      _centerItemId = null;
      _builtWithAbove = false;
      needsInitialBottomJump = false;
      lastUsableBottom = null;
      return;
    }

    final pinnedIndex = widget.pinnedId == null
        ? -1
        : _indexOfId(widget.pinnedId!);
    final initialIndex =
        initial && pinnedIndex < 0 && widget.initialItemId != null
        ? _indexOfId(widget.initialItemId!)
        : -1;

    final openAtTop =
        !widget.initialAtBottom && initialIndex < 0 && pinnedIndex < 0;
    var index = initialIndex >= 0
        ? initialIndex
        : (openAtTop || count <= _initialTailWindow
              ? 0
              : count - _initialTailWindow);
    if (pinnedIndex >= 0 && index > pinnedIndex) {
      index = pinnedIndex;
    }
    _centerIndex = index;
    _centerItemId = widget.itemId(index);
    _builtWithAbove = index > 0;

    if (initialIndex >= 0) {
      needsInitialBottomJump = false;
      _pendingInitialAlign = (
        id: widget.initialItemId!,
        alignment: widget.initialAlignment.clamp(0, 1),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _pendingInitialAlign == null) return;
        final align = _pendingInitialAlign!;
        _pendingInitialAlign = null;
        final pos = turnPosition;
        if (pos == null || !pos.hasContentDimensions) return;
        final exact = exactOffsetFor(
          align.id,
          alignment: align.alignment,
          minScrollExtent: pos.minScrollExtent,
          maxScrollExtent: pos.maxScrollExtent,
          viewportDimension: pos.viewportDimension,
        );
        if (exact != null && (exact - pos.pixels).abs() > 0.5) {
          programmaticJumpTo(pos, exact);
        }
        if (_hasStickyHeaders) _syncStickyHeader();
      });
    } else {
      needsInitialBottomJump =
          initial && widget.initialAtBottom && pinnedIndex < 0;
    }
  }

  void _reconcileCenter(TurnScrollView<S> oldWidget) {
    final count = widget.itemCount;
    if (count == 0) {
      extents.clear();
      _sectionHeaderExtents.clear();
      _indexHints.clear();
      _initCenter(initial: false);
      return;
    }

    if (oldWidget.itemCount == 0 && count > 0) {
      _initCenter(initial: widget.pinnedId == null);
      return;
    }

    final prevId = _centerItemId;
    var nextCenter = -1;
    if (prevId != null) {
      nextCenter = _indexOfId(prevId, hint: _centerIndex);
    }
    if (nextCenter < 0) {
      final sameThread = _hasAnyKnownItem();
      if (!sameThread) {
        extents.clear();
        _sectionHeaderExtents.clear();
        _indexHints.clear();
        _initCenter(initial: widget.pinnedId == null);
        return;
      }
      nextCenter = _centerIndex.clamp(0, count - 1);
    }

    final pinnedIndex = widget.pinnedId == null
        ? -1
        : _indexOfId(widget.pinnedId!);
    if (pinnedIndex >= 0 && nextCenter > pinnedIndex) {
      for (var i = pinnedIndex; i < nextCenter; i++) {
        _pendingCenterShift +=
            _sectionHeaderExtraFor(i) +
            _estimatedExtentOf(i) +
            widget.itemSpacing;
      }
      nextCenter = pinnedIndex;
    }

    final delta = nextCenter - _centerIndex;
    if (delta != 0 && _indexHints.isNotEmpty) {
      _indexHints.updateAll((_, v) => v + delta);
    }

    _centerIndex = nextCenter;
    _centerItemId = widget.itemId(nextCenter);
  }

  bool _hasAnyKnownItem() {
    if (extents.isEmpty) return false;
    final count = widget.itemCount;
    for (var i = count - 1; i >= 0; i--) {
      if (extents.containsKey(widget.itemId(i))) return true;
    }
    return false;
  }

  int _indexOfId(Object id, {int? hint}) {
    final count = widget.itemCount;
    if (count == 0) return -1;
    if (hint != null &&
        hint >= 0 &&
        hint < count &&
        widget.itemId(hint) == id) {
      return hint;
    }
    for (var i = count - 1; i >= 0; i--) {
      if (widget.itemId(i) == id) return i;
    }
    return -1;
  }

  double _estimatedExtentOf(int index) =>
      extents[widget.itemId(index)] ?? meanExtent;

  @override
  void onUserScroll() {
    super.onUserScroll();
    _pendingInstantOffset = null;
    _pendingInitialAlign = null;
  }

  @override
  void onMetricsChanged(double pixels, double maxScrollExtent) {
    super.onMetricsChanged(pixels, maxScrollExtent);
    if (_hasStickyHeaders) _scheduleStickySync();
  }

  /// Returns the rendered total scroll extent of `widget.leadingSlivers`
  /// between `_topKey` and the `above` sliver, falling back to the last
  /// measured value when slivers are not yet attached/laid out.
  double _leadingSliversExtent() {
    if (widget.leadingSlivers.isEmpty) {
      _lastLeadingExtent = 0;
      return 0;
    }
    final topSliver = _topKey.currentContext?.findRenderObject();
    final belowSliver = _belowKey.currentContext?.findRenderObject();
    if (topSliver is RenderSliver &&
        belowSliver is RenderSliver &&
        topSliver.attached &&
        belowSliver.attached) {
      final parent = belowSliver.parent;
      if (parent is RenderViewport && identical(topSliver.parent, parent)) {
        final aboveSliver = parent.childBefore(belowSliver);
        var extent = 0.0;
        var allLaidOut = true;
        var current = parent.childAfter(topSliver);
        while (current != null && !identical(current, aboveSliver)) {
          final geom = current.geometry;
          if (geom == null) {
            allLaidOut = false;
            break;
          }
          extent += geom.scrollExtent;
          current = parent.childAfter(current);
        }
        if (allLaidOut) {
          _lastLeadingExtent = extent;
          return extent;
        }
      }
    }
    return _lastLeadingExtent;
  }

  /// Reads `_belowKey`'s exact pre-switch scroll offset from `RenderViewport`
  /// (`topSpacer + sum(leadingSlivers.scrollExtent)`) before flipping
  /// `Viewport.center` from `_topKey` to `_belowKey`.
  double _preSwitchBelowOffset(double fallbackTopSpacer) {
    final belowSliver = _belowKey.currentContext?.findRenderObject();
    if (belowSliver is RenderSliver &&
        belowSliver.attached &&
        belowSliver.geometry != null) {
      final parent = belowSliver.parent;
      if (parent is RenderViewport) {
        final offset = parent.scrollOffsetOf(belowSliver, 0);
        if (offset.isFinite) {
          final topSliver = _topKey.currentContext?.findRenderObject();
          final topExtent =
              (topSliver is RenderSliver
                  ? topSliver.geometry?.scrollExtent
                  : null) ??
              fallbackTopSpacer;
          _lastLeadingExtent = math.max(0, offset - topExtent);
          return offset;
        }
      }
    }
    return fallbackTopSpacer + _leadingSliversExtent();
  }

  double _estimatedOffsetFor(
    int index, {
    required double alignment,
    required double minScrollExtent,
    required double maxScrollExtent,
    required double viewportDimension,
    int? centerIndex,
    bool clamp = true,
  }) {
    final split = centerIndex ?? _centerIndex;
    final spacing = widget.itemSpacing;
    var coord = split == 0 ? _topSpacer + _leadingSliversExtent() : 0.0;
    if (index >= split) {
      for (var i = split; i < index; i++) {
        coord += _sectionHeaderExtraFor(i) + _estimatedExtentOf(i) + spacing;
      }
    } else {
      for (var i = split - 1; i >= index; i--) {
        coord -= _sectionHeaderExtraFor(i) + _estimatedExtentOf(i) + spacing;
      }
    }
    coord += _sectionHeaderExtraFor(index);
    final estHeight = _estimatedExtentOf(index);
    final topInset = effectiveTop + extraTopObstruction;
    final usable = math.max<double>(
      0,
      viewportDimension - topInset - effectiveBottom,
    );
    final raw = coord - topInset - alignment * (usable - estHeight);
    return clamp ? raw.clamp(minScrollExtent, maxScrollExtent) : raw;
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

    if (_pendingInitialAlign case final align?) {
      final idx = _indexOfId(align.id);
      if (idx >= 0) {
        final target = _estimatedOffsetFor(
          idx,
          alignment: align.alignment,
          minScrollExtent: minScrollExtent,
          maxScrollExtent: maxScrollExtent,
          viewportDimension: viewportDimension,
        );
        if (align.alignment == 0 &&
            !_isSectionStart(idx) &&
            !_hasStickyHeaders) {
          _pendingInitialAlign = null;
        }
        _pendingCenterShift = 0;
        return target;
      }
      _pendingInitialAlign = null;
    }

    if (_pendingInstantOffset case final offset?) {
      _pendingInstantOffset = null;
      _pendingCenterShift = 0;
      return offset;
    }

    if (needsInitialBottomJump) {
      initialBottomPasses++;
      if (_hasExactBottomExtent() ||
          maxScrollExtent <= minScrollExtent ||
          initialBottomPasses >= _maxInitialPasses) {
        needsInitialBottomJump = false;
      }
      _pendingCenterShift = 0;
      return maxScrollExtent;
    }

    var nextPixels = pixels;
    var shifted = false;
    if (_pendingCenterShift != 0) {
      nextPixels += _pendingCenterShift;
      _pendingCenterShift = 0;
      shifted = true;
    }

    return applyBottomEdgeDelta(
      nextPixels: nextPixels,
      shifted: shifted,
      prevUsableBottom: prevUsableBottom,
      usableBottom: usableBottom,
      minScrollExtent: minScrollExtent,
      maxScrollExtent: maxScrollExtent,
    );
  }

  bool _sliverListReachedEnd(
    GlobalKey listKey,
    int childCount, {
    bool requirePositiveExtent = false,
  }) {
    if (childCount <= 0) return true;
    final list = listKey.currentContext?.findRenderObject();
    if (list is! RenderSliverList) return false;
    final last = list.lastChild;
    if (last == null || list.indexOf(last) != childCount - 1) return false;
    if (requirePositiveExtent && (list.geometry?.scrollExtent ?? 0) <= 0) {
      return false;
    }
    return true;
  }

  bool _hasExactBottomExtent() {
    final count = widget.itemCount;
    if (count == 0) return true;
    final lastId = widget.itemId(count - 1);
    final lastBox = mountedBoxes[lastId];
    if (lastBox == null ||
        !lastBox.attached ||
        !lastBox.hasSize ||
        isKeptAliveOffscreen(lastBox)) {
      return false;
    }

    final pinnedIndex = widget.pinnedId == null
        ? -1
        : _indexOfId(widget.pinnedId!);
    final centerIndex = _centerIndex.clamp(
      0,
      pinnedIndex >= 0 ? pinnedIndex : count - 1,
    );
    final belowPrePinEnd = pinnedIndex >= 0 ? pinnedIndex : count;
    final belowPrePinCount = math.max(0, belowPrePinEnd - centerIndex);

    if (!_sliverListReachedEnd(_belowListKey, belowPrePinCount)) return false;
    if (pinnedIndex >= 0) {
      final afterPinCount = math.max(0, count - pinnedIndex - 1);
      if (!_sliverListReachedEnd(
        _afterListKey,
        afterPinCount,
        requirePositiveExtent: true,
      )) {
        return false;
      }
    }
    return true;
  }

  double? _cachedBottomOffset(TurnScrollPosition pos) {
    final count = widget.itemCount;
    if (count == 0) return pos.minScrollExtent;
    final pinnedIndex = widget.pinnedId == null
        ? -1
        : _indexOfId(widget.pinnedId!);
    final centerIndex = _centerIndex.clamp(
      0,
      pinnedIndex >= 0 ? pinnedIndex : count - 1,
    );
    final belowPrePinEnd = pinnedIndex >= 0 ? pinnedIndex : count;
    final spacing = widget.itemSpacing;

    double? sectionExtra(int index) {
      if (!_isSectionStart(index)) return 0;
      final h = _sectionHeaderExtents[widget.itemId(index)];
      if (h == null) return null;
      return h + widget.sectionHeaderSpacing;
    }

    var total = centerIndex == 0 ? _topSpacer + _leadingSliversExtent() : 0.0;
    for (var i = centerIndex; i < belowPrePinEnd; i++) {
      final h = extents[widget.itemId(i)];
      final sh = sectionExtra(i);
      if (h == null || sh == null) return null;
      final isLastBeforePin = pinnedIndex >= 0 && i == pinnedIndex - 1;
      final hasNext = i < belowPrePinEnd - 1 || isLastBeforePin;
      total += sh + h + (hasNext ? spacing : 0);
    }

    if (pinnedIndex >= 0) {
      final pinSectionH = sectionExtra(pinnedIndex);
      final anchorH = extents[widget.itemId(pinnedIndex)];
      if (pinSectionH == null || anchorH == null) return null;
      total += pinSectionH;
      var actualTurn = anchorH;
      for (var i = pinnedIndex + 1; i < count; i++) {
        final h = extents[widget.itemId(i)];
        final sh = sectionExtra(i);
        if (h == null || sh == null) return null;
        actualTurn += spacing + sh + h;
      }
      final usable = math.max<double>(
        0,
        pos.viewportDimension - effectiveTop - effectiveBottom,
      );
      final minTurn = RenderSliverTurnStage.computeMinExtent(
        usableExtent: usable,
        anchorExtent: anchorH,
        anchorConfig: widget.anchorConfig,
      );
      total += math.max(minTurn, actualTurn);
    }

    total += _bottomSpacer;
    return math.max(pos.minScrollExtent, total - pos.viewportDimension);
  }

  @override
  Future<bool> jumpToBottom({required bool animate, Motion? motion}) async {
    final pos = turnPosition;
    if (pos == null || !pos.hasContentDimensions) return false;
    if (widget.itemCount == 0) return false;

    onUserScroll();
    final epoch = navEpoch;

    final shouldAnimate = animate && !MediaQuery.disableAnimationsOf(context);
    final flightMotion = motion ?? resolvedMotion;

    if (!shouldAnimate) {
      if (_hasExactBottomExtent()) {
        programmaticJumpTo(pos, pos.maxScrollExtent);
        return true;
      }
      final count = widget.itemCount;
      final pinnedIndex = widget.pinnedId == null
          ? -1
          : _indexOfId(widget.pinnedId!);
      final tailStart = count <= _initialTailWindow
          ? 0
          : count - _initialTailWindow;
      final nextCenter = pinnedIndex >= 0
          ? math.min(tailStart, pinnedIndex)
          : tailStart;
      if (nextCenter != _centerIndex) {
        setState(() {
          _centerIndex = nextCenter;
          _centerItemId = widget.itemId(nextCenter);
          _builtWithAbove = nextCenter > 0;
          _pendingCenterShift = 0;
          needsInitialBottomJump = true;
          initialBottomPasses = 0;
        });
        await nextFrame();
        if (!mounted || epoch != navEpoch || !pos.hasContentDimensions) {
          return false;
        }
      }
      programmaticJumpTo(pos, pos.maxScrollExtent);
      return mounted && epoch == navEpoch;
    }

    double? frozenTarget;
    if (_hasExactBottomExtent()) {
      frozenTarget = pos.maxScrollExtent;
    }

    final arrived = await pos.animateToTarget(
      motion: flightMotion,
      vsync: this,
      resolveTarget: () {
        if (!mounted || epoch != navEpoch || !pos.hasContentDimensions) {
          return null;
        }
        if (frozenTarget != null) return frozenTarget;
        if (_hasExactBottomExtent()) {
          return frozenTarget = pos.maxScrollExtent;
        }
        return _cachedBottomOffset(pos) ?? pos.maxScrollExtent;
      },
    );
    return arrived && mounted && epoch == navEpoch;
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
    final targetIndex = _indexOfId(itemId);
    if (targetIndex < 0) return false;

    onUserScroll();
    final epoch = navEpoch;

    final shouldAnimate = animate && !MediaQuery.disableAnimationsOf(context);
    final flightMotion = motion ?? resolvedMotion;
    final clampedAlignment = alignment.clamp(0.0, 1.0);

    double? exact(Object id) => exactOffsetFor(
      id,
      alignment: clampedAlignment,
      minScrollExtent: pos.minScrollExtent,
      maxScrollExtent: pos.maxScrollExtent,
      viewportDimension: pos.viewportDimension,
    );

    double estimated(int index) {
      final ex = exact(itemId);
      if (ex != null) return ex;
      return _estimatedOffsetFor(
        index,
        alignment: clampedAlignment,
        minScrollExtent: pos.minScrollExtent,
        maxScrollExtent: pos.maxScrollExtent,
        viewportDimension: pos.viewportDimension,
      );
    }

    if (!shouldAnimate) {
      final ex = exact(itemId);
      if (ex != null) {
        programmaticJumpTo(pos, ex);
        return true;
      }

      final pinnedIndex = widget.pinnedId == null
          ? -1
          : _indexOfId(widget.pinnedId!);
      final nextCenter = pinnedIndex >= 0
          ? math.min(targetIndex, pinnedIndex)
          : targetIndex;
      if (nextCenter != _centerIndex) {
        final initialOffset = _estimatedOffsetFor(
          targetIndex,
          alignment: clampedAlignment,
          minScrollExtent: pos.minScrollExtent,
          maxScrollExtent: pos.maxScrollExtent,
          viewportDimension: pos.viewportDimension,
          centerIndex: nextCenter,
          clamp: false,
        );

        pos.correctPixels(initialOffset);
        setState(() {
          _centerIndex = nextCenter;
          _centerItemId = widget.itemId(nextCenter);
          _builtWithAbove = nextCenter > 0;
          _pendingCenterShift = 0;
          _pendingInstantOffset = initialOffset;
        });
        await nextFrame();
        if (!mounted || epoch != navEpoch || !pos.hasContentDimensions) {
          return false;
        }
      }
      final refined = estimated(targetIndex);
      if ((refined - pos.pixels).abs() > 0.5) {
        programmaticJumpTo(pos, refined);
      }
      _pendingInstantOffset = null;
      return mounted && epoch == navEpoch;
    }

    final arrived = await pos.animateToTarget(
      motion: flightMotion,
      vsync: this,
      resolveTarget: () {
        if (!mounted || epoch != navEpoch || !pos.hasContentDimensions) {
          return null;
        }
        final currentIndex = _indexOfId(itemId, hint: targetIndex);
        if (currentIndex < 0) return null;
        return estimated(currentIndex);
      },
    );
    return arrived && mounted && epoch == navEpoch;
  }

  Widget _buildInlineHeader(BuildContext context, int index, Object itemId) {
    final section = widget.sectionId!(index);
    final header = widget.sectionHeaderBuilder!(context, section, false);
    var content = header;
    if (_hasStickyHeaders) {
      content = ValueListenableBuilder<_StickyHeaderState<S>>(
        valueListenable: _stickyState,
        builder: (context, sticky, child) => Visibility.maintain(
          visible: sticky.hiddenHeaderItemId != itemId,
          child: child!,
        ),
        child: header,
      );
    }
    return TurnItemExtentObserver(
      itemId: itemId,
      onLayout: _onSectionHeaderLayout,
      onDetach: _onSectionHeaderDetach,
      child: content,
    );
  }

  Widget _buildObservedItem(
    BuildContext context,
    int index, {
    required double topGap,
    required double bottomGap,
    bool includeInlineHeader = true,
  }) {
    final id = widget.itemId(index);
    _indexHints[id] = index;
    Widget child = TurnScrollItem(
      id: id,
      child: widget.itemBuilder(context, index),
    );
    if (includeInlineHeader && _isSectionStart(index)) {
      child = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildInlineHeader(context, index, id),
          if (widget.sectionHeaderSpacing > 0)
            SizedBox(height: widget.sectionHeaderSpacing),
          child,
        ],
      );
    }
    if (topGap > 0 || bottomGap > 0) {
      child = Padding(
        padding: EdgeInsets.only(top: topGap, bottom: bottomGap),
        child: child,
      );
    }
    return KeyedSubtree(key: ValueKey(id), child: child);
  }

  (List<Widget> slivers, Key? center) _buildSlivers() {
    final horizontal = EdgeInsets.only(
      left: effectiveLeft,
      right: effectiveRight,
    );
    final count = widget.itemCount;
    final pinnedIndex = widget.pinnedId == null
        ? -1
        : _indexOfId(widget.pinnedId!);
    final centerIndex = count == 0
        ? 0
        : _centerIndex.clamp(
            0,
            pinnedIndex >= 0 ? pinnedIndex : count - 1,
          );
    final aboveCount = centerIndex;
    final belowPrePinEnd = pinnedIndex >= 0 ? pinnedIndex : count;
    final belowPrePinCount = math.max(0, belowPrePinEnd - centerIndex);
    final afterPinCount = pinnedIndex >= 0
        ? math.max(0, count - pinnedIndex - 1)
        : 0;

    final spacing = widget.itemSpacing;
    final topSpacer = _topSpacer;
    final bottomSpacer = _bottomSpacer;
    final hasAbove = aboveCount > 0;
    if (!_builtWithAbove && hasAbove) {
      _pendingCenterShift -= _preSwitchBelowOffset(topSpacer);
    } else if (_builtWithAbove && !hasAbove) {
      _pendingCenterShift += topSpacer + _leadingSliversExtent();
    }
    _builtWithAbove = hasAbove;

    final leading = hasAbove
        ? widget.leadingSlivers.reversed
        : widget.leadingSlivers;
    final pinnedHasInlineHeader =
        pinnedIndex >= 0 && _isSectionStart(pinnedIndex);

    final slivers = <Widget>[
      SliverToBoxAdapter(
        key: _topKey,
        child: SizedBox(height: topSpacer),
      ),

      ...leading,

      SliverPadding(
        key: const ValueKey('TurnScrollView.above'),
        padding: horizontal,
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, reverseIndex) {
              final index = centerIndex - 1 - reverseIndex;
              return _buildObservedItem(
                context,
                index,
                topGap: 0,
                bottomGap: spacing,
              );
            },
            childCount: aboveCount,
          ),
        ),
      ),

      SliverPadding(
        key: _belowKey,
        padding: horizontal,
        sliver: SliverList(
          key: _belowListKey,
          delegate: SliverChildBuilderDelegate(
            (context, localIndex) {
              final index = centerIndex + localIndex;
              final isLastBeforePin =
                  pinnedIndex >= 0 && index == pinnedIndex - 1;
              final hasNext = index < belowPrePinEnd - 1 || isLastBeforePin;
              return _buildObservedItem(
                context,
                index,
                topGap: 0,
                bottomGap: hasNext ? spacing : 0,
              );
            },
            childCount: belowPrePinCount,
          ),
        ),
      ),

      if (pinnedHasInlineHeader)
        SliverPadding(
          padding: EdgeInsets.only(
            left: effectiveLeft,
            right: effectiveRight,
            bottom: widget.sectionHeaderSpacing,
          ),
          sliver: SliverToBoxAdapter(
            child: Builder(
              builder: (context) => _buildInlineHeader(
                context,
                pinnedIndex,
                widget.itemId(pinnedIndex),
              ),
            ),
          ),
        ),

      if (pinnedIndex >= 0)
        SliverTurnStage(
          anchorConfig: widget.anchorConfig,
          anchorSliver: SliverPadding(
            padding: horizontal,
            sliver: SliverToBoxAdapter(
              child: Builder(
                builder: (context) => _buildObservedItem(
                  context,
                  pinnedIndex,
                  topGap: 0,
                  bottomGap: 0,
                  includeInlineHeader: false,
                ),
              ),
            ),
          ),
          afterSliver: SliverPadding(
            padding: horizontal,
            sliver: SliverList(
              key: _afterListKey,
              delegate: SliverChildBuilderDelegate(
                (context, localIndex) {
                  final index = pinnedIndex + 1 + localIndex;
                  return _buildObservedItem(
                    context,
                    index,
                    topGap: spacing,
                    bottomGap: 0,
                  );
                },
                childCount: afterPinCount,
              ),
            ),
          ),
          tailSliver: widget.tailSliver == null
              ? null
              : SliverPadding(
                  padding: horizontal,
                  sliver: widget.tailSliver,
                ),
        )
      else if (widget.tailSliver != null)
        SliverPadding(
          padding: horizontal,
          sliver: widget.tailSliver,
        ),

      if (bottomSpacer > 0)
        SliverToBoxAdapter(child: SizedBox(height: bottomSpacer)),
    ];

    return (slivers, hasAbove ? _belowKey : _topKey);
  }

  @override
  Widget build(BuildContext context) {
    resolveClearances(
      context,
      applyTopPadding: widget.applyTopPadding,
      applyBottomPadding: widget.applyBottomPadding,
    );
    final (slivers, center) = _buildSlivers();

    Widget scrollView = CustomScrollView(
      controller: turnController,
      center: center,
      physics: widget.physics,
      scrollCacheExtent: widget.scrollCacheExtent,
      slivers: slivers,
    );

    if (_hasStickyHeaders) {
      scrollView = Stack(
        fit: StackFit.passthrough,
        children: [
          scrollView,
          Positioned(
            top: effectiveTop,
            left: effectiveLeft,
            right: effectiveRight,
            child: IgnorePointer(
              ignoring: widget.stickyHeaderIgnoresPointer,
              child: ValueListenableBuilder<_StickyHeaderState<S>>(
                valueListenable: _stickyState,
                builder: (context, sticky, _) {
                  final section = sticky.section;
                  if (section == null) return const SizedBox.shrink();
                  return ClipRect(
                    child: Transform.translate(
                      offset: Offset(0, sticky.pushOffset),
                      child: _StickyHeightObserver(
                        onHeight: _onStickyHeaderHeight,
                        child: widget.sectionHeaderBuilder!(
                          context,
                          section,
                          true,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      );
    }

    return TurnScrollScope(
      topClearance: effectiveTop,
      bottomClearance: effectiveBottom,
      onItemLayout: onItemLayout,
      onItemDetach: onItemDetach,
      onTurnStageAttach: onTurnStageAttach,
      onTurnStageDetach: onTurnStageDetach,
      child: wrapWithTurnNotification(scrollView),
    );
  }
}

class _StickyHeightObserver extends SingleChildRenderObjectWidget {
  const _StickyHeightObserver({
    required this.onHeight,
    required super.child,
  });

  final ValueChanged<double> onHeight;

  @override
  _RenderStickyHeightObserver createRenderObject(BuildContext context) =>
      _RenderStickyHeightObserver(onHeight: onHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderStickyHeightObserver renderObject,
  ) {
    renderObject.onHeight = onHeight;
  }
}

class _RenderStickyHeightObserver extends RenderProxyBox {
  _RenderStickyHeightObserver({required this.onHeight});

  ValueChanged<double> onHeight;

  @override
  void performLayout() {
    super.performLayout();
    onHeight(size.height);
  }
}
