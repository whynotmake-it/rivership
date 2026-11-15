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
import 'package:motor_widgets/src/layout/motion_layout.dart';
import 'package:motor_widgets/src/painted_position.dart';

/// Lays out a [MotionDropZone]'s [slots].
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
/// The zone builds each item with [itemBuilder], and [builder] lays the
/// [MotionDropSlots] out with any list widget:
///
/// ```dart
/// MotionDropZone<Song>(
///   items: songs,
///   id: (song) => song.id,
///   onInsert: (song, index) => setState(() {
///     songs
///       ..remove(song)
///       ..insert(index, song);
///   }),
///   itemBuilder: (context, song) =>
///       MotionDraggable<Song>(child: SongTile(song)),
///   builder: (context, slots) => ListView.builder(
///     itemCount: slots.length,
///     itemBuilder: (context, i) => slots[i],
///   ),
/// )
/// ```
///
/// A `Column`, `Row` or `Wrap` takes [MotionDropSlots.children].
///
/// A [MotionDraggable] inside an item drags that item: its data and id
/// default to the item's. Wrap the whole item to drag it anywhere, or only
/// a handle. Plain [Draggable]s are accepted too.
///
/// Every slot is a [MotionLayoutItem], so items fly whenever the zone's
/// layout moves them: when the gap opens, moves or closes, on a drop, and
/// when [items] changes. The zone uses the [MotionLayoutGroup] around it,
/// or else its own. Put one group around several zones, such as the
/// columns of a board, to make moves between them fly without a drag too.
///
/// ## The gap
///
/// While a compatible draggable hovers over the zone, the zone opens a gap
/// where the item would go: before the first item whose painted center is
/// past the probe point (see [probe]), within the row the probe is in for a
/// grid or a wrap. The zone learns the layout from where the items are, so
/// rows, reversed lists and right-to-left rows need no setting. To move the
/// gap past an item, the probe has to pass the item's center by a few
/// pixels, so the gap holds still at a boundary.
///
/// The gap is as large as the dragged item, unless [placeholderBuilder]
/// draws it and picks its own size.
///
/// Dragging an item of this zone turns its slot into the gap, so nothing
/// moves until the drag does. The item stays out of the zone until its
/// drag is over, unless the drop is rejected: then it comes back, and the
/// feedback lands on it.
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
/// completes without the item in [items], the drop counts as rejected.
///
/// ## Scrolling and accessibility
///
/// While an item is dragged near an edge of a [Scrollable] around the
/// items, the zone scrolls it like a [MotionEdgeScroll], and a drag held
/// still finds its target again as the content moves. Each item gets the
/// screen-reader actions to move it, which call [onInsert].
class MotionDropZone<T extends Object> extends StatefulWidget {
  /// Creates a zone that previews drops into [items].
  const MotionDropZone({
    required this.items,
    required this.itemBuilder,
    required this.builder,
    this.id,
    this.onInsert,
    this.onWillAcceptWithDetails,
    this.placeholderBuilder,
    this.probe = MotionDragProbe.pointer,
    this.motion,
    this.autoScroll = const MotionEdgeScrollSettings(),
    this.debugLabel,
    this.tickerRate,
    super.key,
  });

  /// The items, in order. The zone never changes this list.
  final List<T> items;

  /// The identity of an item, compared with `==`: the id of its
  /// [MotionLayoutItem], and of the [MotionDraggable]s inside it.
  ///
  /// Defaults to the item itself.
  final Object Function(T item)? id;

  /// Builds an item.
  final MotionDropItemBuilder<T> itemBuilder;

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
  /// own size, such as a thin insertion line. Defaults to empty space of
  /// that size.
  final MotionDropPlaceholderBuilder? placeholderBuilder;

  /// The point of a hovering [MotionDraggable] that places the gap and
  /// drives [autoScroll].
  ///
  /// Defaults to [MotionDragProbe.pointer], the finger.
  /// [MotionDragProbe.feedbackCenter] places the gap by where the card is,
  /// which differs when the card was grabbed near an edge.
  final MotionDragProbe probe;

  /// The motion of the items. Defaults to their [MotionLayoutGroup]'s.
  final Motion? motion;

  /// How a drag near an edge of a [Scrollable] around the items scrolls
  /// it, as a [MotionEdgeScroll] would, or null not to scroll.
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

  /// Slot [index]: an item, or the gap.
  Widget operator [](int index) {
    final gap = gapIndex;
    if (index == gap) return _zone._buildGap();
    final itemIndex = gap != null && index > gap ? index - 1 : index;
    return _zone._buildItem(_items[itemIndex], itemIndex);
  }

  /// Every slot, in order, for a `Column`, `Row` or `Wrap`.
  List<Widget> get children => [for (var i = 0; i < length; i++) this[i]];

  /// The slot index of the child with [key].
  ///
  /// The items fly without it. As the `findChildIndexCallback` of
  /// [ListView.builder] or [GridView.builder], it also keeps an item's
  /// widget state when the item moves.
  int? indexOfKey(Key key) {
    if (key is! _SlotKey || !identical(key.zone, _zone)) return null;
    if (identical(key.value, _zone._gapToken)) return gapIndex;
    final indices = _indices ??= {
      for (final (i, item) in _items.indexed) _zone._idOf(item): i,
    };
    final itemIndex = indices[key.value];
    if (itemIndex == null) return null;
    final gap = gapIndex;
    return gap != null && itemIndex >= gap ? itemIndex + 1 : itemIndex;
  }
}

/// The key of a slot: the zone and the item's id, so that it never equals
/// a key the app uses itself.
class _SlotKey extends LocalKey {
  const _SlotKey(this.zone, this.value);

  final Object zone;
  final Object value;

  @override
  bool operator ==(Object other) =>
      other is _SlotKey && identical(other.zone, zone) && other.value == value;

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

bool _overlaps((double, double) a, (double, double) b) =>
    math.min(a.$2, b.$2) - math.max(a.$1, b.$1) > 0.5;

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

  /// The item of this zone that is being dragged, and its flight. It stays
  /// out of the zone until the flight is over.
  T? _own;
  DragFlight? _ownFlight;

  _Pending<T>? _pending;

  /// The flow found by the last index lookup.
  _Flow? _flow;

  Object _idOf(T item) => widget.id?.call(item) ?? item;

  bool _isSame(T a, T b) => _idOf(a) == _idOf(b);

  bool _contains(Object? data) {
    if (data is! T) return false;
    final id = _idOf(data);
    return widget.items.any((item) => _idOf(item) == id);
  }

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
    _ticker.dispose();
    super.dispose();
  }

  // Drags of this zone's items.

  @override
  void flightStarted(DragFlight flight) {
    if (!mounted) return;
    final hover = _hover;
    if (hover != null && flight.data == hover.data) {
      hover.flight = flight;
      _gapSize = flight.feedbackRect.size;
    }
    final context = flight.source?.context;
    if (context == null || !context.mounted) return;
    final slot = context.findAncestorRenderObjectOfType<_RenderDropSlot>();
    if (slot == null || !identical(slot.zone, this) || slot.isGap) return;
    final id = slot.id;
    final item = widget.items.where((item) => _idOf(item) == id).firstOrNull;
    if (item == null) return;
    setState(() {
      _own = item;
      _ownFlight = flight;
      // The item's slot becomes the gap, so nothing moves: the gap goes
      // after the shown items that came before it.
      final shown = {for (final other in _shown()) _idOf(other)};
      _gapIndex = widget.items
          .takeWhile((other) => _idOf(other) != id)
          .where((other) => shown.contains(_idOf(other)))
          .length;
      _gapSize = flight.feedbackRect.size;
    });
  }

  @override
  void flightMoved(DragFlight flight) {}

  @override
  void flightReleased(DragFlight flight) {
    // A rejected item comes back, and the feedback lands on it.
    if (flight.phase == MotionDragPhase.rejected) _releaseOwn(flight);
  }

  @override
  void flightFinished(DragFlight flight) => _releaseOwn(flight);

  void _releaseOwn(DragFlight flight) {
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
  /// dragged from this zone, while no insert is pending, and without the
  /// one whose insert is pending.
  ///
  /// While an insert is pending, a dragged item keeps its slot, hidden by
  /// its draggable, since the zone has only the one gap.
  List<T> _shown() {
    final pending = _pending?.item;
    final own = pending == null ? _own : null;
    if (own == null && pending == null) return widget.items;
    return [
      for (final item in widget.items)
        if ((own == null || !_isSame(item, own)) &&
            (pending == null || !_isSame(item, pending)))
          item,
    ];
  }

  /// Each laid-out slot with where it is laid out and where it was last
  /// painted, in global coordinates.
  List<_Measured> _measure() => [
    for (final slot in _slots)
      if (slot.attached && slot.hasSize)
        (
          slot: slot,
          layout: slot.localToGlobal(Offset.zero) & slot.size,
          painted: paintedGlobalRect(slot),
        ),
  ];

  /// The insertion index for [probe] among the shown items.
  ///
  /// The slots are grouped into lines by where they are laid out, and the
  /// probe picks the nearest line. The index is the order of the line's
  /// first shown item, plus the shown items in the line whose painted
  /// center the probe has passed. Past the gap, an item's center must be
  /// passed by a band, so the gap holds still while the probe wobbles.
  ///
  /// Order comes from the items, by id, never from the slots, which
  /// describe the last build. The gap, and slots of items that aren't shown
  /// any more, only shape the lines.
  int _indexAt(Offset probe, List<_Measured> measured) {
    final shown = _shown();
    final order = {for (final (i, item) in shown.indexed) _idOf(item): i};
    int? orderOf(_Measured m) => m.slot.isGap ? null : order[m.slot.id];
    if (!measured.any((m) => orderOf(m) != null)) return 0;
    final gap = _gapIndex;
    final flow = _flow = _flowOf(measured);

    // Lines: a column is one line; rows are runs of slots that overlap
    // across the flow.
    final lines = <List<_Measured>>[];
    if (flow.axis == Axis.vertical) {
      lines.add(measured);
    } else {
      final sorted = [...measured]
        ..sort((a, b) => a.layout.top.compareTo(b.layout.top));
      (double, double)? span;
      for (final m in sorted) {
        final next = flow.crossSpan(m.layout);
        if (span == null || !_overlaps(span, next)) {
          lines.add([]);
          span = next;
        } else {
          span = (math.min(span.$1, next.$1), math.max(span.$2, next.$2));
        }
        lines.last.add(m);
      }
    }

    // The line the probe is in, else the nearest one.
    final cross = flow.cross(probe);
    var line = 0;
    var distance = double.infinity;
    for (final (i, candidate) in lines.indexed) {
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
        line = i;
      }
    }

    // The shown items before the line: the order of its first item, else of
    // the first item after it, else all of them.
    var index = shown.length;
    for (final candidate in lines.skip(line)) {
      final orders = candidate.map(orderOf).nonNulls;
      if (orders.isNotEmpty) {
        index = orders.reduce(math.min);
        break;
      }
    }
    final along = flow.along(probe);
    for (final m in lines[line]) {
      final itemOrder = orderOf(m);
      if (itemOrder == null) continue;
      final center = flow.along(m.painted.center);
      final band = _band(flow.extent(m.painted));
      final passed = switch (gap) {
        null => along > center,
        _ when itemOrder < gap => along > center - band,
        _ => along > center + band,
      };
      if (passed) index++;
    }
    return index.clamp(0, shown.length);
  }

  /// How the items follow each other: down a column when they all share
  /// the first one's columns, along rows when they share its rows or wrap,
  /// and along the scrollable's axis when there is too little to tell. The
  /// direction comes from a scrollable along that axis, else the reading
  /// direction for rows.
  _Flow _flowOf(List<_Measured> measured) {
    final first = measured.first.layout;
    var column = true;
    var row = true;
    for (final m in measured) {
      final rect = m.layout;
      column &= _overlaps((first.left, first.right), (rect.left, rect.right));
      row &= _overlaps((first.top, first.bottom), (rect.top, rect.bottom));
    }
    final element = measured.first.slot.element;
    final Axis axis;
    if (column == row) {
      // One slot, or slots stacked on each other: the layout can't tell.
      axis = column ? _scrollAxis(element) : Axis.horizontal;
    } else {
      axis = column ? Axis.vertical : Axis.horizontal;
    }
    return _Flow(axis, _sign(element, axis));
  }

  Axis _scrollAxis(BuildContext element) {
    if (!element.mounted) return Axis.vertical;
    final scrollable = Scrollable.maybeOf(element);
    return scrollable == null
        ? Axis.vertical
        : axisDirectionToAxis(scrollable.axisDirection);
  }

  double _sign(BuildContext element, Axis axis) {
    if (!element.mounted) return 1;
    for (
      var scrollable = Scrollable.maybeOf(element);
      scrollable != null;
      scrollable = Scrollable.maybeOf(scrollable.context)
    ) {
      final direction = scrollable.axisDirection;
      if (axisDirectionToAxis(direction) == axis) {
        return axisDirectionIsReversed(direction) ? -1 : 1;
      }
    }
    if (axis == Axis.vertical) return 1;
    return Directionality.maybeOf(element) == TextDirection.rtl ? -1 : 1;
  }

  // Dropping.

  void _accept(DragTargetDetails<T> details) {
    final item = details.data;
    final probe = _probePoint();
    final own = _own != null && _isSame(_own!, item);
    final index =
        (_gapIndex ?? (probe == null ? 0 : _indexAt(probe, _measure()))).clamp(
          0,
          _shownWithout(item).length,
        );
    final flight = _hover?.flight ?? DragFlight.draggingWith(item);
    // The item goes into this zone's group, so the flight lands there.
    if (_landings() case final registry?) flight?.landIn(registry);
    _endHover();
    final result = widget.onInsert?.call(item, index);
    if (result is! Future<void>) {
      // The item is in its new place: the feedback lands on it.
      setState(() {
        if (own) {
          _own = null;
          _ownFlight = null;
        }
      });
      return;
    }
    final pending = _Pending(item, index, flight);
    setState(() => _pending = pending);
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

  /// The landing registry of the zone's group, found from a slot, or null
  /// before any is laid out.
  LandingRegistry? _landings() {
    for (final slot in _slots) {
      if (slot.element.mounted) {
        return LandingRegistry.maybeOf(slot.element, listen: false);
      }
    }
    return null;
  }

  List<T> _shownWithout(T item) => [
    for (final shown in _shown())
      if (!_isSame(shown, item)) shown,
  ];

  /// Ends a pending insert: the gap closes in the build in which the item
  /// takes its place.
  void _settle(_Pending<T> pending, {required bool threw}) {
    if (!mounted || !identical(_pending, pending)) return;
    final own = _own != null && _isSame(_own!, pending.item);
    setState(() {
      _pending = null;
      if (own) {
        _own = null;
        _ownFlight = null;
      }
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
    final flow = _flow;
    final forward = (flow?.sign ?? 1) > 0;
    final String back;
    final String next;
    if ((flow?.axis ?? Axis.vertical) == Axis.vertical) {
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

  Widget _buildItem(T item, int index) {
    final id = _idOf(item);
    return MotionLayoutItem(
      key: _SlotKey(this, id),
      id: id,
      motion: widget.motion,
      child: _DropSlot(
        zone: this,
        id: id,
        isGap: false,
        child: DraggableSlot(
          item: item,
          id: id,
          child: Builder(
            builder: (context) => Semantics(
              customSemanticsActions: _actions(
                context,
                item,
                widget.items.indexWhere((other) => _isSame(other, item)),
                widget.items.length,
              ),
              child: widget.itemBuilder(context, item),
            ),
          ),
        ),
      ),
    );
  }

  /// The gap. While an insert is pending, it stands in for the item: it has
  /// the item's id and holds its landing until the item takes its place.
  Widget _buildGap() {
    final pending = _pending;
    return LandingHold(
      key: _SlotKey(this, _gapToken),
      holds: pending != null,
      child: MotionLayoutItem(
        id: pending == null ? _gapToken : _idOf(pending.item),
        motion: widget.motion,
        child: _DropSlot(
          zone: this,
          id: null,
          isGap: true,
          child: _DropGap(
            size: _gapSize,
            placeholder: widget.placeholderBuilder,
          ),
        ),
      ),
    );
  }

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
    final list = widget.builder(context, slots);
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
        child: MotionLayoutGroup.isIn(context)
            ? list
            : MotionLayoutGroup(
                motion: widget.motion ?? MotionLayoutGroup.defaultMotion,
                debugLabel: widget.debugLabel,
                tickerRate: widget.tickerRate,
                child: list,
              ),
      ),
    );
  }
}

/// Registers one slot's rects with its zone.
class _DropSlot extends SingleChildRenderObjectWidget {
  const _DropSlot({
    required this.zone,
    required this.id,
    required this.isGap,
    super.child,
  });

  final _MotionDropZoneState<Object> zone;
  final Object? id;
  final bool isGap;

  @override
  _RenderDropSlot createRenderObject(BuildContext context) =>
      _RenderDropSlot(zone: zone, id: id, isGap: isGap, element: context);

  @override
  void updateRenderObject(BuildContext context, _RenderDropSlot renderObject) {
    renderObject
      ..zone = zone
      ..id = id
      ..isGap = isGap
      ..element = context;
  }
}

class _RenderDropSlot extends RenderProxyBox {
  _RenderDropSlot({
    required _MotionDropZoneState<Object> zone,
    required this.id,
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

  /// The id of the slot's item, or null for the gap.
  Object? id;
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
}

/// The gap's placeholder, which fades in.
class _DropGap extends StatelessWidget {
  const _DropGap({required this.size, required this.placeholder});

  final Size size;
  final MotionDropPlaceholderBuilder? placeholder;

  @override
  Widget build(BuildContext context) => SingleMotionBuilder(
    value: 1,
    from: 0,
    motion: const CupertinoMotion.smooth(duration: Duration(milliseconds: 200)),
    debugLabel: 'MotionDropZone.placeholder',
    builder: (context, opacity, child) =>
        Opacity(opacity: opacity.clamp(0.0, 1.0), child: child),
    child: placeholder?.call(context, size) ?? SizedBox.fromSize(size: size),
  );
}
