import 'dart:async';

import 'package:coil/src/foundation/input_modality.dart';
import 'package:coil/src/foundation/metrics.dart';
import 'package:coil/src/foundation/motion.dart';
import 'package:coil/src/foundation/theme.dart';
import 'package:coil/src/foundation/typography.dart';
import 'package:coil/src/primitives/active_item.dart';
import 'package:coil/src/primitives/drawn_glyph.dart';
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
import 'package:motor_widgets/motor_widgets.dart';

/// One entry of a [CoilActionList]: a [CoilAction] row, a [CoilMenuLabel]
/// heading or a [CoilMenuSeparator].
@immutable
sealed class CoilMenuEntry {
  const CoilMenuEntry();
}

/// How a [CoilAction] reads.
enum CoilActionTone {
  /// An ordinary action.
  normal,

  /// An action that destroys something: red. Put it last, after a
  /// separator.
  destructive,
}

/// The mark a checkable [CoilAction] shows when [CoilAction.selected].
enum CoilActionMark {
  /// Not checkable.
  none,

  /// One of several independent options: a check.
  check,

  /// One choice among the rows around it: a dot.
  radio,
}

/// One row of a [CoilActionList].
class CoilAction extends CoilMenuEntry {
  /// Creates an action.
  const CoilAction({
    required this.label,
    this.leading,
    this.shortcut,
    this.onPressed,
    this.tone = CoilActionTone.normal,
    this.mark = CoilActionMark.none,
    this.selected = false,
  });

  /// The row's text, also used for typeahead and semantics.
  final String label;

  /// A glyph before the label, styled by [IconTheme].
  final Widget? leading;

  /// The keyboard shortcut, shown at the end of the row on the pointer tier
  /// only (a finger has no keyboard).
  final Widget? shortcut;

  /// Runs the action. Null disables the row.
  final VoidCallback? onPressed;

  /// How the row reads.
  final CoilActionTone tone;

  /// Whether the row is checkable, and how it shows [selected].
  final CoilActionMark mark;

  /// Whether a checkable row is on: semibold, with its mark.
  final bool selected;

  /// Whether the row can be picked.
  bool get enabled => onPressed != null;
}

/// A heading over a group of rows.
class CoilMenuLabel extends CoilMenuEntry {
  /// Creates a heading.
  const CoilMenuLabel(this.label);

  /// The heading's text.
  final String label;
}

/// A hairline between groups of rows.
class CoilMenuSeparator extends CoilMenuEntry {
  /// Creates a separator.
  const CoilMenuSeparator();
}

/// A menu's rows, headings and separators, for a popover or a sheet.
///
/// A hovering pointer lights rows with a gliding highlight. The arrow keys,
/// Home and End move between enabled rows, typing jumps to a row by its
/// label, and Enter or Space picks. Escape and Tab dismiss. Opened from the
/// keyboard, the list starts on the first row with a focus ring.
///
/// Picking an action calls [onClose] with [CoilPopupCloseReason.selected]
/// and then runs it. Picking a checkable row runs it first and closes after
/// the theme's `acknowledgeDuration`, so the mark lands before the menu
/// goes. On the touch tier of [metrics], rows rest at full
/// strength, since a finger can't hover.
///
/// The rows scroll when the list is taller than its room, with edges that
/// fade into [surface].
class CoilActionList extends StatefulWidget {
  /// Creates an action list.
  const CoilActionList({
    required this.entries,
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

  /// The rows, headings and separators.
  final List<CoilMenuEntry> entries;

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
  late List<GlobalKey> _rowKeys = _keysFor(widget.entries.length);
  Timer? _acknowledge;

  static List<GlobalKey> _keysFor(int count) => [
    for (var i = 0; i < count; i++) GlobalKey(debugLabel: 'CoilActionList $i'),
  ];

  int get _count => widget.entries.length;
  bool _enabled(int i) => switch (widget.entries[i]) {
    final CoilAction action => action.enabled,
    _ => false,
  };

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
    if (oldWidget.entries.length != widget.entries.length) {
      _rowKeys = _keysFor(widget.entries.length);
    }
  }

  @override
  void dispose() {
    _acknowledge?.cancel();
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

  /// Closes the menu, then runs the action. A checkable row runs first and
  /// closes once its mark has landed.
  void _pick(int i) {
    final action = widget.entries[i];
    if (action is! CoilAction || !action.enabled) return;
    if (action.mark == CoilActionMark.none) {
      widget.onClose(CoilPopupCloseReason.selected);
      action.onPressed?.call();
      return;
    }
    action.onPressed?.call();
    _acknowledge?.cancel();
    _acknowledge = Timer(
      CoilTheme.motionOf(context, override: widget.motion).acknowledgeDuration,
      () => widget.onClose(CoilPopupCloseReason.selected),
    );
  }

  /// The typeahead text of [entry]; headings and separators match nothing.
  static String _labelOf(CoilMenuEntry entry) => switch (entry) {
    final CoilAction action => action.label,
    _ => '',
  };

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
            labels: [for (final entry in widget.entries) _labelOf(entry)],
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
                          for (final (i, entry) in widget.entries.indexed)
                            switch (entry) {
                              final CoilAction action => CoilHoverItem(
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
                              final CoilMenuLabel label => _GroupLabel(
                                key: _rowKeys[i],
                                label: label.label,
                                metrics: metrics,
                              ),
                              CoilMenuSeparator() => _Separator(
                                key: _rowKeys[i],
                                inset: metrics.popupInset,
                              ),
                            },
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
    final action = widget.action;
    return Semantics(
      role: switch (action.mark) {
        CoilActionMark.none => SemanticsRole.menuItem,
        CoilActionMark.check => SemanticsRole.menuItemCheckbox,
        CoilActionMark.radio => SemanticsRole.menuItemRadio,
      },
      checked: action.mark == CoilActionMark.none ? null : action.selected,
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
              final color = action.tone == CoilActionTone.destructive
                  ? colors.redLabel
                  : emphasized || action.selected
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

/// The leading glyph, label and trailing shortcut or mark, at least a
/// control tall and centered in it.
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
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final pointer = metrics.tier == CoilTier.pointer;
    final mark = switch (action.mark) {
      CoilActionMark.none => null,
      _ when !action.selected => SizedBox.square(dimension: metrics.iconSize),
      CoilActionMark.check => IconTheme.merge(
        data: const IconThemeData(weight: CoilIconWeight.emphasis),
        child: const CoilDrawnGlyph(CoilGlyph.check),
      ),
      CoilActionMark.radio => SizedBox.square(
        dimension: metrics.iconSize,
        child: Center(
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: color,
              shape: const RoundedSuperellipseBorder(
                borderRadius: BorderRadius.all(Radius.circular(3)),
              ),
            ),
            child: const SizedBox.square(dimension: 6),
          ),
        ),
      ),
    };
    final shortcut = pointer ? action.shortcut : null;
    return ConstrainedBox(
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
              style: theme.typography.style(
                metrics.body,
                weight: action.selected
                    ? CoilWeight.semibold
                    : CoilWeight.normal,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              child: Row(
                spacing: metrics.gap,
                children: [
                  ?action.leading,
                  Expanded(child: Text(action.label)),
                  if (shortcut != null)
                    DefaultTextStyle(
                      style: theme.typography.style(
                        metrics.caption,
                        color: theme.colors.mutedForeground,
                      ),
                      child: shortcut,
                    ),
                  ?mark,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A heading over a group of rows: a muted caption.
class _GroupLabel extends StatelessWidget {
  const _GroupLabel({required this.label, required this.metrics, super.key});

  final String label;
  final CoilMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    return Semantics(
      header: true,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          metrics.itemPaddingX,
          8,
          metrics.itemPaddingX,
          6,
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
    );
  }
}

/// A hairline between groups, reaching the popup's edges.
class _Separator extends StatelessWidget {
  const _Separator({required this.inset, super.key});

  /// The popup's padding, which the line reaches across.
  final double inset;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    // Negative side padding reaches across the popup's inset.
    child: PaddingExtended(
      padding: EdgeInsets.symmetric(horizontal: -inset),
      child: SizedBox(
        height: 1,
        child: ColoredBox(
          color: CoilTheme.of(context).colors.border.withValues(alpha: 0.6),
        ),
      ),
    ),
  );
}
