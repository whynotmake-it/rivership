import 'package:flutter/widgets.dart';

/// An action on a `CoilChatMessage`, such as Copy or Retry.
///
/// Each action shows as an icon-only ghost button in the meta row; a mouse
/// hovering it shows [label] in a tooltip. On touch, long-pressing the
/// message lists the same actions in a menu, each row named by [label].
///
/// As with `IconButton`, the icon names the icon-only button for screen
/// readers: give it a `semanticLabel` (`Icon`, `CoilIcon`), or wrap one
/// without it in `Semantics(label: …)`.
///
/// ```dart
/// CoilChatMessageAction(
///   label: const Text('Retry'),
///   icon: const Icon(retryIcon, semanticLabel: 'Retry'),
///   onPressed: retry,
/// )
/// ```
///
/// For Copy, use coil's copy feedback so the icon shows a check after a
/// copy, as `CoilInputCopy` does:
///
/// ```dart
/// CoilChatMessageAction(
///   label: const Text('Copy'),
///   icon: Semantics(
///     label: 'Copy',
///     child: CoilCopyGlyph.listening(controller: copy),
///   ),
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
  });

  /// What the action is called, usually a [Text]: the long-press menu
  /// row's text, and the tooltip of the meta row's icon-only button.
  final Widget label;

  /// The button's icon, styled through [IconTheme]. Give it a
  /// `semanticLabel`, as for an `IconButton`: it is the icon-only button's
  /// name for screen readers.
  final Widget icon;

  /// Called when the action runs. Null disables it.
  final VoidCallback? onPressed;
}
