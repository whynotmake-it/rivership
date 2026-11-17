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

  /// The index of the item that has focus, or -1.
  int get _current => widget.nodes.indexWhere((n) => n.hasPrimaryFocus);

  /// Where [move] goes from the focused item; null when nowhere.
  int? _target(_Move move) {
    final current = _current;
    if (current < 0) return null;
    return switch (move) {
      _Move.next => _next(current, 1),
      _Move.previous => _next(current, -1),
      _Move.first => _next(-1, 1),
      _Move.last => _next(widget.nodes.length, -1),
    };
  }

  late final _action = _RoveAction(this);

  void _rove(_RoveIntent intent) {
    final target = _target(intent.move);
    // Keys we own are consumed at the ends too, so focus doesn't leak to
    // a directional traversal outside the group.
    if (target == null) return;
    widget.nodes[target].requestFocus();
    widget.onMoved?.call(target);
  }

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.maybeOf(context) == TextDirection.rtl;
    final forward = widget.axis == Axis.horizontal
        ? (rtl ? LogicalKeyboardKey.arrowLeft : LogicalKeyboardKey.arrowRight)
        : LogicalKeyboardKey.arrowDown;
    final backward = widget.axis == Axis.horizontal
        ? (rtl ? LogicalKeyboardKey.arrowRight : LogicalKeyboardKey.arrowLeft)
        : LogicalKeyboardKey.arrowUp;
    return Shortcuts(
      includeSemantics: false,
      shortcuts: {
        SingleActivator(forward): _RoveIntent(_Move.next, widget.axis),
        SingleActivator(backward): _RoveIntent(_Move.previous, widget.axis),
        const SingleActivator(LogicalKeyboardKey.home): _RoveIntent(
          _Move.first,
          widget.axis,
        ),
        const SingleActivator(LogicalKeyboardKey.end): _RoveIntent(
          _Move.last,
          widget.axis,
        ),
      },
      child: Actions(actions: {_RoveIntent: _action}, child: widget.child),
    );
  }
}

enum _Move { next, previous, first, last }

/// Moves focus within a [CoilRovingFocus].
///
/// It names its group's [axis]: an arrow an inner group leaves alone, such
/// as Down in a horizontal group, bubbles to an outer group's [Shortcuts],
/// whose action lookup starts at the focused inner item again.
class _RoveIntent extends Intent {
  const _RoveIntent(this.move, this.axis);

  final _Move move;

  final Axis axis;
}

/// Moves focus for a [_RoveIntent]. Disabled while focus is outside the
/// group's items, and for Home and End when no item can take focus, so the
/// key goes on to whatever is above.
class _RoveAction extends Action<_RoveIntent> {
  _RoveAction(this.state);

  final _CoilRovingFocusState state;

  @override
  bool isEnabled(_RoveIntent intent) =>
      intent.axis == state.widget.axis &&
      switch (intent.move) {
        _Move.next || _Move.previous => state._current >= 0,
        _Move.first || _Move.last => state._target(intent.move) != null,
      };

  @override
  void invoke(_RoveIntent intent) => state._rove(intent);
}
