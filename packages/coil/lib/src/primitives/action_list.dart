import 'package:coil/src/foundation/input_modality.dart';
import 'package:coil/src/foundation/metrics.dart';
import 'package:coil/src/foundation/motion.dart';
import 'package:coil/src/foundation/theme.dart';
import 'package:coil/src/primitives/active_item.dart';
import 'package:coil/src/primitives/edge_fade.dart';
import 'package:coil/src/primitives/hover.dart';
import 'package:coil/src/primitives/interaction.dart';
import 'package:coil/src/primitives/layer.dart';
import 'package:coil/src/primitives/popup_controller.dart';
import 'package:coil/src/primitives/scrollbar.dart';
import 'package:coil/src/primitives/typeahead.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// One row of a [CoilActionList].
@immutable
class CoilAction {
  /// Creates an action.
  const CoilAction({required this.label, this.leading, this.onPressed});

  /// The row's text, also used for typeahead and semantics.
  final String label;

  /// A glyph before the label, styled by [IconTheme].
  final Widget? leading;

  /// Runs the action. Null disables the row.
  final VoidCallback? onPressed;

  /// Whether the row can be picked.
  bool get enabled => onPressed != null;
}

/// A menu's list of actions, for a popover or a sheet.
///
/// A hovering pointer lights rows with a gliding highlight. The arrow keys,
/// Home and End move between enabled rows, typing jumps to a row by its
/// label, and Enter or Space picks. Escape and Tab dismiss. Opened from the
/// keyboard, the list starts on the first row with a focus ring.
///
/// Picking a row calls [onClose] with [CoilPopupCloseReason.selected] and
/// then runs the action. On the touch tier of [metrics], rows rest at full
/// strength, since a finger can't hover.
///
/// The rows scroll when the list is taller than its room, with edges that
/// fade into [surface].
class CoilActionList extends StatefulWidget {
  /// Creates an action list.
  const CoilActionList({
    required this.actions,
    required this.onClose,
    required this.metrics,
    required this.surface,
    required this.scrollbar,
    super.key,
    this.fadeExtent = 32,
    this.highlight,
    this.pressFill,
    this.radius,
    this.motion,
  });

  /// The rows.
  final List<CoilAction> actions;

  /// Called when a pick, Escape or Tab closes the menu.
  final ValueChanged<CoilPopupCloseReason> onClose;

  /// The row sizes, and the tier that picks the rows' resting emphasis.
  final CoilMetrics metrics;

  /// The color behind the list, which the scroll edges fade into.
  final Color surface;

  /// How the scrollbar looks.
  final CoilScrollbarLook scrollbar;

  /// How far each scroll edge fade reaches.
  final double fadeExtent;

  /// The hover highlight; the theme's `hover` tint when null.
  final Color? highlight;

  /// The fill under a row while a finger presses it; the theme's `active`
  /// tint when null.
  final Color? pressFill;

  /// The row corner radius; the theme's item radius when null.
  final double? radius;

  /// Overrides the theme's motion tokens for this list.
  final CoilMotion? motion;

  @override
  State<CoilActionList> createState() => _CoilActionListState();
}

class _CoilActionListState extends State<CoilActionList>
    with TickerProviderStateMixin {
  final _active = CoilActiveItemController();
  late List<GlobalKey> _rowKeys = _keysFor(widget.actions.length);

  static List<GlobalKey> _keysFor(int count) => [
    for (var i = 0; i < count; i++) GlobalKey(debugLabel: 'CoilActionList $i'),
  ];

  int get _count => widget.actions.length;
  bool _enabled(int i) => widget.actions[i].enabled;

  @override
  void initState() {
    super.initState();
    if (CoilInputModality.instance.value == CoilModality.keyboard) {
      _active.first(count: _count, isEnabled: _enabled);
    }
    _active.addListener(_reveal);
  }

  @override
  void didUpdateWidget(CoilActionList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.actions.length != widget.actions.length) {
      _rowKeys = _keysFor(widget.actions.length);
    }
  }

  @override
  void dispose() {
    _active
      ..removeListener(_reveal)
      ..dispose();
    super.dispose();
  }

  /// Scrolls a row the keyboard made active into view.
  void _reveal() {
    if (!_active.keyboardDriven) return;
    final i = _active.index;
    final row = i == null ? null : _rowKeys[i].currentContext;
    if (row == null) return;
    Scrollable.ensureVisible(
      row,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
    );
    Scrollable.ensureVisible(
      row,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
    );
  }

  /// Closes the menu, then runs the action.
  void _pick(int i) {
    final action = widget.actions[i];
    if (!action.enabled) return;
    widget.onClose(CoilPopupCloseReason.selected);
    action.onPressed?.call();
  }

  void _pickActive() {
    if (_active.index case final i?) _pick(i);
  }

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final motion = CoilTheme.motionOf(context, override: widget.motion);
    final metrics = widget.metrics;
    final radius = widget.radius ?? theme.shape.radii(metrics.tier).item;
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
            widget.onClose(CoilPopupCloseReason.escape),
        const SingleActivator(LogicalKeyboardKey.tab): () =>
            widget.onClose(CoilPopupCloseReason.dismissed),
      },
      child: ListenableBuilder(
        listenable: _active,
        builder: (context, child) {
          return CoilTypeahead(
            labels: [for (final a in widget.actions) a.label],
            current: _active.index,
            isEnabled: _enabled,
            onMatch: (i) => _active.activate(i, via: CoilModality.keyboard),
            child: child!,
          );
        },
        child: Focus(
          autofocus: true,
          debugLabel: 'CoilActionList',
          child: Semantics(
            role: SemanticsRole.menu,
            child: CoilScrollEdgeFade.solid(
              color: widget.surface,
              extent: widget.fadeExtent,
              child: ScrollConfiguration(
                behavior: CoilScrollBehavior(
                  tier: metrics.tier,
                  look: widget.scrollbar,
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(metrics.popupInset),
                  // The region and its layer scroll with the rows, so the
                  // highlight and the ring stay on their rows.
                  child: CoilHoverRegion(
                    activeItem: _active,
                    followFocus: false,
                    child: ListenableBuilder(
                      listenable: _active,
                      builder: (context, rows) {
                        final ring = CoilHighlight(
                          debugLabel: 'CoilActionList.ring',
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
                        return CoilHoverHighlight(
                          color: widget.highlight,
                          radius: radius,
                          motion: widget.motion,
                          foreground: [ring],
                          child: rows!,
                        );
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final (i, action) in widget.actions.indexed)
                            CoilHoverItem(
                              key: _rowKeys[i],
                              index: i,
                              enabled: action.enabled,
                              child: _Row(
                                index: i,
                                action: action,
                                active: _active,
                                metrics: metrics,
                                radius: radius,
                                pressFill:
                                    widget.pressFill ?? theme.colors.active,
                                motion: motion,
                                onPressed: action.enabled
                                    ? () => _pick(i)
                                    : null,
                              ),
                            ),
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

/// One row: leading glyph and label. It paints only its own press fill;
/// the list's layer paints the highlight and the ring.
class _Row extends StatefulWidget {
  const _Row({
    required this.index,
    required this.action,
    required this.active,
    required this.metrics,
    required this.radius,
    required this.pressFill,
    required this.motion,
    required this.onPressed,
  });

  final int index;
  final CoilAction action;
  final CoilActiveItemController active;
  final CoilMetrics metrics;
  final double radius;
  final Color pressFill;
  final CoilMotion motion;
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
    final theme = CoilTheme.of(context);
    final colors = theme.colors;
    final metrics = widget.metrics;
    final motion = widget.motion;
    final enabled = widget.onPressed != null;
    final touch = metrics.tier == CoilTier.touch;
    // The active row is lit by the pointer or, when the keyboard moved it
    // there, focused.
    final lit = CoilHoverRegion.maybeOf(context)?.activeIndex == widget.index;
    final keyboard = widget.active.keyboardDriven;
    final radius = BorderRadius.circular(widget.radius);
    return Semantics(
      role: SemanticsRole.menuItem,
      enabled: enabled,
      label: widget.action.label,
      excludeSemantics: true,
      onTap: widget.onPressed,
      child: Opacity(
        opacity: enabled ? 1 : widget.metrics.disabledRowOpacity,
        // Rows aren't focus stops: the list holds focus and the active item
        // says which row Enter picks.
        child: CoilInteractionDetector(
          states: _states,
          enabled: enabled,
          onTap: widget.onPressed,
          cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
          excludeFromSemantics: true,
          child: ListenableBuilder(
            listenable: _states,
            builder: (context, child) {
              final states = {
                ..._states.value,
                if (lit && keyboard) WidgetState.focused,
                if (lit && !keyboard) WidgetState.hovered,
              };
              final pressed = states.contains(WidgetState.pressed);
              // Touch rows rest at full strength: the muted to foreground
              // change says "the pointer is here", which a finger can't.
              final emphasized =
                  touch ||
                  pressed ||
                  states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.focused);
              final color = emphasized
                  ? colors.foreground
                  : colors.mutedForeground;
              // A finger gets a fill while it presses; a hovering pointer
              // already shows the highlight.
              final fill =
                  pressed && !_states.value.contains(WidgetState.hovered)
                  ? widget.pressFill
                  : widget.pressFill.withValues(alpha: 0);
              return MotionBuilder<Color>(
                value: fill,
                converter: MotionConverter.colorRgb,
                motion: pressed ? motion.fade : motion.fadeExit,
                debugLabel: 'CoilActionList.press',
                builder: (context, fill, child) => DecoratedBox(
                  decoration: ShapeDecoration(
                    color: fill,
                    shape: RoundedSuperellipseBorder(borderRadius: radius),
                  ),
                  child: child,
                ),
                child: MotionBuilder<Color>(
                  value: color,
                  converter: MotionConverter.colorRgb,
                  motion: motion.fade,
                  debugLabel: 'CoilActionList.label',
                  builder: (context, color, _) => _RowContent(
                    action: widget.action,
                    metrics: metrics,
                    color: color,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The leading glyph and label, at least a control tall and centered in it.
class _RowContent extends StatelessWidget {
  const _RowContent({
    required this.action,
    required this.metrics,
    required this.color,
  });

  final CoilAction action;
  final CoilMetrics metrics;
  final Color color;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(minHeight: metrics.controlHeight),
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: metrics.itemPaddingX),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        heightFactor: 1,
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
                ?action.leading,
                Flexible(child: Text(action.label)),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
