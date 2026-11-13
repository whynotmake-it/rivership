import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/input/input_style.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// Marks one field of a `CoilInputGroup`: the group, not the field's own
/// pointer, decides whether it shows hover (the field nearest the pointer
/// does).
class InputGroupSlot extends InheritedWidget {
  /// Creates a slot for the group item at [index].
  const InputGroupSlot({required this.index, required super.child, super.key});

  /// The field's index in its group's hover region.
  /// See `CoilInput.index` / `CoilTextarea.index`.
  final int index;

  /// The slot above [context], if it's in an input group.
  static InputGroupSlot? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<InputGroupSlot>();

  @override
  bool updateShouldNotify(InputGroupSlot oldWidget) => oldWidget.index != index;
}

/// The chrome `CoilInput` and `CoilTextarea` share: a hairline field around
/// a [CoilTextFieldCore], with hover (pointer only), the focus border (any
/// focus) and the invalid border, colors on `fade`.
class TextFieldChrome extends StatefulWidget {
  /// Creates the chrome.
  const TextFieldChrome({
    required this.controller,
    required this.focusNode,
    required this.placeholder,
    required this.leading,
    required this.trailing,
    required this.enabled,
    required this.readOnly,
    required this.invalid,
    required this.obscureText,
    required this.autofocus,
    required this.keyboardType,
    required this.textInputAction,
    required this.textCapitalization,
    required this.autocorrect,
    required this.enableSuggestions,
    required this.inputFormatters,
    required this.autofillHints,
    required this.onChanged,
    required this.onSubmitted,
    required this.size,
    required this.statesController,
    required this.motion,
    required this.style,
    required this.semanticLabel,
    this.minLines,
    this.maxLines = 1,
    super.key,
  });

  /// See `CoilInput.controller` / `CoilTextarea.controller`.
  final TextEditingController? controller;

  /// See `CoilInput.focusNode` / `CoilTextarea.focusNode`.
  final FocusNode? focusNode;

  /// See `CoilInput.placeholder` / `CoilTextarea.placeholder`.
  final Widget? placeholder;

  /// See `CoilInput.leading` / `CoilTextarea.leading`.
  final Widget? leading;

  /// See `CoilInput.trailing` / `CoilTextarea.trailing`.
  final Widget? trailing;

  /// See `CoilInput.enabled` / `CoilTextarea.enabled`.
  final bool enabled;

  /// See `CoilInput.readOnly` / `CoilTextarea.readOnly`.
  final bool readOnly;

  /// See `CoilInput.invalid` / `CoilTextarea.invalid`.
  final bool invalid;

  /// See `CoilInput.obscureText` / `CoilTextarea.obscureText`.
  final bool obscureText;

  /// See `CoilInput.autofocus` / `CoilTextarea.autofocus`.
  final bool autofocus;

  /// See `CoilInput.keyboardType` / `CoilTextarea.keyboardType`.
  final TextInputType? keyboardType;

  /// See `CoilInput.textInputAction` / `CoilTextarea.textInputAction`.
  final TextInputAction? textInputAction;

  /// See `CoilInput.textCapitalization` / `CoilTextarea.textCapitalization`.
  final TextCapitalization textCapitalization;

  /// See `CoilInput.autocorrect` / `CoilTextarea.autocorrect`.
  final bool autocorrect;

  /// See `CoilInput.enableSuggestions` / `CoilTextarea.enableSuggestions`.
  final bool enableSuggestions;

  /// See `CoilInput.inputFormatters` / `CoilTextarea.inputFormatters`.
  final List<TextInputFormatter>? inputFormatters;

  /// See `CoilInput.autofillHints` / `CoilTextarea.autofillHints`.
  final Iterable<String>? autofillHints;

  /// See `CoilInput.onChanged` / `CoilTextarea.onChanged`.
  final ValueChanged<String>? onChanged;

  /// See `CoilInput.onSubmitted` / `CoilTextarea.onSubmitted`.
  final ValueChanged<String>? onSubmitted;

  /// See `CoilInput.size` / `CoilTextarea.size`.
  final CoilSize? size;

  /// See `CoilInput.statesController` / `CoilTextarea.statesController`.
  final WidgetStatesController? statesController;

  /// See `CoilInput.motion` / `CoilTextarea.motion`.
  final CoilMotion? motion;

  /// See `CoilInput.style` / `CoilTextarea.style`.
  final CoilInputStyle? style;

  /// See `CoilInput.semanticLabel` / `CoilTextarea.semanticLabel`.
  final String? semanticLabel;

  /// See `CoilInput.minLines` / `CoilTextarea.minLines`.
  final int? minLines;

  /// See `CoilInput.maxLines` / `CoilTextarea.maxLines`.
  final int? maxLines;

  @override
  State<TextFieldChrome> createState() => _TextFieldChromeState();
}

class _TextFieldChromeState extends State<TextFieldChrome> {
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
  void didUpdateWidget(TextFieldChrome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocusNode)?.removeListener(_onFocus);
      _focusNode.addListener(_onFocus);
      _onFocus();
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

  void _focusFromLabel() {
    if (_focusNode.canRequestFocus) _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = CoilTheme.of(context);
    final colors = theme.colors;
    final sizes = CoilTheme.metricsOf(context, size: widget.size);
    final multiline = widget.maxLines != 1;
    final look = CoilInputStyle.fallback(
      theme,
      sizes,
      multiline: multiline,
    ).merge(CoilTheme.styleOf<CoilInputStyle>(context)).merge(widget.style);
    final style = look.textStyle!;
    final radius = BorderRadius.circular(look.radius!);
    final invalid =
        widget.invalid || (CoilFieldScope.maybeOf(context)?.invalid ?? false);
    final groupSlot = InputGroupSlot.maybeOf(context);
    // Gives the hover to the group's nearest field instead of the pointer
    // over this one.
    final groupHovered = groupSlot == null
        ? null
        : CoilHoverItem.isActive(context, groupSlot.index);

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

    // Slots sit on the first line: centered in a single-line field, at the
    // top of a multi-line one, each in a box one line tall.
    final lineHeight =
        MediaQuery.textScalerOf(
          context,
        ).scale(style.fontSize!) *
        style.height!;
    Widget lineSlot(Widget child) => multiline
        ? ConstrainedBox(
            constraints: BoxConstraints(minHeight: lineHeight),
            child: Center(widthFactor: 1, child: slot(child)),
          )
        : slot(child);

    Widget decorate(BuildContext context, Widget field) => ListenableBuilder(
      listenable: _states,
      builder: (context, child) {
        final states = _states.value;
        final focused = states.contains(WidgetState.focused);
        final hovered =
            !widget.readOnly &&
            widget.enabled &&
            (groupHovered ?? states.contains(WidgetState.hovered));
        final resolved = {
          if (focused) WidgetState.focused,
          if (hovered) WidgetState.hovered,
          if (invalid) WidgetState.error,
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
          crossAxisAlignment: multiline
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            if (widget.leading case final leading?) lineSlot(leading),
            Expanded(child: field),
            if (widget.trailing case final trailing?) lineSlot(trailing),
          ],
        ),
      ),
    );

    return CoilFieldControl(
      onLabelTap: widget.enabled ? _focusFromLabel : null,
      child: Semantics(
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
              strutStyle: StrutStyle.fromTextStyle(
                style,
                forceStrutHeight: true,
              ),
              cursorColor: colors.foreground,
              cursorWidth: 1,
              selectionColor: colors.brand.withValues(alpha: 0.3),
              enabled: widget.enabled,
              readOnly: widget.readOnly,
              obscureText: widget.obscureText,
              autofocus: widget.autofocus,
              keyboardType: widget.keyboardType,
              textInputAction: widget.textInputAction,
              textCapitalization: widget.textCapitalization,
              autocorrect: widget.autocorrect,
              enableSuggestions: widget.enableSuggestions,
              keyboardAppearance: theme.brightness,
              // Keeps the field 16 clear of the keyboard and screen edges.
              scrollPadding: const EdgeInsets.all(16),
              inputFormatters: widget.inputFormatters,
              autofillHints: widget.autofillHints,
              minLines: widget.minLines,
              maxLines: widget.maxLines,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              decorationBuilder: decorate,
            ),
          ),
        ),
      ),
    );
  }
}
