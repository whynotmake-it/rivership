import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

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

  /// The items, anywhere below.
  final Widget child;

  @override
  State<CoilRovingFocus> createState() => _CoilRovingFocusState();
}

class _CoilRovingFocusState extends State<CoilRovingFocus> {
  void _syncTraversal() {
    final nodes = widget.nodes;
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
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    _syncTraversal();
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      onKeyEvent: _onKey,
      child: widget.child,
    );
  }
}
