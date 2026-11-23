import 'package:coil/foundation.dart';
import 'package:flutter/widgets.dart';

/// An action on a `CoilChatMessage`, such as Copy or Retry.
///
/// Each action shows as an icon-only ghost button in the meta row. On
/// touch, long-pressing the message lists the same actions in a menu.
///
/// For Copy, use coil's copy feedback so the icon shows a check after a
/// copy, as `CoilInputCopy` does:
///
/// ```dart
/// CoilChatMessageAction(
///   label: const Text('Copy'),
///   icon: CoilCopyGlyph.listening(controller: copy),
///   onPressed: () => copy.copy(text, context: context),
/// )
/// ```
@immutable
class CoilChatMessageAction {
  /// Creates an action.
  const CoilChatMessageAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    String? semanticLabel,
  }) // The field is null when the label names the action.
    // ignore: prefer_initializing_formals
    : _semanticLabel = semanticLabel;

  /// The long-press menu row's text, usually a [Text].
  ///
  /// The meta-row button shows only the [icon], so this is a widget the
  /// menu row can style, not arbitrary content.
  final Widget label;

  /// Names the icon-only button for screen readers.
  ///
  /// Defaults to the text of [label] when it is a [Text]. Set it when the
  /// label is another widget.
  String get semanticLabel {
    final name = _semanticLabel ?? plainTextOf(label);
    assert(
      name != null,
      'Set semanticLabel: the icon-only button needs a name, and label is '
      'not a Text to take one from.',
    );
    return name ?? '';
  }

  final String? _semanticLabel;

  /// The button's icon, styled through [IconTheme].
  final Widget icon;

  /// Called when the action runs. Null disables it.
  final VoidCallback? onPressed;
}
