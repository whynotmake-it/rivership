import 'package:fluid_functionalism/src/foundation/fluid_theme.dart';
import 'package:fluid_functionalism/src/primitives/fluid_highlight.dart';
import 'package:fluid_functionalism/src/primitives/fluid_interaction.dart';
import 'package:fluid_functionalism/src/primitives/fluid_motion_layer.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Which direction "nearest item" is resolved along.
enum FluidHoverAxis {
  /// Horizontal strips (tabs): closest by left/width.
  x,

  /// Vertical lists (menus): closest by top/height.
  y,

  /// 2-D grids: closest by distance to each item's center.
  xy,
}

/// What a [FluidHoverRegion] knows: which item is lit.
@immutable
class FluidHoverState {
  /// Creates a hover state snapshot.
  const FluidHoverState({
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
      other is FluidHoverState &&
      other.activeIndex == activeIndex &&
      other.session == session &&
      other.pointerInside == pointerInside;

  @override
  int get hashCode => Object.hash(activeIndex, session, pointerInside);
}

/// A group of [FluidHoverItem]s that share one highlight gliding between
/// them: the signature Fluid Functionalism interaction.
///
/// The port of `hooks/use-fluid-hover.ts`, on a [FluidMotionLayer]: items
/// are [FluidMotionTarget]s of the layer, which reads their rects at paint
/// time, so the highlight tracks a resizing or scrolling item in the same
/// frame without measuring. The region tracks hover-capable pointers and
/// keyboard focus into items and lights one item at a time; by default a
/// [FluidHighlightPainter] paints behind the lit item ([highlight]).
/// Callers add their own painters ([background], [foreground]) and read the
/// state in [onStateChanged], called while building, to drive them.
///
/// ```dart
/// FluidHoverRegion(
///   child: Column(children: [
///     for (final (i, label) in labels.indexed)
///       FluidHoverItem(index: i, child: MenuRow(label)),
///   ]),
/// )
/// ```
class FluidHoverRegion extends StatefulWidget {
  /// Creates a hover region.
  const FluidHoverRegion({
    required this.child,
    super.key,
    this.axis = FluidHoverAxis.y,
    this.nearest = false,
    this.followFocus = true,
    this.background = const [],
    this.foreground = const [],
    this.highlight = true,
    this.onStateChanged,
    this.onActiveIndexChanged,
  });

  /// The items, anywhere below.
  final Widget child;

  /// The axis for [nearest].
  final FluidHoverAxis axis;

  /// Whether empty space (gaps, padding) lights the nearest item. Off by
  /// default: only the item under the pointer lights.
  final bool nearest;

  /// Whether an item gaining focus lights it.
  final bool followFocus;

  /// Painters behind the items (and behind the default highlight).
  final List<FluidLayerPainter> background;

  /// Painters in front of the items.
  final List<FluidLayerPainter> foreground;

  /// Whether the region paints its own hover highlight.
  final bool highlight;

  /// Called while the region builds, with its current state, so callers can
  /// update their painters.
  final ValueChanged<FluidHoverState>? onStateChanged;

  /// Called when the lit item changes.
  final ValueChanged<int?>? onActiveIndexChanged;

  /// The nearest region's state, if any.
  static FluidHoverState? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_FluidHoverScope>()?.state;

  @override
  State<FluidHoverRegion> createState() => _FluidHoverRegionState();
}

class _FluidHoverRegionState extends State<FluidHoverRegion>
    with TickerProviderStateMixin {
  final _layer = FluidMotionLayerHandle();
  late final _highlight = FluidHighlightPainter(
    vsync: this,
    debugLabel: 'FluidHoverRegion',
  );
  final _items = <int, _FluidHoverItemState>{};
  final _focused = <int>{};
  int? _activeIndex;
  int _session = 0;
  bool _pointerInside = false;
  bool _sessionPending = false;

  FluidHoverState get _state => FluidHoverState(
    activeIndex: _activeIndex,
    session: _session,
    pointerInside: _pointerInside,
  );

  void _register(int index, _FluidHoverItemState item) => _items[index] = item;

  void _unregister(int index, _FluidHoverItemState item) {
    if (_items[index] != item) return;
    _items.remove(index);
    _focused.remove(index);
    // Called during unmount: no setState. The highlight stops painting a
    // target that is gone, and the next build sees the cleared index.
    if (_activeIndex == index) _activeIndex = null;
  }

  void _setActive(int? index) {
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
        FluidHoverAxis.x => (position.dx - rect.center.dx).abs(),
        FluidHoverAxis.y => (position.dy - rect.center.dy).abs(),
        FluidHoverAxis.xy => (position - rect.center).distance,
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
    if (!FluidInputModality.canHover(event.kind)) return;
    _pointerInside = true;
    _sessionPending = true;
  }

  void _onHover(PointerHoverEvent event) {
    if (!FluidInputModality.canHover(event.kind)) return;
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
          FluidInputModality.instance.value == FluidModality.keyboard
      ? _focused.last
      : null;

  void _onModality() {
    if (!mounted || _pointerInside) return;
    _setActive(_focusLitIndex);
  }

  @override
  void initState() {
    super.initState();
    FluidInputModality.instance.addListener(_onModality);
  }

  @override
  void dispose() {
    FluidInputModality.instance.removeListener(_onModality);
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
    final theme = FluidTheme.of(context);
    final motion = FluidTheme.motionOf(context);
    _highlight.update(
      target: widget.highlight ? state.activeIndex : null,
      session: state.session,
      motion: motion.fast,
      exitMotion: motion.fastExit,
      exitTravelMotion: motion.moderate,
      fade: motion.fade,
      decoration: BoxDecoration(
        color: theme.colors.hover,
        borderRadius: BorderRadius.circular(theme.shape.item),
      ),
    );
    return _FluidHoverScope(
      region: this,
      state: state,
      child: MouseRegion(
        onEnter: _onEnter,
        onHover: _onHover,
        onExit: _onExit,
        child: FluidMotionLayer(
          handle: _layer,
          background: [...widget.background, _highlight],
          foreground: widget.foreground,
          child: widget.child,
        ),
      ),
    );
  }
}

class _FluidHoverScope extends InheritedWidget {
  const _FluidHoverScope({
    required this.region,
    required this.state,
    required super.child,
  });

  final _FluidHoverRegionState region;
  final FluidHoverState state;

  @override
  bool updateShouldNotify(_FluidHoverScope oldWidget) =>
      oldWidget.state.activeIndex != state.activeIndex ||
      oldWidget.state.session != state.session;
}

/// One item of a [FluidHoverRegion].
///
/// Registers [child]'s box under [index] and reports when anything inside
/// it gains or loses focus, so keyboard focus moves the highlight too.
class FluidHoverItem extends StatefulWidget {
  /// Creates a hover item.
  const FluidHoverItem({
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
      FluidHoverRegion.maybeOf(context)?.activeIndex == index;

  @override
  State<FluidHoverItem> createState() => _FluidHoverItemState();
}

class _FluidHoverItemState extends State<FluidHoverItem> {
  _FluidHoverRegionState? _region;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final region = context
        .getInheritedWidgetOfExactType<_FluidHoverScope>()
        ?.region;
    if (region != _region) {
      _region?._unregister(widget.index, this);
      _region = region?.._register(widget.index, this);
    }
  }

  @override
  void didUpdateWidget(FluidHoverItem oldWidget) {
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
      child: FluidMotionTarget(index: widget.index, child: widget.child),
    );
  }
}
