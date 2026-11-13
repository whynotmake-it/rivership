import 'package:coil/foundation.dart';
import 'package:coil/src/components/input/input_style.dart';
import 'package:coil/src/components/input/text_field_chrome.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// A single-line text field.
///
/// It uses the platform's own text editing: IME composition, selection
/// gestures and handles, the magnifier and the native edit menu.
///
/// Focus darkens the border, whether it came from a tap or the keyboard. A
/// hovering mouse adds a faint fill; touch never does. Inside a `CoilField`,
/// it takes the field's invalid state and focuses when the label is tapped.
/// Give it a field label: the placeholder is an example, not a label.
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
    this.textCapitalization = TextCapitalization.none,
    this.autocorrect = true,
    this.enableSuggestions = true,
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

  /// Marks the field invalid: a `destructive` border (focus wins). A
  /// `CoilField` with an error sets this for its control.
  final bool invalid;

  /// Hides the text (passwords).
  final bool obscureText;

  /// Whether to take focus when first built.
  final bool autofocus;

  /// The software keyboard type.
  final TextInputType? keyboardType;

  /// The software keyboard's action button.
  final TextInputAction? textInputAction;

  /// How the software keyboard capitalizes.
  final TextCapitalization textCapitalization;

  /// Whether the platform autocorrects. Always off while [obscureText].
  final bool autocorrect;

  /// Whether the keyboard offers suggestions. Always off while
  /// [obscureText].
  final bool enableSuggestions;

  /// Input formatters.
  final List<TextInputFormatter>? inputFormatters;

  /// Autofill hints.
  final Iterable<String>? autofillHints;

  /// Called when the text changes.
  final ValueChanged<String>? onChanged;

  /// Called when the keyboard's action button (or Return) submits, never
  /// for a Return that commits an IME composition.
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
  @override
  Widget build(BuildContext context) => TextFieldChrome(
    controller: widget.controller,
    focusNode: widget.focusNode,
    placeholder: widget.placeholder,
    leading: widget.leading,
    trailing: widget.trailing,
    enabled: widget.enabled,
    readOnly: widget.readOnly,
    invalid: widget.invalid,
    obscureText: widget.obscureText,
    autofocus: widget.autofocus,
    keyboardType: widget.keyboardType,
    textInputAction: widget.textInputAction,
    textCapitalization: widget.textCapitalization,
    autocorrect: widget.autocorrect,
    enableSuggestions: widget.enableSuggestions,
    inputFormatters: widget.inputFormatters,
    autofillHints: widget.autofillHints,
    onChanged: widget.onChanged,
    onSubmitted: widget.onSubmitted,
    size: widget.size,
    statesController: widget.statesController,
    motion: widget.motion,
    style: widget.style,
    semanticLabel: widget.semanticLabel,
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      DiagnosticsProperty('controller', widget.controller, defaultValue: null),
    );
  }
}
