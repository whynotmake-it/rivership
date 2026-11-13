import 'package:coil/src/components/chat_message/chat_message_style.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// A chat message's meta row: the time and the action buttons. It keeps
/// its height while hidden, so showing it never moves the transcript, and
/// Tab and screen readers still reach the buttons.
class ChatMessageMeta extends StatelessWidget {
  /// Creates the meta row.
  const ChatMessageMeta({
    required this.visible,
    required this.time,
    required this.actions,
    required this.showMotion,
    required this.hideMotion,
    required this.style,
    super.key,
  });

  /// Whether the row shows.
  final bool visible;

  /// The formatted time, if any.
  final String? time;

  /// The action buttons.
  final List<Widget> actions;

  /// The fade as the row shows.
  final Motion showMotion;

  /// The fade as the row hides.
  final Motion hideMotion;

  /// The resolved look.
  final CoilChatMessageStyle style;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: EdgeInsets.symmetric(horizontal: style.metaPaddingX!),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: style.metaGap!,
        children: [
          if (time case final time?)
            // The container's label already says the time.
            ExcludeSemantics(child: Text(time, style: style.metaStyle)),
          if (actions.isNotEmpty)
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: style.actionGap!,
              children: actions,
            ),
        ],
      ),
    );
    return IgnorePointer(
      ignoring: !visible,
      child: SingleMotionBuilder(
        value: visible ? 1 : 0,
        motion: visible ? showMotion : hideMotion,
        debugLabel: 'CoilChatMessage.meta',
        child: row,
        builder: (context, opacity, row) => Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          alwaysIncludeSemantics: true,
          child: row,
        ),
      ),
    );
  }
}
