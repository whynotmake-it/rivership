import 'package:coil/foundation.dart';
import 'package:coil/src/components/input/input_style.dart';
import 'package:coil/src/components/input/text_field_chrome.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// A multi-line text field that looks like `CoilInput`.
///
/// It starts [minLines] tall and grows with its text up to [maxLines], then
/// scrolls. Return inserts a newline. A Return that only commits an IME
/// composition doesn't. Inside a `CoilField`, it takes the field's invalid
/// state and focuses when the label is tapped.
class CoilTextarea extends StatelessWidget {
  /// Creates a textarea.
  const CoilTextarea({
    super.key,
    this.controller,
    this.focusNode,
    this.placeholder,
    this.leading,
    this.trailing,
    this.minLines = 3,
    this.maxLines = 10,
    this.enabled = true,
    this.readOnly = false,
    this.invalid = false,
    this.autofocus = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.sentences,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.inputFormatters,
    this.autofillHints,
    this.onChanged,
    this.size,
    this.statesController,
    this.motion,
    this.style,
    this.semanticLabel,
  }) : assert(minLines > 0, 'A textarea shows at least one line.'),
       assert(
         maxLines == null || maxLines >= minLines,
         'maxLines must be at least minLines.',
       );

  /// The text controller; one is created if null.
  final TextEditingController? controller;

  /// The focus node; one is created if null.
  final FocusNode? focusNode;

  /// Shown, muted, while the field is empty. Usually a [Text].
  final Widget? placeholder;

  /// A widget before the first line, usually an icon (muted).
  final Widget? leading;

  /// A widget after the first line.
  final Widget? trailing;

  /// The lines the field shows when empty.
  final int minLines;

  /// The lines the field grows to before it scrolls; null grows without
  /// limit.
  final int? maxLines;

  /// Whether the field accepts input and focus.
  final bool enabled;

  /// Whether the text can be selected but not changed.
  final bool readOnly;

  /// Marks the field invalid: a `destructive` border (focus wins).
  final bool invalid;

  /// Whether to take focus when first built.
  final bool autofocus;

  /// The software keyboard type; multi-line text by default.
  final TextInputType? keyboardType;

  /// How the software keyboard capitalizes; sentences by default.
  final TextCapitalization textCapitalization;

  /// Whether the platform autocorrects.
  final bool autocorrect;

  /// Whether the keyboard offers suggestions.
  final bool enableSuggestions;

  /// Input formatters.
  final List<TextInputFormatter>? inputFormatters;

  /// Autofill hints.
  final Iterable<String>? autofillHints;

  /// Called when the text changes.
  final ValueChanged<String>? onChanged;

  /// Pins the field to one size step. Null follows [CoilAdaptiveScope].
  final CoilSize? size;

  /// Observes, and can force, hovered and focused looks.
  final WidgetStatesController? statesController;

  /// Overrides the theme's motion tokens for this instance.
  final CoilMotion? motion;

  /// Overrides for this field's look, on top of the theme's
  /// [CoilInputStyle] (shared with `CoilInput`) and the defaults.
  final CoilInputStyle? style;

  /// A label for assistive technology.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => TextFieldChrome(
    controller: controller,
    focusNode: focusNode,
    placeholder: placeholder,
    leading: leading,
    trailing: trailing,
    minLines: minLines,
    maxLines: maxLines,
    enabled: enabled,
    readOnly: readOnly,
    invalid: invalid,
    obscureText: false,
    autofocus: autofocus,
    keyboardType: keyboardType ?? TextInputType.multiline,
    textInputAction: TextInputAction.newline,
    textCapitalization: textCapitalization,
    autocorrect: autocorrect,
    enableSuggestions: enableSuggestions,
    inputFormatters: inputFormatters,
    autofillHints: autofillHints,
    onChanged: onChanged,
    onSubmitted: null,
    size: size,
    statesController: statesController,
    motion: motion,
    style: style,
    semanticLabel: semanticLabel,
  );
}
