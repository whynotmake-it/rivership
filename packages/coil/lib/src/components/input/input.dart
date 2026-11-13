import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/input/input_style.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// A single-line text field (`registry/default/input.tsx`).
///
/// Built on [CoilTextFieldCore], so it gets the platform's text editing:
/// IME composition (CJK, dead keys, emoji pickers), tap / double-tap /
/// long-press / drag selection, the platform's selection handles,
/// magnifier and context menu (the iOS system edit menu, the browser's on
/// web), and the shortcuts from [DefaultTextEditingShortcuts].
///
/// Like the web, focus is shown by the border turning
/// `foreground / 40%` (not the blue ring buttons use), and hover lays a
/// faint wash that focus removes.
class CoilInput extends StatefulWidget {
  /// Creates an input.
  const CoilInput({
    super.key,
    this.controller,
    this.focusNode,
    this.placeholder,
    this.leading,
    this.trailing,
    this.enabled = true,
    this.readOnly = false,
    this.invalid = false,
    this.obscureText = false,
    this.autofocus = false,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
    this.size,
    this.statesController,
    this.motion,
    this.style,
    this.semanticLabel,
  });

  /// The text controller; one is created if null.
  final TextEditingController? controller;

  /// The focus node; one is created if null.
  final FocusNode? focusNode;

  /// Shown, muted, while the field is empty. Usually a [Text].
  final Widget? placeholder;

  /// A widget before the text, usually an icon (muted).
  final Widget? leading;

  /// A widget after the text, usually an icon or a small button.
  final Widget? trailing;

  /// Whether the field accepts input and focus.
  final bool enabled;

  /// Whether the text can be selected but not changed.
  final bool readOnly;

  /// Marks the field invalid (`aria-invalid`): a red-tinted border.
  final bool invalid;

  /// Hides the text (passwords).
  final bool obscureText;

  /// Whether to take focus when first built.
  final bool autofocus;

  /// The software keyboard type.
  final TextInputType? keyboardType;

  /// The software keyboard's action button.
  final TextInputAction? textInputAction;

  /// Input formatters.
  final List<TextInputFormatter>? inputFormatters;

  /// Autofill hints.
  final Iterable<String>? autofillHints;

  /// Called when the text changes.
  final ValueChanged<String>? onChanged;

  /// Called when the user submits (Enter, outside a composition).
  final ValueChanged<String>? onSubmitted;

  /// Pins the field to one size step. Null follows [CoilAdaptiveScope].
  final CoilSize? size;

  /// Observes, and can force, hovered and focused looks.
  final WidgetStatesController? statesController;

  /// Overrides the theme's motion tokens ([CoilThemeData.motion]) for this
  /// instance.
  final CoilMotion? motion;

  /// Overrides for this field's look, on top of the theme's
  /// [CoilInputStyle] and the defaults.
  final CoilInputStyle? style;

  /// A label for assistive technology.
  final String? semanticLabel;

  @override
  State<CoilInput> createState() => _CoilInputState();
}

class _CoilInputState extends State<CoilInput> {
  /// The motion tokens, read where each animation starts so runtime
  /// theme changes apply to the next one.
  CoilMotion get _motion =>
      CoilTheme.motionOf(context, override: widget.motion);

  FocusNode? _ownFocusNode;
  WidgetStatesController? _ownStates;

  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownFocusNode ??= FocusNode());
  WidgetStatesController get _states =>
      widget.statesController ?? (_ownStates ??= WidgetStatesController());

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(CoilInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocusNode)?.removeListener(_onFocus);
      _focusNode.addListener(_onFocus);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocus);
    _ownFocusNode?.dispose();
    _ownStates?.dispose();
    super.dispose();
  }

  void _onFocus() => _states.update(WidgetState.focused, _focusNode.hasFocus);

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final colors = theme.colors;
    final sizes = CoilTheme.metricsOf(context, size: widget.size);
    final look = CoilInputStyle.fallback(
      theme,
      sizes,
    ).merge(CoilTheme.styleOf<CoilInputStyle>(context)).merge(widget.style);
    final style = look.textStyle!;
    final radius = BorderRadius.circular(look.radius!);

    Widget slot(Widget child) => IconTheme(
      data: IconThemeData(
        size: sizes.iconSize,
        applyTextScaling: true,
        color: look.placeholder,
        weight: CoilIconWeight.rest,
      ),
      child: DefaultTextStyle(
        style: style.copyWith(color: look.placeholder),
        child: child,
      ),
    );

    Widget decorate(BuildContext context, Widget field) => ListenableBuilder(
      listenable: _states,
      builder: (context, child) {
        final states = _states.value;
        final focused = states.contains(WidgetState.focused);
        final hovered = states.contains(WidgetState.hovered);
        final resolved = {
          if (focused) WidgetState.focused,
          if (hovered) WidgetState.hovered,
          if (widget.invalid) WidgetState.error,
        };
        final border = look.border!.resolve(resolved)!;
        final fill = look.fill!.resolve(resolved)!;
        return MotionBuilder<Color>(
          value: border,
          motion: _motion.fade,
          converter: MotionConverter.colorRgb,
          builder: (context, borderColor, child) => MotionBuilder<Color>(
            value: fill,
            motion: _motion.fade,
            converter: MotionConverter.colorRgb,
            // A minimum height plus symmetric padding: the text's line box
            // sits centered and the field grows with the text scale.
            builder: (context, fillColor, child) => Container(
              constraints: BoxConstraints(minHeight: look.minHeight!),
              decoration: ShapeDecoration(
                color: fillColor,
                shape: RoundedSuperellipseBorder(
                  borderRadius: radius,
                  side: BorderSide(color: borderColor),
                ),
              ),
              child: child,
            ),
            child: child,
          ),
          child: child,
        );
      },
      child: Padding(
        // 1 px of each side is the border.
        padding: EdgeInsets.symmetric(
          horizontal: sizes.controlPaddingX - 1,
          vertical: sizes.controlPaddingY(sizes.field) - 1,
        ),
        child: Row(
          spacing: sizes.gap,
          children: [
            if (widget.leading case final leading?) slot(leading),
            Expanded(child: field),
            if (widget.trailing case final trailing?) slot(trailing),
          ],
        ),
      ),
    );

    return Semantics(
      label: widget.semanticLabel,
      // Hover from hover-capable pointers only; the core handles taps,
      // selection, focus and the text cursor itself.
      child: CoilInteractionDetector(
        states: _states,
        enabled: widget.enabled,
        trackPress: false,
        child: Opacity(
          opacity: widget.enabled ? 1 : 0.5,
          child: CoilTextFieldCore(
            controller: widget.controller,
            focusNode: _focusNode,
            placeholder: widget.placeholder,
            placeholderColor: look.placeholder,
            style: style,
            strutStyle: StrutStyle.fromTextStyle(style, forceStrutHeight: true),
            cursorColor: colors.foreground,
            cursorWidth: 1,
            selectionColor: colors.brand.withValues(alpha: 0.3),
            enabled: widget.enabled,
            readOnly: widget.readOnly,
            obscureText: widget.obscureText,
            autofocus: widget.autofocus,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            keyboardAppearance: theme.brightness,
            inputFormatters: widget.inputFormatters,
            autofillHints: widget.autofillHints,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            decorationBuilder: decorate,
          ),
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      DiagnosticsProperty('controller', widget.controller, defaultValue: null),
    );
  }
}
