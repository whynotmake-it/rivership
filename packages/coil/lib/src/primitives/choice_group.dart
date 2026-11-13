import 'package:coil/src/foundation/option.dart';
import 'package:coil/src/foundation/theme.dart';
import 'package:coil/src/primitives/highlight.dart';
import 'package:coil/src/primitives/hover.dart';
import 'package:coil/src/primitives/roving_focus.dart';
import 'package:coil/src/primitives/selection_blocks.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// How the selected items of a [CoilChoiceGroup] are marked.
enum CoilChoiceSelection {
  /// Selected items that touch share one block, which merges and splits as
  /// the selection changes (checkbox and toggle groups).
  merged,

  /// One fill glides to the selected item (radio groups).
  gliding,
}

/// Builds the item for [option], given the focus node and states controller
/// the group keeps for it.
typedef CoilChoiceItemBuilder<T> =
    Widget Function(
      BuildContext context,
      CoilOption<T> option,
      FocusNode node,
      WidgetStatesController states,
    );

/// Lays out the items of a checkbox, radio or toggle group and gives them
/// one hover highlight, one focus ring and arrow-key focus.
///
/// The group paints the selection behind the items: merged blocks or one
/// gliding fill ([selection]). Items are built by [itemBuilder] and should
/// use `CoilInteraction` with the node and states they are given.
class CoilChoiceGroup<T> extends StatefulWidget {
  /// Creates a choice group.
  const CoilChoiceGroup({
    required this.options,
    required this.selected,
    required this.itemBuilder,
    required this.selectionColor,
    required this.highlightColor,
    required this.radius,
    required this.selectionMotion,
    required this.ringMotion,
    required this.fadeMotion,
    super.key,
    this.axis = Axis.vertical,
    this.selection = CoilChoiceSelection.merged,
    this.tabStops = CoilRovingTabStops.each,
    this.enabled = true,
    this.onFocusMoved,
  });

  /// The items, in order.
  final List<CoilOption<T>> options;

  /// The values of the selected items.
  final Set<T> selected;

  /// Builds one item.
  final CoilChoiceItemBuilder<T> itemBuilder;

  /// The selection fill.
  final Color selectionColor;

  /// The hover highlight.
  final Color highlightColor;

  /// The corner radius of the fills.
  final double radius;

  /// The motion of the selection fill: merging and splitting, or gliding.
  final Motion selectionMotion;

  /// The motion of the focus ring travelling between items.
  final Motion ringMotion;

  /// The motion of fades (the ring appearing).
  final Motion fadeMotion;

  /// The direction of the items and of the arrow keys.
  final Axis axis;

  /// How the selected items are marked.
  final CoilChoiceSelection selection;

  /// Which items Tab reaches. With [CoilRovingTabStops.one] it is the first
  /// selected item, else the first.
  final CoilRovingTabStops tabStops;

  /// Whether the items can take part in hover and focus. Items whose option
  /// is disabled never do.
  final bool enabled;

  /// Called with the value of the item that an arrow key, Home or End moved
  /// focus to.
  final ValueChanged<T>? onFocusMoved;

  @override
  State<CoilChoiceGroup<T>> createState() => _CoilChoiceGroupState<T>();
}

class _CoilChoiceGroupState<T> extends State<CoilChoiceGroup<T>>
    with TickerProviderStateMixin {
  late final _blocks = CoilSelectionPainter(vsync: this);
  late final _fill = CoilHighlightPainter(
    vsync: this,
    debugLabel: 'CoilChoiceGroup.selected',
  );
  late final _ring = CoilHighlightPainter(
    vsync: this,
    debugLabel: 'CoilChoiceGroup.focus',
  );

  final _nodes = <FocusNode>[];
  final _states = <WidgetStatesController>[];
  int? _focusVisible;

  @override
  void initState() {
    super.initState();
    _resize();
  }

  @override
  void didUpdateWidget(CoilChoiceGroup<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _resize();
  }

  void _resize() {
    while (_nodes.length < widget.options.length) {
      final i = _nodes.length;
      _nodes.add(FocusNode(debugLabel: 'CoilChoiceGroup item $i'));
      final states = WidgetStatesController();
      states.addListener(() => _onStates(i, states.value));
      _states.add(states);
    }
    while (_nodes.length > widget.options.length) {
      _nodes.removeLast().dispose();
      _states.removeLast().dispose();
    }
  }

  void _onStates(int index, Set<WidgetState> states) {
    final focused = states.contains(WidgetState.focused);
    if (focused && _focusVisible != index) {
      setState(() => _focusVisible = index);
    } else if (!focused && _focusVisible == index) {
      setState(() => _focusVisible = null);
    }
  }

  @override
  void dispose() {
    _blocks.dispose();
    _fill.dispose();
    _ring.dispose();
    for (final node in _nodes) {
      node.dispose();
    }
    for (final states in _states) {
      states.dispose();
    }
    super.dispose();
  }

  bool _isEnabled(int i) => widget.enabled && widget.options[i].enabled;

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final horizontal = widget.axis == Axis.horizontal;
    final selected = {
      for (final (i, option) in widget.options.indexed)
        if (widget.selected.contains(option.value)) i,
    };
    final first = selected.isEmpty
        ? null
        : selected.reduce((a, b) => a < b ? a : b);
    final tabStop = first != null && _isEnabled(first) ? first : null;

    switch (widget.selection) {
      case CoilChoiceSelection.merged:
        _blocks.update(
          selected: selected,
          axis: widget.axis,
          color: widget.selectionColor,
          radius: widget.radius,
          motion: CoilTheme.motionOf(
            context,
          ).copyWith(standard: widget.selectionMotion),
        );
      case CoilChoiceSelection.gliding:
        _fill.update(
          target: first,
          motion: widget.selectionMotion,
          exitMotion: widget.selectionMotion,
          exitTravelMotion: widget.selectionMotion,
          fade: widget.fadeMotion,
          decoration: ShapeDecoration(
            color: widget.selectionColor,
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(widget.radius),
            ),
          ),
        );
    }
    _ring.update(
      target: _focusVisible,
      fadeIn: false,
      motion: widget.ringMotion,
      exitMotion: widget.ringMotion,
      exitTravelMotion: widget.ringMotion,
      fade: widget.fadeMotion,
      inflate: 1 + theme.focusRingWidth,
      decoration: ShapeDecoration(
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(
            theme.shape.radii(CoilTheme.tierOf(context)).focusRing,
          ),
          side: BorderSide(
            color: theme.colors.focusRing,
            width: theme.focusRingWidth,
          ),
        ),
      ),
    );

    final items = [
      for (final (i, option) in widget.options.indexed)
        CoilHoverItem(
          index: i,
          enabled: _isEnabled(i),
          child: widget.itemBuilder(context, option, _nodes[i], _states[i]),
        ),
    ];

    return CoilRovingFocus(
      nodes: _nodes,
      axis: widget.axis,
      tabStops: widget.tabStops,
      tabStop: tabStop,
      onMoved: widget.onFocusMoved == null
          ? null
          : (i) {
              if (_isEnabled(i)) {
                widget.onFocusMoved!(widget.options[i].value);
              }
            },
      child: CoilHoverRegion(
        axis: horizontal ? CoilHoverAxis.x : CoilHoverAxis.y,
        background: [
          if (widget.selection == CoilChoiceSelection.merged)
            _blocks
          else
            _fill,
        ],
        foreground: [_ring],
        highlightColor: widget.highlightColor,
        highlightRadius: widget.radius,
        child: horizontal
            ? Row(mainAxisSize: MainAxisSize.min, children: items)
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: items,
              ),
      ),
    );
  }
}
