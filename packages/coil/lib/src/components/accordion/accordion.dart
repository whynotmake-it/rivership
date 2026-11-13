// MotorInspectionScope is part of motor's experimental inspection API.
// ignore_for_file: experimental_member_use

import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/accordion/accordion_style.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/motor_widgets.dart';

/// How many items of a [CoilAccordion] can be open at once.
enum CoilAccordionMode {
  /// At most one. Opening an item closes the open one.
  single,

  /// Any number.
  multiple,
}

/// How a [CoilAccordion] looks.
enum CoilAccordionVariant {
  /// Full width. Each trigger shows its own hover fill.
  plain,

  /// 288 wide by default. The triggers share one gliding hover highlight,
  /// and open items get a tint behind trigger and panel.
  group,
}

/// One section of a [CoilAccordion].
@immutable
class CoilAccordionItem<T> {
  /// Creates an item.
  const CoilAccordionItem({
    required this.value,
    required this.label,
    required this.child,
    this.icon,
    this.enabled = true,
  });

  /// What the accordion reports when this item opens or closes.
  final T value;

  /// The trigger's text. It also names the panel for screen readers.
  final String label;

  /// The panel's content, shown while the item is open.
  final Widget child;

  /// An optional glyph before the label.
  final Widget? icon;

  /// Whether the item can be toggled. Arrow keys skip disabled items.
  final bool enabled;
}

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
    this.style,
  }) : mode = CoilAccordionMode.multiple,
       value = null,
       collapsible = true,
       _onValueChanged = null,
       _onValuesChanged = onChanged;

  /// The sections, in order.
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
  final _nodes = <FocusNode>[];
  final _states = <WidgetStatesController>[];
  int? _focusVisible;

  void _sync() {
    while (_nodes.length < widget.items.length) {
      final i = _nodes.length;
      _nodes.add(FocusNode(debugLabel: 'CoilAccordion trigger $i'));
      final states = WidgetStatesController();
      states.addListener(() => _onStates(i, states.value));
      _states.add(states);
    }
    while (_nodes.length > widget.items.length) {
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

  /// Up and Down move between triggers (wrapping), Home and End jump.
  /// Disabled triggers can't take focus, so they're skipped.
  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final current = _nodes.indexWhere((n) => n.hasPrimaryFocus);
    if (current < 0) return KeyEventResult.ignored;
    int? step(int from, int by) {
      for (var n = 1; n <= _nodes.length; n++) {
        final i = (from + by * n) % _nodes.length;
        if (_nodes[i].canRequestFocus) return i;
      }
      return null;
    }

    final int? target;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        target = step(current, 1);
      case LogicalKeyboardKey.arrowUp:
        target = step(current, -1);
      case LogicalKeyboardKey.home:
        target = step(-1, 1);
      case LogicalKeyboardKey.end:
        target = step(_nodes.length, -1);
      default:
        return KeyEventResult.ignored;
    }
    if (target != null) _nodes[target].requestFocus();
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    _focusRing.dispose();
    for (final node in _nodes) {
      node.dispose();
    }
    for (final states in _states) {
      states.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _sync();
    final theme = CoilTheme.of(context);
    final metrics = CoilTheme.metricsOf(context, size: widget.size);
    final motion = CoilTheme.motionOf(context, override: widget.motion);
    final style = CoilAccordionStyle.fallback(
      theme,
      metrics,
      highContrast: MediaQuery.maybeHighContrastOf(context) ?? false,
    ).merge(CoilTheme.styleOf<CoilAccordionStyle>(context)).merge(widget.style);
    final group = widget.variant == CoilAccordionVariant.group;

    Widget list = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, item) in widget.items.indexed)
          _Item(
            index: i,
            label: item.label,
            icon: item.icon,
            open: widget._isOpen(item.value),
            group: group,
            indicator: widget.indicator,
            focusNode: _nodes[i],
            statesController: _states[i],
            onPressed: widget._enabled && item.enabled
                ? () => widget._toggle(item.value)
                : null,
            metrics: metrics,
            motion: motion,
            style: style,
            child: item.child,
          ),
      ],
    );

    if (group) {
      // The ring follows keyboard focus, which this state tracks itself.
      _focusRing.update(
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
              theme.shape.radii(metrics.tier).focusRing,
            ),
            side: BorderSide(
              color: theme.colors.focusRing,
              width: theme.focusRingWidth,
            ),
          ),
        ),
      );
      list = CoilHoverRegion(
        highlightColor: style.highlight,
        highlightRadius: style.radius,
        foreground: [_focusRing],
        child: list,
      );
      // DESIGN.md §14.4: 288 wide by default; a tight parent still wins.
      list = ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 288),
        child: list,
      );
    }

    return MotorInspectionScope(
      group: 'CoilAccordion',
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        includeSemantics: false,
        onKeyEvent: _onKey,
        child: list,
      ),
    );
  }
}

/// One section: the trigger over its collapsible panel, with the open tint
/// behind both in the group variant.
class _Item extends StatelessWidget {
  const _Item({
    required this.index,
    required this.label,
    required this.icon,
    required this.open,
    required this.group,
    required this.indicator,
    required this.focusNode,
    required this.statesController,
    required this.onPressed,
    required this.metrics,
    required this.motion,
    required this.style,
    required this.child,
  });

  final int index;
  final String label;
  final Widget? icon;
  final bool open;
  final bool group;
  final Widget? indicator;
  final FocusNode focusNode;
  final WidgetStatesController statesController;
  final VoidCallback? onPressed;
  final CoilMetrics metrics;
  final CoilMotion motion;
  final CoilAccordionStyle style;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Unique per item, so the trigger can point screen readers at its panel.
    final panelId = 'CoilAccordion.panel.${identityHashCode(focusNode)}';
    Widget trigger = _Trigger(
      index: index,
      label: label,
      icon: icon,
      open: open,
      group: group,
      indicator: indicator,
      panelId: panelId,
      focusNode: focusNode,
      statesController: statesController,
      onPressed: onPressed,
      metrics: metrics,
      motion: motion,
      style: style,
    );
    if (group) {
      trigger = CoilHoverItem(
        index: index,
        enabled: onPressed != null,
        child: trigger,
      );
    }
    final section = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        trigger,
        CoilCollapsible(
          expanded: open,
          motion: motion,
          debugLabel: 'CoilAccordion.panel',
          child: Semantics(
            container: true,
            explicitChildNodes: true,
            role: SemanticsRole.region,
            label: label,
            identifier: panelId,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                metrics.controlPaddingX,
                0,
                metrics.controlPaddingX,
                12,
              ),
              child: DefaultTextStyle(
                style: style.panelTextStyle!,
                child: child,
              ),
            ),
          ),
        ),
      ],
    );
    if (!group) return section;
    final tint = style.openTint!;
    return MotionBuilder<Color>(
      value: open ? tint : tint.withValues(alpha: 0),
      motion: open ? motion.fade : motion.fadeExit,
      converter: MotionConverter.colorRgb,
      debugLabel: 'CoilAccordion.tint',
      builder: (context, color, child) => DecoratedBox(
        decoration: ShapeDecoration(
          color: color,
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(style.radius!),
          ),
        ),
        child: child,
      ),
      child: section,
    );
  }
}

class _Trigger extends StatelessWidget {
  const _Trigger({
    required this.index,
    required this.label,
    required this.icon,
    required this.open,
    required this.group,
    required this.indicator,
    required this.panelId,
    required this.focusNode,
    required this.statesController,
    required this.onPressed,
    required this.metrics,
    required this.motion,
    required this.style,
  });

  final int index;
  final String label;
  final Widget? icon;
  final bool open;
  final bool group;
  final Widget? indicator;
  final String panelId;
  final FocusNode focusNode;
  final WidgetStatesController statesController;
  final VoidCallback? onPressed;
  final CoilMetrics metrics;
  final CoilMotion motion;
  final CoilAccordionStyle style;

  @override
  Widget build(BuildContext context) {
    // In the group the region lights the trigger, keyboard focus included.
    final regionLit = group && CoilHoverItem.isActive(context, index);
    final radius = BorderRadius.circular(style.radius!);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final disabledOpacity = metrics.tier == CoilTier.touch ? 0.4 : 0.5;

    return Semantics(
      container: true,
      button: true,
      enabled: onPressed != null,
      expanded: open,
      controlsNodes: {panelId},
      child: CoilInteraction(
        onPressed: onPressed,
        focusNode: focusNode,
        statesController: statesController,
        minHitTarget: metrics.minHitTarget,
        builder: (context, states, _) {
          final hovered = states.contains(WidgetState.hovered);
          final pressed = states.contains(WidgetState.pressed);
          final lit = hovered || regionLit;
          // A mouse press keeps the hover look; a touch press fills.
          final fill = style.triggerFill!.resolve({
            if (hovered && !group) WidgetState.hovered,
            if (pressed && !hovered) WidgetState.pressed,
          })!;
          final color = style.label!.resolve({
            if (open) WidgetState.selected,
            if (lit) WidgetState.hovered,
          })!;
          return Opacity(
            opacity: onPressed == null ? disabledOpacity : 1,
            child: CoilFocusRing(
              visible: !group && states.contains(WidgetState.focused),
              borderRadius: radius,
              offset: 2,
              child: MotionBuilder<Color>(
                value: fill,
                motion: fill.a > 0 ? motion.fade : motion.fadeExit,
                converter: MotionConverter.colorRgb,
                debugLabel: 'CoilAccordion.fill',
                builder: (context, fill, child) => DecoratedBox(
                  decoration: ShapeDecoration(
                    color: fill,
                    shape: RoundedSuperellipseBorder(borderRadius: radius),
                  ),
                  child: child,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: metrics.controlHeight,
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: metrics.controlPaddingX,
                      vertical: metrics.controlPaddingY(metrics.body),
                    ),
                    child: MotionBuilder<Color>(
                      value: color,
                      motion: motion.fade,
                      converter: MotionConverter.colorRgb,
                      debugLabel: 'CoilAccordion.label',
                      builder: (context, color, _) => IconTheme(
                        data: IconThemeData(
                          size: metrics.iconSize,
                          applyTextScaling: true,
                          color: color,
                          weight: open || lit
                              ? CoilIconWeight.emphasis
                              : CoilIconWeight.rest,
                        ),
                        child: Row(
                          spacing: metrics.gap,
                          children: [
                            ?icon,
                            Expanded(
                              child: _Label(
                                label: label,
                                open: open,
                                color: color,
                                textStyle: style.textStyle!,
                                motion: motion,
                              ),
                            ),
                            MotionRotation(
                              turns: open ? (rtl ? -0.25 : 0.25) : 0,
                              motion: open ? motion.quick : motion.quickExit,
                              debugLabel: 'CoilAccordion.chevron',
                              child: indicator ?? const _Chevron(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The trigger's label: semibold while open, with a hidden semibold copy
/// reserving the width so opening never shifts the row.
class _Label extends StatelessWidget {
  const _Label({
    required this.label,
    required this.open,
    required this.color,
    required this.textStyle,
    required this.motion,
  });

  final String label;
  final bool open;
  final Color color;
  final TextStyle textStyle;
  final CoilMotion motion;

  @override
  Widget build(BuildContext context) {
    Widget text(TextStyle style) => Text(
      label,
      style: style,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
    );
    return Stack(
      children: [
        ExcludeSemantics(
          child: Opacity(
            opacity: 0,
            child: text(
              textStyle.copyWith(
                fontVariations: CoilWeight.semibold.variations,
              ),
            ),
          ),
        ),
        SingleMotionBuilder(
          value: open ? CoilWeight.semibold.wght : CoilWeight.normal.wght,
          motion: motion.fade,
          debugLabel: 'CoilAccordion.weight',
          builder: (context, wght, _) {
            // Interpolates opsz with wght, as CoilWeight pairs them.
            final t =
                (wght - CoilWeight.normal.wght) /
                (CoilWeight.semibold.wght - CoilWeight.normal.wght);
            return text(
              textStyle.copyWith(
                color: color,
                fontVariations: [
                  FontVariation('wght', wght),
                  FontVariation(
                    'opsz',
                    CoilWeight.normal.opsz +
                        t * (CoilWeight.semibold.opsz - CoilWeight.normal.opsz),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

/// The default indicator: a chevron pointing toward the end, drawn in the
/// [IconTheme]'s size, color and weight (1.5 stroke at 400, 2 at 533).
class _Chevron extends StatelessWidget {
  const _Chevron();

  @override
  Widget build(BuildContext context) {
    final icons = IconTheme.of(context);
    return CustomPaint(
      size: Size.square(CoilIconSize.of(context)),
      painter: _ChevronPainter(
        color: icons.color ?? const Color(0xFF000000),
        stroke: 1.5 * (icons.weight ?? CoilIconWeight.rest) / 400,
        rtl: Directionality.of(context) == TextDirection.rtl,
      ),
    );
  }
}

class _ChevronPainter extends CustomPainter {
  _ChevronPainter({
    required this.color,
    required this.stroke,
    required this.rtl,
  });

  final Color color;
  final double stroke;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    // On the 24-unit grid; mirrored so it points to the end in RTL.
    double x(double v) => (rtl ? 24 - v : v) * s;
    canvas.drawPath(
      Path()
        ..moveTo(x(9), 6 * s)
        ..lineTo(x(15), 12 * s)
        ..lineTo(x(9), 18 * s),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke * s
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_ChevronPainter old) =>
      old.color != color || old.stroke != stroke || old.rtl != rtl;
}
