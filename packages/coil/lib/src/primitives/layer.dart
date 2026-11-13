import 'package:coil/src/foundation/motion.dart';
import 'package:coil/src/primitives/highlight.dart';
import 'package:coil/src/primitives/motion_layer.dart';
import 'package:coil/src/primitives/selection_blocks.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// Something a [CoilMotionLayer] paints behind or in front of its targets.
///
/// Items are immutable descriptions. The layer owns the animation behind
/// each one and retargets it when an item changes, so a component only says
/// what it wants highlighted, in `build`, with no side effects.
@immutable
sealed class CoilLayerItem {
  const CoilLayerItem({this.key});

  /// Matches an item to the same item in the next build. Without a key,
  /// items match by type and position.
  final Key? key;
}

/// A box that glides between targets and fades in and out: a hovered row's
/// fill, a selected tab's pill, a focus ring that travels.
///
/// * A [target] after none, or a new [session], starts fresh: the box
///   appears at [from] (default: the target) and fades in.
/// * A new [target] while visible glides there on [motion].
/// * A null [target] fades out on [exitMotion], gliding to [exitTo] if set,
///   on [exitTravelMotion].
/// * [opacity] changes fade on [fade].
final class CoilHighlight extends CoilLayerItem {
  /// Creates a highlight.
  const CoilHighlight({
    required this.target,
    required this.decoration,
    required this.motion,
    required this.exitMotion,
    required this.exitTravelMotion,
    required this.fade,
    super.key,
    this.session = 0,
    this.from,
    this.exitTo,
    this.fadeIn = true,
    this.opacity = 1,
    this.inflate = 0,
    this.debugLabel,
  });

  /// The target index, or null to hide.
  final int? target;

  /// What the box looks like.
  final Decoration decoration;

  /// The glide between targets.
  final Motion motion;

  /// The fade out.
  final Motion exitMotion;

  /// The glide to [exitTo] while fading out.
  final Motion exitTravelMotion;

  /// Opacity changes.
  final Motion fade;

  /// Changing it starts a fresh session.
  final int session;

  /// Where a fresh session appears.
  final int? from;

  /// Where a fading box glides to.
  final int? exitTo;

  /// Whether a fresh session fades in, or appears at once.
  final bool fadeIn;

  /// The box's opacity while visible.
  final double opacity;

  /// How far the box extends past its target.
  final double inflate;

  /// A name for motor_devtools.
  final String? debugLabel;

  @override
  bool operator ==(Object other) =>
      other is CoilHighlight &&
      other.key == key &&
      other.target == target &&
      other.decoration == decoration &&
      other.motion == motion &&
      other.exitMotion == exitMotion &&
      other.exitTravelMotion == exitTravelMotion &&
      other.fade == fade &&
      other.session == session &&
      other.from == from &&
      other.exitTo == exitTo &&
      other.fadeIn == fadeIn &&
      other.opacity == opacity &&
      other.inflate == inflate;

  @override
  int get hashCode => Object.hash(
    key,
    target,
    decoration,
    motion,
    exitMotion,
    exitTravelMotion,
    fade,
    session,
    from,
    exitTo,
    fadeIn,
    opacity,
    inflate,
  );
}

/// Fills behind the [selected] targets, merging neighbors into one block
/// with rounded outer corners, and merging and splitting as the selection
/// changes.
final class CoilSelectionBlocks extends CoilLayerItem {
  /// Creates selection blocks. [selected] is copied, so later changes to
  /// the set passed in don't reach this item.
  CoilSelectionBlocks({
    required Set<int> selected,
    required this.color,
    required this.radius,
    required this.motion,
    super.key,
    this.axis = Axis.vertical,
  }) : selected = Set.unmodifiable(selected);

  /// The selected target indexes.
  final Set<int> selected;

  /// The fill.
  final Color color;

  /// The outer corner radius.
  final double radius;

  /// The tokens the merges and splits run on.
  final CoilMotion motion;

  /// The direction the targets are laid out in.
  final Axis axis;

  @override
  bool operator ==(Object other) =>
      other is CoilSelectionBlocks &&
      other.key == key &&
      setEquals(other.selected, selected) &&
      other.color == color &&
      other.radius == radius &&
      other.motion == motion &&
      other.axis == axis;

  @override
  int get hashCode => Object.hash(
    key,
    Object.hashAllUnordered(selected),
    color,
    radius,
    motion,
    axis,
  );
}

/// A custom layer item, like a `CustomPainter` that can read the rects of
/// the layer's targets.
///
/// Extend it with immutable fields for everything it draws. The layer
/// repaints when [shouldRepaint] says so after a rebuild, and whenever
/// [repaint] notifies (for values that change every frame, such as a
/// dragged thumb).
abstract class CoilLayerPaint extends CoilLayerItem {
  /// Creates a custom layer item.
  const CoilLayerPaint({super.key, this.repaint});

  /// Notifies when the item must repaint without a rebuild.
  final Listenable? repaint;

  /// Paints, with [geometry] giving the targets' rects in the layer.
  void paint(Canvas canvas, Offset offset, CoilLayerGeometry geometry);

  /// Whether [oldItem] painted something different.
  bool shouldRepaint(covariant CoilLayerPaint oldItem);
}

/// Paints [CoilLayerItem]s behind and in front of a group of
/// [CoilMotionTarget]s.
///
/// It reads each target's rect while painting, so an item follows a target
/// that resizes or reflows in the same frame, with no measuring pass. Put
/// the layer inside a scroll view's content so it moves with the items.
class CoilMotionLayer extends StatefulWidget {
  /// Creates a motion layer.
  const CoilMotionLayer({
    required this.child,
    super.key,
    this.background = const [],
    this.foreground = const [],
    this.handle,
  });

  /// The targets.
  final Widget child;

  /// Painted behind [child].
  final List<CoilLayerItem> background;

  /// Painted in front of [child].
  final List<CoilLayerItem> foreground;

  /// Gives the owning widget access to target rects.
  final CoilMotionLayerHandle? handle;

  @override
  State<CoilMotionLayer> createState() => _CoilMotionLayerState();
}

class _CoilMotionLayerState extends State<CoilMotionLayer>
    with TickerProviderStateMixin {
  final _background = _Painters();
  final _foreground = _Painters();

  @override
  void initState() {
    super.initState();
    _background.sync(widget.background, this);
    _foreground.sync(widget.foreground, this);
  }

  @override
  void didUpdateWidget(CoilMotionLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _background.sync(widget.background, this);
    _foreground.sync(widget.foreground, this);
  }

  @override
  void dispose() {
    _background.dispose();
    _foreground.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CoilPainterLayer(
    background: _background.painters,
    foreground: _foreground.painters,
    handle: widget.handle,
    child: widget.child,
  );
}

/// The painters behind one list of items, matched to the items by type and
/// key (or position).
class _Painters {
  List<CoilLayerPainter> painters = [];
  var _items = <CoilLayerItem>[];

  static Object _identity(CoilLayerItem item, int index) =>
      (item.runtimeType, item.key ?? index);

  void sync(List<CoilLayerItem> items, TickerProvider vsync) {
    final previous = {
      for (final (i, item) in _items.indexed)
        _identity(item, i): (item, painters[i]),
    };
    final next = <CoilLayerPainter>[];
    for (final (i, item) in items.indexed) {
      final match = previous.remove(_identity(item, i));
      final painter = match?.$2 ?? _create(item, vsync);
      if (match != null && match.$1 != item) _apply(painter, item);
      if (match == null && item is! CoilLayerPaint) _apply(painter, item);
      next.add(painter);
    }
    for (final (_, painter) in previous.values) {
      painter.dispose();
    }
    painters = next;
    _items = List.of(items);
  }

  static CoilLayerPainter _create(CoilLayerItem item, TickerProvider vsync) =>
      switch (item) {
        CoilHighlight() => CoilHighlightPainter(
          vsync: vsync,
          debugLabel: item.debugLabel,
        ),
        CoilSelectionBlocks() => CoilSelectionPainter(vsync: vsync),
        CoilLayerPaint() => _CustomPainter(item),
      };

  static void _apply(CoilLayerPainter painter, CoilLayerItem item) {
    switch (item) {
      case CoilHighlight():
        (painter as CoilHighlightPainter).update(
          target: item.target,
          decoration: item.decoration,
          motion: item.motion,
          exitMotion: item.exitMotion,
          exitTravelMotion: item.exitTravelMotion,
          fade: item.fade,
          session: item.session,
          from: item.from,
          exitTo: item.exitTo,
          fadeIn: item.fadeIn,
          opacity: item.opacity,
          inflate: item.inflate,
        );
      case CoilSelectionBlocks():
        (painter as CoilSelectionPainter).update(
          selected: item.selected,
          color: item.color,
          radius: item.radius,
          motion: item.motion,
          axis: item.axis,
        );
      case CoilLayerPaint():
        (painter as _CustomPainter).update(item);
    }
  }

  void dispose() {
    for (final painter in painters) {
      painter.dispose();
    }
  }
}

/// Paints a [CoilLayerPaint], repainting when it changes or its
/// `repaint` listenable notifies.
class _CustomPainter extends CoilLayerPainter {
  _CustomPainter(this._item) {
    _item.repaint?.addListener(notifyListeners);
  }

  CoilLayerPaint _item;

  void update(CoilLayerPaint value) {
    final old = _item;
    if (identical(old, value)) return;
    _item = value;
    if (old.repaint != value.repaint) {
      old.repaint?.removeListener(notifyListeners);
      value.repaint?.addListener(notifyListeners);
    }
    if (value.runtimeType != old.runtimeType || value.shouldRepaint(old)) {
      notifyListeners();
    }
  }

  @override
  void paint(Canvas canvas, Offset offset, CoilLayerGeometry geometry) =>
      _item.paint(canvas, offset, geometry);

  @override
  void dispose() {
    _item.repaint?.removeListener(notifyListeners);
    super.dispose();
  }
}
