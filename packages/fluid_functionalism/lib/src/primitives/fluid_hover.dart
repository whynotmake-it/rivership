import 'package:fluid_functionalism/src/primitives/fluid_highlight.dart';
import 'package:fluid_functionalism/src/primitives/fluid_interaction.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
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

/// What a [FluidHoverRegion] knows: which item is lit and where every item
/// is, in the region's coordinate space.
@immutable
class FluidHoverState {
  /// Creates a hover state snapshot.
  const FluidHoverState({
    required this.activeIndex,
    required this.rects,
    required this.session,
    required this.pointerInside,
    required this.isMeasured,
  });

  /// The lit item: under the pointer, or holding focus. Null when none.
  final int? activeIndex;

  /// Every registered item's rect, by index.
  final Map<int, Rect> rects;

  /// Counts pointer entries. It steps when the pointer, having entered the
  /// region, first lights an item, so a highlight keyed on it fades in at
  /// that item instead of sliding over from where it was last.
  final int session;

  /// Whether a mouse is inside the region.
  final bool pointerInside;

  /// Whether every registered item has been measured.
  final bool isMeasured;

  /// The rect of [activeIndex], once measured.
  Rect? get activeRect =>
      activeIndex == null || !isMeasured ? null : rects[activeIndex];

  /// The rect of item [index], once measured.
  Rect? rectOf(int? index) =>
      index == null || !isMeasured ? null : rects[index];
}

/// Builds a highlight layer from the region's state.
typedef FluidHoverLayerBuilder =
    Widget Function(
      BuildContext context,
      FluidHoverState state,
    );

/// A group of [FluidHoverItem]s that share one highlight gliding between
/// them: the signature Fluid Functionalism interaction.
///
/// The port of `hooks/use-fluid-hover.ts`. Items register themselves; the
/// region measures them after layout, tracks the mouse, and follows
/// keyboard focus into items, then hands a [FluidHoverState] to
/// [backgroundBuilder] (painted behind the items) and [foregroundBuilder]
/// (painted above them). By default the background is a single
/// [FluidHighlight] on the lit item.
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
    this.backgroundBuilder,
    this.foregroundBuilder,
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

  /// Painted behind the items. Defaults to [defaultHighlight].
  final FluidHoverLayerBuilder? backgroundBuilder;

  /// Painted above the items.
  final FluidHoverLayerBuilder? foregroundBuilder;

  /// Called when the lit item changes.
  final ValueChanged<int?>? onActiveIndexChanged;

  /// The default background: one [FluidHighlight] on the lit item.
  static Widget defaultHighlight(BuildContext context, FluidHoverState state) =>
      FluidHighlight(rect: state.activeRect, session: state.session);

  /// The nearest region's state, if any.
  static FluidHoverState? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_FluidHoverScope>()?.state;

  @override
  State<FluidHoverRegion> createState() => _FluidHoverRegionState();
}

class _FluidHoverRegionState extends State<FluidHoverRegion> {
  final _stackKey = GlobalKey();
  final _items = <int, _FluidHoverItemState>{};
  final _focused = <int>{};
  Map<int, Rect> _rects = const {};
  bool _measured = false;
  bool _measureScheduled = false;
  int? _activeIndex;
  int _session = 0;
  bool _pointerInside = false;
  bool _sessionPending = false;

  FluidHoverState get _state => FluidHoverState(
    activeIndex: _activeIndex,
    rects: _rects,
    session: _session,
    pointerInside: _pointerInside,
    isMeasured: _measured,
  );

  void _register(int index, _FluidHoverItemState item) {
    _items[index] = item;
    _measured = false;
    _scheduleMeasure();
  }

  void _unregister(int index, _FluidHoverItemState item) {
    if (_items[index] != item) return;
    _items.remove(index);
    _focused.remove(index);
    // Called during unmount, when setState is not allowed: the measurement
    // pass that follows rebuilds.
    if (_activeIndex == index) _activeIndex = null;
    _measured = false;
    _scheduleMeasure();
  }

  void _scheduleMeasure() {
    if (_measureScheduled) return;
    _measureScheduled = true;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) => _measure())
      ..ensureVisualUpdate();
  }

  void _measure() {
    _measureScheduled = false;
    if (!mounted) return;
    final region = _stackKey.currentContext?.findRenderObject();
    if (region is! RenderBox || !region.hasSize || !region.attached) return;
    final rects = <int, Rect>{};
    for (final MapEntry(:key, :value) in _items.entries) {
      final box = value.context.findRenderObject();
      if (box is! RenderBox || !box.hasSize || !box.attached) continue;
      rects[key] = box.localToGlobal(Offset.zero, ancestor: region) & box.size;
    }
    final measured = rects.length == _items.length;
    if (!mapEquals(rects, _rects) || measured != _measured) {
      setState(() {
        _rects = rects;
        _measured = measured;
      });
    }
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
    for (final MapEntry(key: index, value: rect) in _rects.entries) {
      if (_items[index]?.widget.enabled != true) continue;
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
    final background =
        widget.backgroundBuilder ?? FluidHoverRegion.defaultHighlight;
    return _FluidHoverScope(
      region: this,
      state: state,
      child: MouseRegion(
        onEnter: _onEnter,
        onHover: _onHover,
        onExit: _onExit,
        child: Stack(
          key: _stackKey,
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: Builder(
                  builder: (context) => background(context, state),
                ),
              ),
            ),
            _LayoutReporter(onLayout: _scheduleMeasure, child: widget.child),
            if (widget.foregroundBuilder case final foreground?)
              Positioned.fill(
                child: IgnorePointer(
                  child: Builder(
                    builder: (context) => foreground(context, state),
                  ),
                ),
              ),
          ],
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
      child: _LayoutReporter(
        onLayout: () => _region?._scheduleMeasure(),
        child: widget.child,
      ),
    );
  }
}

/// Calls [onLayout] after every layout of its child, so the region can
/// remeasure (the Flutter counterpart of the hook's ResizeObserver).
class _LayoutReporter extends SingleChildRenderObjectWidget {
  const _LayoutReporter({required this.onLayout, super.child});

  final VoidCallback onLayout;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderLayoutReporter(onLayout);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderLayoutReporter renderObject,
  ) => renderObject.onLayout = onLayout;
}

class _RenderLayoutReporter extends RenderProxyBox {
  _RenderLayoutReporter(this.onLayout);

  VoidCallback onLayout;

  @override
  void performLayout() {
    super.performLayout();
    onLayout();
  }
}
