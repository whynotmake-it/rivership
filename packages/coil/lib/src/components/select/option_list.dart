import 'dart:math' as math;

import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/select/select_style.dart';
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
  });

  /// The choices.
  final List<CoilOption<T>> options;

  /// The values picked when the list opened.
  final Set<T> picked;

  /// Called with each picked (or toggled) value.
  final ValueChanged<T> onPick;

  /// Escape or Tab.
  final VoidCallback onDismiss;

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

  @override
  State<CoilOptionList<T>> createState() => _CoilOptionListState<T>();
}

class _CoilOptionListState<T> extends State<CoilOptionList<T>>
    with TickerProviderStateMixin {
  final _active = CoilActiveItemController();
  late final _selectedFill = CoilHighlightPainter(
    vsync: this,
    debugLabel: 'CoilSelect.selected',
  );
  late final _blocks = CoilSelectionPainter(vsync: this);
  late final _ring = CoilHighlightPainter(
    vsync: this,
    debugLabel: 'CoilSelect.ring',
  );
  late final _rowKeys = [
    for (var i = 0; i < widget.options.length; i++)
      GlobalKey(debugLabel: 'CoilSelect row $i'),
  ];

  /// The rows showing as picked.
  final Set<int> _checked = {};
  bool _done = false;

  @override
  void initState() {
    super.initState();
    for (final (i, option) in widget.options.indexed) {
      if (widget.picked.contains(option.value)) _checked.add(i);
    }
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
    _active
      ..removeListener(_onActive)
      ..dispose();
    _selectedFill.dispose();
    _blocks.dispose();
    _ring.dispose();
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

    if (widget.multiple) {
      _blocks.update(
        selected: _checked,
        color: style.selectedFill!,
        radius: style.radius!,
        motion: motion,
      );
    }
    _selectedFill.update(
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

    return CoilTypeahead(
      labels: [for (final o in widget.options) o.label],
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
          const SingleActivator(LogicalKeyboardKey.escape): widget.onDismiss,
          const SingleActivator(LogicalKeyboardKey.tab): widget.onDismiss,
        },
        child: Focus(
          autofocus: true,
          debugLabel: 'CoilSelect list',
          child: Semantics(
            role: SemanticsRole.menu,
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
                        theme.shape.focusRing,
                      ),
                      side: BorderSide(
                        color: colors.focusRing,
                        width: theme.focusRingWidth,
                      ),
                    ),
                  ),
                );
                return child!;
              },
              child: CoilHoverRegion(
                activeItem: _active,
                followFocus: false,
                highlightColor: style.highlight,
                highlightRadius: style.radius,
                background: [
                  if (widget.multiple) _blocks else _selectedFill,
                ],
                foreground: [_ring],
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(metrics.popupInset),
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
      label: option.label,
      excludeSemantics: true,
      onTap: onPressed,
      child: Opacity(
        opacity: option.enabled ? 1 : (fullEmphasis ? 0.4 : 0.5),
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
                            icon,
                            SizedBox(width: metrics.gap),
                          ],
                          Expanded(child: option.child ?? Text(option.label)),
                          SizedBox(width: metrics.gap),
                          IconTheme.merge(
                            data: IconThemeData(color: colors.foreground),
                            child: _Check(checked: checked, glyph: checkmark),
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
    final icons = IconTheme.of(context);
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
          return CustomPaint(
            painter: _CheckPainter(t, icons.color ?? const Color(0xFF000000)),
          );
        },
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter(this.progress, this.color);

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final s = size.width / 24;
    final path = Path()
      ..moveTo(4 * s, 12 * s)
      ..lineTo(9 * s, 17 * s)
      ..lineTo(20 * s, 6 * s);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * s
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      old.progress != progress || old.color != color;
}
