import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// How many items of a [CoilRovingFocus] Tab can reach.
enum CoilRovingTabStops {
  /// Only the item at `tabStop`: a radio group, tab list or toolbar.
  one,

  /// Every item. The arrow keys still move focus: a checkbox group.
  each,
}

/// One tab stop for a group of items, with arrow keys between them.
///
/// The roving tab index of WAI-ARIA toolbars, tab lists and radio groups:
/// only the item at [tabStop] is reached with Tab, and the arrow keys along
/// [axis], Home and End move focus between [nodes]. Items whose node can't
/// take focus (disabled) are skipped. Horizontal arrows follow the ambient
/// [Directionality], so Right moves backwards in RTL.
///
/// The caller owns [nodes] (usually one per item, passed to each item's
/// `CoilInteraction.focusNode`) and decides [tabStop] (usually the selected
/// item). Moving focus does not activate an item; listen to the nodes for
/// that.
class CoilRovingFocus extends StatefulWidget {
  /// Creates a roving focus group.
  const CoilRovingFocus({
    required this.nodes,
    required this.tabStop,
    required this.child,
    super.key,
    this.axis = Axis.horizontal,
    this.wrap = true,
    this.tabStops = CoilRovingTabStops.one,
    this.onMoved,
  });

  /// The items' focus nodes, in order.
  final List<FocusNode> nodes;

  /// The index of the item Tab reaches. Null or out of range: the first
  /// focusable item.
  final int? tabStop;

  /// The arrow keys that move focus: Left/Right or Up/Down.
  final Axis axis;

  /// Whether moving past the last item goes to the first, and back.
  final bool wrap;

  /// Which items Tab reaches. With [CoilRovingTabStops.each], `tabStop` is
  /// ignored.
  final CoilRovingTabStops tabStops;

  /// Called with the index of the item an arrow key, Home or End moved focus
  /// to, after the request. Not called for other focus changes.
  final ValueChanged<int>? onMoved;

  /// The items, anywhere below.
  final Widget child;

  @override
  State<CoilRovingFocus> createState() => _CoilRovingFocusState();
}

class _CoilRovingFocusState extends State<CoilRovingFocus> {
  @override
  void initState() {
    super.initState();
    _syncTraversal();
  }

  @override
  void didUpdateWidget(CoilRovingFocus oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTraversal();
  }

  void _syncTraversal() {
    final nodes = widget.nodes;
    if (widget.tabStops == CoilRovingTabStops.each) return;
    var stop = widget.tabStop;
    if (stop == null ||
        stop < 0 ||
        stop >= nodes.length ||
        !nodes[stop].canRequestFocus) {
      stop = nodes.indexWhere((n) => n.canRequestFocus);
    }
    for (var i = 0; i < nodes.length; i++) {
      nodes[i].skipTraversal = i != stop;
    }
  }

  /// The next focusable index from [from] in [step] direction, or null.
  int? _next(int from, int step) {
    final count = widget.nodes.length;
    var i = from;
    for (var n = 0; n < count; n++) {
      i += step;
      if (i < 0 || i >= count) {
        if (!widget.wrap) return null;
        i = (i + count) % count;
      }
      if (widget.nodes[i].canRequestFocus) return i;
    }
    return null;
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final nodes = widget.nodes;
    final current = nodes.indexWhere((n) => n.hasPrimaryFocus);
    if (current < 0) return KeyEventResult.ignored;
    final rtl = Directionality.maybeOf(context) == TextDirection.rtl;
    final forward = widget.axis == Axis.horizontal
        ? (rtl ? LogicalKeyboardKey.arrowLeft : LogicalKeyboardKey.arrowRight)
        : LogicalKeyboardKey.arrowDown;
    final backward = widget.axis == Axis.horizontal
        ? (rtl ? LogicalKeyboardKey.arrowRight : LogicalKeyboardKey.arrowLeft)
        : LogicalKeyboardKey.arrowUp;
    final key = event.logicalKey;
    final target = key == forward
        ? _next(current, 1)
        : key == backward
        ? _next(current, -1)
        : key == LogicalKeyboardKey.home
        ? _next(-1, 1)
        : key == LogicalKeyboardKey.end
        ? _next(nodes.length, -1)
        : null;
    if (target == null) {
      // Keys we own are consumed at the ends, so focus doesn't leak to a
      // directional traversal outside the group.
      return key == forward || key == backward
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }
    nodes[target].requestFocus();
    widget.onMoved?.call(target);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      onKeyEvent: _onKey,
      child: widget.child,
    );
  }
}
