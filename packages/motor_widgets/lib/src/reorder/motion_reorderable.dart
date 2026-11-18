import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/src/drag/flight.dart';
import 'package:motor_widgets/src/drag/motion_drag_point.dart';
import 'package:motor_widgets/src/drag/motion_drag_to_scroll.dart';
import 'package:motor_widgets/src/drag/motion_draggable.dart';
import 'package:motor_widgets/src/layout/motion_layout.dart';
import 'package:motor_widgets/src/painted_position.dart';

/// Builds a [MotionReorderable]'s content from the [drop] that hovers over
/// it, or null while none does.
typedef MotionReorderableBuilder<T extends Object> =
    Widget Function(BuildContext context, MotionDrop<T>? drop);

/// Called when a drop moves an item, see [MotionReorderable.onMove].
typedef MotionMoveCallback<T extends Object> =
    FutureOr<void> Function(MotionMove<T> move);

/// Where a drag over a [MotionReorderable] would drop: between [after] and
/// [before].
@immutable
final class MotionDrop<T extends Object> {
  const MotionDrop._({
    required this.after,
    required this.before,
    required this.data,
    required this.size,
    required this.pending,
  });

  /// The item the drop comes after, or null at the start.
  ///
  /// It is never the dragged item itself, wherever that is shown.
  final T? after;

  /// The item the drop comes before, or null at the end.
  final T? before;

  /// What is dragged: an item, or anything else the reorderable accepts.
  final Object data;

  /// The dragged item's measured size, or null for a plain [Draggable],
  /// which doesn't tell.
  final Size? size;

  /// Whether the drop has happened and waits for [MotionReorderable.onMove]
  /// to complete.
  final bool pending;

  /// [data] when it is a `T`, else null.
  T? get item => switch (data) {
    final T item => item,
    _ => null,
  };
}

/// A drop that moves an item, passed to [MotionReorderable.onMove].
@immutable
final class MotionMove<T extends Object> {
  const MotionMove._({
    required this.data,
    required this.after,
    required this.before,
    required this.index,
  });

  /// What was dropped: an item, or anything else the reorderable accepts.
  final Object data;

  /// The item it goes after, or null at the start.
  final T? after;

  /// The item it goes before, or null at the end.
  final T? before;

  /// Where it goes in the items, counted after it has been removed from
  /// them.
  final int index;

  /// [data] when it is a `T`, else null.
  T? get item => switch (data) {
    final T item => item,
    _ => null,
  };
}

/// Takes drags, and tells its [builder] where they would drop: between two
/// items.
///
/// It doesn't lay anything out, and it never adds or removes children: the
/// builder builds the content, with a [MotionReorderableItem] around each
/// item, and decides how a drop shows. A [MotionDropGap] in front of
/// [MotionDrop.before] opens room for it, and the items after the gap fly
/// aside; a line drawn by the items on either side marks it without moving
/// anything:
///
/// ```dart
/// MotionReorderable<Song>(
///   items: songs,
///   onMove: (move) => setState(() {
///     songs
///       ..remove(move.item)
///       ..insert(move.index, move.item!);
///   }),
///   builder: (context, drop) => ListView(
///     children: [
///       for (final song in songs) ...[
///         if (drop?.before == song) const MotionDropGap(child: SongSlot()),
///         MotionReorderableItem(
///           item: song,
///           child: MotionDraggable<Song>(data: song, child: SongTile(song)),
///         ),
///       ],
///       if (drop != null && drop.before == null)
///         const MotionDropGap(child: SongSlot()),
///     ],
///   ),
/// )
/// ```
///
/// The whole content takes drags, so a drop on a header or on the empty
/// space below the items goes to the nearest end. Children that aren't
/// [MotionReorderableItem]s, such as headers, stay where they are.
///
/// When the drag leaves, the drop stays where it was, so the content keeps
/// its size, until another reorderable takes the drag. Letting go outside
/// drops there. See [keepsDropOnLeave].
///
/// The dragged item stays in the content: its [MotionDraggable] shows
/// [MotionDraggable.childWhenDragging] in its place, which collapses it or
/// keeps its room. Either way, [MotionDrop.after] and [MotionDrop.before]
/// skip it.
///
/// The items are [MotionLayoutItem]s of the [MotionLayoutGroup] around the
/// reorderable, or of one it makes, so they fly when the drop or the items
/// move them. A drop that the reorderable accepts lands in that group.
///
/// [onMove] may return a [Future]. Until it completes, [MotionDrop.pending]
/// keeps the drop where it was, and the dragged feedback waits over the
/// [MotionDropGap], until the item shows up in [items]. Update [items]
/// when you like, before or after the future completes; if the item isn't
/// there once it completes, or it throws, the feedback flies back.
class MotionReorderable<T extends Object> extends StatefulWidget {
  /// Takes drags over a box: its whole content.
  const MotionReorderable({
    required this.items,
    required this.builder,
    this.onMove,
    this.onWillAccept,
    this.id,
    this.point = MotionDragPoint.pointer,
    this.keepsDropOnLeave = true,
    this.motion,
    this.debugLabel,
    this.tickerRate,
    super.key,
  }) : _sliver = false;

  /// Takes drags over a sliver, such as one section of a scroll view.
  ///
  /// Flutter only finds drag targets that are boxes, so here each item and
  /// gap takes drags, and the space between them doesn't. A drag there keeps
  /// the drop, see [keepsDropOnLeave], and letting go drops it. An empty
  /// section needs a child to drop on. It must be inside a
  /// [MotionLayoutGroup].
  const MotionReorderable.sliver({
    required this.items,
    required this.builder,
    this.onMove,
    this.onWillAccept,
    this.id,
    this.point = MotionDragPoint.pointer,
    this.keepsDropOnLeave = true,
    this.motion,
    this.debugLabel,
    this.tickerRate,
    super.key,
  }) : _sliver = true;

  /// The items, in order. The reorderable never changes this list.
  final List<T> items;

  /// Builds the content from the drop that hovers over it.
  final MotionReorderableBuilder<T> builder;

  /// Called when a drag is dropped, or a screen reader moves an item.
  ///
  /// For a list that reorders itself, removing the item and inserting it
  /// at [MotionMove.index] is the whole job. Return a future to keep the
  /// drop pending until it completes.
  final MotionMoveCallback<T>? onMove;

  /// Whether to take drags of the data it is given. Items of this
  /// reorderable are always taken. Defaults to taking every `T`.
  final bool Function(Object data)? onWillAccept;

  /// The identity of an item, compared with `==`: the id of its
  /// [MotionLayoutItem], which a [MotionDraggable] lands on. Defaults to
  /// the item itself.
  final Object Function(T item)? id;

  /// The point of the drag that places the drop.
  final MotionDragPoint point;

  /// Whether the drop stays when the drag leaves, until another
  /// reorderable takes the drag or the drag ends. Letting go outside then
  /// drops where the drop shows, as if over it.
  ///
  /// The content then keeps its size while the pointer is outside, so
  /// nothing around it moves: a grid doesn't shrink, and sections of one
  /// scroll view don't shift under the pointer while it crosses a header
  /// between them. When false, the drop goes as the drag leaves.
  ///
  /// Only a [MotionDraggable]'s drag can be kept: the reorderable can't
  /// tell when a plain [Draggable]'s drag ends elsewhere, so its drop always
  /// goes as it leaves.
  final bool keepsDropOnLeave;

  /// The items' motion. Defaults to their group's.
  final Motion? motion;

  /// {@macro motor_widgets.debugLabel}
  final String? debugLabel;

  /// {@macro motor_widgets.tickerRate}
  final TickerRate? tickerRate;

  final bool _sliver;

  @override
  State<MotionReorderable<T>> createState() => _MotionReorderableState<T>();
}

/// One item of a [MotionReorderable]: a [MotionLayoutItem] with the item's
/// id, whose place the reorderable measures, with the screen-reader actions
/// that move it.
class MotionReorderableItem<T extends Object> extends StatelessWidget {
  /// Marks [child] as [item].
  const MotionReorderableItem({
    required this.item,
    required this.child,
    super.key,
  });

  /// The item.
  final T item;

  /// The widget below this widget in the tree.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final zone = _ReorderableScope.of(context);
    final id = zone._idOfItem(item);
    return MotionLayoutItem(
      id: id,
      motion: zone.widget.motion,
      child: _Slot(
        zone: zone,
        id: id,
        isGap: false,
        child: zone.widget._sliver ? zone._target(child) : child,
      ),
    );
  }
}

/// The room a [MotionReorderable]'s drop opens: any widget, placed by its
/// builder where the drop would go.
///
/// It flies when the drop moves it, and while the drop is pending, the
/// dragged feedback waits over it.
class MotionDropGap extends StatelessWidget {
  /// Opens room for the drop with [child].
  const MotionDropGap({required this.child, super.key});

  /// What the room shows.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final zone = _ReorderableScope.of(context);
    return LandingHold(
      holds: true,
      child: MotionLayoutItem(
        id: zone._gapToken,
        motion: zone.widget.motion,
        child: _GapSite(
          zone: zone,
          child: _Slot(
            zone: zone,
            id: null,
            isGap: true,
            child: zone.widget._sliver ? zone._target(child) : child,
          ),
        ),
      ),
    );
  }
}

class _ReorderableScope extends InheritedWidget {
  const _ReorderableScope({
    required this.zone,
    required this.motion,
    required this.sliver,
    required super.child,
  });

  final _MotionReorderableState<Object> zone;

  /// What items read from [zone] while building, so a hover that only
  /// moves the drop doesn't rebuild items the builder kept.
  final Motion? motion;
  final bool sliver;

  static _MotionReorderableState<Object> of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_ReorderableScope>();
    assert(
      scope != null,
      'MotionReorderableItem and MotionDropGap must be inside a '
      'MotionReorderable.',
    );
    return scope!.zone;
  }

  @override
  bool updateShouldNotify(_ReorderableScope oldWidget) =>
      zone != oldWidget.zone ||
      motion != oldWidget.motion ||
      sliver != oldWidget.sliver;
}

/// Tells the reorderable which landing site its gap is.
class _GapSite extends StatefulWidget {
  const _GapSite({required this.zone, required this.child});

  final _MotionReorderableState<Object> zone;
  final Widget child;

  @override
  State<_GapSite> createState() => _GapSiteState();
}

class _GapSiteState extends State<_GapSite> {
  LandingSite? _site;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _site = context.findAncestorStateOfType<MotionLayoutItemState>();
    widget.zone._gapSite = _site;
  }

  @override
  void dispose() {
    if (identical(widget.zone._gapSite, _site)) widget.zone._gapSite = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// How the items of a reorderable follow each other on screen.
@immutable
class _Flow {
  const _Flow(this.axis, this.sign, {this.wraps = false, this.crossSign = 1});

  @override
  bool operator ==(Object other) =>
      other is _Flow &&
      other.axis == axis &&
      other.sign == sign &&
      other.wraps == wraps &&
      other.crossSign == crossSign;

  @override
  int get hashCode => Object.hash(axis, sign, wraps, crossSign);

  /// The axis along which consecutive items follow each other.
  final Axis axis;

  /// 1 when later items are further right or down, -1 otherwise.
  final double sign;

  /// Whether the items wrap onto several lines across [axis].
  final bool wraps;

  /// 1 when later lines are further right or down, -1 otherwise.
  final double crossSign;

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

class _Hover {
  _Hover(this.data, this.offset, this.flight);

  final Object data;
  Offset offset;
  DragFlight? flight;
}

class _Pending {
  _Pending(this.drop, this.id, this.flight);

  final MotionDrop<Object> drop;
  final Object id;
  final DragFlight? flight;
}

typedef _Measured = ({_RenderSlot slot, Rect layout, Rect painted});

/// The distance past an item's center that moves the drop past it.
double _band(double extent) => math.min(8, extent / 4);

bool _overlaps((double, double) a, (double, double) b) =>
    math.min(a.$2, b.$2) - math.max(a.$1, b.$1) > 0.5;

class _MotionReorderableState<T extends Object>
    extends State<MotionReorderable<T>>
    with SingleTickerProviderStateMixin
    implements DragFlightObserver {
  /// The reorderables that keep the drop of a drag that left them.
  static final _keeping = <_MotionReorderableState<Object>>{};

  final _slots = <_RenderSlot>{};
  final _gapToken = Object();

  /// Created on first use: creating it in [dispose], for a reorderable
  /// that never needed it, would look up an ancestor of a deactivated
  /// element.
  Ticker? _tickerOrNull;
  Ticker get _ticker => _tickerOrNull ??= createTicker((_) => _update());

  /// The probe and painted rects of the last update, to stop the ticker
  /// once nothing moves.
  List<Object>? _lastFrame;

  _Hover? _hover;

  /// Where the drop is among the items without the dragged one.
  int? _index;

  _Pending? _pending;

  /// The landing site of the gap the builder placed, if any.
  LandingSite? _gapSite;

  /// The targets the drag is over: the box, or a sliver's items and gap.
  int _entered = 0;

  /// Whether the drag left and the drop stays, see
  /// [MotionReorderable.keepsDropOnLeave].
  bool _kept = false;

  /// The labels of the screen-reader actions, read while building.
  WidgetsLocalizations _strings = const DefaultWidgetsLocalizations();

  Object _idOfItem(T item) => widget.id?.call(item) ?? item;

  /// The id of dragged [data]: its item's, else the flight's.
  Object _idOfData(Object data, DragFlight? flight) => switch (data) {
    final T item => _idOfItem(item),
    _ => flight?.id ?? data,
  };

  bool _contains(Object id) => _indexOfId(id) != null;

  /// The index of the item with [id], from a map built once per widget, as
  /// every slot asks for its own. Items may be a list changed in place, so
  /// every new widget drops it.
  int? _indexOfId(Object id) {
    final indices = _indicesById ??= {
      for (final (i, item) in widget.items.indexed.toList().reversed)
        _idOfItem(item): i,
    };
    return indices[id];
  }

  Map<Object, int>? _indicesById;

  /// The items without the one dragged with [data].
  List<T> _order(Object? data) {
    if (data is! T) return widget.items;
    final id = _idOfItem(data);
    return [
      for (final item in widget.items)
        if (_idOfItem(item) != id) item,
    ];
  }

  @override
  void didUpdateWidget(MotionReorderable<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _indicesById = null;
    final pending = _pending;
    // The pending item arrived: the feedback lands on it.
    if (pending != null && _contains(pending.id)) pending.flight?.relocate();
  }

  @override
  void deactivate() {
    reportPlainDrag(context, this, null);
    super.deactivate();
  }

  @override
  void dispose() {
    _unkeep();
    _tickerOrNull?.dispose();
    super.dispose();
  }

  // Hovering.

  bool _willAccept(DragTargetDetails<Object> details) {
    if (_pending != null) return false;
    final data = details.data;
    final accepts =
        (data is T && _contains(_idOfItem(data))) ||
        (widget.onWillAccept?.call(data) ?? data is T);
    if (!accepts) return false;
    // This one takes the drag, so the drop goes from those that kept it.
    for (final other in [..._keeping]) {
      if (!identical(other, this) && other._hover?.data == data) {
        other._endKeptHover();
      }
    }
    _unkeep();
    _entered++;
    if (_hover == null || _hover!.data != data) {
      _hover = _Hover(data, details.offset, DragFlight.draggingWith(data));
      _index = null;
    }
    // Flutter's drag reaches this before a MotionDraggable's flight starts,
    // and tells only where its own feedback is. The ticker places the drop
    // on the next tick, by the flight's point once there is one, before
    // that frame is built.
    if (_hover!.flight != null) _update();
    _reportPlain();
    setState(() {});
    _wake();
    return true;
  }

  /// Runs the ticker that places the drop while things move under a still
  /// pointer: flights and scrolling. It stops once nothing moves.
  void _wake() {
    if (_hover != null && !_kept && !_ticker.isActive) {
      unawaited(_ticker.start());
    }
  }

  void _move(DragTargetDetails<Object> details) {
    final hover = _hover;
    if (hover == null) return;
    hover.offset = details.offset;
    _reportPlain();
    _update();
    _wake();
  }

  void _leave() {
    final hover = _hover;
    if (hover == null) return;
    _entered = math.max(0, _entered - 1);
    // A sliver's drag is still over it while another of its targets has it.
    if (widget._sliver && _entered > 0) return;
    // A kept drop stays when the drag leaves for the space between a
    // sliver's targets, and entering another target takes it up again.
    final keeps =
        widget.keepsDropOnLeave &&
        ((hover.flight ??= DragFlight.draggingWith(hover.data))?.isDragging ??
            false);
    if (!widget._sliver || keeps) {
      _left();
      return;
    }
    // Between the targets of a sliver, the drag is still over the
    // reorderable as long as it enters another one by the next frame.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _entered > 0 || _hover == null || _kept) return;
      _left();
    }, debugLabel: 'MotionReorderable.leave');
  }

  /// The drag left: the drop stays until the drag ends or another
  /// reorderable takes it, or goes now.
  void _left() {
    final flight = _hover?.flight;
    if (widget.keepsDropOnLeave && flight != null && flight.isDragging) {
      _kept = true;
      _tickerOrNull?.stop();
      _lastFrame = null;
      _keeping.add(this as _MotionReorderableState<Object>);
      DragFlight.addObserver(this);
      flight.takeUnaccepted = _takeKept;
      return;
    }
    _endHover();
    setState(() {});
  }

  /// Stops keeping the drop, without ending the hover.
  void _unkeep() {
    if (!_kept) return;
    _kept = false;
    _keeping.remove(this);
    DragFlight.removeObserver(this);
    final flight = _hover?.flight;
    if (flight != null && flight.takeUnaccepted == _takeKept) {
      flight.takeUnaccepted = null;
    }
  }

  /// Takes the drop of a drag that let go outside, where the kept drop
  /// shows.
  bool _takeKept() {
    final hover = _hover;
    if (!_kept || !mounted || hover == null) return false;
    _accept(DragTargetDetails(data: hover.data, offset: hover.offset));
    return true;
  }

  void _endKeptHover() {
    if (!_kept) return;
    _endHover();
    if (mounted) setState(() {});
  }

  @override
  void flightStarted(DragFlight flight) {}

  @override
  void flightMoved(DragFlight flight) {}

  @override
  void flightReleased(DragFlight flight) {
    if (identical(flight, _hover?.flight)) _endKeptHover();
  }

  @override
  void flightFinished(DragFlight flight) {
    if (identical(flight, _hover?.flight)) _endKeptHover();
  }

  void _endHover() {
    _unkeep();
    _hover = null;
    _index = null;
    _lastFrame = null;
    _entered = 0;
    _tickerOrNull?.stop();
    if (mounted) _reportPlain();
  }

  /// Passes a plain [Draggable]'s drag on to the [MotionDragToScroll]s
  /// around, from which taking it hides it. A [MotionDraggable]'s drag they
  /// see themselves.
  void _reportPlain() {
    final hover = _hover;
    final plain =
        hover != null &&
        (hover.flight ??= DragFlight.draggingWith(hover.data)) == null;
    reportPlainDrag(context, this, plain ? hover.offset : null);
  }

  /// The point the drop is placed by.
  Offset? _probePoint() {
    final hover = _hover;
    if (hover == null) return null;
    final flight = hover.flight ??= DragFlight.draggingWith(hover.data);
    if (flight != null && flight.isDragging) {
      return switch (widget.point) {
        MotionDragPoint.feedbackCenter => flight.feedbackRect.center,
        MotionDragPoint.pointer => flight.pointer,
      };
    }
    return hover.offset;
  }

  /// Places the drop after a move, a scroll or a flight's frame.
  void _update() {
    if (!mounted || _kept) return;
    final hover = _hover;
    if (hover == null) return;
    final probe = _probePoint();
    if (probe == null) return;
    final measured = _measure();
    final index = _indexAt(probe, measured, hover.data);
    if (index != _index) {
      setState(() => _index = index);
      _lastFrame = null;
      return;
    }
    final frame = <Object>[probe, for (final m in measured) m.painted];
    if (_lastFrame case final last? when listEquals(last, frame)) {
      _tickerOrNull?.stop();
    }
    _lastFrame = frame;
  }

  /// Each laid-out slot with where it is laid out and where it was last
  /// painted, in global coordinates. Slots without a size, such as a
  /// collapsed dragged item, are left out.
  List<_Measured> _measure() => [
    for (final slot in _slots)
      if (slot.attached && slot.hasSize && !slot.size.isEmpty)
        (
          slot: slot,
          layout: layoutGlobalRect(slot),
          painted: paintedGlobalRect(slot),
        ),
  ];

  /// The drop's index for [probe] among the items without the one dragged
  /// with [data].
  ///
  /// The slots are grouped into lines by where they are laid out, and the
  /// probe picks the nearest line. The index is the order of the line's
  /// first item, plus the items in the line whose painted center the probe
  /// has passed. Past the drop, an item's center must be passed by a band,
  /// so the drop holds still while the probe wobbles.
  ///
  /// Order comes from the items, by id. The gap, the dragged item, and
  /// slots of items that aren't in the items any more only shape the lines.
  int _indexAt(Offset probe, List<_Measured> measured, Object data) {
    final shown = _order(data);
    final order = {for (final (i, item) in shown.indexed) _idOfItem(item): i};
    int? orderOf(_Measured m) => m.slot.isGap ? null : order[m.slot.id];
    if (!measured.any((m) => orderOf(m) != null)) return 0;
    final current = _index;
    final flow = _flowOf(measured);

    final lines = <List<_Measured>>[];
    if (flow.axis == Axis.vertical && !flow.wraps) {
      lines.add(measured);
    } else {
      final sorted = [...measured]
        ..sort(
          (a, b) => flow
              .crossSpan(a.layout)
              .$1
              .compareTo(
                flow.crossSpan(b.layout).$1,
              ),
        );
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
      // Lines in the order the items fill them.
      if (flow.crossSign < 0) lines.setAll(0, lines.reversed.toList());
    }

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
      final passed = switch (current) {
        null => along > center,
        _ when itemOrder < current => along > center - band,
        _ => along > center + band,
      };
      if (passed) index++;
    }
    return index.clamp(0, shown.length);
  }

  /// How the items follow each other: down a column when they all share
  /// the first one's columns, along a row when they share its rows, and
  /// along the scrollable's axis when there is too little to tell.
  ///
  /// Items on several rows and columns wrap: they go along a row, as in a
  /// [Wrap] or a vertical grid, or down a column, as in a vertical [Wrap]
  /// or a horizontal grid, whichever way consecutive items follow each
  /// other. Without two items to tell, they go across the scrollable's
  /// axis, else along rows.
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
    final wraps = !column && !row;
    final Axis axis;
    if (column && row) {
      axis = _scrollAxis(element);
    } else if (wraps) {
      axis =
          _progression(measured) ??
          switch (_scrollAxisOrNull(element)) {
            final scroll? => flipAxis(scroll),
            null => Axis.horizontal,
          };
    } else {
      axis = column ? Axis.vertical : Axis.horizontal;
    }
    return _Flow(
      axis,
      _sign(element, axis),
      wraps: wraps,
      crossSign: wraps ? _sign(element, flipAxis(axis)) : 1,
    );
  }

  /// The axis along which consecutive items follow each other: horizontal
  /// when the first pair of consecutive items that share a row or a column
  /// share a row. Null when no pair does.
  Axis? _progression(List<_Measured> measured) {
    final order = {
      for (final (i, item) in widget.items.indexed) _idOfItem(item): i,
    };
    final byOrder = [
      for (final m in measured)
        if (!m.slot.isGap && order[m.slot.id] != null) m,
    ]..sort((a, b) => order[a.slot.id]!.compareTo(order[b.slot.id]!));
    for (var i = 1; i < byOrder.length; i++) {
      final a = byOrder[i - 1].layout;
      final b = byOrder[i].layout;
      final sameRow = _overlaps((a.top, a.bottom), (b.top, b.bottom));
      final sameColumn = _overlaps((a.left, a.right), (b.left, b.right));
      if (sameRow != sameColumn) {
        return sameRow ? Axis.horizontal : Axis.vertical;
      }
    }
    return null;
  }

  Axis? _scrollAxisOrNull(BuildContext element) {
    if (!element.mounted) return null;
    return switch (Scrollable.maybeOf(element)) {
      final scrollable? => axisDirectionToAxis(scrollable.axisDirection),
      null => null,
    };
  }

  Axis _scrollAxis(BuildContext element) =>
      _scrollAxisOrNull(element) ?? Axis.vertical;

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

  /// The drop the builder gets.
  MotionDrop<T>? _drop() {
    if (_pending case final pending?) {
      // Once the item is in the items, it is the drop.
      if (_contains(pending.id)) return null;
      final drop = pending.drop;
      return MotionDrop<T>._(
        after: drop.after as T?,
        before: drop.before as T?,
        data: drop.data,
        size: drop.size,
        pending: true,
      );
    }
    final hover = _hover;
    final index = _index;
    if (hover == null || index == null) return null;
    final order = _order(hover.data);
    final i = index.clamp(0, order.length);
    // Flutter's drag reaches this before its flight starts, so the flight
    // is looked up once the drop is built, when it has the size.
    final flight = hover.flight ??= DragFlight.draggingWith(hover.data);
    return MotionDrop<T>._(
      after: i > 0 ? order[i - 1] : null,
      before: i < order.length ? order[i] : null,
      data: hover.data,
      size: flight?.feedbackRect.size,
      pending: false,
    );
  }

  // Dropping.

  void _accept(DragTargetDetails<Object> details) {
    final data = details.data;
    final flight = _hover?.flight ?? DragFlight.draggingWith(data);
    final probe = _probePoint();
    final order = _order(data);
    final index =
        (_index ??
                (probe == null
                    ? order.length
                    : _indexAt(probe, _measure(), data)))
            .clamp(0, order.length);
    final drop = MotionDrop<Object>._(
      after: index > 0 ? order[index - 1] : null,
      before: index < order.length ? order[index] : null,
      data: data,
      size: flight?.feedbackRect.size,
      pending: true,
    );
    // The item goes into this reorderable's group, so the flight lands
    // there.
    if (_landings() case final registry?) flight?.landIn(registry);
    _endHover();
    final result = widget.onMove?.call(
      MotionMove<T>._(
        data: data,
        after: drop.after as T?,
        before: drop.before as T?,
        index: index,
      ),
    );
    if (result is! Future<void>) {
      setState(() {});
      return;
    }
    final pending = _Pending(drop, _idOfData(data, flight), flight);
    // The flight waits over the gap until the item arrives.
    if (_gapSite case final gap?) flight?.hold = gap;
    setState(() => _pending = pending);
    result.then(
      (_) => _settle(pending, threw: false),
      onError: (Object error, StackTrace stack) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'motor_widgets',
            context: ErrorDescription('while moving a MotionReorderable item'),
          ),
        );
        _settle(pending, threw: true);
      },
    );
  }

  /// The landing registry of the reorderable's group, or null.
  LandingRegistry? _landings() {
    for (final slot in _slots) {
      if (slot.element.mounted) {
        return LandingRegistry.maybeOf(slot.element, listen: false);
      }
    }
    return mounted ? LandingRegistry.maybeOf(context, listen: false) : null;
  }

  /// Ends a pending move: the drop goes away, and the feedback lands on the
  /// item, or flies back when it isn't there.
  void _settle(_Pending pending, {required bool threw}) {
    if (!mounted || !identical(_pending, pending)) return;
    setState(() => _pending = null);
    final flight = pending.flight;
    if (flight == null) return;
    if (threw) {
      flight.reject();
    } else {
      // The app updated the items by now; they are built by the end of the
      // next frame.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_contains(pending.id)) flight.reject();
      });
    }
    flight.relocate();
  }

  // Screen readers.

  /// How the items follow each other, for naming the screen-reader actions,
  /// as last measured while they painted: down a column until then.
  ///
  /// Semantics are described while children are still laid out, when the
  /// items can't be measured, so the slots measure while they paint.
  _Flow get _semanticsFlow =>
      _paintedFlowAt?.$2 ?? const _Flow(Axis.vertical, 1);

  /// How the items follow each other now that this frame is laid out,
  /// measured once a frame for all the slots that paint.
  _Flow _paintedFlow() {
    final now = SchedulerBinding.instance.currentFrameTimeStamp;
    if (_paintedFlowAt case (final at, final flow) when at == now) return flow;
    final measured = _measure();
    final flow = measured.isEmpty ? _semanticsFlow : _flowOf(measured);
    _paintedFlowAt = (now, flow);
    return flow;
  }

  (Duration, _Flow)? _paintedFlowAt;

  /// The actions that move the item with [id], named by the way the items
  /// are laid out. Its slot asks once it is laid out.
  Map<CustomSemanticsAction, VoidCallback> _actions(Object id, _Flow flow) {
    final onMove = widget.onMove;
    final items = widget.items;
    if (!mounted || onMove == null || items.length < 2) return const {};
    final index = _indexOfId(id);
    if (index == null) return const {};
    final item = items[index];
    final strings = _strings;
    void to(int target) {
      final order = _order(item);
      onMove(
        MotionMove<T>._(
          data: item,
          after: target > 0 ? order[target - 1] : null,
          before: target < order.length ? order[target] : null,
          index: target,
        ),
      );
    }

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
    final count = items.length;
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

  /// A drag target for one item or gap of a sliver reorderable.
  Widget _target(Widget child) => DragTarget<Object>(
    onWillAcceptWithDetails: _willAccept,
    onMove: _move,
    onLeave: (_) => _leave(),
    onAcceptWithDetails: _accept,
    builder: (context, _, _) => child,
  );

  @override
  Widget build(BuildContext context) {
    _strings =
        Localizations.of<WidgetsLocalizations>(
          context,
          WidgetsLocalizations,
        ) ??
        const DefaultWidgetsLocalizations();
    final drop = _drop();
    final content = _ReorderableScope(
      zone: this as _MotionReorderableState<Object>,
      motion: widget.motion,
      sliver: widget._sliver,
      child: NotificationListener<ScrollNotification>(
        // A scroll under a still pointer moves the items past it.
        onNotification: (_) {
          _wake();
          return false;
        },
        child: Builder(builder: (context) => widget.builder(context, drop)),
      ),
    );
    if (widget._sliver) {
      assert(
        MotionLayoutGroup.isIn(context),
        'MotionReorderable.sliver must be inside a MotionLayoutGroup.',
      );
      return content;
    }
    return DragTarget<Object>(
      onWillAcceptWithDetails: _willAccept,
      onMove: _move,
      onLeave: (_) => _leave(),
      onAcceptWithDetails: _accept,
      builder: (context, _, _) => MotionLayoutGroup.isIn(context)
          ? content
          : MotionLayoutGroup(
              motion: widget.motion ?? MotionLayoutGroup.defaultMotion,
              debugLabel: widget.debugLabel,
              tickerRate: widget.tickerRate,
              child: content,
            ),
    );
  }
}

/// Registers one item's or the gap's rects with the reorderable.
class _Slot extends SingleChildRenderObjectWidget {
  const _Slot({
    required this.zone,
    required this.id,
    required this.isGap,
    super.child,
  });

  final _MotionReorderableState<Object> zone;
  final Object? id;
  final bool isGap;

  @override
  _RenderSlot createRenderObject(BuildContext context) =>
      _RenderSlot(zone: zone, id: id, isGap: isGap, element: context);

  @override
  void updateRenderObject(BuildContext context, _RenderSlot renderObject) {
    renderObject
      ..zone = zone
      ..id = id
      ..isGap = isGap
      ..element = context
      // The items, and with them the actions, may have changed.
      ..markNeedsSemanticsUpdate();
  }
}

class _RenderSlot extends RenderProxyBox {
  _RenderSlot({
    required _MotionReorderableState<Object> zone,
    required this.id,
    required this.isGap,
    required this.element,
  }) : _zone = zone;

  _MotionReorderableState<Object> get zone => _zone;
  _MotionReorderableState<Object> _zone;
  set zone(_MotionReorderableState<Object> value) {
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

  /// The flow the actions were last named by.
  _Flow? _described;

  /// The screen-reader actions that move the item, named by how the items
  /// follow each other, so a row says left and right.
  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    final id = this.id;
    if (isGap || id == null) return;
    final flow = _described = _zone._semanticsFlow;
    final actions = _zone._actions(id, flow);
    if (actions.isEmpty) return;
    // Each item is its own node, so its actions don't merge with another
    // item's of the same name.
    config
      ..isSemanticBoundary = true
      ..customSemanticsActions = actions;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    // The framework describes the semantics as soon as the slot is
    // attached, before the items are laid out. Once they are, rename the
    // actions if the items turn out to follow each other another way.
    final described = _described;
    if (described != null && described != _zone._paintedFlow()) {
      markNeedsSemanticsUpdate();
    }
  }
}
