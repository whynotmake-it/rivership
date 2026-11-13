import 'package:flutter/widgets.dart';

/// An action on a `CoilChatMessage`, such as Copy or Retry.
///
/// Each action shows as an icon-only ghost button in the meta row. On
/// touch, long-pressing the message lists the same actions in a menu.
@immutable
class CoilChatMessageAction {
  /// Creates an action.
  const CoilChatMessageAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  /// The name: the button's semantic label and the menu row's text.
  final String label;

  /// The button's icon, styled through [IconTheme].
  final Widget icon;

  /// Called when the action runs. Null disables it.
  final VoidCallback? onPressed;
}
