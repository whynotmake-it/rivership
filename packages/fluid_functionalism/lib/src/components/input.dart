import 'package:fluid_functionalism/src/foundation/fluid_motion.dart';
import 'package:fluid_functionalism/src/foundation/fluid_sizes.dart';
import 'package:fluid_functionalism/src/foundation/fluid_theme.dart';
import 'package:fluid_functionalism/src/foundation/fluid_typography.dart'
    show FluidIconWeight;
import 'package:fluid_functionalism/src/primitives/fluid_interaction.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// A single-line text field (`registry/default/input.tsx`).
///
/// Built directly on [EditableText] with a
/// [TextSelectionGestureDetectorBuilder], so it gets the platform's text
/// editing for free: IME composition (CJK, dead keys, emoji pickers),
/// mouse drag / double-click / triple-click selection, and the desktop
/// shortcuts from [DefaultTextEditingShortcuts] (word and line navigation,
/// select all, copy, cut, paste, undo). It installs no shortcuts of its own,
/// so nothing above the field can steal keys from an active composition.
///
/// Like the web, focus is shown by the border turning
/// `foreground / 40%` (not the blue ring buttons use), and hover lays a
/// faint wash that focus removes.
class FluidInput extends StatefulWidget {
  /// Creates an input.
  const FluidInput({
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
    this.density,
    this.statesController,
    this.motion,
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

  /// Pins the field to one size step. Null follows [FluidSizeScope].
  final FluidDensity? density;

  /// Observes, and can force, hovered and focused looks.
  final WidgetStatesController? statesController;

  /// Overrides the theme's motion tokens ([FluidThemeData.motion]) for this
  /// instance.
  final FluidMotionThemeData? motion;

  /// A label for assistive technology.
  final String? semanticLabel;

  @override
  State<FluidInput> createState() => _FluidInputState();
}

class _FluidInputState extends State<FluidInput>
    implements TextSelectionGestureDetectorBuilderDelegate {
  /// The motion tokens, read where each animation starts so runtime
  /// theme changes apply to the next one.
  FluidMotionThemeData get _motion =>
      FluidTheme.motionOf(context, override: widget.motion);

  TextEditingController? _ownController;
  FocusNode? _ownFocusNode;
  WidgetStatesController? _ownStates;

  TextEditingController get _controller =>
      widget.controller ?? (_ownController ??= TextEditingController());
  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownFocusNode ??= FocusNode());
  WidgetStatesController get _states =>
      widget.statesController ?? (_ownStates ??= WidgetStatesController());

  late final _selectionGestures = TextSelectionGestureDetectorBuilder(
    delegate: this,
  );

  @override
  final GlobalKey<EditableTextState> editableTextKey =
      GlobalKey<EditableTextState>();

  @override
  bool get forcePressEnabled => false;

  @override
  bool get selectionEnabled => widget.enabled;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocus);
    _controller.addListener(_onText);
  }

  @override
  void didUpdateWidget(FluidInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocusNode)?.removeListener(_onFocus);
      _focusNode.addListener(_onFocus);
    }
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _ownController)?.removeListener(_onText);
      _controller.addListener(_onText);
    }
    _focusNode.canRequestFocus = widget.enabled;
    if (!widget.enabled && _focusNode.hasFocus) _focusNode.unfocus();
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocus);
    _controller.removeListener(_onText);
    _ownController?.dispose();
    _ownFocusNode?.dispose();
    _ownStates?.dispose();
    super.dispose();
  }

  void _onFocus() => _states.update(WidgetState.focused, _focusNode.hasFocus);

  void _onText() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final theme = FluidTheme.of(context);
    final colors = theme.colors;
    final sizes = FluidTheme.sizesOf(context, density: widget.density);
    final style = theme.typography.style(
      sizes.field,
      color: colors.foreground,
    );
    final radius = BorderRadius.circular(theme.shape.item);

    final editable = EditableText(
      key: editableTextKey,
      controller: _controller,
      focusNode: _focusNode,
      readOnly: widget.readOnly || !widget.enabled,
      obscureText: widget.obscureText,
      autofocus: widget.autofocus,
      style: style,
      strutStyle: StrutStyle.fromTextStyle(style, forceStrutHeight: true),
      cursorColor: colors.foreground,
      backgroundCursorColor: colors.mutedForeground,
      cursorWidth: 1,
      cursorOpacityAnimates: true,
      selectionColor: colors.fluidAccent.withValues(alpha: 0.3),
      selectionControls: emptyTextSelectionControls,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      keyboardAppearance: theme.brightness,
      inputFormatters: widget.inputFormatters,
      autofillHints: widget.autofillHints,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      rendererIgnoresPointer: true,
      enableInteractiveSelection: widget.enabled,
    );

    final placeholder = widget.placeholder;
    final field = Stack(
      alignment: AlignmentDirectional.centerStart,
      children: [
        if (placeholder != null && _controller.text.isEmpty)
          IgnorePointer(
            child: ExcludeSemantics(
              child: DefaultTextStyle(
                style: style.copyWith(color: colors.mutedForeground),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                child: placeholder,
              ),
            ),
          ),
        _selectionGestures.buildGestureDetector(
          behavior: HitTestBehavior.translucent,
          // Fills the field's height so a click anywhere in it lands, while
          // the text itself sits centered on its cap height.
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: DefaultTextStyle(
              style: style,
              child: editable,
            ),
          ),
        ),
      ],
    );

    Widget slot(Widget child) => IconTheme(
      data: IconThemeData(
        size: sizes.iconSize,
        color: colors.mutedForeground,
        weight: FluidIconWeight.rest,
      ),
      child: DefaultTextStyle(
        style: style.copyWith(color: colors.mutedForeground),
        child: child,
      ),
    );

    return Semantics(
      label: widget.semanticLabel,
      // Hover from hover-capable pointers only; EditableText handles taps
      // and focus itself, so the detector does not track presses.
      child: FluidInteractionDetector(
        states: _states,
        enabled: widget.enabled,
        trackPress: false,
        cursor: widget.enabled ? SystemMouseCursors.text : MouseCursor.defer,
        child: IgnorePointer(
          ignoring: !widget.enabled,
          child: Opacity(
            opacity: widget.enabled ? 1 : 0.5,
            child: ListenableBuilder(
              listenable: _states,
              builder: (context, child) {
                final states = _states.value;
                final focused = states.contains(WidgetState.focused);
                final hovered = states.contains(WidgetState.hovered);
                final border = focused
                    ? colors.foreground.withValues(alpha: 0.4)
                    : widget.invalid
                    ? colors.destructive.withValues(alpha: 0.5)
                    : colors.border;
                final fill = hovered && !focused
                    ? colors.hover
                    : colors.hover.withValues(alpha: 0);
                return MotionBuilder<Color>(
                  value: border,
                  motion: _motion.color,
                  converter: MotionConverter.colorRgb,
                  builder: (context, borderColor, child) =>
                      MotionBuilder<Color>(
                        value: fill,
                        motion: _motion.color,
                        converter: MotionConverter.colorRgb,
                        builder: (context, fillColor, child) => Container(
                          height: sizes.controlHeight,
                          decoration: BoxDecoration(
                            color: fillColor,
                            borderRadius: radius,
                            border: Border.all(color: borderColor),
                          ),
                          child: child,
                        ),
                        child: child,
                      ),
                  child: child,
                );
              },
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: sizes.controlPaddingX - 1,
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
            ),
          ),
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      DiagnosticsProperty('controller', _controller, defaultValue: null),
    );
  }
}
