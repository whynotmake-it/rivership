import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/src/drag/flight.dart';
import 'package:motor_widgets/src/drag/motion_drag_probe.dart';
import 'package:motor_widgets/src/drag/motion_draggable.dart';
import 'package:motor_widgets/src/drag/motion_edge_scroll.dart';
import 'package:motor_widgets/src/painted_position.dart';
import 'package:motor_widgets/src/reorder/motion_reorder.dart';

/// Builds a [MotionDropZone]'s list from its [slots].
typedef MotionDropZoneBuilder<T extends Object> =
    Widget Function(BuildContext context, MotionDropSlots<T> slots);

/// Builds the widget for one item of a [MotionDropZone].
typedef MotionDropItemBuilder<T extends Object> =
    Widget Function(BuildContext context, T item);

/// Builds a [MotionDropZone]'s gap from the dragged item's measured [size].
typedef MotionDropPlaceholderBuilder =
    Widget Function(BuildContext context, Size size);

/// Inserts [item] at [index] of a [MotionDropZone]'s items, see
/// [MotionDropZone.onInsert].
typedef MotionDropInsertCallback<T extends Object> =
    FutureOr<void> Function(T item, int index);

/// A list, grid or wrap that makes room for an item dragged over it, and
/// takes the drop at that place.
///
/// The zone is one [DragTarget] for the whole list. While a compatible
/// [MotionDraggable] hovers over it, the zone opens a gap where the item
/// would go: the items after the gap fly aside on their [MotionReorder]
/// springs, and each move of the gap redirects them with their velocity.
/// Leaving the zone closes the gap. A drop calls [onInsert] with the gap's
/// index, and the item takes the gap's place: the feedback flies into the
/// open gap and hands off to the item on the next frame.
///
/// The zone doesn't lay anything out. [builder] gets the [MotionDropSlots]
/// and lays them out with any list widget, building each one with
/// [MotionDropSlots.build]:
///
/// ```dart
/// MotionDropZone<Song>(
///   items: songs,
///   onInsert: (song, index) => setState(() {
///     songs
///       ..remove(song)
///       ..insert(index, song);
///   }),
///   builder: (context, slots) => ListView.builder(
///     itemCount: slots.length,
///     findChildIndexCallback: slots.indexOfKey,
///     itemBuilder: (context, i) => slots.build(
///       i,
///       (context, song) => MotionDraggable<Song>(
///         data: song,
///         child: SongTile(song),
///       ),
///     ),
///   ),
/// )
/// ```
///
/// A `Column` or `Wrap` uses `[for (var i = 0; i < slots.length; i++)
/// slots.build(i, …)]` as its children.
///
/// ## The gap
///
/// The gap goes before the first item whose painted center is past the
/// probe point (see [probe]). For a grid or a wrap, that is within the row
/// the probe is in. The zone learns the layout from the items, so rows,
/// reversed lists and right-to-left rows need no setting. To move the gap
/// past an item, the probe has to pass the item's center by a few pixels,
/// so the gap holds still at a boundary.
///
/// The gap is laid out at full size at once, and the items around it fly.
/// It is as large as the dragged item, which [MotionDraggable] measures,
/// unless [placeholderBuilder] draws it and picks its own size.
///
/// ## Items of this zone
///
/// Dragging an item of this zone turns its slot into the gap, so nothing
/// moves until the drag does. Leaving the zone closes the gap behind the
/// item; a drop back on the zone reorders it; a rejected drop brings it
/// back, and the feedback lands on it. The item's widget is left out while
/// it is dragged, so it loses its state.
///
/// ## The drop
///
/// [onInsert] gets the index in [items] after the item has been removed
/// from wherever it was. One callback covers drops from this zone, drops
/// from other lists, and moves by a screen reader.
///
/// When [onInsert] returns a [Future], the gap stays open at the drop's
/// index until it completes, and the feedback lands on it and waits there.
/// Update [items] before the future completes: the item then takes the
/// gap's place, and the landing hands off to it. If the future throws, or
/// completes without the item in [items], the drop counts as rejected: the
/// gap closes, and the feedback flies back to the item where it still is,
/// or plays its rejected exit when there is none. A future that never
/// completes keeps the gap open.
///
/// ## Scrolling and accessibility
///
/// While an item is dragged near an edge of a [Scrollable] around the
/// items, the zone scrolls it like a [MotionEdgeScroll], faster the closer
/// it gets to the edge, and the gap follows the content. Each item gets the
/// screen-reader actions to move up, down, to the start and to the end, or
/// left and right in a row, which call [onInsert].
///
/// A plain [Draggable] also works, but the zone can only place the gap by
/// [DragTargetDetails.offset], the gap is empty unless [placeholderBuilder]
/// sizes it, and nothing lands.
class MotionDropZone<T extends Object> extends StatefulWidget {
  /// Creates a zone that previews drops into [items].
  const MotionDropZone({
    required this.items,
    required this.builder,
    this.onInsert,
    this.onWillAcceptWithDetails,
    this.placeholderBuilder,
    this.itemKey,
    this.probe = MotionDragProbe.pointer,
    this.motion = MotionReorder.defaultMotion,
    this.autoScroll = const MotionEdgeScrollSettings(),
    this.debugLabel,
    this.tickerRate,
    super.key,
  });

  /// The items, in order. The zone never changes this list.
  final List<T> items;

  /// Lays out the slots: the items, minus one of them while it is dragged,
  /// plus the gap while an item hovers.
  final MotionDropZoneBuilder<T> builder;

  /// Called when an item is dropped, or moved by a screen reader, at an
  /// index in [items] counted after the item has been removed from it.
  ///
  /// For a list that reorders itself, `items..remove(item)..insert(index,
  /// item)` is the whole job. Return a future to keep the gap open, as the
  /// landing site, until the insert is done.
  final MotionDropInsertCallback<T>? onInsert;

  /// Whether to accept data dragged over the zone, like
  /// [DragTarget.onWillAcceptWithDetails]. Items of this zone are always
  /// accepted. Defaults to accepting every `T`.
  final DragTargetWillAcceptWithDetails<T>? onWillAcceptWithDetails;

  /// Builds the gap from the dragged item's measured size.
  ///
  /// The gap is laid out under the list's constraints, so it can pick its
  /// own size, such as a thin insertion line. In a list, only the main axis
  /// of the size counts, since the cross axis is tight. Defaults to empty
  /// space of that size.
  final MotionDropPlaceholderBuilder? placeholderBuilder;

  /// The identity of an item for its slot's key, compared with `==`.
  /// Defaults to the item itself.
  final Object Function(T item)? itemKey;

  /// The point of a hovering [MotionDraggable] that places the gap and
  /// drives [autoScroll].
  ///
  /// Defaults to [MotionDragProbe.pointer], the finger.
  /// [MotionDragProbe.feedbackCenter] places the gap by where the card is,
  /// which differs when the card was grabbed near an edge.
  final MotionDragProbe probe;

  /// The motion of every slot's [MotionReorder].
  final Motion motion;

  /// How a drag near an edge of a [Scrollable] around the items scrolls
  /// it, as a [MotionEdgeScroll] would, or null not to scroll.
  ///
  /// A [MotionEdgeScroll] of your own inside the list overrides it.
  final MotionEdgeScrollSettings? autoScroll;

  /// {@macro motor_widgets.debugLabel}
  final String? debugLabel;

  /// {@macro motor_widgets.tickerRate}
  final TickerRate? tickerRate;

  @override
  State<MotionDropZone<T>> createState() => _MotionDropZoneState<T>();
}

/// The slots of a [MotionDropZone]: its items, minus one of them while it
/// is dragged, plus the gap while an item hovers.
final class MotionDropSlots<T extends Object> {
  MotionDropSlots._(this._zone, this._items, this.gapIndex, this.candidate);

  final _MotionDropZoneState<T> _zone;
  final List<T> _items;

  /// The slot index of the gap, or null while there is none.
  final int? gapIndex;

  /// The data that hovers over the zone and that it accepts, or null.
  final T? candidate;

  Map<Object, int>? _indices;

  /// How many slots to lay out.
  int get length => _items.length + (gapIndex == null ? 0 : 1);

  /// Builds slot [index]: an item, with [item], or the gap.
  ///
  /// Each slot comes keyed and inside a [MotionReorder] whose flight key is
  /// its index, so it must be the list's direct child.
  Widget build(int index, MotionDropItemBuilder<T> item) {
    final gap = gapIndex;
    if (index == gap) return _zone._buildGap(index);
    final itemIndex = gap != null && index > gap ? index - 1 : index;
    return _zone._buildItem(this, index, itemIndex, _items[itemIndex], item);
  }

  /// The slot index of the child with [key], for the
  /// `findChildIndexCallback` of [ListView.builder] and [GridView.builder].
  int? indexOfKey(Key key) {
    if (key is! _DropSlotKey || !identical(key.zone, _zone)) return null;
    if (identical(key.value, _zone._gapToken)) return gapIndex;
    final indices = _indices ??= {
      for (final (i, item) in _items.indexed) _zone._keyOf(item): i,
    };
    final itemIndex = indices[key.value];
    if (itemIndex == null) return null;
    final gap = gapIndex;
    return gap != null && itemIndex >= gap ? itemIndex + 1 : itemIndex;
  }
}

/// The key of a slot: the zone and the item's key, so that it never equals
/// a key the app uses itself.
class _DropSlotKey extends LocalKey {
  const _DropSlotKey(this.zone, this.value);

  final Object zone;
  final Object value;

  @override
  bool operator ==(Object other) =>
      other is _DropSlotKey &&
      identical(other.zone, zone) &&
      other.value == value;

  @override
  int get hashCode => Object.hash(identityHashCode(zone), value);
}

/// How the items of a zone follow each other on screen.
@immutable
class _Flow {
  const _Flow(this.axis, this.sign);

  /// The axis along which consecutive items follow each other.
  final Axis axis;

  /// 1 when later items are further right or down, -1 otherwise.
  final double sign;

  /// [offset]'s position along the flow.
  double along(Offset offset) =>
      sign * (axis == Axis.horizontal ? offset.dx : offset.dy);

  double extent(Rect rect) =>
      axis == Axis.horizontal ? rect.width : rect.height;

  (double, double) crossSpan(Rect rect) => axis == Axis.horizontal
      ? (rect.top, rect.bottom)
      : (rect.left, rect.right);

  double cross(Offset offset) =>
      axis == Axis.horizontal ? offset.dy : offset.dx;
}

class _Hover<T> {
  _Hover(this.data, this.offset, this.flight);

  final T data;
  Offset offset;
  DragFlight? flight;
}

class _Pending<T> {
  _Pending(this.item, this.index, this.flight);

  final T item;
  final int index;
  final DragFlight? flight;
}

typedef _Measured = ({_RenderDropSlot slot, Rect layout, Rect painted});

/// The distance past an item's center that moves the gap past it.
double _band(double extent) => math.min(8, extent / 4);

class _MotionDropZoneState<T extends Object> extends State<MotionDropZone<T>>
    with SingleTickerProviderStateMixin
    implements DragFlightObserver {
  final _slots = <_RenderDropSlot>{};
  final _gapToken = Object();
  late final Ticker _ticker = createTicker((_) => _update());

  /// The probe and painted rects of the last update, to stop the ticker
  /// once nothing moves.
  List<Object>? _lastFrame;

  late final EdgeScrollSource _edgeScroll = EdgeScrollSource(
    scrollables: () {
      for (final slot in _slots) {
        if (slot.attached && slot.element.mounted) {
          return enclosingScrollables(slot.element);
        }
      }
      return const [];
    },
    settings: widget.autoScroll ?? const MotionEdgeScrollSettings(),
    probe: widget.probe,
    explicit: false,
  );

  _Hover<T>? _hover;

  /// Where the gap is among the shown items while an item hovers.
  int? _gapIndex;

  /// The dragged item's measured size.
  Size _gapSize = Size.zero;

  /// The item of this zone that is being dragged, and its flight.
  T? _own;
  DragFlight? _ownFlight;

  _Pending<T>? _pending;
  _DropGapState? _gap;
  ({LandingRegistry registry, Object tag, LandingSite site})? _reservation;

  /// Bumped on every drop, so that every slot that the drop moved flies.
  int _drops = 0;

  /// The flow found by the last index lookup.
  _Flow? _flow;

  Object _keyOf(T item) => widget.itemKey?.call(item) ?? item;

  bool _contains(Object? data) {
    if (data is! T) return false;
    final key = _keyOf(data);
    return widget.items.any((item) => _keyOf(item) == key);
  }

  bool _isSame(T a, T b) => _keyOf(a) == _keyOf(b);

  @override
  void initState() {
    super.initState();
    DragFlight.addObserver(this);
    if (widget.autoScroll != null) EdgeScroller.add(_edgeScroll);
  }

  @override
  void didUpdateWidget(MotionDropZone<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final settings = widget.autoScroll;
    _edgeScroll.probe = widget.probe;
    if (settings != null) _edgeScroll.settings = settings;
    if ((settings == null) != (oldWidget.autoScroll == null)) {
      settings == null
          ? EdgeScroller.remove(_edgeScroll)
          : EdgeScroller.add(_edgeScroll);
    }
  }

  @override
  void dispose() {
    DragFlight.removeObserver(this);
    EdgeScroller.remove(_edgeScroll);
    _unreserve();
    _ticker.dispose();
    super.dispose();
  }

  // Drags of this zone's items.

  @override
  void flightStarted(DragFlight flight) {
    if (!mounted) return;
    final hover = _hover;
    if (hover != null && flight.widget.data == hover.data) {
      hover.flight = flight;
      _gapSize = flight.feedbackRect.size;
    }
    final context = flight.source?.context;
    if (context == null || !context.mounted) return;
    final slot = context.findAncestorRenderObjectOfType<_RenderDropSlot>();
    if (slot == null || !identical(slot.zone, this) || slot.isGap) return;
    final item = slot.item! as T;
    setState(() {
      _own = item;
      _ownFlight = flight;
      // The item's slot becomes the gap, so nothing moves.
      _gapIndex = slot.itemIndex;
      _gapSize = flight.feedbackRect.size;
    });
  }

  @override
  void flightMoved(DragFlight flight) {}

  @override
  void flightReleased(DragFlight flight) {
    if (!mounted || !identical(flight, _ownFlight)) return;
    setState(() {
      _own = null;
      _ownFlight = null;
    });
  }

  // Hovering.

  bool _willAccept(DragTargetDetails<T> details) {
    if (_pending != null) return false;
    final accepts =
        _contains(details.data) ||
        (widget.onWillAcceptWithDetails?.call(details) ?? true);
    if (!accepts) return false;
    final flight = DragFlight.draggingWith(details.data);
    _hover = _Hover(details.data, details.offset, flight);
    if (flight != null) _gapSize = flight.feedbackRect.size;
    if (!identical(_ownFlight, flight)) _gapIndex = null;
    _update();
    setState(() {});
    _wake();
    return true;
  }

  /// Runs the ticker that places the gap while things move under a still
  /// pointer: flights and scrolling. It stops once nothing moves.
  void _wake() {
    if (_hover != null && !_ticker.isActive) unawaited(_ticker.start());
  }

  void _move(DragTargetDetails<T> details) {
    final hover = _hover;
    if (hover == null) return;
    hover.offset = details.offset;
    _update();
    _wake();
  }

  void _leave() {
    if (_hover == null) return;
    _endHover();
    setState(() {});
  }

  void _endHover() {
    _hover = null;
    _gapIndex = null;
    _lastFrame = null;
    _edgeScroll.point = null;
    _ticker.stop();
  }

  /// The point the gap is placed by.
  Offset? _probePoint() {
    final hover = _hover;
    if (hover == null) return null;
    final flight = hover.flight ??= DragFlight.draggingWith(hover.data);
    if (flight != null && flight.isDragging) {
      return switch (widget.probe) {
        MotionDragProbe.feedbackCenter => flight.feedbackRect.center,
        MotionDragProbe.pointer => flight.pointer,
      };
    }
    return hover.offset;
  }

  /// Places the gap after a move, a scroll or a flight's frame.
  void _update() {
    if (!mounted || _hover == null) return;
    final probe = _probePoint();
    if (probe == null) return;
    final measured = _measure();
    final index = _indexAt(probe, measured);
    final flight = _hover?.flight;
    // A plain Draggable tells only this zone where it is.
    _edgeScroll.point = flight == null || !flight.isDragging ? probe : null;
    if (index != _gapIndex) {
      setState(() => _gapIndex = index);
      _lastFrame = null;
      return;
    }
    final frame = <Object>[probe, for (final m in measured) m.painted];
    if (_lastFrame case final last? when listEquals(last, frame)) {
      _ticker.stop();
    }
    _lastFrame = frame;
  }

  /// The shown items: [MotionDropZone.items] without the one that is
  /// dragged from this zone or waits for its insert.
  List<T> _shown() {
    final own = _own;
    final pending = _pending?.item;
    if (own == null && pending == null) return widget.items;
    return [
      for (final item in widget.items)
        if ((own == null || !_isSame(item, own)) &&
            (pending == null || !_isSame(item, pending)))
          item,
    ];
  }

  /// Each laid-out slot with where layout puts it and where it was last
  /// painted, in slot order. Measured once per update.
  List<_Measured> _measure() => [
    for (final slot in _slots)
      if (slot.attached && slot.hasSize) slot.measure(),
  ]..sort((a, b) => a.slot.index.compareTo(b.slot.index));

  /// The insertion index for [probe]: the count of shown items whose
  /// painted center comes before it, within its line.
  int _indexAt(Offset probe, List<_Measured> slots) {
    final shown = _shown().length;
    final gap = _gapIndex;
    if (!slots.any((m) => !m.slot.isGap)) return 0;
    final flow = _flow = _flowOf(slots);

    // Lines: runs of consecutive slots that overlap across the flow.
    final lines = <List<_Measured>>[];
    _Measured? previous;
    for (final m in slots) {
      if (previous == null ||
          m.slot.index != previous.slot.index + 1 ||
          !_overlaps(
            flow.crossSpan(previous.layout),
            flow.crossSpan(m.layout),
          )) {
        lines.add([]);
      }
      lines.last.add(m);
      previous = m;
    }

    // The line the probe is in, else the nearest one.
    final cross = flow.cross(probe);
    List<_Measured>? line;
    var distance = double.infinity;
    for (final candidate in lines) {
      var start = double.infinity;
      var end = double.negativeInfinity;
      for (final m in candidate) {
        final (a, b) = flow.crossSpan(m.layout);
        start = math.min(start, a);
        end = math.max(end, b);
      }
      final d = cross < start
          ? start - cross
          : cross > end
          ? cross - end
          : 0.0;
      if (d < distance) {
        distance = d;
        line = candidate;
      }
    }

    var index = line!.first.slot.itemIndex;
    final along = flow.along(probe);
    for (final m in line) {
      final slot = m.slot;
      if (slot.isGap) continue;
      final rect = m.painted;
      final center = flow.along(rect.center);
      final band = _band(flow.extent(rect));
      final before = switch (gap) {
        null => along > center,
        _ when slot.itemIndex < gap => along > center - band,
        _ => along > center + band,
      };
      if (before) index++;
    }
    return index.clamp(0, shown);
  }

  static bool _overlaps((double, double) a, (double, double) b) =>
      math.min(a.$2, b.$2) - math.max(a.$1, b.$1) > 0.5;

  /// How consecutive slots follow each other, from the first consecutive
  /// pair, else the nearest [Scrollable]'s axis.
  _Flow _flowOf(List<_Measured> slots) {
    for (var i = 0; i + 1 < slots.length; i++) {
      final a = slots[i];
      final b = slots[i + 1];
      if (b.slot.index != a.slot.index + 1) continue;
      final ra = a.layout;
      final rb = b.layout;
      if (_overlaps((ra.top, ra.bottom), (rb.top, rb.bottom))) {
        return _Flow(Axis.horizontal, rb.center.dx >= ra.center.dx ? 1 : -1);
      }
      if (_overlaps((ra.left, ra.right), (rb.left, rb.right))) {
        return _Flow(Axis.vertical, rb.center.dy >= ra.center.dy ? 1 : -1);
      }
    }
    return _fallbackFlow(slots.isEmpty ? null : slots.first.slot.element);
  }

  _Flow _fallbackFlow(BuildContext? context) {
    final scrollable = context == null || !context.mounted
        ? null
        : Scrollable.maybeOf(context);
    if (scrollable == null) return const _Flow(Axis.vertical, 1);
    final direction = scrollable.axisDirection;
    return _Flow(
      axisDirectionToAxis(direction),
      axisDirectionIsReversed(direction) ? -1 : 1,
    );
  }

  // Dropping.

  void _accept(DragTargetDetails<T> details) {
    final item = details.data;
    final probe = _probePoint();
    final index =
        (_gapIndex ?? (probe == null ? 0 : _indexAt(probe, _measure()))).clamp(
          0,
          _shownWithout(item).length,
        );
    final flight = _hover?.flight ?? DragFlight.draggingWith(item);
    _endHover();
    final result = widget.onInsert?.call(item, index);
    if (result is! Future<void>) {
      setState(() => _drops++);
      return;
    }
    final pending = _Pending(item, index, flight);
    setState(() => _pending = pending);
    _syncReservation();
    result.then(
      (_) => _settle(pending, threw: false),
      onError: (Object error, StackTrace stack) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'motor_widgets',
            context: ErrorDescription('while inserting a MotionDropZone item'),
          ),
        );
        _settle(pending, threw: true);
      },
    );
  }

  List<T> _shownWithout(T item) => [
    for (final shown in _shown())
      if (!_isSame(shown, item)) shown,
  ];

  /// Ends a pending insert: the gap closes in the build in which the item
  /// takes its place.
  void _settle(_Pending<T> pending, {required bool threw}) {
    if (!mounted || !identical(_pending, pending)) return;
    _unreserve();
    setState(() {
      _pending = null;
      _drops++;
    });
    final flight = pending.flight;
    if (flight == null) return;
    if (threw) {
      flight.reject();
    } else {
      // The app updated the items before the future completed; they are
      // built by the end of the next frame.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_contains(pending.item)) flight.reject();
      });
    }
    // Then the flight lands on the item, which replaced the gap, or on the
    // item where it still is.
    flight.relocate();
  }

  /// Reserves the gap as the pending drop's landing site, once both exist.
  void _syncReservation() {
    final flight = _pending?.flight;
    final gap = _gap;
    if (flight == null || gap == null || _reservation != null) return;
    flight.registry.reserve(flight.tag, gap);
    _reservation = (registry: flight.registry, tag: flight.tag, site: gap);
    gap.landingChanged();
  }

  void _unreserve() {
    final reservation = _reservation;
    if (reservation == null) return;
    _reservation = null;
    reservation.registry.unreserve(reservation.tag, reservation.site);
  }

  void _attachGap(_DropGapState gap) {
    _gap = gap;
    _syncReservation();
  }

  void _detachGap(_DropGapState gap) {
    if (!identical(_gap, gap)) return;
    _gap = null;
    _unreserve();
  }

  bool _isReserved(_DropGapState gap) => identical(_reservation?.site, gap);

  // Screen readers.

  Map<CustomSemanticsAction, VoidCallback> _actions(
    BuildContext context,
    T item,
    int index,
    int count,
  ) {
    final onInsert = widget.onInsert;
    if (onInsert == null || count < 2) return const {};
    final strings =
        Localizations.of<WidgetsLocalizations>(
          context,
          WidgetsLocalizations,
        ) ??
        const DefaultWidgetsLocalizations();
    void to(int target) => onInsert(item, target);
    final flow = _flow ?? _fallbackFlow(context);
    final forward = flow.sign > 0;
    final String back;
    final String next;
    if (flow.axis == Axis.vertical) {
      (back, next) = forward
          ? (strings.reorderItemUp, strings.reorderItemDown)
          : (strings.reorderItemDown, strings.reorderItemUp);
    } else {
      (back, next) = forward
          ? (strings.reorderItemLeft, strings.reorderItemRight)
          : (strings.reorderItemRight, strings.reorderItemLeft);
    }
    return {
      if (index > 0) ...{
        CustomSemanticsAction(label: strings.reorderItemToStart): () => to(0),
        CustomSemanticsAction(label: back): () => to(index - 1),
      },
      if (index < count - 1) ...{
        CustomSemanticsAction(label: next): () => to(index + 1),
        CustomSemanticsAction(label: strings.reorderItemToEnd): () =>
            to(count - 1),
      },
    };
  }

  // Building.

  Widget _reorder({
    required Object key,
    required int index,
    required Widget child,
  }) => MotionReorder(
    key: _DropSlotKey(this, key),
    flightKey: (index, _drops),
    // A slot that moves in from another zone is a new element anyway; one
    // that moves within the zone flies.
    scope: this,
    motion: widget.motion,
    tickerRate: widget.tickerRate,
    debugLabel: widget.debugLabel,
    child: child,
  );

  Widget _buildItem(
    MotionDropSlots<T> slots,
    int index,
    int itemIndex,
    T item,
    MotionDropItemBuilder<T> builder,
  ) => _reorder(
    key: _keyOf(item),
    index: index,
    child: _DropSlot(
      zone: this,
      index: index,
      itemIndex: itemIndex,
      item: item,
      isGap: false,
      child: Builder(
        builder: (context) => Semantics(
          customSemanticsActions: _actions(
            context,
            item,
            itemIndex,
            widget.items.length,
          ),
          child: builder(context, item),
        ),
      ),
    ),
  );

  Widget _buildGap(int index) => _reorder(
    key: _gapToken,
    index: index,
    child: _DropSlot(
      zone: this,
      index: index,
      itemIndex: index,
      item: null,
      isGap: true,
      child: _DropGap(zone: this, size: _gapSize),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final shown = _shown();
    final pending = _pending;
    final int? gap;
    if (pending != null) {
      // The gap waits for the item, and closes in the build in which the
      // item is there.
      gap = pending.index.clamp(0, shown.length);
    } else if (_hover != null) {
      gap = _gapIndex?.clamp(0, shown.length);
    } else {
      gap = null;
    }
    final slots = MotionDropSlots<T>._(this, shown, gap, _hover?.data);
    return DragTarget<T>(
      onWillAcceptWithDetails: _willAccept,
      onMove: _move,
      onLeave: (_) => _leave(),
      onAcceptWithDetails: _accept,
      builder: (context, _, _) => NotificationListener<ScrollNotification>(
        // A scroll under a still pointer moves the items past it.
        onNotification: (_) {
          _wake();
          return false;
        },
        child: widget.builder(context, slots),
      ),
    );
  }
}

/// Registers one slot's rects with its zone.
class _DropSlot extends SingleChildRenderObjectWidget {
  const _DropSlot({
    required this.zone,
    required this.index,
    required this.itemIndex,
    required this.item,
    required this.isGap,
    super.child,
  });

  final _MotionDropZoneState<Object> zone;
  final int index;
  final int itemIndex;
  final Object? item;
  final bool isGap;

  @override
  _RenderDropSlot createRenderObject(BuildContext context) => _RenderDropSlot(
    zone: zone,
    index: index,
    itemIndex: itemIndex,
    item: item,
    isGap: isGap,
    element: context,
  );

  @override
  void updateRenderObject(BuildContext context, _RenderDropSlot renderObject) {
    renderObject
      ..zone = zone
      ..index = index
      ..itemIndex = itemIndex
      ..item = item
      ..isGap = isGap
      ..element = context;
  }
}

class _RenderDropSlot extends RenderProxyBox {
  _RenderDropSlot({
    required _MotionDropZoneState<Object> zone,
    required this.index,
    required this.itemIndex,
    required this.item,
    required this.isGap,
    required this.element,
  }) : _zone = zone;

  _MotionDropZoneState<Object> get zone => _zone;
  _MotionDropZoneState<Object> _zone;
  set zone(_MotionDropZoneState<Object> value) {
    if (identical(value, _zone)) return;
    if (attached) _zone._slots.remove(this);
    _zone = value;
    if (attached) _zone._slots.add(this);
  }

  /// The slot's index among all slots, the gap included.
  int index;

  /// The item's index among the shown items; for the gap, the index it
  /// inserts at.
  int itemIndex;
  Object? item;
  bool isGap;
  BuildContext element;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _zone._slots.add(this);
  }

  @override
  void detach() {
    _zone._slots.remove(this);
    super.detach();
  }

  /// Where layout puts the slot, and where it was last painted, including
  /// its [MotionReorder]'s flight, both in global coordinates.
  _Measured measure() {
    final layout = localToGlobal(Offset.zero) & size;
    return (
      slot: this,
      layout: layout,
      painted: layout.shift(paintOffsetAbove(this)),
    );
  }
}

/// The gap: the placeholder, and the landing site of a pending insert.
class _DropGap extends StatefulWidget {
  const _DropGap({required this.zone, required this.size});

  final _MotionDropZoneState<Object> zone;
  final Size size;

  @override
  State<_DropGap> createState() => _DropGapState();
}

class _DropGapState extends State<_DropGap> implements LandingSite {
  @override
  final LayerLink landingLink = LayerLink();

  @override
  void initState() {
    super.initState();
    widget.zone._attachGap(this);
  }

  @override
  void didUpdateWidget(_DropGap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.zone, widget.zone)) {
      oldWidget.zone._detachGap(this);
      widget.zone._attachGap(this);
    }
  }

  @override
  void dispose() {
    widget.zone._detachGap(this);
    super.dispose();
  }

  @override
  Rect? get globalRect {
    if (!mounted) return null;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return paintedGlobalRect(box);
  }

  // The gap shows nothing of the item, so nothing can take the landing over
  // in the tree: it waits in the overlay until the item arrives.
  @override
  FlightReceiver? get flightReceiver => null;

  @override
  Rect? get visibleRect => mounted ? visibleRectOf(context) : null;

  @override
  bool get holdsLanding => true;

  @override
  void receiveVisuals(List<TrackValue<double>> values) {}

  @override
  void landingChanged() {
    if (mounted) setState(() {});
  }

  @override
  bool grab(PointerDownEvent event, DragFlight flight) => false;

  @override
  void endGrab(DragFlight flight) {}

  @override
  Widget build(BuildContext context) {
    final zone = widget.zone;
    final size = widget.size;
    final placeholder =
        zone.widget.placeholderBuilder?.call(context, size) ??
        SizedBox.fromSize(size: size);
    return LeaderWhile(
      link: zone._isReserved(this) ? landingLink : null,
      child: SingleMotionBuilder(
        value: 1,
        from: 0,
        motion: const CupertinoMotion.smooth(
          duration: Duration(milliseconds: 200),
        ),
        debugLabel: 'MotionDropZone.placeholder',
        builder: (context, opacity, child) =>
            Opacity(opacity: opacity.clamp(0.0, 1.0), child: child),
        child: placeholder,
      ),
    );
  }
}
