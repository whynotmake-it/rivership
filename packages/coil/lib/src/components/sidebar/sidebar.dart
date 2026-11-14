import 'dart:math' as math;

import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// A page with a [sidebar] beside its [body].
///
/// In a window at least [CoilAdaptivePopup.compactWidth] wide, the sidebar
/// sits at the start edge, and [CoilSidebarScaffoldState.toggle] (or
/// Ctrl+B, ⌘B on Apple platforms, while focus is inside) folds it away and
/// back on a spring. In a narrower window it is hidden, and toggling slides
/// it in over the page as a drawer, which a pick in a [CoilSidebarMenu]
/// closes.
///
/// Reach the state with [CoilSidebarScaffold.of], for example from a
/// toggle button in the body.
class CoilSidebarScaffold extends StatefulWidget {
  /// Creates a sidebar scaffold.
  const CoilSidebarScaffold({
    required this.sidebar,
    required this.body,
    super.key,
    this.width = 256,
    this.initiallyExpanded = true,
    this.motion,
  });

  /// The sidebar, usually a [CoilSidebar].
  final Widget sidebar;

  /// The page.
  final Widget body;

  /// The sidebar's width.
  final double width;

  /// Whether the sidebar starts unfolded in a wide window.
  final bool initiallyExpanded;

  /// Overrides the theme's motion tokens.
  final CoilMotion? motion;

  /// The nearest scaffold's state.
  static CoilSidebarScaffoldState of(BuildContext context) =>
      context.findAncestorStateOfType<CoilSidebarScaffoldState>()!;

  @override
  State<CoilSidebarScaffold> createState() => CoilSidebarScaffoldState();
}

/// The state of a [CoilSidebarScaffold].
class CoilSidebarScaffoldState extends State<CoilSidebarScaffold> {
  late bool _expanded = widget.initiallyExpanded;

  /// Whether the sidebar shows beside the body in a wide window.
  bool get expanded => _expanded;

  /// Whether the scaffold was narrower than [CoilAdaptivePopup.compactWidth]
  /// at its last layout: its own width, not the window's, since it can sit
  /// in a pane.
  bool _compact = false;

  /// Folds or unfolds the sidebar, or in a narrow window opens it as a
  /// drawer.
  void toggle() {
    if (_compact) {
      showCoilModal<void>(
        context: context,
        presentation: CoilModalPresentation.drawer,
        motion: widget.motion,
        builder: (context) => _CoilDrawerScope(
          child: SizedBox(
            width: math.min(
              widget.width,
              MediaQuery.sizeOf(context).width * 0.85,
            ),
            height: double.infinity,
            child: widget.sidebar,
          ),
        ),
      );
      return;
    }
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final motion = CoilTheme.motionOf(context, override: widget.motion);
    final apple =
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.iOS;
    return LayoutBuilder(
      builder: (context, constraints) {
        _compact = constraints.maxWidth < CoilAdaptivePopup.compactWidth;
        return _layout(context, motion: motion, apple: apple);
      },
    );
  }

  Widget _layout(
    BuildContext context, {
    required CoilMotion motion,
    required bool apple,
  }) {
    final shown = _expanded && !_compact;
    return CallbackShortcuts(
      bindings: {
        SingleActivator(
          LogicalKeyboardKey.keyB,
          meta: apple,
          control: !apple,
        ): toggle,
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleMotionBuilder(
            value: shown ? widget.width : 0,
            motion: shown ? motion.gentle : motion.gentleExit,
            // Folded away, it stays built, so it keeps its scroll and
            // state, but offstage.
            builder: (context, width, child) => Offstage(
              offstage: !shown && width <= 0,
              child: ClipRect(
                child: SizedBox(
                  width: math.max(0, width),
                  child: OverflowBox(
                    alignment: AlignmentDirectional.centerEnd,
                    minWidth: widget.width,
                    maxWidth: widget.width,
                    child: child,
                  ),
                ),
              ),
            ),
            // Folded away, it leaves focus order and screen readers.
            child: ExcludeFocus(
              excluding: !shown,
              child: ExcludeSemantics(
                excluding: !shown,
                child: IgnorePointer(ignoring: !shown, child: widget.sidebar),
              ),
            ),
          ),
          Expanded(child: widget.body),
        ],
      ),
    );
  }
}

/// Marks a sidebar shown as a drawer: a pick closes it.
class _CoilDrawerScope extends InheritedWidget {
  const _CoilDrawerScope({required super.child});

  static bool of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_CoilDrawerScope>() != null;

  @override
  bool updateShouldNotify(_CoilDrawerScope oldWidget) => false;
}

/// The sidebar's panel: a [header], scrolling [children] and a [footer],
/// on the page's surface with a hairline at its end edge.
class CoilSidebar extends StatelessWidget {
  /// Creates a sidebar panel.
  const CoilSidebar({
    required this.children,
    super.key,
    this.header,
    this.footer,
  });

  /// Above the scrolling content, such as a workspace switcher.
  final Widget? header;

  /// The groups and menus.
  final List<Widget> children;

  /// Below the scrolling content, such as the signed-in user.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final metrics = CoilTheme.metricsOf(context);
    final drawer = _CoilDrawerScope.of(context);
    final padding = EdgeInsets.all(metrics.popupInset * 2);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: drawer ? theme.colors.surface(3) : theme.colors.surface(0),
        border: BorderDirectional(
          end: BorderSide(color: theme.colors.border),
        ),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (header case final header?)
              Padding(padding: padding, child: header),
            Expanded(
              child: SingleChildScrollView(
                padding: padding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: metrics.popupInset * 2,
                  children: children,
                ),
              ),
            ),
            if (footer case final footer?)
              Padding(padding: padding, child: footer),
          ],
        ),
      ),
    );
  }
}

/// A labelled group of sidebar content.
class CoilSidebarGroup extends StatelessWidget {
  /// Creates a group.
  const CoilSidebarGroup({required this.child, super.key, this.label});

  /// The group's heading.
  final String? label;

  /// The group's content, usually a [CoilSidebarMenu].
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final metrics = CoilTheme.metricsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label case final label?)
          Semantics(
            header: true,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                metrics.itemPaddingX,
                4,
                metrics.itemPaddingX,
                4,
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.style(
                  metrics.caption,
                  color: theme.colors.mutedForeground,
                ),
              ),
            ),
          ),
        child,
      ],
    );
  }
}

/// One row of a [CoilSidebarMenu].
@immutable
class CoilSidebarItem {
  /// Describes a row.
  const CoilSidebarItem({
    required this.label,
    this.icon,
    this.trailing,
    this.selected = false,
    this.onPressed,
  });

  /// The row's text.
  final String label;

  /// A glyph before the label, styled by [IconTheme].
  final Widget? icon;

  /// After the label, such as a count badge.
  final Widget? trailing;

  /// Whether this row is the current page.
  final bool selected;

  /// Called when the row is picked. Null disables it.
  final VoidCallback? onPressed;
}

/// Navigation rows: a hovering pointer lights them with a gliding
/// highlight, and the selected row's fill glides when the selection moves.
///
/// Each row is a focus stop that Enter or Space picks. In a drawer, a pick
/// also closes the drawer.
class CoilSidebarMenu extends StatefulWidget {
  /// Creates a sidebar menu.
  const CoilSidebarMenu({required this.items, super.key, this.motion});

  /// The rows.
  final List<CoilSidebarItem> items;

  /// Overrides the theme's motion tokens.
  final CoilMotion? motion;

  @override
  State<CoilSidebarMenu> createState() => _CoilSidebarMenuState();
}

class _CoilSidebarMenuState extends State<CoilSidebarMenu> {
  /// The row the keyboard focused, for the ring.
  int? _focused;

  void _pick(CoilSidebarItem item) {
    if (_CoilDrawerScope.of(context)) Navigator.pop(context);
    item.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final colors = theme.colors;
    final metrics = CoilTheme.metricsOf(context);
    final motion = CoilTheme.motionOf(context, override: widget.motion);
    final radii = theme.shape.radii(metrics.tier);
    final selected = widget.items.indexWhere((item) => item.selected);
    final keyboard = CoilInputModality.instance.value == CoilModality.keyboard;
    return CoilHoverRegion(
      child: CoilHoverHighlight(
        radius: radii.item,
        motion: widget.motion,
        background: [
          CoilHighlight(
            debugLabel: 'CoilSidebarMenu.selected',
            target: selected < 0 ? null : selected,
            fadeIn: false,
            motion: motion.standard,
            exitMotion: motion.fadeExit,
            exitTravelMotion: motion.standard,
            fade: motion.fade,
            decoration: ShapeDecoration(
              color: colors.active,
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(radii.item),
              ),
            ),
          ),
        ],
        foreground: [
          CoilHighlight(
            debugLabel: 'CoilSidebarMenu.ring',
            target: keyboard ? _focused : null,
            fadeIn: false,
            motion: motion.quick,
            exitMotion: motion.fadeExit,
            exitTravelMotion: motion.quick,
            fade: motion.fade,
            inflate: 1 + theme.focusRingWidth,
            decoration: ShapeDecoration(
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(radii.focusRing),
                side: BorderSide(
                  color: colors.focusRing,
                  width: theme.focusRingWidth,
                ),
              ),
            ),
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, item) in widget.items.indexed)
              CoilHoverItem(
                index: i,
                enabled: item.onPressed != null,
                child: Semantics(
                  selected: item.selected,
                  child: CoilInteraction(
                    onPressed: item.onPressed == null
                        ? null
                        : () => _pick(item),
                    onFocusChange: (focused) => setState(() {
                      if (focused) {
                        _focused = i;
                      } else if (_focused == i) {
                        _focused = null;
                      }
                    }),
                    builder: (context, states, _) => _Row(
                      item: item,
                      metrics: metrics,
                      lit:
                          item.selected ||
                          states.contains(WidgetState.hovered) ||
                          states.contains(WidgetState.focused),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.item, required this.metrics, required this.lit});

  final CoilSidebarItem item;
  final CoilMetrics metrics;
  final bool lit;

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final colors = theme.colors;
    final color = lit || metrics.tier == CoilTier.touch
        ? colors.foreground
        : colors.mutedForeground;
    return Opacity(
      opacity: item.onPressed == null ? metrics.disabledOpacity : 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: metrics.controlHeight),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: metrics.itemPaddingX),
          child: IconTheme(
            data: IconThemeData(
              size: metrics.iconSize,
              applyTextScaling: true,
              color: color,
            ),
            child: DefaultTextStyle(
              style: theme.typography.style(
                metrics.body,
                weight: item.selected ? CoilWeight.semibold : CoilWeight.normal,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              child: Row(
                spacing: metrics.gap,
                children: [
                  ?item.icon,
                  Expanded(child: Text(item.label)),
                  ?item.trailing,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
