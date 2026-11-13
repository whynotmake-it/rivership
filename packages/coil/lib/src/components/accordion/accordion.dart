// MotorInspectionScope is part of motor's experimental inspection API.
// ignore_for_file: experimental_member_use

import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/accordion/accordion_item.dart';
import 'package:coil/src/components/accordion/accordion_section.dart';
import 'package:coil/src/components/accordion/accordion_style.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';

/// A column of sections that each open and close a panel under their
/// trigger.
///
/// The accordion is controlled: it shows the open items you pass and
/// reports the new ones through `onChanged`. Use [CoilAccordion.single] for
/// at most one open item and [CoilAccordion.multiple] for any number.
///
/// Every trigger is a tab stop. Enter or Space toggles it, Up and Down move
/// between triggers, and Home and End jump to the first and last.
class CoilAccordion<T> extends StatefulWidget {
  /// An accordion with at most one open item, [value].
  ///
  /// [onChanged] gets the item to open, or null when the open item closes.
  /// The open item only closes when [collapsible] is true.
  const CoilAccordion.single({
    required this.items,
    required this.value,
    required ValueChanged<T?>? onChanged,
    super.key,
    this.collapsible = true,
    this.variant = CoilAccordionVariant.plain,
    this.indicator,
    this.size,
    this.motion,
    this.motions,
    this.style,
  }) : mode = CoilAccordionMode.single,
       values = null,
       _onValueChanged = onChanged,
       _onValuesChanged = null;

  /// An accordion with any number of open items, [values].
  ///
  /// [onChanged] gets the new set of open values.
  const CoilAccordion.multiple({
    required this.items,
    required Set<T> this.values,
    required ValueChanged<Set<T>>? onChanged,
    super.key,
    this.variant = CoilAccordionVariant.plain,
    this.indicator,
    this.size,
    this.motion,
    this.motions,
    this.style,
  }) : mode = CoilAccordionMode.multiple,
       value = null,
       collapsible = true,
       _onValueChanged = null,
       _onValuesChanged = onChanged;

  /// The sections, in order. Each item's `value` identifies it, so an open
  /// item stays open, and keeps its panel's state, when the list reorders.
  final List<CoilAccordionItem<T>> items;

  /// Whether one or several items can be open. Set by the constructor.
  final CoilAccordionMode mode;

  /// The open item in [CoilAccordionMode.single]. Null when none is open.
  final T? value;

  /// The open items in [CoilAccordionMode.multiple]. Null in single mode.
  final Set<T>? values;

  /// In single mode, whether pressing the open item closes it.
  final bool collapsible;

  /// The look.
  final CoilAccordionVariant variant;

  /// Replaces the chevron. It turns a quarter when its item opens.
  final Widget? indicator;

  /// Pins the accordion to one size step. Null follows
  /// [CoilAdaptiveScope].
  final CoilSize? size;

  /// Overrides the theme's motion tokens.
  final CoilMotion? motion;

  /// Per-track motions for this accordion, keyed by [CoilAccordionTrack]s.
  /// They win over the theme's [CoilThemeData.trackMotions] and the tokens.
  final Map<CoilAccordionTrack<Object>, Motion>? motions;

  /// Overrides for this accordion's look, on top of the theme's
  /// [CoilAccordionStyle] and the defaults.
  final CoilAccordionStyle? style;

  final ValueChanged<T?>? _onValueChanged;
  final ValueChanged<Set<T>>? _onValuesChanged;

  bool get _enabled => (_onValueChanged ?? _onValuesChanged) != null;

  bool _isOpen(T item) =>
      mode == CoilAccordionMode.single ? value == item : values!.contains(item);

  void _toggle(T item) {
    switch (mode) {
      case CoilAccordionMode.single:
        if (value != item) {
          _onValueChanged?.call(item);
        } else if (collapsible) {
          _onValueChanged?.call(null);
        }
      case CoilAccordionMode.multiple:
        final next = {...values!};
        if (!next.remove(item)) next.add(item);
        _onValuesChanged?.call(next);
    }
  }

  @override
  State<CoilAccordion<T>> createState() => _CoilAccordionState<T>();
}

class _CoilAccordionState<T> extends State<CoilAccordion<T>>
    with TickerProviderStateMixin {
  late final _focusRing = CoilHighlightPainter(
    vsync: this,
    debugLabel: 'CoilAccordion.focus',
  );
  final _nodes = <T, FocusNode>{};
  final _states = <T, WidgetStatesController>{};

  /// The trigger showing keyboard focus, for the group's shared ring.
  WidgetStatesController? _focusVisible;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(CoilAccordion<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  /// One focus node and states controller per item value.
  void _sync() {
    final values = {for (final item in widget.items) item.value};
    for (final value in values) {
      _nodes.putIfAbsent(
        value,
        () => FocusNode(debugLabel: 'CoilAccordion trigger $value'),
      );
      _states.putIfAbsent(value, () {
        final states = WidgetStatesController();
        states.addListener(() => _onStates(states));
        return states;
      });
    }
    _nodes.removeWhere((value, node) {
      if (values.contains(value)) return false;
      node.dispose();
      return true;
    });
    _states.removeWhere((value, states) {
      if (values.contains(value)) return false;
      if (identical(states, _focusVisible)) _focusVisible = null;
      states.dispose();
      return true;
    });
  }

  void _onStates(WidgetStatesController states) {
    final focused = states.value.contains(WidgetState.focused);
    if (focused && !identical(_focusVisible, states)) {
      setState(() => _focusVisible = states);
    } else if (!focused && identical(_focusVisible, states)) {
      setState(() => _focusVisible = null);
    }
  }

  @override
  void dispose() {
    _focusRing.dispose();
    for (final node in _nodes.values) {
      node.dispose();
    }
    for (final states in _states.values) {
      states.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final metrics = CoilTheme.metricsOf(context, size: widget.size);
    final motion = CoilTheme.motionOf(context, override: widget.motion);
    final group = widget.variant == CoilAccordionVariant.group;
    final style = CoilAccordionStyle.fallback(
      theme,
      metrics,
      highContrast: MediaQuery.maybeHighContrastOf(context) ?? false,
      variant: widget.variant,
    ).merge(CoilTheme.styleOf<CoilAccordionStyle>(context)).merge(widget.style);
    final items = widget.items;

    Widget list = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, item) in items.indexed)
          AccordionSection(
            key: ValueKey(item.value),
            index: i,
            item: item,
            open: widget._isOpen(item.value),
            group: group,
            indicator: widget.indicator,
            focusNode: _nodes[item.value]!,
            statesController: _states[item.value]!,
            onPressed: widget._enabled && item.enabled
                ? () => widget._toggle(item.value)
                : null,
            metrics: metrics,
            motion: motion,
            motions: widget.motions,
            style: style,
          ),
      ],
    );

    if (group) {
      final focused = _focusVisible;
      final target = focused == null
          ? -1
          : items.indexWhere((item) => identical(_states[item.value], focused));
      // The ring follows keyboard focus, which this state tracks itself.
      _focusRing.update(
        target: target < 0 ? null : target,
        fadeIn: false,
        motion: motion.quick,
        exitMotion: motion.quickExit,
        exitTravelMotion: motion.standard,
        fade: motion.fade,
        inflate: 1 + theme.focusRingWidth,
        decoration: ShapeDecoration(
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(
              theme.shape.radii(metrics.tier).focusRing,
            ),
            side: BorderSide(
              color: theme.colors.focusRing,
              width: theme.focusRingWidth,
            ),
          ),
        ),
      );
      list = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: style.groupWidth!),
        child: CoilHoverRegion(
          child: CoilHoverHighlight(
            color: style.highlight,
            radius: style.radius,
            motion: widget.motion,
            foreground: [_focusRing],
            child: list,
          ),
        ),
      );
    }

    return MotorInspectionScope(
      group: 'CoilAccordion',
      child: CoilRovingFocus(
        tabStop: null,
        tabStops: CoilRovingTabStops.each,
        axis: Axis.vertical,
        nodes: [for (final item in items) _nodes[item.value]!],
        child: list,
      ),
    );
  }
}
