// MotorInspectionScope is @experimental; the motor example uses it too.
// ignore_for_file: experimental_member_use
import 'dart:async';
import 'dart:math' as math;

import 'package:fluid_mobile_spike/src/adaptive.dart';
import 'package:fluid_mobile_spike/src/option_list.dart';
import 'package:fluid_mobile_spike/src/routes.dart';
import 'package:fluid_mobile_spike/src/tokens.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';

/// Pick one of a few values. One API, two presentations:
///
/// * [FluidPresentation.popover]: a list anchored under the trigger with the
///   fluid hover highlight, arrow keys, Home/End, typeahead, Enter/Space to
///   pick, Escape/Tab or an outside click to dismiss, and focus handed back
///   to the trigger.
/// * [FluidPresentation.sheet]: the same list in a bottom sheet, with 44px
///   rows, dismissed by dragging down or tapping the scrim.
///
/// Which one shows is decided per open by
/// [FluidAdaptiveScope.presentationOf]; pass [presentation] to pin it. On a
/// phone, [fluidPhonePresentation] keeps a short single select (at most
/// [fluidShortMenuMaxItems] options) anchored at touch size and sends longer
/// ones and every multi-select to a sheet.
///
/// No icons are bundled: [icon], [indicator], [checkmark] and
/// [FluidOption.icon] take any widget and are styled through [IconTheme].
class FluidSelect<T> extends StatefulWidget {
  /// Creates a single-choice select.
  const FluidSelect({
    required this.options,
    required this.value,
    required this.onChanged,
    this.placeholder = 'Select…',
    this.icon,
    this.indicator,
    this.checkmark,
    this.sheetTitle,
    this.presentation,
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
    this.motion,
    super.key,
  }) : values = null,
       onValuesChanged = null;

  /// Creates a multi-select: rows toggle and the list stays open.
  const FluidSelect.multiple({
    required this.options,
    // Narrows the nullable field: a multi-select always has a set.
    // ignore: type_init_formals
    required Set<T> this.values,
    required this.onValuesChanged,
    this.placeholder = 'Select…',
    this.icon,
    this.indicator,
    this.checkmark,
    this.sheetTitle,
    this.presentation,
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
    this.motion,
    super.key,
  }) : value = null,
       onChanged = null;

  /// The choices.
  final List<FluidOption<T>> options;

  /// The picked value, or null for none (single-choice).
  final T? value;

  /// Called when the user picks a value (single-choice).
  final ValueChanged<T>? onChanged;

  /// The picked values (multi-select).
  final Set<T>? values;

  /// Called with the new set after each toggle (multi-select).
  final ValueChanged<Set<T>>? onValuesChanged;

  /// Replaces the trigger's chevron. Styled through [IconTheme].
  final Widget? indicator;

  /// Replaces the check in the rows. Styled through [IconTheme].
  final Widget? checkmark;

  bool get _multiple => values != null;

  /// Shown in the trigger when nothing is picked.
  final String placeholder;

  /// A leading glyph in the trigger.
  final Widget? icon;

  /// A heading for the sheet presentation (what is being picked). The
  /// popover has no title: it sits under its labelled trigger.
  final Widget? sheetTitle;

  /// Pins the presentation. Null follows [FluidAdaptiveScope].
  final FluidPresentation? presentation;

  /// Whether the select can be opened.
  final bool enabled;

  /// The trigger's focus node.
  final FocusNode? focusNode;

  /// Whether the trigger takes focus when first built.
  final bool autofocus;

  /// Motion tokens for this select only (trigger, list, popover or sheet).
  /// Null uses the surrounding [FluidTheme]'s. Reduced motion still applies
  /// on top.
  final FluidMotionThemeData? motion;

  @override
  State<FluidSelect<T>> createState() => _FluidSelectState<T>();
}

class _FluidSelectState<T> extends State<FluidSelect<T>> {
  FocusNode? _ownFocusNode;
  FocusNode get _focusNode =>
      widget.focusNode ??
      (_ownFocusNode ??= FocusNode(debugLabel: 'FluidSelect'));

  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;
  bool _open = false;

  @override
  void dispose() {
    _ownFocusNode?.dispose();
    super.dispose();
  }

  bool get _enabled =>
      widget.enabled &&
      (widget.onChanged != null || widget.onValuesChanged != null);

  /// A context below this select's own [FluidTheme] (when [FluidSelect.motion]
  /// overrides it), so motion lookups and the theme capture for the overlay
  /// see the override.
  BuildContext? _inner;

  Future<void> _show({required bool keyboard}) async {
    if (_open || !_enabled) return;
    final context = _inner ?? this.context;
    final navigator = Navigator.of(context);
    final presentation = FluidAdaptiveScope.presentationOf(
      context,
      override: widget.presentation,
      traits: FluidOverlayTraits(
        kind: FluidOverlayKind.select,
        itemCount: widget.options.length,
        multiSelect: widget._multiple,
      ),
    );
    final motion = FluidTheme.motionOf(context);
    // Carries FluidTheme (an InheritedTheme) and any other themes from the
    // trigger into the overlay, whichever navigator it is pushed on.
    final themes = InheritedTheme.capture(
      from: context,
      to: navigator.context,
    );
    var picked = <T>{...?widget.values, ?widget.value};
    final metrics = presentation == FluidPresentation.sheet
        ? FluidMetrics.touch
        : FluidAdaptiveScope.metricsOf(context);

    Timer? ack;
    Route<T>? route;
    void close(Route<T>? route) {
      if (route == null || !route.isActive) return;
      if (route.isCurrent) {
        navigator.pop();
      } else {
        navigator.removeRoute(route);
      }
    }

    // Everything the select animates shows up as one group in
    // motor_devtools.
    Widget list() => MotorInspectionScope(
      group: 'FluidSelect',
      child: FluidOptionList<T>(
        options: widget.options,
        selected: picked,
        multiple: widget._multiple,
        checkmark: widget.checkmark,
        metrics: metrics,
        keyboardOpened: keyboard,
        selectedFill: presentation == FluidPresentation.popover,
        onPick: (value) {
          if (widget._multiple) {
            picked = picked.contains(value)
                ? ({...picked}..remove(value))
                : {...picked, value};
            widget.onValuesChanged?.call(picked);
            return;
          }
          widget.onChanged?.call(value);
          // Hold the list open long enough to see the check draw and the
          // selected fill land on the picked row.
          ack = Timer(motion.selectionAck, () => close(route));
        },
        onDismiss: () => close(route),
      ),
    );

    switch (presentation) {
      case FluidPresentation.popover:
        final box = context.findRenderObject()! as RenderBox;
        final overlay = navigator.context.findRenderObject()! as RenderBox;
        final anchor =
            box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
        route = FluidPopoverRoute<T>(
          // The web caps popups at 300px: 8 rows of 36 plus the inset. The
          // same eight rows at touch size need more, so the cap follows the
          // row height instead of clipping a row in half.
          maxHeight: math.max(
            300,
            fluidShortMenuMaxItems * metrics.rowHeight + metrics.popupInset * 2,
          ),
          anchor: anchor,
          minWidth: box.size.width,
          contentHeight:
              widget.options.length * metrics.rowHeight +
              metrics.popupInset * 2,
          capturedThemes: themes,
          exitDuration: motion.popoverExit.duration ?? Duration.zero,
          builder: (context) => _PopoverShell(metrics: metrics, child: list()),
        );
      case FluidPresentation.sheet:
        route = FluidSheetRoute<T>(
          motion: motion.sheet,
          exitMotion: motion.sheetExit,
          capturedThemes: themes,
          child: FluidSheetPanel(title: widget.sheetTitle, child: list()),
        );
    }

    setState(() => _open = true);
    await navigator.push(route);
    ack?.cancel();
    if (!mounted) return;
    setState(() => _open = false);
    // Focus goes back to the trigger however the list closed.
    _focusNode.requestFocus();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowUp) {
      unawaited(_show(keyboard: true));
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final colors = FluidTheme.of(context);
    final picked = widget.options
        .where(
          (o) => widget._multiple
              ? widget.values!.contains(o.value)
              : o.value == widget.value,
        )
        .toList();

    final label = switch (picked) {
      [] => Text(
        widget.placeholder,
        style: TextStyle(color: colors.mutedForeground),
      ),
      [final only] when !widget._multiple => only.child ?? Text(only.label),
      _ => Text(picked.map((o) => o.label).join(', ')),
    };

    final override = widget.motion;
    Widget scoped(Widget child) => override == null
        ? child
        : FluidTheme(colors: colors, motion: override, child: child);

    return scoped(
      Builder(
        builder: (inner) {
          _inner = inner;
          return _buildTrigger(inner, label, picked);
        },
      ),
    );
  }

  Widget _buildTrigger(
    BuildContext context,
    Widget label,
    List<FluidOption<T>> picked,
  ) {
    final metrics = FluidAdaptiveScope.metricsOf(context);
    return MotorInspectionScope(
      group: 'FluidSelect',
      child: Semantics(
        button: true,
        enabled: _enabled,
        expanded: _open,
        value: picked.isEmpty ? null : picked.map((o) => o.label).join(', '),
        hint: picked.isEmpty ? widget.placeholder : null,
        child: Focus(
          focusNode: _focusNode,
          autofocus: widget.autofocus,
          canRequestFocus: _enabled,
          onKeyEvent: _onKey,
          onFocusChange: (focused) => setState(() => _focused = focused),
          child: MouseRegion(
            cursor: _enabled
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            onEnter: (event) {
              if (fluidCanHover(event.kind)) setState(() => _hovered = true);
            },
            onExit: (_) => setState(() => _hovered = false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              // Touch gets press feedback that ends with the press, never a
              // hover state that outlives it.
              onTapDown: (details) {
                if (_enabled && !fluidCanHover(details.kind)) {
                  setState(() => _pressed = true);
                }
              },
              onTapCancel: () => setState(() => _pressed = false),
              onTapUp: (_) => setState(() => _pressed = false),
              onTap: () => _show(keyboard: false),
              child: ValueListenableBuilder(
                valueListenable: FluidKeyboardModality.instance,
                builder: (context, keyboard, _) => FluidTriggerBox(
                  metrics: metrics,
                  hovered: _hovered && !_open,
                  pressed: _pressed,
                  focusRing: _focused && keyboard && !_open,
                  enabled: _enabled,
                  icon: widget.icon,
                  indicator: widget.indicator,
                  label: label,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The bordered trigger: leading glyph, label, chevron. Public so the
/// size-comparison golden can render it at rest in any state.
class FluidTriggerBox extends StatelessWidget {
  /// Creates a trigger box.
  const FluidTriggerBox({
    required this.metrics,
    required this.label,
    this.icon,
    this.indicator,
    this.hovered = false,
    this.pressed = false,
    this.focusRing = false,
    this.enabled = true,
    super.key,
  });

  /// The size step.
  final FluidMetrics metrics;

  /// The label.
  final Widget label;

  /// A leading glyph: any widget, styled through [IconTheme].
  final Widget? icon;

  /// Replaces the chevron: any widget, styled through [IconTheme].
  final Widget? indicator;

  /// Draws the hover fill.
  final bool hovered;

  /// Draws the press fill (touch, while the finger is down).
  final bool pressed;

  /// Draws the keyboard focus ring.
  final bool focusRing;

  /// Disabled triggers draw at half opacity.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = FluidTheme.of(context);
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: MotionBuilder<Color>(
        value: pressed
            ? colors.active
            : (hovered ? colors.hover : colors.hover.withValues(alpha: 0)),
        converter: MotionConverter.colorRgb,
        motion: FluidTheme.motionOf(context).color,
        debugLabel: 'Trigger fill',
        builder: (context, fill, child) => Container(
          constraints: BoxConstraints(
            minWidth: metrics.triggerMinWidth,
            minHeight: metrics.controlHeight,
            maxHeight: metrics.controlHeight,
          ),
          padding: EdgeInsets.symmetric(horizontal: metrics.controlPaddingX),
          decoration: BoxDecoration(
            color: fill,
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(metrics.controlRadius),
            boxShadow: [
              if (focusRing)
                BoxShadow(color: colors.focusRing, spreadRadius: 1),
            ],
          ),
          child: child,
        ),
        child: IconTheme(
          data: IconThemeData(
            size: metrics.icon,
            color: hovered ? colors.foreground : colors.mutedForeground,
          ),
          child: DefaultTextStyle(
            style: metrics.body.style(color: colors.foreground),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            // Fills the trigger's width when it has one (chevron at the
            // end), hugs the label when it doesn't.
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bounded = constraints.hasBoundedWidth;
                return Row(
                  mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
                  children: [
                    if (icon case final icon?) ...[
                      icon,
                      SizedBox(width: metrics.gap),
                    ],
                    if (bounded) Expanded(child: label) else label,
                    SizedBox(width: metrics.gap),
                    indicator ?? const _Chevron(),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _PopoverShell extends StatelessWidget {
  const _PopoverShell({required this.metrics, required this.child});

  final FluidMetrics metrics;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = FluidTheme.of(context);
    final radius = BorderRadius.circular(metrics.containerRadius);
    // <Elevated offset={2} shadowLevel={3}> on the page: surface-3, shadow-3.
    return IntrinsicWidth(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface(3),
          borderRadius: radius,
          boxShadow: colors.shadow(3),
        ),
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: colors.insetRing(3),
          ),
          child: ClipRRect(borderRadius: radius, child: child),
        ),
      ),
    );
  }
}

/// The default trigger glyph, drawn in the [IconTheme]'s size and color.
class _Chevron extends StatelessWidget {
  const _Chevron();

  @override
  Widget build(BuildContext context) {
    final icons = IconTheme.of(context);
    return CustomPaint(
      size: Size.square(icons.size ?? 16),
      painter: _ChevronPainter(icons.color ?? const Color(0xFF000000)),
    );
  }
}

class _ChevronPainter extends CustomPainter {
  _ChevronPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    canvas.drawPath(
      Path()
        ..moveTo(6 * s, 9 * s)
        ..lineTo(12 * s, 15 * s)
        ..lineTo(18 * s, 9 * s),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * s
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_ChevronPainter old) => old.color != color;
}
