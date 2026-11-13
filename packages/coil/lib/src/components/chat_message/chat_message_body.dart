import 'dart:async';

import 'package:coil/button.dart';
import 'package:coil/foundation.dart';
import 'package:coil/primitives.dart';
import 'package:coil/src/components/chat_message/chat_message_action.dart';
import 'package:coil/src/components/chat_message/chat_message_menu.dart';
import 'package:coil/src/components/chat_message/chat_message_meta.dart';
import 'package:coil/src/components/chat_message/chat_message_style.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// A chat message's column: attachments, the body with its long-press
/// menu, and the meta row, which shows on hover or focus within.
class ChatMessageBody extends StatefulWidget {
  /// Creates the column.
  const ChatMessageBody({
    required this.user,
    required this.attachments,
    required this.time,
    required this.actions,
    required this.metrics,
    required this.metaIn,
    required this.metaOut,
    required this.style,
    required this.child,
    super.key,
  });

  /// Whether the user wrote it.
  final bool user;

  /// Widgets above the body.
  final List<Widget> attachments;

  /// The formatted time.
  final String? time;

  /// The actions.
  final List<CoilChatMessageAction> actions;

  /// The sizes.
  final CoilMetrics metrics;

  /// The meta row's fade in.
  final Motion metaIn;

  /// The meta row's fade out.
  final Motion metaOut;

  /// The resolved look.
  final CoilChatMessageStyle style;

  /// The message text.
  final Widget? child;

  @override
  State<ChatMessageBody> createState() => _ChatMessageBodyState();
}

class _ChatMessageBodyState extends State<ChatMessageBody> {
  final _states = WidgetStatesController();
  final _menu = CoilPopupController();
  bool _focusWithin = false;

  @override
  void dispose() {
    _states.dispose();
    _menu.dispose();
    super.dispose();
  }

  void _openMenu() => unawaited(_menu.open());

  @override
  Widget build(BuildContext context) {
    final style = widget.style;
    final gap = style.gap!;
    final hasMeta = widget.time != null || widget.actions.isNotEmpty;
    // Touch can't hover, and a screen reader can't act on hidden buttons.
    final alwaysMeta =
        widget.metrics.tier == CoilTier.touch ||
        MediaQuery.accessibleNavigationOf(context);

    Widget? body;
    if (widget.child case final child?) {
      body = DefaultTextStyle(
        style: style.textStyle!,
        // A bubble hugs its longest line instead of the full width.
        textWidthBasis: TextWidthBasis.longestLine,
        child: widget.user
            ? DecoratedBox(
                decoration: ShapeDecoration(
                  color: style.bubble,
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(style.radius!),
                  ),
                ),
                child: Padding(padding: style.padding!, child: child),
              )
            : Padding(
                padding: EdgeInsets.symmetric(vertical: style.padding!.top),
                child: child,
              ),
      );
    }

    final column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: widget.user
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      spacing: gap,
      children: [
        if (widget.attachments.isNotEmpty)
          Wrap(
            spacing: gap,
            runSpacing: gap,
            alignment: widget.user ? WrapAlignment.end : WrapAlignment.start,
            children: widget.attachments,
          ),
        if (body != null)
          ChatMessageMenu(
            controller: _menu,
            minWidth: style.menuMinWidth!,
            actions: [
              for (final action in widget.actions)
                CoilAction(
                  label: action.label,
                  leading: action.icon,
                  onPressed: action.onPressed,
                ),
            ],
            child: body,
          ),
        if (hasMeta)
          ListenableBuilder(
            listenable: _states,
            builder: (context, _) => ChatMessageMeta(
              visible:
                  alwaysMeta ||
                  _focusWithin ||
                  _states.value.contains(WidgetState.hovered),
              time: widget.time,
              actions: [
                for (final action in widget.actions)
                  CoilButton.icon(
                    onPressed: action.onPressed,
                    icon: action.icon,
                    semanticLabel: action.label,
                    variant: CoilButtonVariant.ghost,
                    size: CoilSize.compact,
                  ),
              ],
              showMotion: widget.metaIn,
              hideMotion: widget.metaOut,
              style: style,
            ),
          ),
      ],
    );

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      onFocusChange: (focused) => setState(() => _focusWithin = focused),
      child: CoilInteractionDetector(
        states: _states,
        trackPress: false,
        child: GestureDetector(
          supportedDevices: const {PointerDeviceKind.touch},
          onLongPress: widget.actions.isEmpty ? null : _openMenu,
          child: column,
        ),
      ),
    );
  }
}
