import 'package:fluid_functionalism/src/foundation/fluid_motion.dart';
import 'package:fluid_functionalism/src/foundation/fluid_sizes.dart';
import 'package:fluid_functionalism/src/foundation/fluid_theme.dart';
import 'package:fluid_functionalism/src/foundation/fluid_typography.dart';
import 'package:fluid_functionalism/src/icons/fluid_icon.dart';
import 'package:fluid_functionalism/src/primitives/fluid_highlight.dart';
import 'package:fluid_functionalism/src/primitives/fluid_hover.dart';
import 'package:fluid_functionalism/src/primitives/fluid_label.dart';
import 'package:fluid_functionalism/src/primitives/fluid_pressable.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// One tab of [FluidTabs].
@immutable
class FluidTab {
  /// Creates a tab.
  const FluidTab({required this.label, this.icon, this.semanticLabel});

  /// The label, usually a [Text]. It turns semibold when selected; a hidden
  /// semibold copy reserves the width so neighbors never shift.
  final Widget label;

  /// An optional icon before the label.
  final Widget? icon;

  /// A label for assistive technology when [label] is not plain text.
  final String? semanticLabel;
}

/// A row of tabs with the fluid highlight (`registry/radix/tabs.tsx`).
///
/// * The selected pill glides between tabs on the theme's `moderate` motion.
/// * A lighter hover pill glides out of the selected one, follows the
///   pointer on `fast`, and glides back into it when the pointer
///   leaves.
/// * Arrow keys, Home and End move focus; Enter or Space selects (manual
///   activation). Only the selected tab is in the Tab order. A focus ring
///   travels with keyboard focus.
class FluidTabs extends StatefulWidget {
  /// Creates tabs.
  const FluidTabs({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
    this.activeLabel = false,
    this.density,
    this.motion,
    this.debugHoveredIndex,
    this.debugFocusedIndex,
  });

  /// The tabs.
  final List<FluidTab> tabs;

  /// The selected tab.
  final int selectedIndex;

  /// Called with the index of the tab to select.
  final ValueChanged<int> onSelected;

  /// When true, only the selected tab shows its label; the others show
  /// their icon alone. Requires icons.
  final bool activeLabel;

  /// Pins the tabs to one size step. Null follows [FluidSizeScope].
  final FluidDensity? density;

  /// Overrides the theme's motion tokens ([FluidThemeData.motion]) for these
  /// tabs.
  final FluidMotionThemeData? motion;

  /// Forces a hovered tab (for goldens and docs).
  @visibleForTesting
  final int? debugHoveredIndex;

  /// Forces a keyboard-focused tab (for goldens and docs).
  @visibleForTesting
  final int? debugFocusedIndex;

  @override
  State<FluidTabs> createState() => _FluidTabsState();
}

class _FluidTabsState extends State<FluidTabs> {
  final _nodes = <FocusNode>[];
  final _states = <WidgetStatesController>[];
  int? _focusVisible;

  void _sync() {
    while (_nodes.length < widget.tabs.length) {
      final i = _nodes.length;
      _nodes.add(FocusNode(debugLabel: 'FluidTab $i'));
      final states = WidgetStatesController();
      states.addListener(() => _onStates(i, states.value));
      _states.add(states);
    }
    while (_nodes.length > widget.tabs.length) {
      _nodes.removeLast().dispose();
      _states.removeLast().dispose();
    }
    for (var i = 0; i < _nodes.length; i++) {
      // Roving tab index: only the selected tab is reached with Tab.
      _nodes[i].skipTraversal = i != widget.selectedIndex;
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

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final current = _nodes.indexWhere((n) => n.hasPrimaryFocus);
    if (current < 0) return KeyEventResult.ignored;
    final count = _nodes.length;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final target = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowRight => (current + (rtl ? -1 : 1)) % count,
      LogicalKeyboardKey.arrowLeft => (current + (rtl ? 1 : -1)) % count,
      LogicalKeyboardKey.home => 0,
      LogicalKeyboardKey.end => count - 1,
      _ => null,
    };
    if (target == null) return KeyEventResult.ignored;
    _nodes[target].requestFocus();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    _sync();
    final theme = FluidTheme.of(context);
    final motion = FluidTheme.motionOf(context, override: widget.motion);
    final colors = theme.colors;
    final sizes = FluidTheme.sizesOf(context, density: widget.density);
    final radius = BorderRadius.circular(theme.shape.item);
    final selected = widget.selectedIndex;
    final focused = widget.debugFocusedIndex ?? _focusVisible;

    return Semantics(
      role: SemanticsRole.tabBar,
      container: true,
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: _onKey,
        child: FluidHoverRegion(
          axis: FluidHoverAxis.x,
          backgroundBuilder: (context, state) {
            final hovered = widget.debugHoveredIndex ?? state.activeIndex;
            final selectedRect = state.rectOf(selected);
            final hoverRect = hovered != null && hovered != selected
                ? state.rectOf(hovered)
                : null;
            final leftRegion = !state.pointerInside;
            return Stack(
              children: [
                FluidHighlight(
                  rect: selectedRect,
                  motion: motion.moderate,
                  opacity: hoverRect != null ? 0.8 : 1,
                  fadeIn: false,
                  color: colors.active,
                  borderRadius: radius,
                ),
                FluidHighlight(
                  rect: hoverRect,
                  session: state.session,
                  from: selectedRect,
                  opacity: 0.4,
                  color: colors.active,
                  borderRadius: radius,
                  motion: motion.fast,
                  exitMotion: motion.fastExit,
                  exitTravelMotion: motion.moderate,
                  // Leaving the strip: glide back into the selected pill.
                  exitTo: leftRegion ? selectedRect : null,
                ),
              ],
            );
          },
          foregroundBuilder: (context, state) => FluidHighlight(
            rect: state.rectOf(focused)?.inflate(2),
            fadeIn: false,
            motion: motion.fast,
            exitMotion: motion.fastExit,
            borderRadius: BorderRadius.circular(theme.shape.focusRing),
            border: Border.all(color: colors.focusRing),
          ),
          child: Builder(
            builder: (context) {
              final region = FluidHoverRegion.maybeOf(context);
              final hovered = widget.debugHoveredIndex ?? region?.activeIndex;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (i, tab) in widget.tabs.indexed)
                    FluidHoverItem(
                      index: i,
                      child: _TabButton(
                        motion: motion,
                        tab: tab,
                        sizes: sizes,
                        selected: i == selected,
                        active: i == selected || i == hovered,
                        collapseLabel: widget.activeLabel && tab.icon != null,
                        focusNode: _nodes[i],
                        statesController: _states[i],
                        onPressed: () => widget.onSelected(i),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
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
  });

  final FluidTab tab;
  final FluidSizes sizes;
  final bool selected;
  final bool active;
  final bool collapseLabel;
  final FocusNode focusNode;
  final WidgetStatesController statesController;
  final VoidCallback onPressed;
  final FluidMotionThemeData motion;

  @override
  Widget build(BuildContext context) {
    final theme = FluidTheme.of(context);
    final colors = theme.colors;
    final showLabel = !collapseLabel || selected;
    final semibold = theme.typography.style(
      sizes.body,
      weight: FluidWeight.semibold,
    );

    return Semantics(
      role: SemanticsRole.tab,
      selected: selected,
      label: tab.semanticLabel,
      child: FluidPressable(
        onPressed: onPressed,
        focusNode: focusNode,
        statesController: statesController,
        builder: (context, states, _) => SizedBox(
          height: sizes.controlHeight,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: sizes.controlPaddingX),
            child: MotionBuilder<Color>(
              value: active ? colors.foreground : colors.mutedForeground,
              motion: motion.color,
              converter: MotionConverter.colorRgb,
              builder: (context, color, _) => SingleMotionBuilder(
                value: selected ? FluidWeight.semibold.wght : 400,
                motion: motion.color,
                builder: (context, wght, _) {
                  final style = theme.typography
                      .style(
                        sizes.body,
                        color: color,
                      )
                      .copyWith(
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
                            child: FluidLabel(child: tab.label),
                          ),
                        ),
                      ),
                      DefaultTextStyle(
                        style: style,
                        maxLines: 1,
                        softWrap: false,
                        child: FluidLabel(child: tab.label),
                      ),
                    ],
                  );
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (tab.icon case final icon?)
                        FluidIconTheme(
                          data: FluidIconThemeData(
                            size: sizes.iconSize,
                            strokeWidth: active ? 2 : 1.5,
                            color: color,
                          ),
                          child: icon,
                        ),
                      SingleMotionBuilder(
                        value: showLabel ? 1 : 0,
                        motion: motion.fast,
                        builder: (context, reveal, child) => ClipRect(
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            widthFactor: reveal.clamp(0, 1),
                            child: Opacity(
                              opacity: reveal.clamp(0, 1),
                              child: child,
                            ),
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsetsDirectional.only(
                            start: tab.icon == null ? 0 : sizes.gap,
                          ),
                          child: label,
                        ),
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
