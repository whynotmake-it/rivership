import 'dart:math' as math;

import 'package:coil/src/foundation/option.dart';
import 'package:coil/src/foundation/theme.dart';
import 'package:coil/src/primitives/hover.dart';
import 'package:coil/src/primitives/layer.dart';
import 'package:coil/src/primitives/roving_focus.dart';
import 'package:flutter/rendering.dart';
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

    final selection = switch (widget.selection) {
      CoilChoiceSelection.merged => CoilSelectionBlocks(
        selected: selected,
        axis: widget.axis,
        color: widget.selectionColor,
        radius: widget.radius,
        motion: CoilTheme.motionOf(
          context,
        ).copyWith(standard: widget.selectionMotion),
      ),
      CoilChoiceSelection.gliding => CoilHighlight(
        debugLabel: 'CoilChoiceGroup.selection',
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
      ),
    };
    final ring = CoilHighlight(
      debugLabel: 'CoilChoiceGroup.focus',
      target: _focusVisible,
      fadeIn: false,
      motion: widget.ringMotion,
      exitMotion: widget.ringMotion,
      exitTravelMotion: widget.ringMotion,
      fade: widget.fadeMotion,
      inflate: theme.focusRing.extent,
      decoration: theme.focusRing.decorationAround(
        theme.colors,
        radius: widget.radius,
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
        child: CoilHoverHighlight(
          background: [selection],
          foreground: [ring],
          color: widget.highlightColor,
          radius: widget.radius,
          child: horizontal
              ? _FitRow(children: items)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: items,
                ),
        ),
      ),
    );
  }
}

/// A row of items at their natural widths. When they don't all fit, the
/// widest are cut to a common cap so the row fills its room (their labels
/// ellipsize); short items keep their full width.
class _FitRow extends MultiChildRenderObjectWidget {
  const _FitRow({required super.children});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderFitRow(textDirection: Directionality.of(context));

  @override
  void updateRenderObject(BuildContext context, _RenderFitRow renderObject) {
    renderObject.textDirection = Directionality.of(context);
  }
}

class _FitRowParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderFitRow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _FitRowParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _FitRowParentData> {
  _RenderFitRow({required TextDirection textDirection})
    // The field sits behind a setter that marks layout dirty.
    // ignore: prefer_initializing_formals
    : _textDirection = textDirection;

  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _FitRowParentData) {
      child.parentData = _FitRowParentData();
    }
  }

  /// The widths the children get in [maxWidth].
  List<double> _widths(double maxWidth) {
    final children = getChildrenAsList();
    final natural = [
      for (final c in children) c.getMaxIntrinsicWidth(double.infinity),
    ];
    final total = natural.fold<double>(0, (a, b) => a + b);
    if (!maxWidth.isFinite || total <= maxWidth) return natural;
    final sorted = [...natural]..sort();
    var left = maxWidth;
    var cap = 0.0;
    for (final (i, w) in sorted.indexed) {
      final share = left / (sorted.length - i);
      if (w > share) {
        cap = share;
        break;
      }
      left -= w;
      cap = w;
    }
    return [for (final w in natural) math.min(w, cap)];
  }

  Size _compute(BoxConstraints constraints, ChildLayouter layoutChild) {
    final widths = _widths(constraints.maxWidth);
    var width = 0.0;
    var height = 0.0;
    for (final (i, child) in getChildrenAsList().indexed) {
      final size = layoutChild(
        child,
        BoxConstraints(maxWidth: widths[i], maxHeight: constraints.maxHeight),
      );
      width += size.width;
      height = math.max(height, size.height);
    }
    return constraints.constrain(Size(width, height));
  }

  @override
  double computeMinIntrinsicWidth(double height) => 0;

  @override
  double computeMaxIntrinsicWidth(double height) => getChildrenAsList().fold(
    0,
    (sum, c) => sum + c.getMaxIntrinsicWidth(height),
  );

  @override
  double computeMinIntrinsicHeight(double width) => _compute(
    BoxConstraints(maxWidth: width),
    ChildLayoutHelper.dryLayoutChild,
  ).height;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      computeMinIntrinsicHeight(width);

  @override
  @protected
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _compute(constraints, ChildLayoutHelper.dryLayoutChild);

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      defaultComputeDistanceToHighestActualBaseline(baseline);

  @override
  void performLayout() {
    size = _compute(constraints, ChildLayoutHelper.layoutChild);
    final rtl = textDirection == TextDirection.rtl;
    var x = rtl ? size.width : 0.0;
    for (final child in getChildrenAsList()) {
      final w = child.size.width;
      if (rtl) x -= w;
      (child.parentData! as _FitRowParentData).offset = Offset(
        x,
        (size.height - child.size.height) / 2,
      );
      if (!rtl) x += w;
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
