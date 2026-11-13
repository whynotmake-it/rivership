import 'package:coil/src/foundation/input_modality.dart';
import 'package:coil/src/foundation/theme.dart';
import 'package:coil/src/primitives/active_item.dart';
import 'package:coil/src/primitives/highlight.dart';
import 'package:coil/src/primitives/motion_layer.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Which direction "nearest item" is resolved along.
enum CoilHoverAxis {
  /// Horizontal strips (tabs): closest by left/width.
  x,

  /// Vertical lists (menus): closest by top/height.
  y,

  /// 2-D grids: closest by distance to each item's center.
  xy,
}

/// What a [CoilHoverRegion] knows: which item is lit.
@immutable
class CoilHoverState {
  /// Creates a hover state snapshot.
  const CoilHoverState({
    required this.activeIndex,
    required this.session,
    required this.pointerInside,
  });

  /// The lit item: under the pointer, or holding keyboard focus. Null when
  /// none.
  final int? activeIndex;

  /// Counts pointer entries. It steps when the pointer, having entered the
  /// region, first lights an item, so a highlight keyed on it fades in at
  /// that item instead of sliding over from where it was last.
  final int session;

  /// Whether a mouse is inside the region.
  final bool pointerInside;

  @override
  bool operator ==(Object other) =>
      other is CoilHoverState &&
      other.activeIndex == activeIndex &&
      other.session == session &&
      other.pointerInside == pointerInside;

  @override
  int get hashCode => Object.hash(activeIndex, session, pointerInside);
}

/// A group of [CoilHoverItem]s that share one highlight gliding between
/// them: the signature Fluid Functionalism interaction.
///
/// The port of `hooks/use-fluid-hover.ts`, on a [CoilMotionLayer]: items
/// are [CoilMotionTarget]s of the layer, which reads their rects at paint
/// time, so the highlight tracks a resizing or scrolling item in the same
/// frame without measuring. The region tracks hover-capable pointers and
/// keyboard focus into items and lights one item at a time; by default a
/// [CoilHighlightPainter] paints behind the lit item ([highlight]).
/// Callers add their own painters ([background], [foreground]) and read the
/// state in [onStateChanged], called while building, to drive them.
///
/// ```dart
/// CoilHoverRegion(
///   child: Column(children: [
///     for (final (i, label) in labels.indexed)
///       CoilHoverItem(index: i, child: MenuRow(label)),
///   ]),
/// )
/// ```
class CoilHoverRegion extends StatefulWidget {
  /// Creates a hover region.
  const CoilHoverRegion({
    required this.child,
    super.key,
    this.axis = CoilHoverAxis.y,
    this.nearest = false,
    this.followFocus = true,
    this.background = const [],
    this.foreground = const [],
    this.highlight = true,
    this.onStateChanged,
    this.onActiveIndexChanged,
    this.activeItem,
  });

  /// Shares the lit item with a list's [CoilActiveItemController]: hovering
  /// pointers write into it (via [CoilModality.pointer]) and the highlight
  /// paints whatever it holds, including items the keyboard made active. A
  /// pointer leaving the region clears an item it set.
  final CoilActiveItemController? activeItem;

  /// The items, anywhere below.
  final Widget child;

  /// The axis for [nearest].
  final CoilHoverAxis axis;

  /// Whether empty space (gaps, padding) lights the nearest item. Off by
  /// default: only the item under the pointer lights.
  final bool nearest;

  /// Whether an item gaining focus lights it.
  final bool followFocus;

  /// Painters behind the items (and behind the default highlight).
  final List<CoilLayerPainter> background;

  /// Painters in front of the items.
  final List<CoilLayerPainter> foreground;

  /// Whether the region paints its own hover highlight.
  final bool highlight;

  /// Called while the region builds, with its current state, so callers can
  /// update their painters.
  final ValueChanged<CoilHoverState>? onStateChanged;

  /// Called when the lit item changes.
  final ValueChanged<int?>? onActiveIndexChanged;

  /// The nearest region's state, if any.
  static CoilHoverState? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_CoilHoverScope>()?.state;

  @override
  State<CoilHoverRegion> createState() => _CoilHoverRegionState();
}

class _CoilHoverRegionState extends State<CoilHoverRegion>
    with TickerProviderStateMixin {
  final _layer = CoilMotionLayerHandle();
  late final _highlight = CoilHighlightPainter(
    vsync: this,
    debugLabel: 'CoilHoverRegion',
  );
  final _items = <int, _CoilHoverItemState>{};
  final _focused = <int>{};
  int? _activeIndex;
  int _session = 0;
  bool _pointerInside = false;
  bool _sessionPending = false;

  CoilHoverState get _state => CoilHoverState(
    activeIndex: _activeIndex,
    session: _session,
    pointerInside: _pointerInside,
  );

  void _register(int index, _CoilHoverItemState item) => _items[index] = item;

  void _unregister(int index, _CoilHoverItemState item) {
    if (_items[index] != item) return;
    _items.remove(index);
    _focused.remove(index);
    // Called during unmount: no setState. The highlight stops painting a
    // target that is gone, and the next build sees the cleared index.
    if (_activeIndex == index) _activeIndex = null;
  }

  void _setActive(int? index) {
    final controller = widget.activeItem;
    if (controller != null) {
      if (index == null && controller.via == CoilModality.keyboard) return;
      controller.activate(index, via: CoilModality.pointer);
      return; // _onController picks it up.
    }
    if (index == _activeIndex) return;
    if (index != null && (_activeIndex == null || _sessionPending)) {
      _session++;
      _sessionPending = false;
    }
    setState(() => _activeIndex = index);
    widget.onActiveIndexChanged?.call(index);
  }

  int? _hitTest(Offset position) {
    int? best;
    var bestDistance = double.infinity;
    for (final index in _layer.indices) {
      if (_items[index]?.widget.enabled != true) continue;
      // Between frames layout is clean, so the layer's rects are current.
      final rect = _layer.rectOf(index);
      if (rect == null) continue;
      if (rect.contains(position)) return index;
      if (!widget.nearest) continue;
      final distance = switch (widget.axis) {
        CoilHoverAxis.x => (position.dx - rect.center.dx).abs(),
        CoilHoverAxis.y => (position.dy - rect.center.dy).abs(),
        CoilHoverAxis.xy => (position - rect.center).distance,
      };
      if (distance < bestDistance) {
        bestDistance = distance;
        best = index;
      }
    }
    return best;
  }

  // Only pointers that can really hover light items: a touch never leaves
  // a highlight behind where the finger lifted.
  void _onEnter(PointerEnterEvent event) {
    if (!CoilInputModality.canHover(event.kind)) return;
    _pointerInside = true;
    _sessionPending = true;
  }

  void _onHover(PointerHoverEvent event) {
    if (!CoilInputModality.canHover(event.kind)) return;
    if (!_pointerInside) _onEnter(PointerEnterEvent.fromMouseEvent(event));
    final index = _hitTest(event.localPosition);
    // Over empty space without `nearest`, the highlight leaves: a
    // keyboard-focused item keeps it though, like the web's blur handling.
    _setActive(index ?? _focusLitIndex);
  }

  void _onExit(PointerExitEvent event) {
    if (!_pointerInside) return;
    setState(() => _pointerInside = false);
    _setActive(_focusLitIndex);
  }

  /// The focused item, if focus should light it: only while the keyboard
  /// drives focus (`:focus-visible`), never after a tap or click.
  int? get _focusLitIndex =>
      widget.followFocus &&
          _focused.isNotEmpty &&
          CoilInputModality.instance.value == CoilModality.keyboard
      ? _focused.last
      : null;

  void _onModality() {
    if (!mounted || _pointerInside) return;
    _setActive(_focusLitIndex);
  }

  void _onController() {
    final index = widget.activeItem?.index;
    if (index == _activeIndex) return;
    if (index != null && (_activeIndex == null || _sessionPending)) {
      _session++;
      _sessionPending = false;
    }
    setState(() => _activeIndex = index);
    widget.onActiveIndexChanged?.call(index);
  }

  @override
  void initState() {
    super.initState();
    CoilInputModality.instance.addListener(_onModality);
    widget.activeItem?.addListener(_onController);
    _activeIndex = widget.activeItem?.index;
  }

  @override
  void didUpdateWidget(CoilHoverRegion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeItem != widget.activeItem) {
      oldWidget.activeItem?.removeListener(_onController);
      widget.activeItem?.addListener(_onController);
      _activeIndex = widget.activeItem?.index ?? _activeIndex;
    }
  }

  @override
  void dispose() {
    widget.activeItem?.removeListener(_onController);
    CoilInputModality.instance.removeListener(_onModality);
    _highlight.dispose();
    super.dispose();
  }

  void _onItemFocusChange(int index, bool focused) {
    if (focused) {
      _focused.add(index);
      if (_focusLitIndex case final lit?) _setActive(lit);
    } else {
      _focused.remove(index);
      if (!_pointerInside && _activeIndex == index) _setActive(_focusLitIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    widget.onStateChanged?.call(state);
    final theme = CoilTheme.of(context);
    final motion = CoilTheme.motionOf(context);
    _highlight.update(
      target: widget.highlight ? state.activeIndex : null,
      session: state.session,
      motion: motion.quick,
      exitMotion: motion.quickExit,
      exitTravelMotion: motion.standard,
      fade: motion.fade,
      decoration: BoxDecoration(
        color: theme.colors.hover,
        borderRadius: BorderRadius.circular(theme.shape.item),
      ),
    );
    return _CoilHoverScope(
      region: this,
      state: state,
      child: MouseRegion(
        onEnter: _onEnter,
        onHover: _onHover,
        onExit: _onExit,
        child: CoilMotionLayer(
          handle: _layer,
          background: [...widget.background, _highlight],
          foreground: widget.foreground,
          child: widget.child,
        ),
      ),
    );
  }
}

class _CoilHoverScope extends InheritedWidget {
  const _CoilHoverScope({
    required this.region,
    required this.state,
    required super.child,
  });

  final _CoilHoverRegionState region;
  final CoilHoverState state;

  @override
  bool updateShouldNotify(_CoilHoverScope oldWidget) =>
      oldWidget.state.activeIndex != state.activeIndex ||
      oldWidget.state.session != state.session;
}

/// One item of a [CoilHoverRegion].
///
/// Registers [child]'s box under [index] and reports when anything inside
/// it gains or loses focus, so keyboard focus moves the highlight too.
class CoilHoverItem extends StatefulWidget {
  /// Creates a hover item.
  const CoilHoverItem({
    required this.index,
    required this.child,
    super.key,
    this.enabled = true,
  });

  /// The item's position in the region. Indices must be unique per region.
  final int index;

  /// Whether the pointer can light this item. A disabled item stays
  /// registered (so measurements stay stable) but is skipped by hit tests.
  final bool enabled;

  /// The item.
  final Widget child;

  /// Whether the item at [context] is the region's lit item.
  static bool isActive(BuildContext context, int index) =>
      CoilHoverRegion.maybeOf(context)?.activeIndex == index;

  @override
  State<CoilHoverItem> createState() => _CoilHoverItemState();
}

class _CoilHoverItemState extends State<CoilHoverItem> {
  _CoilHoverRegionState? _region;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final region = context
        .getInheritedWidgetOfExactType<_CoilHoverScope>()
        ?.region;
    if (region != _region) {
      _region?._unregister(widget.index, this);
      _region = region?.._register(widget.index, this);
    }
  }

  @override
  void didUpdateWidget(CoilHoverItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      _region
        ?.._unregister(oldWidget.index, this)
        .._register(widget.index, this);
    }
  }

  @override
  void dispose() {
    _region?._unregister(widget.index, this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      onFocusChange: (focused) =>
          _region?._onItemFocusChange(widget.index, focused),
      child: CoilMotionTarget(index: widget.index, child: widget.child),
    );
  }
}
