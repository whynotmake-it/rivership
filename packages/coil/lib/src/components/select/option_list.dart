import 'dart:math' as math;

import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/select/select_style.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// The list inside both presentations of a select: rows on a
/// [CoilMotionLayer] (the fluid highlight on the active item, the selected
/// fill, merge/split blocks for multi-select, a travelling keyboard ring),
/// keyboard navigation and typeahead.
///
/// Internal to the select component.
class CoilOptionList<T> extends StatefulWidget {
  /// Creates the list.
  const CoilOptionList({
    required this.options,
    required this.picked,
    required this.onPick,
    required this.onDismiss,
    required this.metrics,
    required this.style,
    super.key,
    this.multiple = false,
    this.keyboardOpened = false,
    this.selectedFill = true,
    this.fullEmphasis = false,
    this.checkmark,
    this.activeItem,
  });

  /// The choices.
  final List<CoilOption<T>> options;

  /// The values picked when the list opened.
  final Set<T> picked;

  /// Called with each picked (or toggled) value.
  final ValueChanged<T> onPick;

  /// Escape ([CoilPopupCloseReason.escape]) or Tab
  /// ([CoilPopupCloseReason.dismissed]).
  final ValueChanged<CoilPopupCloseReason> onDismiss;

  /// The size step.
  final CoilMetrics metrics;

  /// The resolved look.
  final CoilSelectStyle style;

  /// Whether rows toggle independently.
  final bool multiple;

  /// Whether the list was opened from the keyboard: it then starts on the
  /// picked row (or the first) with the ring showing.
  final bool keyboardOpened;

  /// Whether the picked row gets a fill (popovers). Sheets mark it with the
  /// check alone, like native touch lists.
  final bool selectedFill;

  /// Rows rest at full strength instead of muted (touch: the muted to
  /// foreground fade says "the pointer is here", which a finger can't).
  final bool fullEmphasis;

  /// Replaces the check glyph.
  final Widget? checkmark;

  /// Drives the active row from outside. The owner handles the keys, like a
  /// combobox's field, so the list takes no focus and no keys.
  final CoilActiveItemController? activeItem;

  @override
  State<CoilOptionList<T>> createState() => _CoilOptionListState<T>();
}

class _CoilOptionListState<T> extends State<CoilOptionList<T>>
    with TickerProviderStateMixin {
  CoilActiveItemController? _own;
  CoilActiveItemController get _active =>
      widget.activeItem ?? (_own ??= CoilActiveItemController());
  late List<GlobalKey> _rowKeys = _keysFor(widget.options.length);

  static List<GlobalKey> _keysFor(int count) => [
    for (var i = 0; i < count; i++) GlobalKey(debugLabel: 'CoilSelect row $i'),
  ];

  @override
  void didUpdateWidget(CoilOptionList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.options.length != widget.options.length) {
      _rowKeys = _keysFor(widget.options.length);
    }
    // The owner's value wins over what this list showed since its last
    // build (a popover rebuilds with its owner; a sheet's route doesn't).
    if (!setEquals(oldWidget.picked, widget.picked) ||
        oldWidget.options != widget.options) {
      _syncChecked();
    }
  }

  void _syncChecked() {
    _checked
      ..clear()
      ..addAll([
        for (final (i, option) in widget.options.indexed)
          if (widget.picked.contains(option.value)) i,
      ]);
  }

  /// The rows showing as picked.
  final Set<int> _checked = {};
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _syncChecked();
    final first = _checked.isEmpty ? null : _checked.reduce(math.min);
    if (widget.keyboardOpened) {
      if (first != null) {
        _active.activate(first, via: CoilModality.keyboard);
      } else {
        _active.first(count: widget.options.length, isEnabled: _enabled);
      }
    }
    _active.addListener(_onActive);
    // Scrolls the picked (or active) row into view once the list is laid
    // out; Scrollable.ensureVisible needs the row's render box.
    if (_active.index != null || first != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
    }
  }

  @override
  void dispose() {
    _active.removeListener(_onActive);
    _own?.dispose();
    super.dispose();
  }

  bool _enabled(int i) => widget.options[i].enabled;

  void _onActive() {
    // Typeahead searches from the active item, so it rebuilds with it.
    setState(() {});
    if (_active.keyboardDriven) _reveal();
  }

  void _reveal() {
    if (!mounted) return;
    final i =
        _active.index ?? (_checked.isEmpty ? null : _checked.reduce(math.min));
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

  /// Picks [index]. A pick by touch leaves nothing lit; the keyboard and
  /// hovering pointers keep the highlight on the row through the
  /// acknowledgement.
  void _pick(int index, {required bool touch}) {
    if (_done || !_enabled(index)) return;
    setState(() {
      if (widget.multiple) {
        _checked.contains(index) ? _checked.remove(index) : _checked.add(index);
      } else {
        _done = true;
        _checked
          ..clear()
          ..add(index);
      }
    });
    if (touch) {
      _active.clear();
    } else if (_active.index != index) {
      _active.activate(index, via: CoilModality.pointer);
    }
    widget.onPick(widget.options[index].value);
  }

  void _pickActive() {
    if (_active.index case final i?) _pick(i, touch: false);
  }

  void _move(int step) {
    if (_done) return;
    _active.move(step, count: widget.options.length, isEnabled: _enabled);
  }

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final colors = theme.colors;
    final motion = CoilTheme.motionOf(context);
    final metrics = widget.metrics;
    final style = widget.style;
    final radius = BorderRadius.circular(style.radius!);
    final count = widget.options.length;

    final blocks = CoilSelectionBlocks(
      selected: _checked,
      color: style.selectedFill!,
      radius: style.radius!,
      motion: motion,
    );
    final selectedFill = CoilHighlight(
      debugLabel: 'CoilSelect.selected',
      target: widget.selectedFill && !widget.multiple && _checked.isNotEmpty
          ? _checked.first
          : null,
      fadeIn: false,
      motion: motion.standard,
      exitMotion: motion.fadeExit,
      exitTravelMotion: motion.standard,
      fade: motion.fade,
      decoration: ShapeDecoration(
        color: style.selectedFill,
        shape: RoundedSuperellipseBorder(borderRadius: radius),
      ),
    );

    final rows = <Widget>[
      for (final (i, option) in widget.options.indexed)
        CoilHoverItem(
          key: _rowKeys[i],
          index: i,
          enabled: option.enabled,
          child: _OptionRow(
            index: i,
            style: style,
            option: option,
            metrics: metrics,
            checked: _checked.contains(i),
            fullEmphasis: widget.fullEmphasis,
            checkmark: widget.checkmark,
            onPressed: option.enabled && !_done
                ? () => _pick(
                    i,
                    touch: !CoilInputModality.canHover(
                      CoilInputModality.instance.lastPointerKind ??
                          PointerDeviceKind.touch,
                    ),
                  )
                : null,
          ),
        ),
    ];

    final list = Semantics(
      role: SemanticsRole.menu,
      child: ListenableBuilder(
        listenable: _active,
        builder: (context, child) {
          return child!;
        },
        child: CoilHoverRegion(
          activeItem: _active,
          followFocus: false,
          // After a pick the list waits out the acknowledgement: the
          // highlight stays on the picked row and the rows ignore the
          // pointer until it closes.
          hold: (_) => _done,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(metrics.popupInset),
            // The layer scrolls with the rows, so the highlight, the
            // selection and the ring stay on their rows.
            child: ListenableBuilder(
              listenable: _active,
              builder: (context, rows) {
                final ring = CoilHighlight(
                  debugLabel: 'CoilSelect.ring',
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
                        color: colors.focusRing,
                        width: theme.focusRingWidth,
                      ),
                    ),
                  ),
                );
                return CoilHoverHighlight(
                  color: style.highlight,
                  radius: style.radius,
                  background: [if (widget.multiple) blocks else selectedFill],
                  foreground: [ring],
                  child: rows!,
                );
              },
              child: IgnorePointer(
                ignoring: _done,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: rows,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (widget.activeItem != null) return list;
    return CoilTypeahead(
      searchTexts: [for (final o in widget.options) o.searchText],
      current: _active.index,
      isEnabled: _enabled,
      onMatch: (i) => _done ? null : _active.activate(i, via: .keyboard),
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowDown): () => _move(1),
          const SingleActivator(LogicalKeyboardKey.arrowUp): () => _move(-1),
          const SingleActivator(LogicalKeyboardKey.home): () =>
              _done ? null : _active.first(count: count, isEnabled: _enabled),
          const SingleActivator(LogicalKeyboardKey.pageUp): () =>
              _done ? null : _active.first(count: count, isEnabled: _enabled),
          const SingleActivator(LogicalKeyboardKey.end): () =>
              _done ? null : _active.last(count: count, isEnabled: _enabled),
          const SingleActivator(LogicalKeyboardKey.pageDown): () =>
              _done ? null : _active.last(count: count, isEnabled: _enabled),
          const SingleActivator(
            LogicalKeyboardKey.enter,
            includeRepeats: false,
          ): _pickActive,
          const SingleActivator(
            LogicalKeyboardKey.numpadEnter,
            includeRepeats: false,
          ): _pickActive,
          const SingleActivator(
            LogicalKeyboardKey.space,
            includeRepeats: false,
          ): _pickActive,
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              widget.onDismiss(CoilPopupCloseReason.escape),
          const SingleActivator(LogicalKeyboardKey.tab): () =>
              widget.onDismiss(CoilPopupCloseReason.dismissed),
        },
        child: Focus(
          autofocus: true,
          debugLabel: 'CoilSelect list',
          child: list,
        ),
      ),
    );
  }
}

/// One row: leading glyph, label, trailing check. Draws no background
/// except its own press fill on touch; the list's layer paints the
/// highlight and the selection underneath.
class _OptionRow extends StatefulWidget {
  const _OptionRow({
    required this.index,
    required this.style,
    required this.option,
    required this.metrics,
    required this.checked,
    required this.fullEmphasis,
    required this.checkmark,
    required this.onPressed,
  });

  final int index;
  final CoilSelectStyle style;
  final CoilOption<Object?> option;
  final CoilMetrics metrics;
  final bool checked;
  final bool fullEmphasis;
  final Widget? checkmark;
  final VoidCallback? onPressed;

  @override
  State<_OptionRow> createState() => _OptionRowState();
}

class _OptionRowState extends State<_OptionRow> {
  final _states = WidgetStatesController();

  @override
  void dispose() {
    _states.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final _OptionRow(
      :index,
      :option,
      :metrics,
      :checked,
      :fullEmphasis,
      :checkmark,
      :onPressed,
    ) = widget;
    final theme = CoilTheme.of(context);
    final colors = theme.colors;
    final motion = CoilTheme.motionOf(context);
    final lit = CoilHoverRegion.maybeOf(context)?.activeIndex;
    final style = widget.style;
    final color = style.rowLabel!.resolve({
      if (checked) WidgetState.selected,
      if (lit != null && lit == index) WidgetState.hovered,
      if (fullEmphasis) WidgetState.focused,
    })!;
    return Semantics(
      selected: checked,
      enabled: option.enabled,
      button: true,
      container: true,
      label: option.semanticLabel,
      onTap: onPressed,
      child: Opacity(
        opacity: option.enabled ? 1 : metrics.disabledRowOpacity,
        // Rows aren't focus stops: the list holds focus and the active item
        // says which row Enter picks. So the detector, not CoilInteraction.
        child: CoilInteractionDetector(
          states: _states,
          enabled: onPressed != null,
          onTap: onPressed,
          cursor: onPressed != null
              ? SystemMouseCursors.click
              : MouseCursor.defer,
          excludeFromSemantics: true,
          child: ListenableBuilder(
            listenable: _states,
            builder: (context, child) {
              final states = _states.value;
              return MotionBuilder<Color>(
                // A finger pressing a row gets a fill that ends with the press;
                // hovering pointers already show the highlight.
                value:
                    states.contains(WidgetState.pressed) &&
                        !states.contains(WidgetState.hovered)
                    ? style.selectedFill!
                    : style.selectedFill!.withValues(alpha: 0),
                converter: MotionConverter.colorRgb,
                motion: states.contains(WidgetState.pressed)
                    ? motion.fade
                    : motion.fadeExit,
                debugLabel: 'CoilSelect row press',
                builder: (context, fill, child) => DecoratedBox(
                  decoration: ShapeDecoration(
                    color: fill,
                    shape: RoundedSuperellipseBorder(
                      borderRadius: BorderRadius.circular(style.radius!),
                    ),
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
              debugLabel: 'CoilSelect row text',
              builder: (context, color, _) => ConstrainedBox(
                // A minimum height and symmetric padding: rows grow with text.
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
                      style: style.textStyle!.copyWith(color: color),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      child: Row(
                        children: [
                          if (option.icon case final icon?) ...[
                            ExcludeSemantics(child: icon),
                            SizedBox(width: metrics.gap),
                          ],
                          // The row reads its label, unless a semantic
                          // label replaces it.
                          Expanded(
                            child: ExcludeSemantics(
                              excluding: option.semanticLabel != null,
                              child: option.label,
                            ),
                          ),
                          SizedBox(width: metrics.gap),
                          IconTheme.merge(
                            data: IconThemeData(color: colors.foreground),
                            child: ExcludeSemantics(
                              child: _Check(checked: checked, glyph: checkmark),
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

/// The row's check: a fixed, [IconTheme]-sized slot, so a check appearing
/// never changes the row's width. The default glyph draws in on `fade` and
/// erases on `fadeExit`; a custom [glyph] fades instead.
class _Check extends StatelessWidget {
  const _Check({required this.checked, this.glyph});

  final bool checked;
  final Widget? glyph;

  @override
  Widget build(BuildContext context) {
    final motion = CoilTheme.motionOf(context);
    return SizedBox.square(
      dimension: CoilIconSize.of(context),
      child: SingleMotionBuilder(
        value: checked ? 1 : 0,
        debugLabel: 'CoilSelect check',
        motion: checked ? motion.fade : motion.fadeExit,
        child: glyph,
        builder: (context, progress, glyph) {
          final t = progress.clamp(0.0, 1.0);
          if (glyph != null) return Opacity(opacity: t, child: glyph);
          return IconTheme.merge(
            data: const IconThemeData(weight: CoilIconWeight.emphasis),
            child: CoilDrawnGlyph(CoilGlyph.check, progress: t),
          );
        },
      ),
    );
  }
}
