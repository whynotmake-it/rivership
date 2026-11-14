import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/sidebar/sidebar_scope.dart';
import 'package:flutter/widgets.dart';

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
    final scope = CoilSidebarScope.maybeOf(context);
    if (scope != null && scope.drawer) scope.closeDrawer();
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
