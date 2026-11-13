import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/breadcrumb/breadcrumb_style.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// One row of the "…" menu: what a hidden crumb shows and does.
@immutable
class HiddenCrumb {
  /// Creates a row.
  const HiddenCrumb({required this.label, this.icon, this.onPressed});

  /// The crumb's full name.
  final String label;

  /// The crumb's icon.
  final Widget? icon;

  /// Follows the crumb. Null disables the row.
  final VoidCallback? onPressed;
}

/// The list in the "…" menu: the hidden crumbs by full name, one action
/// row each, with the gliding highlight, arrows, Home/End, typeahead,
/// Enter/Space, and Escape/Tab to close.
///
/// Internal to the breadcrumb. It is a minimal action menu until coil has
/// a Dropdown component, which should replace it.
class HiddenCrumbList extends StatefulWidget {
  /// Creates the list.
  const HiddenCrumbList({
    required this.crumbs,
    required this.metrics,
    required this.style,
    required this.fullEmphasis,
    required this.onPick,
    required this.onDismiss,
    required this.keyboardOpened,
    super.key,
  });

  /// The rows.
  final List<HiddenCrumb> crumbs;

  /// The row sizes.
  final CoilMetrics metrics;

  /// The resolved look.
  final CoilBreadcrumbStyle style;

  /// Rows rest at full strength (touch) instead of muted (pointer).
  final bool fullEmphasis;

  /// Called with the picked row.
  final ValueChanged<int> onPick;

  /// Called on Escape or Tab, with the reason.
  final ValueChanged<CoilPopupCloseReason> onDismiss;

  /// Whether the keyboard opened the menu: it then starts on the first row
  /// with the focus ring showing.
  final bool keyboardOpened;

  @override
  State<HiddenCrumbList> createState() => _HiddenCrumbListState();
}

class _HiddenCrumbListState extends State<HiddenCrumbList>
    with TickerProviderStateMixin {
  final _active = CoilActiveItemController();
  late final _ring = CoilHighlightPainter(
    vsync: this,
    debugLabel: 'CoilBreadcrumb.menuRing',
  );

  int get _count => widget.crumbs.length;
  bool _enabled(int i) => widget.crumbs[i].onPressed != null;

  @override
  void initState() {
    super.initState();
    if (widget.keyboardOpened) {
      _active.first(count: _count, isEnabled: _enabled);
    }
  }

  @override
  void dispose() {
    _active.dispose();
    _ring.dispose();
    super.dispose();
  }

  void _pickActive() {
    if (_active.index case final i? when _enabled(i)) widget.onPick(i);
  }

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final motion = CoilTheme.motionOf(context);
    final metrics = widget.metrics;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
            _active.move(1, count: _count, isEnabled: _enabled),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
            _active.move(-1, count: _count, isEnabled: _enabled),
        const SingleActivator(LogicalKeyboardKey.home): () =>
            _active.first(count: _count, isEnabled: _enabled),
        const SingleActivator(LogicalKeyboardKey.end): () =>
            _active.last(count: _count, isEnabled: _enabled),
        const SingleActivator(LogicalKeyboardKey.enter, includeRepeats: false):
            _pickActive,
        const SingleActivator(
          LogicalKeyboardKey.numpadEnter,
          includeRepeats: false,
        ): _pickActive,
        const SingleActivator(LogicalKeyboardKey.space, includeRepeats: false):
            _pickActive,
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            widget.onDismiss(CoilPopupCloseReason.escape),
        const SingleActivator(LogicalKeyboardKey.tab): () =>
            widget.onDismiss(CoilPopupCloseReason.dismissed),
      },
      child: ListenableBuilder(
        listenable: _active,
        builder: (context, child) {
          _ring.update(
            target: _active.keyboardDriven ? _active.index : null,
            fadeIn: false,
            motion: motion.quick,
            exitMotion: motion.fadeExit,
            exitTravelMotion: motion.quick,
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
          return CoilTypeahead(
            labels: [for (final c in widget.crumbs) c.label],
            current: _active.index,
            isEnabled: _enabled,
            onMatch: (i) => _active.activate(i, via: CoilModality.keyboard),
            child: child!,
          );
        },
        child: Focus(
          autofocus: true,
          debugLabel: 'CoilBreadcrumb menu',
          child: Semantics(
            role: SemanticsRole.menu,
            child: CoilHoverRegion(
              activeItem: _active,
              followFocus: false,
              highlightColor: widget.style.highlight,
              highlightRadius: widget.style.radius,
              foreground: [_ring],
              child: SingleChildScrollView(
                padding: EdgeInsets.all(metrics.popupInset),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, crumb) in widget.crumbs.indexed)
                      CoilHoverItem(
                        index: i,
                        enabled: crumb.onPressed != null,
                        child: _Row(
                          index: i,
                          crumb: crumb,
                          metrics: metrics,
                          style: widget.style,
                          fullEmphasis: widget.fullEmphasis,
                          onPressed: crumb.onPressed == null
                              ? null
                              : () => widget.onPick(i),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One menu row: icon and label. Paints only its own press fill on touch;
/// the list's region paints the highlight.
class _Row extends StatefulWidget {
  const _Row({
    required this.index,
    required this.crumb,
    required this.metrics,
    required this.style,
    required this.fullEmphasis,
    required this.onPressed,
  });

  final int index;
  final HiddenCrumb crumb;
  final CoilMetrics metrics;
  final CoilBreadcrumbStyle style;
  final bool fullEmphasis;
  final VoidCallback? onPressed;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  final _states = WidgetStatesController();

  @override
  void dispose() {
    _states.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motion = CoilTheme.motionOf(context);
    final metrics = widget.metrics;
    final style = widget.style;
    final lit = CoilHoverRegion.maybeOf(context)?.activeIndex == widget.index;
    final color = style.label!.resolve({
      if (lit || widget.fullEmphasis) WidgetState.hovered,
    })!;
    final radius = BorderRadius.circular(style.radius!);
    return Semantics(
      role: SemanticsRole.menuItem,
      enabled: widget.onPressed != null,
      label: widget.crumb.label,
      excludeSemantics: true,
      onTap: widget.onPressed,
      child: Opacity(
        opacity: widget.onPressed != null
            ? 1
            : (widget.fullEmphasis ? 0.4 : 0.5),
        // Rows aren't focus stops: the list holds focus and the active item
        // says which row Enter picks.
        child: CoilInteractionDetector(
          states: _states,
          enabled: widget.onPressed != null,
          onTap: widget.onPressed,
          cursor: widget.onPressed != null
              ? SystemMouseCursors.click
              : MouseCursor.defer,
          excludeFromSemantics: true,
          child: ListenableBuilder(
            listenable: _states,
            builder: (context, child) {
              final s = _states.value;
              // A finger gets a fill while it presses; hovering pointers
              // already show the highlight.
              final pressed =
                  s.contains(WidgetState.pressed) &&
                  !s.contains(WidgetState.hovered);
              return MotionBuilder<Color>(
                value: pressed
                    ? style.pressFill!
                    : style.pressFill!.withValues(alpha: 0),
                converter: MotionConverter.colorRgb,
                motion: pressed ? motion.fade : motion.fadeExit,
                debugLabel: 'CoilBreadcrumb row press',
                builder: (context, fill, child) => DecoratedBox(
                  decoration: ShapeDecoration(
                    color: fill,
                    shape: RoundedSuperellipseBorder(borderRadius: radius),
                  ),
                  child: child,
                ),
                child: child,
              );
            },
            child: MotionBuilder<Color>(
              value: color,
              converter: MotionConverter.colorRgb,
              motion: motion.fade,
              debugLabel: 'CoilBreadcrumb row text',
              builder: (context, color, _) => ConstrainedBox(
                constraints: BoxConstraints(minHeight: metrics.controlHeight),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: metrics.itemPaddingX,
                    vertical: metrics.controlPaddingY(metrics.body),
                  ),
                  child: IconTheme(
                    data: IconThemeData(
                      size: metrics.iconSize,
                      applyTextScaling: true,
                      color: color,
                    ),
                    child: DefaultTextStyle(
                      style: CoilTheme.of(
                        context,
                      ).typography.style(metrics.body, color: color),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      child: Row(
                        spacing: metrics.gap,
                        children: [
                          ?widget.crumb.icon,
                          Flexible(child: Text(widget.crumb.label)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
