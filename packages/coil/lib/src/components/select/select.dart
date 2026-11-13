// MotorInspectionScope is @experimental; the motor example uses it too.
// ignore_for_file: experimental_member_use
import 'dart:async';

import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/select/option_list.dart';
import 'package:coil/src/components/select/select_style.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/inspection.dart';
import 'package:motor/motor.dart';
import 'package:motor_widgets/motor_widgets.dart';

/// Pick one value from a list. One API, two presentations, chosen when the
/// list opens by [CoilAdaptivePopup.presentationOf]:
///
/// * a popover anchored under the trigger, with the fluid highlight, arrow
///   keys, Home/End, typeahead, Enter/Space to pick, Escape/Tab or an outside
///   click to dismiss, and focus handed back to the trigger;
/// * a sheet with touch-sized rows, dismissed by dragging down or tapping the
///   scrim.
///
/// On a phone the hybrid rule keeps a short list (at most
/// [CoilAdaptivePopup.shortMenuMaxItems] options) anchored and sends longer
/// ones to a sheet. Pass [presentation] to pin it.
///
/// No icons are bundled: [icon], [indicator], [checkmark] and
/// [CoilOption.icon] take any widget and are styled through [IconTheme].
class CoilSelect<T> extends StatelessWidget {
  /// Creates a single-choice select.
  const CoilSelect({
    required this.options,
    required this.value,
    required this.onChanged,
    super.key,
    this.placeholder = 'Select…',
    this.icon,
    this.indicator,
    this.checkmark,
    this.sheetTitle,
    this.presentation,
    this.size,
    this.focusNode,
    this.autofocus = false,
    this.motion,
    this.style,
  });

  /// The choices.
  final List<CoilOption<T>> options;

  /// The picked value, or null for none.
  final T? value;

  /// Called with the picked value. Null disables the select.
  final ValueChanged<T>? onChanged;

  /// Shown in the trigger when nothing is picked.
  final String placeholder;

  /// A leading glyph in the trigger.
  final Widget? icon;

  /// Replaces the trigger's chevron.
  final Widget? indicator;

  /// Replaces the check in the rows.
  final Widget? checkmark;

  /// A heading for the sheet presentation.
  final Widget? sheetTitle;

  /// Pins the presentation. Null decides per open.
  final CoilPresentation? presentation;

  /// Pins the trigger's size step. Null follows [CoilAdaptiveScope].
  final CoilSize? size;

  /// The trigger's focus node.
  final FocusNode? focusNode;

  /// Whether the trigger takes focus when first built.
  final bool autofocus;

  /// Motion tokens for this select (trigger, list, popover or sheet).
  final CoilMotion? motion;

  /// Overrides for this select's look, on top of the theme's
  /// [CoilSelectStyle] and the defaults.
  final CoilSelectStyle? style;

  @override
  Widget build(BuildContext context) => _SelectCore<T>(
    options: options,
    picked: {?value},
    multiple: false,
    onPick: switch (onChanged) {
      final onChanged? => (value, _) => onChanged(value),
      null => null,
    },
    placeholder: placeholder,
    icon: icon,
    indicator: indicator,
    checkmark: checkmark,
    sheetTitle: sheetTitle,
    presentation: presentation,
    size: size,
    focusNode: focusNode,
    autofocus: autofocus,
    motion: motion,
    style: style,
  );
}

/// Pick any number of values from a list. Rows toggle and the list stays
/// open; adjacent picked rows merge into one rounded block.
///
/// On a phone, a multi-select always opens as a sheet (the hybrid rule).
/// Otherwise the same as [CoilSelect].
class CoilMultiSelect<T> extends StatelessWidget {
  /// Creates a multi-select.
  const CoilMultiSelect({
    required this.options,
    required this.values,
    required this.onChanged,
    super.key,
    this.placeholder = 'Select…',
    this.icon,
    this.indicator,
    this.checkmark,
    this.sheetTitle,
    this.presentation,
    this.size,
    this.focusNode,
    this.autofocus = false,
    this.motion,
    this.style,
  });

  /// The choices.
  final List<CoilOption<T>> options;

  /// The picked values.
  final Set<T> values;

  /// Called with the new set after each toggle. Null disables the select.
  final ValueChanged<Set<T>>? onChanged;

  /// Shown in the trigger when nothing is picked.
  final String placeholder;

  /// A leading glyph in the trigger.
  final Widget? icon;

  /// Replaces the trigger's chevron.
  final Widget? indicator;

  /// Replaces the check in the rows.
  final Widget? checkmark;

  /// A heading for the sheet presentation.
  final Widget? sheetTitle;

  /// Pins the presentation. Null decides per open.
  final CoilPresentation? presentation;

  /// Pins the trigger's size step. Null follows [CoilAdaptiveScope].
  final CoilSize? size;

  /// The trigger's focus node.
  final FocusNode? focusNode;

  /// Whether the trigger takes focus when first built.
  final bool autofocus;

  /// Motion tokens for this select.
  final CoilMotion? motion;

  /// Overrides for this select's look, on top of the theme's
  /// [CoilSelectStyle] and the defaults.
  final CoilSelectStyle? style;

  @override
  Widget build(BuildContext context) => _SelectCore<T>(
    options: options,
    picked: values,
    multiple: true,
    onPick: switch (onChanged) {
      final onChanged? => (_, picked) => onChanged(picked),
      null => null,
    },
    placeholder: placeholder,
    icon: icon,
    indicator: indicator,
    checkmark: checkmark,
    sheetTitle: sheetTitle,
    presentation: presentation,
    size: size,
    focusNode: focusNode,
    autofocus: autofocus,
    motion: motion,
    style: style,
  );
}

class _SelectCore<T> extends StatefulWidget {
  const _SelectCore({
    required this.options,
    required this.picked,
    required this.multiple,
    required this.onPick,
    required this.placeholder,
    required this.icon,
    required this.indicator,
    required this.checkmark,
    required this.sheetTitle,
    required this.presentation,
    required this.size,
    required this.focusNode,
    required this.autofocus,
    required this.motion,
    required this.style,
  });

  final List<CoilOption<T>> options;
  final Set<T> picked;
  final bool multiple;

  /// Reports the toggled or picked value and the new set.
  final void Function(T value, Set<T> picked)? onPick;
  final String placeholder;
  final Widget? icon;
  final Widget? indicator;
  final Widget? checkmark;
  final Widget? sheetTitle;
  final CoilPresentation? presentation;
  final CoilSize? size;
  final FocusNode? focusNode;
  final bool autofocus;
  final CoilMotion? motion;
  final CoilSelectStyle? style;

  @override
  State<_SelectCore<T>> createState() => _SelectCoreState<T>();
}

class _SelectCoreState<T> extends State<_SelectCore<T>> {
  FocusNode? _ownFocusNode;
  FocusNode get _focusNode =>
      widget.focusNode ??
      (_ownFocusNode ??= FocusNode(debugLabel: 'CoilSelect'));

  final _states = WidgetStatesController();
  bool _open = false;

  /// A context below the per-instance motion override, so the overlay
  /// captures it.
  BuildContext? _inner;

  bool get _enabled => widget.onPick != null;

  @override
  void dispose() {
    _ownFocusNode?.dispose();
    _states.dispose();
    super.dispose();
  }

  Future<void> _show({required bool keyboard}) async {
    if (_open || !_enabled) return;
    final context = _inner ?? this.context;
    final presentation = CoilAdaptivePopup.presentationOf(
      context,
      override: widget.presentation,
      traits: CoilOverlayTraits(
        kind: CoilOverlayKind.select,
        itemCount: widget.options.length,
        multiSelect: widget.multiple,
      ),
    );
    final sheet = presentation == CoilPresentation.sheet;
    final motion = CoilTheme.motionOf(context);
    var picked = {...widget.picked};
    // The sheet is a touch surface whatever the tier: touch-sized rows.
    final metrics = sheet
        ? CoilMetrics.resolve(CoilTier.touch, CoilSize.regular)
        : CoilTheme.metricsOf(context);
    final pointerTier = CoilTheme.tierOf(context) == CoilTier.pointer;
    final style = _resolveStyle(context, metrics);
    final scaler = MediaQuery.textScalerOf(context);
    final rowExtent =
        metrics.controlHeight -
        metrics.body.lineHeight +
        scaler.scale(metrics.body.lineHeight);

    Timer? acknowledge;
    var closed = false;
    void close() {
      if (closed || !mounted) return;
      closed = true;
      Navigator.of(context).pop();
    }

    setState(() => _open = true);
    await CoilAdaptivePopup.show<void>(
      context,
      presentation: presentation,
      estimatedHeight:
          widget.options.length * rowExtent + metrics.popupInset * 2,
      // Pointer: a 300 px cap. Touch popovers list at most eight rows, so
      // only the room on screen bounds them.
      maxHeight: pointerTier && !sheet ? 300 : double.infinity,
      content: (context) => MotorInspectionScope(
        group: 'CoilSelect',
        child: CoilOptionList<T>(
          options: widget.options,
          picked: picked,
          multiple: widget.multiple,
          checkmark: widget.checkmark,
          metrics: metrics,
          style: style,
          keyboardOpened: keyboard,
          selectedFill: !sheet,
          fullEmphasis: sheet || !pointerTier,
          onPick: (value) {
            if (widget.multiple) {
              picked = picked.contains(value)
                  ? ({...picked}..remove(value))
                  : {...picked, value};
              widget.onPick?.call(value, picked);
              return;
            }
            widget.onPick?.call(value, {value});
            // Hold the list open long enough to see the check draw and the
            // selected fill land on the picked row.
            acknowledge = Timer(motion.acknowledgeDuration, close);
          },
          onDismiss: close,
        ),
      ),
      popover: (context, content) =>
          _PopoverSurface(metrics: metrics, style: style, child: content),
      sheet: (context, content) =>
          CoilSheetPanel(title: widget.sheetTitle, child: content),
    );
    closed = true;
    acknowledge?.cancel();
    if (!mounted) return;
    setState(() => _open = false);
    // Focus goes back to the trigger however the list closed.
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final override = widget.motion;
    Widget scoped(Widget child) => override == null
        ? child
        : CoilTheme.override(
            transform: (t) => t.copyWith(motion: override),
            child: child,
          );
    return scoped(
      Builder(
        builder: (inner) {
          _inner = inner;
          return _buildTrigger(inner);
        },
      ),
    );
  }

  CoilSelectStyle _resolveStyle(BuildContext context, CoilMetrics metrics) =>
      CoilSelectStyle.fallback(
        CoilTheme.of(context),
        metrics,
      ).merge(CoilTheme.styleOf<CoilSelectStyle>(context)).merge(widget.style);

  Widget _buildTrigger(BuildContext context) {
    final metrics = CoilTheme.metricsOf(context, size: widget.size);
    final style = _resolveStyle(context, metrics);
    final picked = [
      for (final option in widget.options)
        if (widget.picked.contains(option.value)) option,
    ];
    final label = switch (picked) {
      [] => Text(
        widget.placeholder,
        style: TextStyle(color: style.placeholder),
      ),
      [final only] when !widget.multiple => only.child ?? Text(only.label),
      _ => Text(picked.map((o) => o.label).join(', ')),
    };
    final value = picked.isEmpty ? null : picked.map((o) => o.label).join(', ');
    final motion = CoilTheme.motionOf(context);
    // A new value blur-fades in over the old one.
    final switched = MotionSwitcher(
      motion: motion.fade,
      exitMotion: motion.fadeExit,
      debugLabel: 'CoilSelect.label',
      transitionBuilder: CoilBlurFade.transition(blur: 2, scale: 1),
      layoutBuilder: (current, previous) => Stack(
        alignment: AlignmentDirectional.centerStart,
        children: [...previous, ?current],
      ),
      child: KeyedSubtree(key: ValueKey(value), child: label),
    );

    return MotorInspectionScope(
      group: 'CoilSelect',
      child: Semantics(
        button: true,
        enabled: _enabled,
        expanded: _open,
        onTap: _enabled ? () => unawaited(_show(keyboard: false)) : null,
        value: value,
        hint: value == null ? widget.placeholder : null,
        child: CallbackShortcuts(
          bindings: {
            for (final key in [
              LogicalKeyboardKey.arrowDown,
              LogicalKeyboardKey.arrowUp,
            ])
              SingleActivator(key): () => unawaited(_show(keyboard: true)),
          },
          child: CoilInteraction(
            onPressed: _enabled
                ? () => unawaited(
                    _show(
                      keyboard:
                          CoilInputModality.instance.value ==
                          CoilModality.keyboard,
                    ),
                  )
                : null,
            focusNode: _focusNode,
            autofocus: widget.autofocus,
            statesController: _states,
            excludeFromSemantics: true,
            builder: (context, states, _) => CoilSelectTrigger(
              metrics: metrics,
              style: style,
              states: {
                ...states,
                // The list shows where the pointer is while open.
                if (_open) WidgetState.selected,
              },
              icon: widget.icon,
              indicator: widget.indicator,
              label: switched,
            ),
          ),
        ),
      ),
    );
  }
}

/// The bordered select trigger: leading glyph, label, chevron. Public so
/// goldens can render it in any state.
class CoilSelectTrigger extends StatelessWidget {
  /// Creates a trigger.
  const CoilSelectTrigger({
    required this.metrics,
    required this.label,
    required this.states,
    super.key,
    this.icon,
    this.indicator,
    this.style,
  });

  /// The size step.
  final CoilMetrics metrics;

  /// The resolved look; null computes it from the theme.
  final CoilSelectStyle? style;

  /// The label.
  final Widget label;

  /// The interaction states: hovered, pressed, focused (keyboard),
  /// disabled, selected (open).
  final Set<WidgetState> states;

  /// A leading glyph.
  final Widget? icon;

  /// Replaces the chevron.
  final Widget? indicator;

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final style =
        this.style ??
        CoilSelectStyle.fallback(
          theme,
          metrics,
        ).merge(CoilTheme.styleOf<CoilSelectStyle>(context));
    final motion = CoilTheme.motionOf(context);
    final open = states.contains(WidgetState.selected);
    final hovered = states.contains(WidgetState.hovered) && !open;
    final pressed = states.contains(WidgetState.pressed);
    final focusRing = states.contains(WidgetState.focused) && !open;
    final enabled = !states.contains(WidgetState.disabled);
    final radius = BorderRadius.circular(style.radius!);
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: CoilFocusRing(
        visible: focusRing,
        borderRadius: radius,
        child: MotionBuilder<Color>(
          value: style.triggerFill!.resolve(states)!,
          converter: MotionConverter.colorRgb,
          motion: pressed || hovered ? motion.fade : motion.fadeExit,
          debugLabel: 'CoilSelect trigger fill',
          builder: (context, fill, child) => DecoratedBox(
            decoration: ShapeDecoration(
              color: fill,
              shape: RoundedSuperellipseBorder(
                borderRadius: radius,
                side: BorderSide(color: style.triggerBorder!),
              ),
            ),
            child: child,
          ),
          child: ConstrainedBox(
            // A minimum height and symmetric padding, never a fixed height:
            // the trigger grows with larger text.
            constraints: BoxConstraints(
              minWidth: metrics.triggerMinWidth,
              minHeight: metrics.controlHeight,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: metrics.controlPaddingX,
                vertical: metrics.controlPaddingY(metrics.body),
              ),
              child: IconTheme(
                data: IconThemeData(
                  size: metrics.iconSize,
                  applyTextScaling: true,
                  color: style.indicator!.resolve(states),
                ),
                child: DefaultTextStyle(
                  style: style.textStyle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon case final icon?) ...[
                        icon,
                        SizedBox(width: metrics.gap),
                      ],
                      Flexible(fit: FlexFit.tight, child: label),
                      SizedBox(width: metrics.gap),
                      indicator ?? const _Chevron(),
                    ],
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

class _PopoverSurface extends StatelessWidget {
  const _PopoverSurface({
    required this.metrics,
    required this.style,
    required this.child,
  });

  final CoilMetrics metrics;
  final CoilSelectStyle style;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    // Concentric with the rows: item radius + the popup's inset.
    final radius = BorderRadius.circular(style.radius! + metrics.popupInset);
    return IntrinsicWidth(
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: style.surface,
          shadows: colors.shadow(3),
          shape: RoundedSuperellipseBorder(borderRadius: radius),
        ),
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: ShapeDecoration(
            shape: RoundedSuperellipseBorder(
              borderRadius: radius,
              side: colors.insetRing(3),
            ),
          ),
          child: ClipRSuperellipse(borderRadius: radius, child: child),
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
      size: Size.square(CoilIconSize.of(context)),
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
