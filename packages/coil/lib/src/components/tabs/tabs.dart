import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/tabs/tabs_style.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/motor_widgets.dart';

/// Which tabs of [CoilTabs] show their label.
enum CoilTabLabels {
  /// Every tab shows its label.
  always,

  /// Only the selected tab shows its label; the others show their icon
  /// alone. Tabs without an icon always show their label.
  selected,
}

/// One tab of [CoilTabs].
@immutable
class CoilTab<T> {
  /// Creates a tab.
  const CoilTab({
    required this.value,
    required this.label,
    this.icon,
    this.child,
  });

  /// What selecting this tab reports.
  final T value;

  /// The tab's text: shown unless [child] is set, and read by screen
  /// readers.
  final String label;

  /// An optional icon before the label.
  final Widget? icon;

  /// Replaces the `Text(label)`. It turns semibold when selected; a hidden
  /// semibold copy reserves the width so neighbors never shift.
  final Widget? child;
}

/// A row of tabs with the fluid highlight.
///
/// * The selected pill glides between tabs on the theme's `standard` spring.
/// * A lighter hover pill glides out of the selected one, follows the
///   pointer on `quick`, and glides back into it when the pointer leaves.
/// * Arrow keys, Home and End move focus ([CoilRovingFocus]); Enter or Space
///   selects (manual activation). Only the selected tab is in the Tab order.
///   A focus ring travels with keyboard focus.
/// * When the tabs are wider than their space the strip scrolls
///   horizontally (with the platform's scroll physics), fading out 24 px at
///   an edge that has more tabs behind it. The selected tab, and the tab
///   keyboard focus moves to, scroll into view on the `standard` spring.
///   The pills ride the scrolling content, so they stay on their tab.
class CoilTabs<T> extends StatefulWidget {
  /// Creates tabs.
  const CoilTabs({
    required this.tabs,
    required this.value,
    required this.onChanged,
    super.key,
    this.labels = CoilTabLabels.always,
    this.size,
    this.motion,
    this.style,
    this.debugHoveredIndex,
    this.debugFocusedIndex,
  });

  /// The tabs.
  final List<CoilTab<T>> tabs;

  /// The value of the selected tab, matched with [CoilTab.value]. A value
  /// no tab has selects none.
  final T value;

  /// Called with the value of the tab to select. Null disables the tabs.
  final ValueChanged<T>? onChanged;

  /// Which tabs show their label.
  final CoilTabLabels labels;

  /// Pins the tabs to one size step. Null follows [CoilAdaptiveScope].
  final CoilSize? size;

  /// Overrides the theme's motion tokens ([CoilThemeData.motion]) for these
  /// tabs.
  final CoilMotion? motion;

  /// Overrides for these tabs' look, on top of the theme's [CoilTabsStyle]
  /// and the defaults.
  final CoilTabsStyle? style;

  /// Forces a hovered tab (for goldens and docs).
  @visibleForTesting
  final int? debugHoveredIndex;

  /// Forces a keyboard-focused tab (for goldens and docs).
  @visibleForTesting
  final int? debugFocusedIndex;

  @override
  State<CoilTabs<T>> createState() => _CoilTabsState<T>();
}

class _CoilTabsState<T> extends State<CoilTabs<T>>
    with TickerProviderStateMixin {
  late final _selectedPill = CoilHighlightPainter(
    vsync: this,
    debugLabel: 'CoilTabs.selected',
  );
  late final _hoverPill = CoilHighlightPainter(
    vsync: this,
    debugLabel: 'CoilTabs.hover',
  );
  late final _focusRing = CoilHighlightPainter(
    vsync: this,
    debugLabel: 'CoilTabs.focus',
  );

  final _nodes = <FocusNode>[];
  final _states = <WidgetStatesController>[];
  int? _focusVisible;

  final _scroll = ScrollController(debugLabel: 'CoilTabs');

  /// How far the strip can scroll toward either end, for the edge fades.
  final _overflow = ValueNotifier<_Overflow>(_Overflow.none);

  @override
  void initState() {
    super.initState();
    // Starts with the selected tab in view, without travelling there.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reveal(_selectedIndex, animate: false);
    });
  }

  int? get _selectedIndex {
    final index = widget.tabs.indexWhere((tab) => tab.value == widget.value);
    return index < 0 ? null : index;
  }

  @override
  void didUpdateWidget(CoilTabs<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = oldWidget.tabs.indexWhere(
      (tab) => tab.value == oldWidget.value,
    );
    if (before != _selectedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _reveal(_selectedIndex);
      });
    }
  }

  /// Scrolls tab [index] (and the fade's width around it) into view by the
  /// least distance, on the theme's
  /// `standard` spring (Motor's [MotionCurve] drives Flutter's scroll
  /// animation; the curve is the spring sampled in seconds, so it runs one
  /// second and is flat once settled).
  void _reveal(int? index, {bool animate = true}) {
    if (index == null || index >= _nodes.length || !_scroll.hasClients) return;
    final context = _nodes[index].context;
    if (context == null || !context.mounted) return;
    final motion = CoilTheme.motionOf(
      this.context,
      override: widget.motion,
    ).standard;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    // Reveals the tab plus the fade's width on both sides, so a revealed tab
    // never sits under an edge fade.
    box.showOnScreen(
      rect: Rect.fromLTRB(
        -_edgeFade,
        0,
        box.size.width + _edgeFade,
        box.size.height,
      ),
      duration: animate ? const Duration(seconds: 1) : Duration.zero,
      curve: motion.toCurve,
    );
  }

  bool _onScrollMetrics(ScrollMetrics metrics) {
    if (metrics.axis != Axis.horizontal) return false;
    final next = _Overflow(metrics.extentBefore, metrics.extentAfter);
    if (next != _overflow.value) _overflow.value = next;
    return false;
  }

  void _sync() {
    while (_nodes.length < widget.tabs.length) {
      final i = _nodes.length;
      _nodes.add(FocusNode(debugLabel: 'CoilTab $i'));
      final states = WidgetStatesController();
      states.addListener(() => _onStates(i, states.value));
      _states.add(states);
    }
    while (_nodes.length > widget.tabs.length) {
      _nodes.removeLast().dispose();
      _states.removeLast().dispose();
    }
  }

  void _onStates(int index, Set<WidgetState> states) {
    final focused = states.contains(WidgetState.focused);
    if (focused && _focusVisible != index) {
      setState(() => _focusVisible = index);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _reveal(index);
      });
    } else if (!focused && _focusVisible == index) {
      setState(() => _focusVisible = null);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _overflow.dispose();
    _selectedPill.dispose();
    _hoverPill.dispose();
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
    final motion = CoilTheme.motionOf(context, override: widget.motion);
    final colors = theme.colors;
    final sizes = CoilTheme.metricsOf(context, size: widget.size);
    final style = CoilTabsStyle.fallback(
      theme,
      sizes,
    ).merge(CoilTheme.styleOf<CoilTabsStyle>(context)).merge(widget.style);
    final radius = BorderRadius.circular(style.radius!);
    final index = widget.tabs.indexWhere((tab) => tab.value == widget.value);
    final selected = index < 0 ? null : index;
    final focused = widget.debugFocusedIndex ?? _focusVisible;

    return CoilRovingFocus(
      nodes: _nodes,
      tabStop: selected,
      child: _TabStrip(
        controller: _scroll,
        overflow: _overflow,
        onMetrics: _onScrollMetrics,
        // Inside the scrollable, so the tabs are the tab bar's direct
        // semantic children.
        child: Semantics(
          role: SemanticsRole.tabBar,
          container: true,
          child: CoilHoverRegion(
            axis: CoilHoverAxis.x,
            highlight: false,
            background: [_selectedPill, _hoverPill],
            foreground: [_focusRing],
            onStateChanged: (state) {
              final hovered = widget.debugHoveredIndex ?? state.activeIndex;
              final hovering = hovered != null && hovered != selected;
              final fill = ShapeDecoration(
                color: style.pill,
                shape: RoundedSuperellipseBorder(borderRadius: radius),
              );
              _selectedPill.update(
                target: selected,
                motion: motion.standard,
                exitMotion: motion.quickExit,
                exitTravelMotion: motion.standard,
                fade: motion.fade,
                opacity: hovering ? 0.8 : 1,
                fadeIn: false,
                decoration: fill,
              );
              _hoverPill.update(
                target: hovering ? hovered : null,
                session: state.session,
                from: selected,
                opacity: style.hoverPillOpacity!,
                motion: motion.quick,
                exitMotion: motion.quickExit,
                exitTravelMotion: motion.standard,
                fade: motion.fade,
                // Leaving the strip: glide back into the selected pill.
                exitTo: state.pointerInside ? null : selected,
                decoration: fill,
              );
              _focusRing.update(
                target: focused,
                fadeIn: false,
                motion: motion.quick,
                exitMotion: motion.quickExit,
                exitTravelMotion: motion.standard,
                fade: motion.fade,
                inflate: 1 + theme.focusRingWidth,
                decoration: ShapeDecoration(
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(
                      theme.shape.radii(sizes.tier).focusRing,
                    ),
                    side: BorderSide(
                      color: colors.focusRing,
                      width: theme.focusRingWidth,
                    ),
                  ),
                ),
              );
            },
            child: Builder(
              builder: (context) {
                final region = CoilHoverRegion.maybeOf(context);
                final hovered = widget.debugHoveredIndex ?? region?.activeIndex;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final (i, tab) in widget.tabs.indexed)
                      CoilHoverItem(
                        index: i,
                        child: _TabButton(
                          motion: motion,
                          style: style,
                          tab: tab,
                          sizes: sizes,
                          selected: i == selected,
                          active: i == selected || i == hovered,
                          collapseLabel:
                              widget.labels == CoilTabLabels.selected &&
                              tab.icon != null,
                          focusNode: _nodes[i],
                          statesController: _states[i],
                          onPressed: switch (widget.onChanged) {
                            final onChanged? => () => onChanged(tab.value),
                            null => null,
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// How far a strip can scroll each way, in pixels.
@immutable
class _Overflow {
  const _Overflow(this.before, this.after);

  static const none = _Overflow(0, 0);

  final double before;
  final double after;

  @override
  bool operator ==(Object other) =>
      other is _Overflow && other.before == before && other.after == after;

  @override
  int get hashCode => Object.hash(before, after);
}

/// The fade length at a scrollable edge.
const _edgeFade = 24.0;

/// How far the focus ring and the pills may paint outside the strip's
/// height.
const _bleed = 4.0;

/// Scrolls [child] horizontally when it is wider than the space, hugging it
/// when it fits, and fades the edges that have more behind them.
class _TabStrip extends StatefulWidget {
  const _TabStrip({
    required this.controller,
    required this.overflow,
    required this.onMetrics,
    required this.child,
  });

  final ScrollController controller;
  final ValueNotifier<_Overflow> overflow;
  final bool Function(ScrollMetrics metrics) onMetrics;
  final Widget child;

  @override
  State<_TabStrip> createState() => _TabStripState();
}

class _TabStripState extends State<_TabStrip> {
  /// Keeps the scroll view (and its position) alive when the fade mask
  /// appears around it or goes away.
  final _scrollKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final overflow = widget.overflow;
    final onMetrics = widget.onMetrics;
    final direction = Directionality.of(context);
    return IntrinsicWidth(
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: (n) => onMetrics(n.metrics),
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) => onMetrics(n.metrics),
          child: ValueListenableBuilder<_Overflow>(
            valueListenable: overflow,
            child: SingleChildScrollView(
              key: _scrollKey,
              controller: controller,
              scrollDirection: Axis.horizontal,
              // The focus ring paints just outside the tabs; only the ends
              // are clipped (below).
              clipBehavior: Clip.none,
              child: widget.child,
            ),
            builder: (context, o, child) {
              // An end with nothing more behind it lets the focus ring bleed.
              final leading = o.before <= 0 ? _bleed : 0.0;
              final trailing = o.after <= 0 ? _bleed : 0.0;
              final rtl = direction == TextDirection.rtl;
              final clipped = ClipRect(
                clipper: _StripClipper(
                  left: rtl ? trailing : leading,
                  right: rtl ? leading : trailing,
                ),
                child: child,
              );
              if (o == _Overflow.none) return clipped;
              return ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (rect) {
                  final before = (o.before / _edgeFade).clamp(0.0, 1.0);
                  final after = (o.after / _edgeFade).clamp(0.0, 1.0);
                  final fade = (_edgeFade / rect.width).clamp(0.0, 0.5);
                  const opaque = Color(0xFF000000);
                  return LinearGradient(
                    begin: AlignmentDirectional.centerStart,
                    end: AlignmentDirectional.centerEnd,
                    colors: [
                      opaque.withValues(alpha: 1 - before),
                      opaque,
                      opaque,
                      opaque.withValues(alpha: 1 - after),
                    ],
                    stops: [0, fade, 1 - fade, 1],
                  ).createShader(rect, textDirection: direction);
                },
                child: clipped,
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Clips the strip at its scrolling ends but lets the focus ring bleed
/// vertically, and horizontally where nothing is scrolled away.
class _StripClipper extends CustomClipper<Rect> {
  const _StripClipper({required this.left, required this.right});

  final double left;
  final double right;

  @override
  Rect getClip(Size size) => Rect.fromLTRB(
    -left,
    -_bleed,
    size.width + right,
    size.height + _bleed,
  );

  @override
  bool shouldReclip(_StripClipper oldClipper) =>
      oldClipper.left != left || oldClipper.right != right;
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.tab,
    required this.sizes,
    required this.selected,
    required this.active,
    required this.collapseLabel,
    required this.focusNode,
    required this.statesController,
    required this.onPressed,
    required this.motion,
    required this.style,
  });

  final CoilTab<Object?> tab;
  final CoilMetrics sizes;
  final bool selected;
  final bool active;
  final bool collapseLabel;
  final FocusNode focusNode;
  final WidgetStatesController statesController;
  final VoidCallback? onPressed;
  final CoilMotion motion;
  final CoilTabsStyle style;

  @override
  Widget build(BuildContext context) {
    final showLabel = !collapseLabel || selected;
    final semibold = style.textStyle!.copyWith(
      fontVariations: CoilWeight.semibold.variations,
    );

    return Semantics(
      role: SemanticsRole.tab,
      selected: selected,
      label: tab.child == null ? null : tab.label,
      child: CoilInteraction(
        onPressed: onPressed,
        focusNode: focusNode,
        statesController: statesController,
        builder: (context, states, _) => ConstrainedBox(
          constraints: BoxConstraints(minHeight: style.minHeight!),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: sizes.controlPaddingX,
              vertical: sizes.controlPaddingY(sizes.body),
            ),
            child: MotionBuilder<Color>(
              value: style.label!.resolve({
                if (selected) WidgetState.selected,
                if (active) WidgetState.hovered,
              })!,
              motion: motion.fade,
              converter: MotionConverter.colorRgb,
              builder: (context, color, _) => SingleMotionBuilder(
                value: selected ? CoilWeight.semibold.wght : 400,
                motion: motion.fade,
                builder: (context, wght, _) {
                  final textStyle = style.textStyle!.copyWith(
                    color: color,
                    fontVariations: [
                      FontVariation('wght', wght),
                      FontVariation(
                        'opsz',
                        14 + (wght - 400) / 150 * 4,
                      ),
                    ],
                  );
                  final label = Stack(
                    children: [
                      // Reserves the semibold width so selecting a tab
                      // never nudges its neighbors.
                      Opacity(
                        opacity: 0,
                        child: ExcludeSemantics(
                          child: DefaultTextStyle(
                            style: semibold,
                            maxLines: 1,
                            softWrap: false,
                            child: tab.child ?? Text(tab.label),
                          ),
                        ),
                      ),
                      DefaultTextStyle(
                        style: textStyle,
                        maxLines: 1,
                        softWrap: false,
                        child: tab.child ?? Text(tab.label),
                      ),
                    ],
                  );
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (tab.icon case final icon?)
                        IconTheme(
                          data: IconThemeData(
                            size: sizes.iconSize,
                            applyTextScaling: true,
                            weight: active
                                ? CoilIconWeight.emphasis
                                : CoilIconWeight.rest,
                            color: color,
                          ),
                          child: icon,
                        ),
                      // Collapsed tabs keep their icon; the label springs
                      // its width open and fades in.
                      MotionSizeSwitcher(
                        motion: motion.quick,
                        exitMotion: motion.quickExit,
                        // MotionSizeSwitcher takes a resolved Alignment.
                        alignment: AlignmentDirectional.centerStart.resolve(
                          Directionality.of(context),
                        ),
                        debugLabel: 'CoilTabs.label',
                        child: showLabel
                            ? Padding(
                                key: const ValueKey('label'),
                                padding: EdgeInsetsDirectional.only(
                                  start: tab.icon == null ? 0 : sizes.gap,
                                ),
                                child: label,
                              )
                            : const SizedBox.shrink(key: ValueKey('none')),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
