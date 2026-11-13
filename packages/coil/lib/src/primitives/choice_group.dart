import 'package:coil/src/foundation/metrics.dart';
import 'package:coil/src/foundation/motion.dart';
import 'package:coil/src/foundation/option.dart';
import 'package:coil/src/foundation/theme.dart';
import 'package:coil/src/foundation/typography.dart';
import 'package:coil/src/primitives/highlight.dart';
import 'package:coil/src/primitives/hover.dart';
import 'package:coil/src/primitives/interaction.dart';
import 'package:coil/src/primitives/roving_focus.dart';
import 'package:coil/src/primitives/selection_blocks.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// Builds item [index] of a [CoilChoiceGroup], given the focus node and states
/// controller the group keeps for it.
typedef CoilChoiceItemBuilder =
    Widget Function(
      BuildContext context,
      int index,
      FocusNode node,
      WidgetStatesController states,
    );

/// The shared body of the selection groups (checkbox, radio, toggle): a
/// hover region whose items paint the selection behind the gliding
/// highlight, one traveling focus ring in front, and roving focus between
/// the items.
///
/// With [mergeSelection] the selected items share merged blocks (the
/// checkbox and toggle groups). Without it the single selected item has one
/// fill that glides between items on `standard` (the radio group).
class CoilChoiceGroup extends StatefulWidget {
  /// Creates a choice group of [count] items.
  const CoilChoiceGroup({
    required this.count,
    required this.selected,
    required this.itemBuilder,
    required this.selectionColor,
    required this.highlightColor,
    required this.radius,
    required this.motion,
    super.key,
    this.axis = Axis.vertical,
    this.mergeSelection = true,
    this.singleTabStop = true,
    this.tabStop,
    this.onFocusMoved,
    this.isEnabled,
  });

  /// The number of items.
  final int count;

  /// The indexes of the selected items.
  final Set<int> selected;

  /// Builds one item.
  final CoilChoiceItemBuilder itemBuilder;

  /// The selection fill.
  final Color selectionColor;

  /// The hover highlight.
  final Color highlightColor;

  /// The corner radius of the fills.
  final double radius;

  /// The motion tokens (already resolved against the instance override).
  final CoilMotion motion;

  /// The arrow-key axis and the layout direction.
  final Axis axis;

  /// Whether the selected items share merged blocks.
  final bool mergeSelection;

  /// Whether the group is one tab stop (the roving tabindex of radio groups
  /// and toolbars). Otherwise every item is a tab stop and the arrow keys
  /// still move focus between them, as in a checkbox group.
  final bool singleTabStop;

  /// The item Tab reaches. Null: the first selected item, then the first.
  final int? tabStop;

  /// Called when the keyboard moves focus from one item to another inside
  /// the group (radio groups select on it).
  final ValueChanged<int>? onFocusMoved;

  /// Whether item `i` takes part in hover and focus. All do when null.
  final bool Function(int i)? isEnabled;

  /// The indexes of the [options] whose value is in [values].
  static Set<int> selectedIndexes<T>(
    List<CoilOption<T>> options,
    Set<T> values,
  ) => {
    for (final (i, option) in options.indexed)
      if (values.contains(option.value)) i,
  };

  /// [values] with [value] added, or removed if it is there.
  static Set<T> toggled<T>(Set<T> values, T value) {
    final next = {...values};
    if (!next.remove(value)) next.add(value);
    return next;
  }

  @override
  State<CoilChoiceGroup> createState() => _CoilChoiceGroupState();
}

class _CoilChoiceGroupState extends State<CoilChoiceGroup>
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

  /// Whether focus is inside the group, so a gain is a move, not an entry.
  bool _inside = false;

  void _sync() {
    while (_nodes.length < widget.count) {
      final i = _nodes.length;
      final node = FocusNode(debugLabel: 'CoilChoiceGroup item $i')
        ..addListener(() => _onFocus(i));
      _nodes.add(node);
      final states = WidgetStatesController();
      states.addListener(() => _onStates(i, states.value));
      _states.add(states);
    }
    while (_nodes.length > widget.count) {
      _nodes.removeLast().dispose();
      _states.removeLast().dispose();
    }
  }

  void _onFocus(int i) {
    if (!_nodes[i].hasFocus) return;
    if (_inside) widget.onFocusMoved?.call(i);
    _inside = true;
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

  /// Arrow keys, Home and End when every item is its own tab stop
  /// ([CoilRovingFocus] makes the group one stop, which isn't wanted here).
  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final current = _nodes.indexWhere((n) => n.hasPrimaryFocus);
    if (current < 0) return KeyEventResult.ignored;
    final horizontal = widget.axis == Axis.horizontal;
    final rtl = Directionality.maybeOf(context) == TextDirection.rtl;
    final key = event.logicalKey;
    final forward = horizontal
        ? (rtl ? LogicalKeyboardKey.arrowLeft : LogicalKeyboardKey.arrowRight)
        : LogicalKeyboardKey.arrowDown;
    final backward = horizontal
        ? (rtl ? LogicalKeyboardKey.arrowRight : LogicalKeyboardKey.arrowLeft)
        : LogicalKeyboardKey.arrowUp;
    int? next(int from, int step) {
      var i = from;
      for (var n = 0; n < _nodes.length; n++) {
        i = (i + step + _nodes.length) % _nodes.length;
        if (_nodes[i].canRequestFocus) return i;
      }
      return null;
    }

    final target = key == forward
        ? next(current, 1)
        : key == backward
        ? next(current, -1)
        : key == LogicalKeyboardKey.home
        ? next(-1, 1)
        : key == LogicalKeyboardKey.end
        ? next(_nodes.length, -1)
        : null;
    if (target == null) {
      return key == forward || key == backward
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }
    _nodes[target].requestFocus();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    _sync();
    final theme = CoilTheme.of(context);
    final motion = widget.motion;
    final horizontal = widget.axis == Axis.horizontal;
    final selectedFirst = widget.selected.isEmpty
        ? null
        : widget.selected.reduce((a, b) => a < b ? a : b);

    if (widget.mergeSelection) {
      _blocks.update(
        selected: widget.selected,
        axis: widget.axis,
        color: widget.selectionColor,
        radius: widget.radius,
        motion: motion,
      );
    } else {
      _fill.update(
        target: selectedFirst,
        motion: motion.standard,
        exitMotion: motion.quickExit,
        exitTravelMotion: motion.standard,
        fade: motion.fade,
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
      motion: motion.quick,
      exitMotion: motion.quickExit,
      exitTravelMotion: motion.standard,
      fade: motion.fade,
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
      for (var i = 0; i < widget.count; i++)
        CoilHoverItem(
          index: i,
          enabled: widget.isEnabled?.call(i) ?? true,
          child: widget.itemBuilder(context, i, _nodes[i], _states[i]),
        ),
    ];

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      onFocusChange: (focused) {
        if (!focused) _inside = false;
      },
      onKeyEvent: widget.singleTabStop ? null : _onKey,
      child: _roving(
        selectedFirst,
        child: CoilHoverRegion(
          axis: horizontal ? CoilHoverAxis.x : CoilHoverAxis.y,
          background: [if (widget.mergeSelection) _blocks else _fill],
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
      ),
    );
  }

  Widget _roving(int? selectedFirst, {required Widget child}) =>
      widget.singleTabStop
      ? CoilRovingFocus(
          nodes: _nodes,
          axis: widget.axis,
          tabStop: widget.tabStop ?? selectedFirst,
          child: child,
        )
      : child;
}

/// A selectable row: a leading control, a label that goes from muted to
/// foreground and from regular to semibold when selected (a hidden semibold
/// copy reserves the width), the touch press fill, and the shared
/// interaction states.
class CoilChoiceRow extends StatelessWidget {
  /// Creates a row.
  const CoilChoiceRow({
    required this.leading,
    required this.label,
    required this.selected,
    required this.metrics,
    required this.motion,
    required this.textStyle,
    required this.labelColor,
    required this.pressFill,
    required this.focusNode,
    required this.statesController,
    required this.onPressed,
    required this.radius,
    super.key,
  });

  /// The control at the row's start; receives the row's interaction states.
  final Widget Function(Set<WidgetState> states) leading;

  /// The label.
  final Widget label;

  /// Whether the row is selected (semibold, foreground).
  final bool selected;

  /// The size step.
  final CoilMetrics metrics;

  /// The motion tokens.
  final CoilMotion motion;

  /// The label style (its color comes from [labelColor]).
  final TextStyle textStyle;

  /// The label color, resolved with `selected` and `hovered`.
  final WidgetStateProperty<Color?> labelColor;

  /// The fill a finger shows while pressing the row.
  final Color pressFill;

  /// The row's focus node.
  final FocusNode focusNode;

  /// The row's states.
  final WidgetStatesController statesController;

  /// Called on tap, Enter or Space. Null disables the row.
  final VoidCallback? onPressed;

  /// The corner radius of the press fill.
  final double radius;

  @override
  Widget build(BuildContext context) {
    final touch = metrics.tier == CoilTier.touch;
    final semibold = textStyle.copyWith(
      fontVariations: CoilWeight.semibold.variations,
    );
    return Opacity(
      opacity: onPressed == null ? (touch ? 0.4 : 0.5) : 1,
      child: CoilInteraction(
        onPressed: onPressed,
        focusNode: focusNode,
        statesController: statesController,
        minHitTarget: metrics.minHitTarget,
        builder: (context, states, _) {
          final pressing =
              states.contains(WidgetState.pressed) &&
              !states.contains(WidgetState.hovered);
          // Touch rows rest at full foreground: "the pointer is here"
          // means nothing to a finger.
          final color = touch
              ? labelColor.resolve({WidgetState.selected})!
              : labelColor.resolve({
                  if (selected) WidgetState.selected,
                  if (states.contains(WidgetState.hovered) ||
                      states.contains(WidgetState.focused))
                    WidgetState.hovered,
                })!;
          return MotionBuilder<Color>(
            value: pressing ? pressFill : pressFill.withValues(alpha: 0),
            converter: MotionConverter.colorRgb,
            motion: pressing ? motion.fade : motion.fadeExit,
            debugLabel: 'CoilCoilChoiceRow press',
            builder: (context, fill, child) => DecoratedBox(
              decoration: ShapeDecoration(
                color: fill,
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(radius),
                ),
              ),
              child: child,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: metrics.controlHeight),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: metrics.itemPaddingX,
                  vertical: metrics.controlPaddingY(metrics.body),
                ),
                child: Row(
                  spacing: metrics.gap,
                  children: [
                    leading(states),
                    Expanded(
                      child: MotionBuilder<Color>(
                        value: color,
                        converter: MotionConverter.colorRgb,
                        motion: motion.fade,
                        debugLabel: 'CoilCoilChoiceRow label color',
                        builder: (context, color, _) => SingleMotionBuilder(
                          value: selected ? CoilWeight.semibold.wght : 400,
                          motion: motion.fade,
                          builder: (context, wght, _) => Stack(
                            children: [
                              // Reserves the semibold width, so selecting a
                              // row never rewraps its label.
                              Opacity(
                                opacity: 0,
                                child: ExcludeSemantics(
                                  child: DefaultTextStyle(
                                    style: semibold,
                                    child: label,
                                  ),
                                ),
                              ),
                              DefaultTextStyle(
                                style: textStyle.copyWith(
                                  color: color,
                                  fontVariations: [
                                    FontVariation('wght', wght),
                                    FontVariation(
                                      'opsz',
                                      14 + (wght - 400) / 150 * 4,
                                    ),
                                  ],
                                ),
                                child: label,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
