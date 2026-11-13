import 'dart:async';
import 'dart:math' as math;

import 'package:fluid_mobile_spike/src/adaptive.dart';
import 'package:fluid_mobile_spike/src/tokens.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// One choice in a select.
@immutable
class FluidOption<T> {
  /// Creates a choice.
  const FluidOption({
    required this.value,
    required this.label,
    this.icon,
    this.child,
    this.enabled = true,
  });

  /// What picking this choice reports.
  final T value;

  /// The text of the choice: shown in the row and the trigger unless [child]
  /// is set, matched by typeahead, and read by screen readers.
  final String label;

  /// A leading glyph. Sized and colored by the row through [IconTheme].
  final Widget? icon;

  /// Replaces the [label] text in the row.
  final Widget? child;

  /// Whether the choice can be picked. Disabled rows are skipped by the
  /// highlight, the arrow keys and typeahead.
  final bool enabled;
}

/// The list inside both presentations of a select: rows, the three fills
/// (selected, hover, focus ring), keyboard navigation and typeahead.
class FluidOptionList<T> extends StatefulWidget {
  /// Creates the list.
  const FluidOptionList({
    required this.options,
    required this.selected,
    required this.onPick,
    required this.onDismiss,
    required this.metrics,
    this.multiple = false,
    this.keyboardOpened = false,
    this.selectedFill = true,
    this.checkmark,
    super.key,
  });

  /// The choices.
  final List<FluidOption<T>> options;

  /// The values currently picked: at most one unless [multiple].
  final Set<T> selected;

  /// Called with the picked value. A single-choice list then ignores input
  /// (it is about to close); a [multiple] list reports each toggle and stays
  /// interactive.
  final ValueChanged<T> onPick;

  /// Whether rows toggle independently (a multi-select) instead of picking
  /// one value and closing.
  final bool multiple;

  /// Replaces the check glyph in every row. Sized and colored through
  /// [IconTheme]; it fades in and out instead of drawing.
  final Widget? checkmark;

  /// Escape or Tab.
  final VoidCallback onDismiss;

  /// The size step.
  final FluidMetrics metrics;

  /// Whether the list was opened from the keyboard. If so it starts on the
  /// selected row (or the first) with the focus ring showing.
  final bool keyboardOpened;

  /// Whether the picked row also gets the `--active` fill. The popover
  /// shows it (the web does); the sheet marks the picked row with the check
  /// alone, like native touch lists, so nothing in it looks pressed or
  /// hovered at rest.
  final bool selectedFill;

  @override
  State<FluidOptionList<T>> createState() => _FluidOptionListState<T>();
}

class _FluidOptionListState<T> extends State<FluidOptionList<T>> {
  final _scroll = ScrollController();
  final _focus = FocusNode(debugLabel: 'FluidOptionList');

  /// The highlighted row: under the pointer or reached with the keys.
  int? _active;

  /// Whether [_active] was reached with the keys (draws the focus ring).
  bool _ring = false;

  /// The row under a finger that is pressing it. Only touch sets this, and
  /// release, cancel and scrolling clear it: touch has no hover, so nothing
  /// may stay lit where a finger was.
  int? _pressed;

  /// The rows showing as picked.
  final Set<int> _checked = {};

  bool _picked = false;

  String _typeahead = '';
  Timer? _typeaheadReset;

  @override
  void initState() {
    super.initState();
    for (final (i, option) in widget.options.indexed) {
      if (widget.selected.contains(option.value)) _checked.add(i);
    }
    final first = _checked.isEmpty ? null : _checked.reduce(math.min);
    if (widget.keyboardOpened) {
      _active = first ?? _step(-1, 1);
      _ring = _active != null;
    }
    // Bring the active (or picked) row into view once the list is laid out.
    if (_active != null || first != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
    }
  }

  @override
  void dispose() {
    _typeaheadReset?.cancel();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  // Rows size to their content (min height plus padding), so they grow
  // with the text scale. A key per row lets [_reveal] scroll one into view.
  late final _rowKeys = [
    for (var i = 0; i < widget.options.length; i++)
      GlobalKey(debugLabel: 'FluidOptionList row $i'),
  ];

  /// The next enabled row from [from] in [direction], or null.
  int? _step(int from, int direction) {
    for (
      var i = from + direction;
      i >= 0 && i < widget.options.length;
      i += direction
    ) {
      if (widget.options[i].enabled) return i;
    }
    return null;
  }

  void _activateFromKeyboard(int? index) {
    if (index == null) return;
    setState(() {
      _active = index;
      _ring = true;
    });
    _reveal();
  }

  /// Scrolls the active (or checked) row into view.
  void _reveal() {
    final i = _active ?? (_checked.isEmpty ? null : _checked.reduce(math.min));
    final row = i == null ? null : _rowKeys[i].currentContext;
    if (row == null || !mounted) return;
    Scrollable.ensureVisible(
      row,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
    );
    Scrollable.ensureVisible(
      row,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
    );
  }

  /// Picks [index]. [lightRow] keeps the highlight on it through the
  /// acknowledgment: true for the keyboard and hovering pointers, false for
  /// touch, which must leave nothing lit behind.
  void _pick(int index, {required bool lightRow}) {
    if (_picked || !widget.options[index].enabled) return;
    setState(() {
      if (widget.multiple) {
        _checked.contains(index) ? _checked.remove(index) : _checked.add(index);
      } else {
        _picked = true;
        _checked
          ..clear()
          ..add(index);
      }
      _pressed = null;
      if (lightRow) {
        _active = index;
      } else {
        _active = null;
        _ring = false;
      }
    });
    widget.onPick(widget.options[index].value);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    if (_picked) return KeyEventResult.handled;
    final key = event.logicalKey;
    final last = widget.options.length;
    switch (key) {
      case LogicalKeyboardKey.arrowDown:
        _activateFromKeyboard(_step(_active ?? -1, 1) ?? _active);
      case LogicalKeyboardKey.arrowUp:
        _activateFromKeyboard(
          _active == null ? _step(last, -1) : (_step(_active!, -1) ?? _active),
        );
      case LogicalKeyboardKey.home || LogicalKeyboardKey.pageUp:
        _activateFromKeyboard(_step(-1, 1));
      case LogicalKeyboardKey.end || LogicalKeyboardKey.pageDown:
        _activateFromKeyboard(_step(last, -1));
      case LogicalKeyboardKey.enter || LogicalKeyboardKey.numpadEnter:
        if (event is KeyRepeatEvent) return KeyEventResult.handled;
        if (_active case final i?) _pick(i, lightRow: true);
      // Space picks, unless it is part of a typeahead query ("New York").
      case LogicalKeyboardKey.space when _typeahead.isEmpty:
        if (event is KeyRepeatEvent) return KeyEventResult.handled;
        if (_active case final i?) _pick(i, lightRow: true);
      case LogicalKeyboardKey.escape || LogicalKeyboardKey.tab:
        if (event is KeyDownEvent) widget.onDismiss();
      default:
        final character = event.character;
        if (character == null ||
            character.isEmpty ||
            character.trim().isEmpty && _typeahead.isEmpty) {
          return KeyEventResult.ignored;
        }
        _onType(character);
    }
    return KeyEventResult.handled;
  }

  /// Typeahead: letters typed within a second build one query. A query of
  /// one repeated letter cycles through the rows starting with it.
  void _onType(String character) {
    _typeaheadReset?.cancel();
    _typeaheadReset = Timer(const Duration(seconds: 1), () => _typeahead = '');
    _typeahead += character.toLowerCase();
    final repeated = _typeahead.split('').every((c) => c == _typeahead[0]);
    final query = repeated ? _typeahead[0] : _typeahead;
    final count = widget.options.length;
    final start = _active ?? -1;
    // A fresh multi-letter query may still match the current row.
    final offset = repeated ? 1 : 0;
    for (var n = 0; n < count; n++) {
      final i = (start + offset + n + count) % count;
      final option = widget.options[i];
      if (option.enabled && option.label.toLowerCase().startsWith(query)) {
        _activateFromKeyboard(i);
        return;
      }
    }
  }

  void _release() {
    if (_pressed != null) setState(() => _pressed = null);
  }

  void _hover(int? row) {
    if (_picked) return;
    final index = row != null && widget.options[row].enabled ? row : null;
    if (index == _active && !_ring) return;
    setState(() {
      _active = index;
      _ring = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final metrics = widget.metrics;
    // Touch rows rest at full strength: the muted → foreground fade says
    // "the pointer is here", which a finger can't say.
    final touch =
        FluidAdaptiveScope.inputModeOf(context) == FluidInputMode.touch;
    final highlighted = _pressed ?? _active;

    final rows = <Widget>[
      for (final (i, option) in widget.options.indexed)
        MouseRegion(
          key: _rowKeys[i],
          cursor: option.enabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          onEnter: (event) {
            if (fluidCanHover(event.kind)) _hover(i);
          },
          onHover: (event) {
            if (fluidCanHover(event.kind) && (_active != i || _ring)) {
              _hover(i);
            }
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) {
              // Hovering pointers already show where they are.
              if (_picked || !option.enabled) return;
              if (fluidCanHover(details.kind)) return;
              setState(() => _pressed = i);
            },
            onTapCancel: _release,
            onTapUp: (details) =>
                _pick(i, lightRow: fluidCanHover(details.kind)),
            child: Semantics(
              selected: _checked.contains(i),
              enabled: option.enabled,
              button: true,
              label: option.label,
              excludeSemantics: true,
              // TODO(fluid-highlight-layer): the core spike's highlight layer
              // (a render object that reads row geometry during layout,
              // research 03 §4.4 B) replaces these per-row fills. It brings
              // back the fluid glide between rows and, for multi-select, the
              // merge/split selection (adjacent picked rows as one rounded
              // shape). Until then each row paints its own fills: they fade
              // in place, with no travel.
              child: FluidRowHighlight(
                metrics: metrics,
                selected:
                    widget.selectedFill &&
                    !widget.multiple &&
                    _checked.contains(i),
                hovered: _active == i,
                pressed: _pressed == i,
                focused: _ring && _active == i,
                child: FluidOptionRow(
                  key: ValueKey(i),
                  label: option.child ?? Text(option.label),
                  icon: option.icon,
                  metrics: metrics,
                  highlighted: highlighted == i || _checked.contains(i),
                  checked: _checked.contains(i),
                  fullEmphasis: touch,
                  checkmark: widget.checkmark,
                  enabled: option.enabled,
                ),
              ),
            ),
          ),
        ),
    ];

    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: MouseRegion(
        onExit: (_) {
          if (!_ring) _hover(null);
        },
        child: NotificationListener<ScrollStartNotification>(
          // A press that turns into a scroll is not a press.
          onNotification: (_) {
            _release();
            return false;
          },
          child: SingleChildScrollView(
            controller: _scroll,
            padding: EdgeInsets.all(metrics.popupInset),
            child: Column(mainAxisSize: MainAxisSize.min, children: rows),
          ),
        ),
      ),
    );
  }
}

/// The fills behind one row and its focus ring, each fading in place:
/// selected (`--active`, on the indicator spring), hover (`--hover`), press
/// (`--active`, touch only) and the keyboard focus ring.
///
/// Every fill springs in and tweens out on the theme's tokens. None of them
/// travels between rows; see the `fluid-highlight-layer` TODO in
/// [FluidOptionList].
class FluidRowHighlight extends StatelessWidget {
  /// Creates the fills for one row.
  const FluidRowHighlight({
    required this.metrics,
    required this.child,
    this.selected = false,
    this.hovered = false,
    this.pressed = false,
    this.focused = false,
    super.key,
  });

  /// The size step (radii, ring outset).
  final FluidMetrics metrics;

  /// Shows the selected fill.
  final bool selected;

  /// Shows the hover fill (a hovering pointer or the keyboard is here).
  final bool hovered;

  /// Shows the press fill (a finger is down here).
  final bool pressed;

  /// Shows the keyboard focus ring.
  final bool focused;

  /// The row.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = FluidTheme.of(context);
    final motion = FluidTheme.motionOf(context);
    final radius = BorderRadius.circular(metrics.itemRadius);
    final outset = metrics.focusRingOutset;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: _Fade(
            visible: selected,
            enter: motion.indicator,
            exit: motion.indicatorExit,
            debugLabel: 'Row selected fill',
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.active,
                borderRadius: radius,
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: _Fade(
            visible: hovered,
            enter: motion.highlight,
            exit: motion.fastExit,
            debugLabel: 'Row hover fill',
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.hover,
                borderRadius: radius,
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: _Fade(
            visible: pressed,
            enter: motion.highlight,
            exit: motion.fastExit,
            debugLabel: 'Row press fill',
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.active,
                borderRadius: radius,
              ),
            ),
          ),
        ),
        child,
        Positioned(
          left: -outset,
          right: -outset,
          top: -outset,
          bottom: -outset,
          child: _Fade(
            visible: focused,
            enter: motion.highlight,
            exit: motion.fastExit,
            debugLabel: 'Row focus ring',
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: colors.focusRing),
                borderRadius: BorderRadius.circular(
                  metrics.itemRadius + outset,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One fill's opacity: springs to 1 when [visible], tweens to 0 when not.
/// A fill already visible at mount shows at once.
class _Fade extends StatelessWidget {
  const _Fade({
    required this.visible,
    required this.enter,
    required this.exit,
    required this.debugLabel,
    required this.child,
  });

  final bool visible;
  final Motion enter;
  final Motion exit;
  final String debugLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SingleMotionBuilder(
        value: visible ? 1 : 0,
        motion: visible ? enter : exit,
        debugLabel: debugLabel,
        child: child,
        builder: (context, opacity, child) =>
            Opacity(opacity: opacity.clamp(0.0, 1.0), child: child),
      ),
    );
  }
}

/// One row of a select or menu: leading glyph, label, trailing check slot.
///
/// The row draws no background; the list's fills slide underneath it.
/// Glyphs (the [icon] slot, the check) are styled by the row's [IconTheme]:
/// [FluidMetrics.icon] in size, in the row's text color.
class FluidOptionRow extends StatelessWidget {
  /// Creates a row.
  const FluidOptionRow({
    required this.label,
    required this.metrics,
    this.icon,
    this.highlighted = false,
    this.checked = false,
    this.enabled = true,
    this.fullEmphasis = false,
    this.checkmark,
    super.key,
  });

  /// The label.
  final Widget label;

  /// A leading glyph: any widget, styled through [IconTheme].
  final Widget? icon;

  /// The size step.
  final FluidMetrics metrics;

  /// Hovered, focused or checked: full-strength text.
  final bool highlighted;

  /// Shows the check.
  final bool checked;

  /// Disabled rows draw at half opacity (40% on touch).
  final bool enabled;

  /// Rests at full strength whatever [highlighted] says: touch rows. The
  /// muted → foreground fade is a pointer affordance.
  final bool fullEmphasis;

  /// Replaces the check glyph.
  final Widget? checkmark;

  @override
  Widget build(BuildContext context) {
    final colors = FluidTheme.of(context);
    final color = highlighted || fullEmphasis
        ? colors.foreground
        : colors.mutedForeground;
    final disabledOpacity = fullEmphasis ? 0.4 : 0.5;
    return Opacity(
      opacity: enabled ? 1 : disabledOpacity,
      child: MotionBuilder<Color>(
        value: color,
        converter: MotionConverter.colorRgb,
        motion: FluidTheme.motionOf(context).color,
        debugLabel: 'Row text color',
        // A minimum height and symmetric padding, never a fixed height: at
        // the default text scale, 12 + 20 + 12 = 44 (8 + 20 + 8 = 36 on
        // pointer), and the row grows with larger text.
        builder: (context, color, _) => ConstrainedBox(
          constraints: BoxConstraints(minHeight: metrics.rowHeight),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: metrics.itemPaddingX,
              vertical: (metrics.rowHeight - metrics.body.leading) / 2,
            ),
            child: IconTheme(
              data: IconThemeData(size: metrics.icon, color: color),
              child: DefaultTextStyle(
                style: metrics.body.style(color: color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                child: Row(
                  children: [
                    if (icon case final icon?) ...[
                      icon,
                      SizedBox(width: metrics.gap),
                    ],
                    Expanded(child: label),
                    SizedBox(width: metrics.gap),
                    IconTheme.merge(
                      data: IconThemeData(color: colors.foreground),
                      child: FluidCheck(checked: checked, glyph: checkmark),
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

/// The select's check: a fixed slot, [IconTheme]-sized, so a check
/// appearing never changes the row's width.
///
/// The default glyph is a stroke that draws in (`strokeIn`) and erases
/// (`strokeOut`). A custom [glyph] fades in and out on the same tokens
/// instead. A check present at mount shows finished.
class FluidCheck extends StatelessWidget {
  /// Creates a check.
  const FluidCheck({required this.checked, this.glyph, super.key});

  /// Whether it shows.
  final bool checked;

  /// Replaces the drawn check. Styled through [IconTheme].
  final Widget? glyph;

  @override
  Widget build(BuildContext context) {
    final icons = IconTheme.of(context);
    final size = icons.size ?? 16;
    final motion = FluidTheme.motionOf(context);
    return SizedBox.square(
      dimension: size,
      child: SingleMotionBuilder(
        value: checked ? 1 : 0,
        debugLabel: 'Check',
        motion: checked ? motion.strokeIn : motion.strokeOut,
        child: glyph,
        builder: (context, progress, glyph) {
          final t = progress.clamp(0.0, 1.0);
          if (glyph != null) return Opacity(opacity: t, child: glyph);
          return CustomPaint(
            painter: _CheckPainter(
              t,
              icons.color ?? const Color(0xFF000000),
            ),
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
    final scale = size.width / 24;
    // d="M4 12L9 17L20 6", stroke 2 in a 24 box.
    final path = Path()
      ..moveTo(4 * scale, 12 * scale)
      ..lineTo(9 * scale, 17 * scale)
      ..lineTo(20 * scale, 6 * scale);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * scale
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      old.progress != progress || old.color != color;
}
