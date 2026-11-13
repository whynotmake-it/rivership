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

  /// Steps with each press, so a release fades its own fill out and the
  /// next press starts a fresh one in place (presses never glide).
  int _pressSession = 0;

  /// The rows showing as picked.
  final Set<int> _checked = {};

  /// Steps each time the pointer enters the list, so the hover fill fades
  /// in where it lands instead of sliding over from its last row.
  int _session = 0;

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
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
    } else if (first != null) {
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

  double get _rowHeight => widget.metrics.rowHeight;

  Rect? _rowRect(int? i) =>
      i == null ? null : Rect.fromLTWH(0, i * _rowHeight, 0, _rowHeight);

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
      if (_active == null) _session++;
      _active = index;
      _ring = true;
    });
    _reveal();
  }

  /// Scrolls the active (or checked) row into view.
  void _reveal() {
    final i = _active ?? (_checked.isEmpty ? null : _checked.reduce(math.min));
    if (i == null || !_scroll.hasClients) return;
    final inset = widget.metrics.popupInset;
    final top = inset + i * _rowHeight;
    final bottom = top + _rowHeight + inset;
    final position = _scroll.position;
    final offset = position.pixels;
    final viewport = position.viewportDimension;
    if (top - inset < offset) {
      _scroll.jumpTo(math.max(0, top - inset));
    } else if (bottom > offset + viewport) {
      _scroll.jumpTo(math.min(position.maxScrollExtent, bottom - viewport));
    }
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
      if (_active == null && index != null) _session++;
      _active = index;
      _ring = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final metrics = widget.metrics;
    final colors = FluidTheme.of(context);
    final motion = FluidTheme.motionOf(context);
    // Touch rows rest at full strength: the muted → foreground fade says
    // "the pointer is here", which a finger can't say.
    final touch =
        FluidAdaptiveScope.inputModeOf(context) == FluidInputMode.touch;
    final highlighted = _pressed ?? _active;

    final rows = <Widget>[
      for (final (i, option) in widget.options.indexed)
        MouseRegion(
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
              setState(() {
                _pressSession++;
                _pressed = i;
              });
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
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Selected fill: no fade in, springs to a newly picked row.
                FluidFill(
                  key: const ValueKey('fill-selected'),
                  // TODO(fluid): multi-select fills. The core spike is building
                  // merge/split selection (adjacent selected rows merge into one
                  // rounded shape); it plugs in here, drawing one fill per run
                  // of checked rows. Until then a multi-select shows checks
                  // only, which is also what the sheet wants at rest.
                  rect: widget.selectedFill && !widget.multiple
                      ? _rowRect(_checked.firstOrNull)
                      : null,
                  color: colors.active,
                  radius: metrics.itemRadius,
                  motion: motion.indicator,
                  exitMotion: motion.indicatorExit,
                  fadeIn: false,
                ),
                // Hover fill (hovering pointers and the keyboard): fades in
                // where the pointer lands, then glides between rows.
                FluidFill(
                  key: ValueKey('fill-hover-$_session'),
                  rect: _rowRect(_active),
                  color: colors.hover,
                  radius: metrics.itemRadius,
                  motion: motion.highlight,
                  exitMotion: motion.fastExit,
                ),
                // Press fill (touch only): under the finger while it is down,
                // gone on release. Never glides: each press is its own.
                FluidFill(
                  key: ValueKey('fill-press-$_pressSession'),
                  rect: _rowRect(_pressed),
                  color: colors.active,
                  radius: metrics.itemRadius,
                  motion: motion.highlight,
                  exitMotion: motion.fastExit,
                ),
                Column(mainAxisSize: MainAxisSize.min, children: rows),
                // Focus ring: only for keyboard navigation.
                FluidFill(
                  key: const ValueKey('fill-focus'),
                  rect: _ring ? _rowRect(_active) : null,
                  ring: colors.focusRing,
                  outset: metrics.focusRingOutset,
                  radius: metrics.itemRadius + metrics.focusRingOutset,
                  motion: motion.highlight,
                  exitMotion: motion.fastExit,
                  fadeIn: false,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A full-width fill (or ring) that springs between row rects and fades
/// when it has none. Only the vertical extent of [rect] is used.
class FluidFill extends StatefulWidget {
  /// Creates a fill.
  const FluidFill({
    required this.rect,
    required this.radius,
    required this.motion,
    required this.exitMotion,
    this.color,
    this.ring,
    this.outset = 0,
    this.fadeIn = true,
    super.key,
  });

  /// Where to sit, or null to fade out.
  final Rect? rect;

  /// The fill color.
  final Color? color;

  /// A 1px ring color instead of a fill.
  final Color? ring;

  /// How far outside [rect] to draw.
  final double outset;

  /// Corner radius.
  final double radius;

  /// The travel and fade-in motion.
  final Motion motion;

  /// The fade-out motion.
  final Motion exitMotion;

  /// Whether a fill that appears fades in (true) or shows at once.
  final bool fadeIn;

  @override
  State<FluidFill> createState() => _FluidFillState();
}

class _FluidFillState extends State<FluidFill> {
  // Tracks are identity: created once, on the first build that has a rect,
  // so they start where the fill first appears (no slide in from nowhere).
  Track<Rect>? _rect;
  Track<double>? _opacity;
  Rect? _last;

  @override
  Widget build(BuildContext context) {
    final target = widget.rect ?? _last;
    if (target == null) return const SizedBox.shrink();
    _last = target;
    final label = switch (widget.key) {
      ValueKey<String>(:final value) => value,
      _ => 'fill',
    };
    final rect = _rect ??= Track<Rect>(
      MotionConverter.rect,
      initial: target,
      debugLabel: '$label rect',
    );
    final opacity = _opacity ??= Track<double>(
      MotionConverter.single,
      initial: widget.fadeIn ? 0 : 1,
      debugLabel: '$label opacity',
    );
    final visible = widget.rect != null;
    final fadeIn = FluidTheme.motionOf(context).fast;
    // The rect is a retargetable spring: a new target mid-flight keeps the
    // fill's velocity and bends toward the new row (motor example
    // `retarget.dart`). Opacity springs in and tweens out.
    return TrackBuilder(
      debugLabel: label,
      animations: [
        rect([
          TrackStep.to(target, motion: widget.motion),
        ]),
        opacity([
          TrackStep.to(
            visible ? 1.0 : 0.0,
            motion: visible ? fadeIn : widget.exitMotion,
          ),
        ]),
      ],
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: widget.color,
            border: widget.ring == null
                ? null
                : Border.all(color: widget.ring!),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        ),
      ),
      builder: (context, value, child) {
        final box = value(rect);
        return Positioned(
          left: -widget.outset,
          right: -widget.outset,
          top: box.top - widget.outset,
          height: box.height + widget.outset * 2,
          child: Opacity(
            opacity: value(opacity).clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
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
        builder: (context, color, _) => SizedBox(
          height: metrics.rowHeight,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: metrics.itemPaddingX),
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
