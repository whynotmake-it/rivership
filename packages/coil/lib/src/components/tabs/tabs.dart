import 'dart:math' as math;

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

/// The animated parts of [CoilTabs], as keys of [CoilTabs.motions] and
/// [CoilThemeData.trackMotions].
///
/// A custom motion replaces both the enter and the exit of its part.
final class CoilTabsTrack<T extends Object> extends Track<T> {
  CoilTabsTrack._(super.converter, {required String super.debugLabel});

  /// The selected pill gliding between tabs. Default motion: `standard`.
  static final selected = CoilTabsTrack<double>._(
    .single,
    debugLabel: 'CoilTabs.selected',
  );

  /// The hover pill following the pointer. Default motion: `quick`.
  static final hover = CoilTabsTrack<double>._(
    .single,
    debugLabel: 'CoilTabs.hover',
  );

  /// The focus ring travelling between tabs. Default motion: `quick`.
  static final focus = CoilTabsTrack<double>._(
    .single,
    debugLabel: 'CoilTabs.focus',
  );

  /// A tab's label opening and closing under
  /// [CoilTabLabels.selected]. Default motion: `quick`.
  static final label = CoilTabsTrack<double>._(
    .single,
    debugLabel: 'CoilTabs.label',
  );

  /// The pills' opacity as they appear and leave. Default motion: `fade`.
  static final fade = CoilTabsTrack<double>._(
    .single,
    debugLabel: 'CoilTabs.fade',
  );

  /// The labels turning foreground and semibold. Default motion: `fade`.
  static final emphasis = CoilTabsTrack<double>._(
    .single,
    debugLabel: 'CoilTabs.emphasis',
  );

  /// The strip scrolling a tab into view. Default motion: `standard`.
  static final reveal = CoilTabsTrack<double>._(
    .single,
    debugLabel: 'CoilTabs.reveal',
  );
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

/// A row of tabs with a selected pill that glides between them.
///
/// * A lighter hover pill follows a mouse and glides back into the selected
///   pill when it leaves. Touch never hovers.
/// * Arrows, Home and End move focus; Enter or Space selects. Only the
///   selected tab is in the Tab order, and a focus ring follows the keyboard.
/// * Tabs that don't fit scroll horizontally with the platform's physics and
///   fade out 24 px at an edge with more behind it. The selected tab, and
///   the one that takes keyboard focus, scroll into view.
///
/// Override the motion of one part with [motions].
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
    this.motions,
    this.style,
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

  /// Per-part motions for these tabs, keyed by [CoilTabsTrack]s:
  /// `motions: {.selected: const .bouncySpring()}`.
  final Map<CoilTabsTrack<Object>, Motion>? motions;

  /// Overrides for these tabs' look, on top of the theme's [CoilTabsStyle]
  /// and the defaults.
  final CoilTabsStyle? style;

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

  /// The enter and exit motions of [track]: the instance's or the theme's
  /// override for both, else the tokens.
  ({Motion enter, Motion exit}) _motionFor(
    CoilTabsTrack<Object> track,
    Motion enter,
    Motion exit, {
    bool spatial = true,
  }) {
    final resolved = CoilTheme.trackMotionOf(
      context,
      track,
      instance: widget.motions,
      token: enter,
      spatial: spatial,
    );
    return identical(resolved, enter)
        ? (enter: enter, exit: exit)
        : (enter: resolved, exit: resolved);
  }

  final _nodes = <FocusNode>[];
  final _states = <WidgetStatesController>[];
  int? _focusVisible;

  final _scroll = ScrollController(debugLabel: 'CoilTabs');
  final _revealRequest = _RevealRequest();

  /// How far the strip can scroll toward either end, for the edge fades.
  final _overflow = ValueNotifier<_Overflow>(_Overflow.none);

  @override
  void initState() {
    super.initState();
    _sync();
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
    _sync();
    final before = oldWidget.tabs.indexWhere(
      (tab) => tab.value == oldWidget.value,
    );
    if (before != _selectedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _reveal(_selectedIndex);
      });
    }
  }

  /// Scrolls tab [index] (and an edge fade's width around it) into view by
  /// the least distance. The scroll position follows the `reveal` spring and
  /// stays tappable; a drag takes over at any time.
  void _reveal(int? index, {bool animate = true}) {
    if (index == null || index >= _nodes.length || !_scroll.hasClients) return;
    final tab = _nodes[index].context?.findRenderObject();
    if (tab is! RenderBox || !tab.attached || !tab.hasSize) return;
    final viewport = RenderAbstractViewport.maybeOf(tab);
    if (viewport == null) return;
    final fade = _resolveStyle().edgeFade!;
    final rect = Rect.fromLTRB(
      -fade,
      0,
      tab.size.width + fade,
      tab.size.height,
    );
    final toStart = viewport.getOffsetToReveal(tab, 0, rect: rect).offset;
    final toEnd = viewport.getOffsetToReveal(tab, 1, rect: rect).offset;
    final position = _scroll.position;
    final target = position.pixels
        .clamp(math.min(toStart, toEnd), math.max(toStart, toEnd))
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if (target == position.pixels) return;
    final tokens = CoilTheme.motionOf(context, override: widget.motion);
    final motion = _motionFor(
      CoilTabsTrack.reveal,
      tokens.standard,
      tokens.standardExit,
    ).enter;
    if (!animate || motion.duration == Duration.zero) {
      position.jumpTo(target);
      return;
    }
    if (position is! ScrollPositionWithSingleContext) {
      position.jumpTo(target);
      return;
    }
    _revealRequest.pending = (target: target, motion: motion, velocity: 0);
    position.goBallistic(0);
    _revealRequest.pending = null;
  }

  CoilTabsStyle _resolveStyle() {
    final sizes = CoilTheme.metricsOf(context, size: widget.size);
    return CoilTabsStyle.fallback(
      CoilTheme.of(context),
      sizes,
    ).merge(CoilTheme.styleOf<CoilTabsStyle>(context)).merge(widget.style);
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
    final theme = CoilTheme.of(context);
    final motion = CoilTheme.motionOf(context, override: widget.motion);
    final colors = theme.colors;
    final sizes = CoilTheme.metricsOf(context, size: widget.size);
    final style = _resolveStyle();
    final radius = BorderRadius.circular(style.radius!);
    final index = widget.tabs.indexWhere((tab) => tab.value == widget.value);
    final selected = index < 0 ? null : index;
    final focused = _focusVisible;
    final selectedMotion = _motionFor(
      CoilTabsTrack.selected,
      motion.standard,
      motion.quickExit,
    );
    final hoverMotion = _motionFor(
      CoilTabsTrack.hover,
      motion.quick,
      motion.quickExit,
    );
    final focusMotion = _motionFor(
      CoilTabsTrack.focus,
      motion.quick,
      motion.quickExit,
    );
    final fadeMotion = _motionFor(
      CoilTabsTrack.fade,
      motion.fade,
      motion.fadeExit,
      spatial: false,
    ).enter;
    final emphasisMotion = _motionFor(
      CoilTabsTrack.emphasis,
      motion.fade,
      motion.fadeExit,
      spatial: false,
    ).enter;
    // A custom motion also drives the glide back; else the standard spring.
    Motion travel(({Motion enter, Motion exit}) m, Motion token) =>
        identical(m.enter, token) ? motion.standard : m.enter;
    final labelMotion = _motionFor(
      CoilTabsTrack.label,
      motion.quick,
      motion.quickExit,
    );

    return CoilRovingFocus(
      nodes: _nodes,
      tabStop: selected,
      child: _TabStrip(
        controller: _scroll,
        overflow: _overflow,
        onMetrics: _onScrollMetrics,
        physics: _RevealPhysics(request: _revealRequest),
        edgeFade: style.edgeFade!,
        bleed: 1 + 2 * theme.focusRingWidth,
        // Inside the scrollable, so the tabs are the tab bar's direct
        // semantic children.
        child: Semantics(
          role: SemanticsRole.tabBar,
          container: true,
          child: CoilHoverRegion(
            axis: CoilHoverAxis.x,
            child: Builder(
              builder: (context) {
                final state =
                    CoilHoverRegion.maybeOf(context) ??
                    const CoilHoverState(
                      activeIndex: null,
                      session: 0,
                      pointerInside: false,
                    );
                final hovered = state.activeIndex;
                final hovering = hovered != null && hovered != selected;
                final fill = ShapeDecoration(
                  color: style.pill,
                  shape: RoundedSuperellipseBorder(borderRadius: radius),
                );
                _selectedPill.update(
                  target: selected,
                  motion: selectedMotion.enter,
                  exitMotion: selectedMotion.exit,
                  exitTravelMotion: travel(selectedMotion, motion.standard),
                  fade: fadeMotion,
                  opacity: hovering ? 0.8 : 1,
                  fadeIn: false,
                  decoration: fill,
                );
                _hoverPill.update(
                  target: hovering ? hovered : null,
                  session: state.session,
                  from: selected,
                  opacity: style.hoverPillOpacity!,
                  motion: hoverMotion.enter,
                  exitMotion: hoverMotion.exit,
                  exitTravelMotion: travel(hoverMotion, motion.quick),
                  fade: fadeMotion,
                  // Leaving the strip: glide back into the selected pill.
                  exitTo: state.pointerInside ? null : selected,
                  decoration: fill,
                );
                _focusRing.update(
                  target: focused,
                  fadeIn: false,
                  motion: focusMotion.enter,
                  exitMotion: focusMotion.exit,
                  exitTravelMotion: travel(focusMotion, motion.quick),
                  fade: fadeMotion,
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
                return CoilMotionLayer(
                  background: [_selectedPill, _hoverPill],
                  foreground: [_focusRing],
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final (i, tab) in widget.tabs.indexed)
                        CoilHoverItem(
                          index: i,
                          child: _TabButton(
                            emphasisMotion: emphasisMotion,
                            labelMotion: labelMotion,
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
                  ),
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

/// Lets a requested reveal end on a spring; everything else scrolls with
/// the platform's physics.
class _RevealPhysics extends ScrollPhysics {
  const _RevealPhysics({required this.request, super.parent});

  final _RevealRequest request;

  @override
  _RevealPhysics applyTo(ScrollPhysics? ancestor) =>
      _RevealPhysics(request: request, parent: buildParent(ancestor));

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final reveal = request.pending;
    if (reveal == null) {
      return super.createBallisticSimulation(position, velocity);
    }
    request.pending = null;
    return reveal.motion.createSimulation(
      start: position.pixels,
      end: reveal.target,
      velocity: reveal.velocity,
    );
  }
}

/// A scroll position to spring to, handed to [_RevealPhysics].
class _RevealRequest {
  ({double target, Motion motion, double velocity})? pending;
}

/// Scrolls [child] horizontally when it is wider than the space, hugging it
/// when it fits, and fades the edges that have more behind them.
class _TabStrip extends StatefulWidget {
  const _TabStrip({
    required this.controller,
    required this.overflow,
    required this.onMetrics,
    required this.physics,
    required this.edgeFade,
    required this.bleed,
    required this.child,
  });

  final ScrollController controller;
  final ScrollPhysics physics;

  /// How far an edge with more behind it fades.
  final double edgeFade;

  /// How far the focus ring may paint outside the strip.
  final double bleed;
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
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (n) => onMetrics(n.metrics),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) => onMetrics(n.metrics),
        child: ValueListenableBuilder<_Overflow>(
          valueListenable: overflow,
          child: CoilScrollEdgeFade(
            axis: Axis.horizontal,
            extent: widget.edgeFade,
            child: SingleChildScrollView(
              key: _scrollKey,
              controller: controller,
              physics: widget.physics,
              scrollDirection: Axis.horizontal,
              // The focus ring paints just outside the tabs; only the ends
              // are clipped (below).
              clipBehavior: Clip.none,
              child: widget.child,
            ),
          ),
          builder: (context, o, child) {
            // An end with nothing more behind it lets the focus ring bleed.
            final leading = o.before <= 0 ? widget.bleed : 0.0;
            final trailing = o.after <= 0 ? widget.bleed : 0.0;
            final rtl = direction == TextDirection.rtl;
            final clipped = ClipRect(
              clipper: _StripClipper(
                left: rtl ? trailing : leading,
                right: rtl ? leading : trailing,
                vertical: widget.bleed,
              ),
              child: child,
            );
            return clipped;
          },
        ),
      ),
    );
  }
}

/// Clips the strip at its scrolling ends but lets the focus ring bleed
/// vertically, and horizontally where nothing is scrolled away.
class _StripClipper extends CustomClipper<Rect> {
  const _StripClipper({
    required this.left,
    required this.right,
    required this.vertical,
  });

  final double left;
  final double right;
  final double vertical;

  @override
  Rect getClip(Size size) => Rect.fromLTRB(
    -left,
    -vertical,
    size.width + right,
    size.height + vertical,
  );

  @override
  bool shouldReclip(_StripClipper oldClipper) =>
      oldClipper.left != left ||
      oldClipper.right != right ||
      oldClipper.vertical != vertical;
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
    required this.emphasisMotion,
    required this.labelMotion,
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
  final Motion emphasisMotion;
  final ({Motion enter, Motion exit}) labelMotion;
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
              motion: emphasisMotion,
              converter: MotionConverter.colorRgb,
              builder: (context, color, _) => SingleMotionBuilder(
                value: selected ? CoilWeight.semibold.wght : 400,
                motion: emphasisMotion,
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
                        motion: labelMotion.enter,
                        exitMotion: labelMotion.exit,
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
