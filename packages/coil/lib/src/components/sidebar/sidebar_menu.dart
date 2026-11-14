import 'dart:math' as math;

import 'package:coil/context_menu.dart';
import 'package:coil/dropdown.dart';
import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/sidebar/sidebar_panel.dart';
import 'package:coil/src/components/sidebar/sidebar_scaffold.dart';
import 'package:coil/src/components/sidebar/sidebar_scope.dart';
import 'package:coil/src/components/sidebar/sidebar_style.dart';
import 'package:coil/src/components/sidebar/sidebar_text.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// A thread's state, shown as a dot where a row has no leading icon.
enum CoilSidebarStatus {
  /// The open thread: a filled dot, and the row is selected.
  active,

  /// New messages: a filled dot, announced as unread.
  unread,

  /// Nothing new: a ring.
  idle,
}

/// How a [CoilSidebarDot] is drawn.
enum CoilSidebarDotStyle {
  /// A solid dot.
  filled,

  /// An outlined dot.
  ring,
}

/// When a row's actions show on the pointer tier. Touch always shows its
/// last one.
enum CoilSidebarActionsVisibility {
  /// While the row is hovered or focused, or one of its menus is open. The
  /// label claims their width only then.
  hover,

  /// Always.
  always,
}

/// How keyboard focus shows in a [CoilSidebarMenu].
enum CoilSidebarMenuFocus {
  /// A ring travels between the rows.
  ring,

  /// The hover fill moves instead, for menus whose rows are the whole
  /// surface, such as a settings dialog's sections.
  highlight,
}

/// An 8 dot in a 16 box, for a row's leading slot. Use it when
/// [CoilSidebarStatus] doesn't fit.
class CoilSidebarDot extends StatelessWidget {
  /// Creates a dot.
  const CoilSidebarDot(this.style, {super.key});

  /// Filled or ring.
  final CoilSidebarDotStyle style;

  @override
  Widget build(BuildContext context) {
    final icon = IconTheme.of(context);
    final color = icon.color ?? CoilTheme.of(context).colors.mutedForeground;
    final box = CoilIconSize.of(context);
    final tint = color.withValues(alpha: color.a * 0.6);
    return SizedBox.square(
      dimension: box,
      child: Center(
        child: SizedBox.square(
          dimension: 8,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: style == CoilSidebarDotStyle.filled ? tint : null,
              shape: CircleBorder(
                side: style == CoilSidebarDotStyle.ring
                    ? BorderSide(color: tint)
                    : BorderSide.none,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One row of a [CoilSidebarMenu], with up to one level of [children].
@immutable
class CoilSidebarItem {
  /// Describes a row.
  const CoilSidebarItem({
    required this.label,
    this.semanticLabel,
    this.leading,
    this.status,
    this.trailing,
    this.actions = const [],
    this.actionsVisibility = CoilSidebarActionsVisibility.hover,
    this.selected = false,
    this.onPressed,
    this.children = const [],
    this.expanded = false,
    this.onExpandedChanged,
  });

  /// The row's text, styled by [DefaultTextStyle]: one line, ellipsized.
  final Widget label;

  /// The row's name for screen readers. Null reads the text of a [Text]
  /// [label]; give it for any other widget.
  final String? semanticLabel;

  /// An icon, styled by [IconTheme], or a [CoilSidebarDot].
  final Widget? leading;

  /// Shows a status dot when there is no [leading]. [CoilSidebarStatus.
  /// active] also selects the row.
  final CoilSidebarStatus? status;

  /// A badge, such as a count, in a 24 slot at the end.
  final Widget? trailing;

  /// Up to three actions, drawn as 24 icon buttons before [trailing]:
  /// a [CoilAction] (its `leading` is the icon, its label the tooltip) or a
  /// [CoilSubmenu], whose button opens its entries, usually the last, an
  /// overflow ⋯. Each button is named by the entry's `semanticLabel`, else
  /// its `searchText`; give every action one.
  ///
  /// The same entries open as a context menu on a right-click, and on a
  /// long press on touch, where only the last action shows (all of them
  /// when there is one), as in a data table.
  final List<CoilMenuEntry> actions;

  /// When [actions] show on the pointer tier.
  final CoilSidebarActionsVisibility actionsVisibility;

  /// Whether this row is the current page.
  final bool selected;

  /// Called when the row is picked. Null with no [children] disables it.
  final VoidCallback? onPressed;

  /// The rows nested under this one. They can't nest further.
  final List<CoilSidebarItem> children;

  /// Whether [children] show.
  final bool expanded;

  /// Called with the new [expanded] when the row is toggled: pressed when
  /// it has no [onPressed], or Right and Left from the keyboard.
  final ValueChanged<bool>? onExpandedChanged;

  bool get _selected => selected || status == CoilSidebarStatus.active;

  bool get _hasChildren => children.isNotEmpty;

  bool get _enabled => onPressed != null || onExpandedChanged != null;
}

/// Navigation rows, two levels deep.
///
/// A hovering pointer lights the rows with one fill that glides across
/// both levels; the selected row's fill glides too, one per level. Up and
/// Down move between visible rows, Home and End jump, Right opens a parent
/// or enters it, Left closes it or returns to the parent, Enter and Space
/// pick. The selected row is the tab stop. In a phone drawer, a pick closes
/// the drawer.
class CoilSidebarMenu extends StatefulWidget {
  /// Creates a sidebar menu.
  const CoilSidebarMenu({
    required this.items,
    super.key,
    this.focus = CoilSidebarMenuFocus.ring,
    this.size,
    this.unreadLabel = 'unread',
    this.style,
    this.motion,
    this.motions,
  });

  /// The rows.
  final List<CoilSidebarItem> items;

  /// How keyboard focus shows.
  final CoilSidebarMenuFocus focus;

  /// Pins the rows to one size step. Null follows [CoilAdaptiveScope].
  final CoilSize? size;

  /// Added to an unread row's name for screen readers.
  final String unreadLabel;

  /// Overrides the theme's sidebar style.
  final CoilSidebarStyle? style;

  /// Overrides the theme's motion tokens.
  final CoilMotion? motion;

  /// Per-track motions for this instance, keyed by [CoilSidebarTrack]s.
  final Map<CoilSidebarTrack<Object>, Motion>? motions;

  @override
  State<CoilSidebarMenu> createState() => _CoilSidebarMenuState();
}

/// A row in the flattened list: its item, level, index and parent.
class _Entry {
  const _Entry(this.item, this.index, this.parent);

  final CoilSidebarItem item;
  final int index;

  /// The parent's entry for a nested row.
  final _Entry? parent;

  bool get nested => parent != null;

  /// Whether the row shows: a nested row only while its parent is open.
  bool get visible => parent == null || parent!.item.expanded;
}

class _CoilSidebarMenuState extends State<CoilSidebarMenu> {
  final _nodes = <FocusNode>[];

  /// The row the keyboard focused, for the ring.
  int? _focused;

  @override
  void initState() {
    super.initState();
    // The ring shows only after keyboard use, which can begin after a row
    // already has focus.
    CoilInputModality.instance.addListener(_onModality);
  }

  void _onModality() => setState(() {});

  @override
  void dispose() {
    CoilInputModality.instance.removeListener(_onModality);
    for (final node in _nodes) {
      node.dispose();
    }
    super.dispose();
  }

  List<_Entry> _flatten() {
    final entries = <_Entry>[];
    for (final item in widget.items) {
      assert(
        item.children.every((child) => child.children.isEmpty),
        'Sidebar menus nest one level deep.',
      );
      final parent = _Entry(item, entries.length, null);
      entries.add(parent);
      for (final child in item.children) {
        entries.add(_Entry(child, entries.length, parent));
      }
    }
    return entries;
  }

  void _syncNodes(int count) {
    while (_nodes.length < count) {
      _nodes.add(FocusNode(debugLabel: 'CoilSidebarMenu.row'));
    }
    while (_nodes.length > count) {
      _nodes.removeLast().dispose();
    }
  }

  void _pick(CoilSidebarItem item) {
    if (item.onPressed case final onPressed?) {
      final scope = CoilSidebarScope.maybeOf(context);
      if (scope != null && scope.drawer) scope.closeDrawer();
      onPressed();
    } else {
      item.onExpandedChanged?.call(!item.expanded);
    }
  }

  Motion _motionFor(CoilSidebarTrack<Object> track, Motion token) =>
      CoilTheme.trackMotionOf(
        context,
        track,
        instance: widget.motions,
        token: token,
      );

  @override
  Widget build(BuildContext context) {
    final menu = _menu(context);
    final size = widget.size;
    return size == null ? menu : CoilAdaptiveScope(size: size, child: menu);
  }

  Widget _menu(BuildContext context) => Builder(
    builder: (context) {
      final theme = CoilTheme.of(context);
      final colors = theme.colors;
      final metrics = CoilTheme.metricsOf(context);
      final motion = CoilTheme.motionOf(context, override: widget.motion);
      final radii = theme.shape.radii(metrics.tier);
      final entries = _flatten();
      _syncNodes(entries.length);
      final keyboard =
          CoilInputModality.instance.value == CoilModality.keyboard;
      int? selectedAt({required bool nested}) => entries
          .where(
            (e) => e.nested == nested && e.visible && e.item._selected,
          )
          .map((e) => e.index)
          .firstOrNull;
      final tabStop =
          selectedAt(nested: false) ?? selectedAt(nested: true) ?? 0;
      ShapeDecoration fill(Color color) => ShapeDecoration(
        color: color,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(radii.item),
        ),
      );
      final selectionMotion = _motionFor(
        CoilSidebarTrack.selection,
        motion.standard,
      );
      CoilHighlight selection(String label, int? target) => CoilHighlight(
        key: ValueKey(label),
        debugLabel: label,
        target: target,
        fadeIn: false,
        motion: selectionMotion,
        exitMotion: motion.fadeExit,
        exitTravelMotion: selectionMotion,
        fade: motion.fade,
        decoration: fill(colors.active),
      );
      return CoilRovingFocus(
        nodes: _nodes,
        tabStop: tabStop,
        axis: Axis.vertical,
        child: CoilHoverRegion(
          followFocus: widget.focus == CoilSidebarMenuFocus.highlight,
          child: CoilHoverHighlight(
            radius: radii.item,
            motion: widget.motion,
            glideMotion: _motionFor(CoilSidebarTrack.highlight, motion.quick),
            background: [
              selection(
                'CoilSidebarMenu.selected',
                selectedAt(nested: false),
              ),
              // Its own fill, so a section and the page inside it can both
              // be lit.
              selection(
                'CoilSidebarMenu.selectedNested',
                selectedAt(nested: true),
              ),
            ],
            foreground: [
              if (widget.focus == CoilSidebarMenuFocus.ring)
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
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final entry in entries.where((e) => !e.nested))
                  _group(context, entry, entries),
              ],
            ),
          ),
        ),
      );
    },
  );

  /// A top-level row and, when it has children, its collapsible sub-tree.
  Widget _group(BuildContext context, _Entry entry, List<_Entry> entries) {
    final row = _row(context, entry);
    if (!entry.item._hasChildren) return row;
    final motion = CoilTheme.motionOf(context, override: widget.motion);
    final children = entries.where((e) => e.parent == entry).toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row,
        CoilCollapsible(
          expanded: entry.item.expanded,
          motion: widget.motion,
          heightMotion: _motionFor(
            CoilSidebarTrack.expand,
            entry.item.expanded ? motion.standard : motion.standardExit,
          ),
          child: _SubTree(
            children: [for (final child in children) _row(context, child)],
          ),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, _Entry entry) {
    final item = entry.item;
    final i = entry.index;
    final node = _nodes[i];
    final label = item.semanticLabel ?? coilSidebarPlainText(item.label) ?? '';
    final semanticLabel = item.status == CoilSidebarStatus.unread
        ? '$label, ${widget.unreadLabel}'
        : label;
    final row = CoilHoverItem(
      index: i,
      enabled: item._enabled && entry.visible,
      child: Semantics(
        container: true,
        button: true,
        enabled: item._enabled,
        selected: item._selected,
        expanded: item._hasChildren ? item.expanded : null,
        label: semanticLabel,
        child: CoilInteraction(
          focusNode: node,
          onPressed: item._enabled ? () => _pick(item) : null,
          minHitTarget: CoilTheme.metricsOf(context).minHitTarget,
          onFocusChange: (focused) => setState(() {
            if (focused) {
              _focused = i;
            } else if (_focused == i) {
              _focused = null;
            }
          }),
          builder: (context, states, _) {
            final active =
                CoilHoverItem.isActive(context, i) ||
                states.contains(WidgetState.focused);
            return _Row(
              item: item,
              nested: entry.nested,
              active: active,
              lit: item._selected || active,
              style: widget.style,
              motion: widget.motion,
            );
          },
        ),
      ),
    );
    // Right and Left open, enter, close and leave sub-trees.
    final keyed = CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _horizontal(entry, open: !_rtl(context)),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _horizontal(entry, open: _rtl(context)),
      },
      child: row,
    );
    if (item.actions.isEmpty) return keyed;
    return CoilContextMenu(entries: item.actions, child: keyed);
  }

  bool _rtl(BuildContext context) =>
      Directionality.of(context) == TextDirection.rtl;

  void _horizontal(_Entry entry, {required bool open}) {
    final item = entry.item;
    if (open) {
      if (!item._hasChildren) return;
      if (!item.expanded) {
        item.onExpandedChanged?.call(true);
      } else {
        _nodes[entry.index + 1].requestFocus();
      }
      return;
    }
    if (entry.parent case final parent?) {
      _nodes[parent.index].requestFocus();
    } else if (item._hasChildren && item.expanded) {
      item.onExpandedChanged?.call(false);
    }
  }
}

/// A sub-tree: a guide line under the parent's icon, its rows indented so
/// their labels line up with the parent's.
class _SubTree extends StatelessWidget {
  const _SubTree({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final metrics = CoilTheme.metricsOf(context);
    // The line runs under the center of the parent's icon.
    final axis = metrics.itemPaddingX + metrics.iconSize / 2 - 0.5;
    return Padding(
      padding: EdgeInsetsDirectional.only(start: axis),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: BorderDirectional(
            start: BorderSide(color: CoilTheme.of(context).colors.border),
          ),
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.only(
            start: metrics.iconSize / 2 + metrics.gap - metrics.itemPaddingX,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.item,
    required this.nested,
    required this.active,
    required this.lit,
    this.style,
    this.motion,
  });

  final CoilSidebarItem item;
  final bool nested;

  /// Hovered, or focused by the keyboard.
  final bool active;

  /// [active] or selected.
  final bool lit;
  final CoilSidebarStyle? style;
  final CoilMotion? motion;

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final colors = theme.colors;
    final metrics = CoilTheme.metricsOf(context);
    final tokens = CoilTheme.motionOf(context, override: motion);
    final look = CoilSidebarStyle.fallback(
      theme,
      metrics,
    ).merge(CoilTheme.styleOf<CoilSidebarStyle>(context)).merge(style);
    final touch = metrics.tier == CoilTier.touch;
    final color = lit || touch ? colors.foreground : colors.mutedForeground;
    final height = nested
        ? math.max(coilSidebarRowHeight(metrics) - 4, metrics.minHitTarget)
        : coilSidebarRowHeight(metrics);
    final leading =
        item.leading ??
        switch (item.status) {
          null => null,
          CoilSidebarStatus.idle => const CoilSidebarDot(
            CoilSidebarDotStyle.ring,
          ),
          _ => const CoilSidebarDot(CoilSidebarDotStyle.filled),
        };
    // Open, the chevron only shows while the row is active (always on
    // touch); folded, it stays as the cue to open.
    final showChevron =
        item._hasChildren && (!item.expanded || active || touch);
    return _RevealScope(
      reveal:
          touch ||
          item.actionsVisibility == CoilSidebarActionsVisibility.always ||
          active,
      builder: (context, reveal, _) => Opacity(
        opacity: item._enabled ? 1 : metrics.disabledOpacity,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: height),
          child: Padding(
            padding: EdgeInsetsDirectional.only(
              start: metrics.itemPaddingX,
              end: item.actions.isEmpty && item.trailing == null
                  ? metrics.itemPaddingX
                  : 6,
            ),
            child: IconTheme(
              data: IconThemeData(
                size: metrics.iconSize,
                applyTextScaling: true,
                color: color,
                weight: lit ? CoilIconWeight.emphasis : CoilIconWeight.rest,
              ),
              child: Row(
                spacing: metrics.gap,
                children: [
                  ?leading,
                  Expanded(
                    child: DefaultTextStyle(
                      style: theme.typography.style(
                        metrics.body,
                        weight: item._selected
                            ? CoilWeight.semibold
                            : CoilWeight.normal,
                        color: color,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      child: ExcludeSemantics(child: item.label),
                    ),
                  ),
                  if (showChevron)
                    SizedBox.square(
                      dimension: look.actionSize,
                      child: SingleMotionBuilder(
                        value: item.expanded ? 1 : 0,
                        motion: tokens.quick,
                        builder: (context, turn, child) => Transform.rotate(
                          angle:
                              turn *
                              (Directionality.of(context) == TextDirection.rtl
                                  ? -1
                                  : 1) *
                              math.pi /
                              2,
                          child: child,
                        ),
                        child: IconTheme.merge(
                          data: IconThemeData(
                            size: 16,
                            color: colors.mutedForeground,
                          ),
                          child: const CoilDrawnGlyph(CoilGlyph.chevronEnd),
                        ),
                      ),
                    ),
                  if (reveal && item.actions.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: look.actionGap!,
                      children: [
                        for (final action
                            in touch
                                ? item.actions.sublist(item.actions.length - 1)
                                : item.actions)
                          _ActionButton(action),
                      ],
                    ),
                  if (item.trailing case final trailing?)
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: look.actionSize!,
                      ),
                      child: Center(
                        widthFactor: 1,
                        child: DefaultTextStyle(
                          style: theme.typography.style(
                            metrics.caption,
                            color: colors.mutedForeground,
                          ),
                          child: IconTheme.merge(
                            data: IconThemeData(color: colors.mutedForeground),
                            child: trailing,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Keeps a row's actions shown while anything inside the row has focus,
/// such as a menu one of them opened, on top of [reveal].
class _RevealScope extends StatefulWidget {
  const _RevealScope({required this.reveal, required this.builder});

  final bool reveal;
  final ValueWidgetBuilder<bool> builder;

  @override
  State<_RevealScope> createState() => _RevealScopeState();
}

class _RevealScopeState extends State<_RevealScope> {
  bool _focusInside = false;

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    skipTraversal: true,
    includeSemantics: false,
    onFocusChange: (inside) => setState(() => _focusInside = inside),
    child: widget.builder(context, widget.reveal || _focusInside, null),
  );
}

/// A row action as a 24 icon button: a [CoilAction] runs, a [CoilSubmenu]
/// opens its entries.
class _ActionButton extends StatelessWidget {
  const _ActionButton(this.entry);

  final CoilMenuEntry entry;

  @override
  Widget build(BuildContext context) => switch (entry) {
    CoilAction(
      :final label,
      :final semanticLabel,
      :final searchText,
      :final leading,
      :final shortcut,
      :final onPressed,
    ) =>
      CoilSidebarAction(
        icon: leading ?? const SizedBox.shrink(),
        // An icon-only button: named by the action's semantic label, or
        // its plain text.
        semanticLabel: semanticLabel ?? searchText ?? '',
        tooltip: label,
        shortcut: shortcut,
        onPressed: onPressed,
      ),
    CoilSubmenu(
      :final semanticLabel,
      :final searchText,
      :final leading,
      :final entries,
    ) =>
      CoilDropdown(
        entries: entries,
        builder: (context, menu) => CoilSidebarAction(
          icon: leading ?? const SizedBox.shrink(),
          semanticLabel: semanticLabel ?? searchText ?? '',
          onPressed: menu.open,
        ),
      ),
    _ => throw ArgumentError.value(
      entry,
      'actions',
      'Row actions are CoilActions or CoilSubmenus',
    ),
  };
}
