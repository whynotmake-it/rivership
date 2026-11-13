import 'package:coil/src/foundation/input_modality.dart';
import 'package:coil/src/foundation/motion.dart';
import 'package:coil/src/foundation/theme.dart';
import 'package:coil/src/primitives/active_item.dart';
import 'package:coil/src/primitives/layer.dart';
import 'package:coil/src/primitives/motion_layer.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

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

/// Tracks which of its [CoilHoverItem]s is lit, for a list, a tab strip or
/// a grid.
///
/// An item lights when a hovering pointer is over it, or when it holds
/// keyboard focus. Touch never lights an item. Read the state with
/// [CoilHoverRegion.maybeOf] from any descendant. The region paints
/// nothing: put a [CoilHoverHighlight] (or your own [CoilMotionLayer]) between
/// the region and the items.
///
/// ```dart
/// CoilHoverRegion(
///   child: CoilHoverHighlight(
///     child: Column(children: [
///       for (final (i, label) in labels.indexed)
///         CoilHoverItem(index: i, child: Text(label)),
///     ]),
///   ),
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
    this.activeItem,
    this.onActiveIndexChanged,
  });

  /// The items, anywhere below.
  final Widget child;

  /// The axis [nearest] measures along.
  final CoilHoverAxis axis;

  /// Whether empty space between items lights the nearest one. Off by
  /// default: only the item under the pointer lights.
  final bool nearest;

  /// Whether an item that gets keyboard focus lights.
  final bool followFocus;

  /// Shares the lit item with a list's [CoilActiveItemController]. Hovering
  /// writes into it, and items the keyboard makes active light too. A
  /// pointer leaving the region clears an item it set.
  final CoilActiveItemController? activeItem;

  /// Called when the lit item changes.
  final ValueChanged<int?>? onActiveIndexChanged;

  /// The nearest region's state, if any.
  static CoilHoverState? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_CoilHoverScope>()?.state;

  @override
  State<CoilHoverRegion> createState() => _CoilHoverRegionState();
}

class _CoilHoverRegionState extends State<CoilHoverRegion> {
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
    // Called during unmount: no setState. The next build sees the cleared
    // index.
    if (_activeIndex == index) _activeIndex = null;
  }

  /// Lights [index] (or nothing). A shared [CoilActiveItemController] is
  /// the source of truth when there is one; [_show] applies its value.
  void _setActive(int? index) {
    final controller = widget.activeItem;
    if (controller == null) {
      _show(index);
      return;
    }
    if (index == null && controller.via == CoilModality.keyboard) return;
    controller.activate(index, via: CoilModality.pointer);
  }

  void _onController() => _show(widget.activeItem?.index);

  void _show(int? index) {
    if (index == _activeIndex) return;
    // A new session starts when something lights after nothing was, or on
    // the first light after the pointer entered: the highlight then fades
    // in where it is instead of sliding over.
    if (index != null && (_activeIndex == null || _sessionPending)) {
      _session++;
      _sessionPending = false;
    }
    setState(() => _activeIndex = index);
    widget.onActiveIndexChanged?.call(index);
  }

  int? _hitTest(Offset position) {
    final region = context.findRenderObject();
    if (region is! RenderBox) return null;
    int? best;
    var bestDistance = double.infinity;
    for (final MapEntry(key: index, value: item) in _items.entries) {
      if (!item.widget.enabled) continue;
      // Between frames layout is clean, so the items' boxes are current.
      final box = item.context.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      final rect = MatrixUtils.transformRect(
        box.getTransformTo(region),
        Offset.zero & box.size,
      );
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
    _sessionPending = true;
    if (!_pointerInside) setState(() => _pointerInside = true);
  }

  void _onHover(PointerHoverEvent event) {
    if (!CoilInputModality.canHover(event.kind)) return;
    if (!_pointerInside) _onEnter(PointerEnterEvent.fromMouseEvent(event));
    // Over empty space the highlight leaves, unless an item holds keyboard
    // focus.
    _setActive(_hitTest(event.localPosition) ?? _focusLitIndex);
  }

  void _onExit(PointerExitEvent event) {
    if (!_pointerInside) return;
    setState(() => _pointerInside = false);
    _setActive(_focusLitIndex);
  }

  /// The focused item, if focus should light it: only while the keyboard
  /// drives focus, never after a tap or click.
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
  Widget build(BuildContext context) => _CoilHoverScope(
    region: this,
    state: _state,
    child: MouseRegion(
      onEnter: _onEnter,
      onHover: _onHover,
      onExit: _onExit,
      child: widget.child,
    ),
  );
}

/// The default gliding highlight for a [CoilHoverRegion]: a fill behind the
/// lit item that glides between items and fades in where a new hover
/// starts.
///
/// Put it between the region and the items. It hosts the region's
/// [CoilMotionLayer], so pass any other decorations that share the layer
/// (selection blocks, a focus ring) as [background] and [foreground].
/// Inside a scroll view, put it in the scrolled content so the highlight
/// moves with the rows.
class CoilHoverHighlight extends StatelessWidget {
  /// Creates the highlight.
  const CoilHoverHighlight({
    required this.child,
    super.key,
    this.color,
    this.radius,
    this.background = const [],
    this.foreground = const [],
    this.motion,
    this.glideMotion,
  });

  /// The items.
  final Widget child;

  /// The fill; the theme's `hover` tint when null.
  final Color? color;

  /// The corner radius; the theme's item radius when null.
  final double? radius;

  /// Layer items behind the items, under the highlight.
  final List<CoilLayerItem> background;

  /// Layer items in front of the items.
  final List<CoilLayerItem> foreground;

  /// Overrides the theme's motion tokens for the highlight.
  final CoilMotion? motion;

  /// The glide between items, for a component's resolved track motion.
  /// Defaults to `quick`.
  final Motion? glideMotion;

  @override
  Widget build(BuildContext context) {
    final state = CoilHoverRegion.maybeOf(context);
    final theme = CoilTheme.of(context);
    final tokens = CoilTheme.motionOf(context, override: motion);
    return CoilMotionLayer(
      background: [
        ...background,
        CoilHighlight(
          key: const ValueKey('CoilHoverHighlight'),
          debugLabel: 'CoilHoverHighlight',
          target: state?.activeIndex,
          session: state?.session ?? 0,
          motion: glideMotion ?? tokens.quick,
          exitMotion: tokens.quickExit,
          exitTravelMotion: tokens.standard,
          fade: tokens.fade,
          decoration: ShapeDecoration(
            color: color ?? theme.colors.hover,
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(
                radius ?? CoilTheme.radiiOf(context).item,
              ),
            ),
          ),
        ),
      ],
      foreground: foreground,
      child: child,
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
      oldWidget.state != state;
}

/// One item of a [CoilHoverRegion].
///
/// Registers [child] under [index] for hit testing and for the painters of
/// the nearest [CoilMotionLayer]. Focus inside it lights it too.
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
