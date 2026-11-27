import 'dart:async';

import 'package:coil/coil.dart';
import 'package:coil_example/src/widgets/icons.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';
import 'package:turns/turns.dart';

/// Circular jump-to-latest button for [TurnScrollView] demos.
///
/// Composes both [TurnScrollController.isAwayFromBottom] and
/// [TurnScrollController.isAutoScrolling] so the button stays hidden during
/// programmatic flights (turn pinning, `scrollTo`, and `scrollToBottom`) and
/// surfaces cleanly when the reader scrolls away from the latest message.
class ChatJumpToBottomButton extends StatelessWidget {
  const ChatJumpToBottomButton({
    required this.controller,
    super.key,
    this.buttonKey,
  });

  final TurnScrollController controller;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    final motion = CoilTheme.motionOf(context);
    return ListenableBuilder(
      listenable: Listenable.merge([
        controller.isAwayFromBottom,
        controller.isAutoScrolling,
      ]),
      builder: (context, child) {
        final shown =
            controller.isAwayFromBottom.value &&
            !controller.isAutoScrolling.value;
        return SingleMotionBuilder(
          value: shown ? 1 : 0,
          motion: shown ? motion.standard : motion.fadeExit,
          debugLabel: 'ChatJumpToBottomButton',
          child: child,
          builder: (context, progress, child) {
            final clamped = progress.clamp(0.0, 1.0);
            return IgnorePointer(
              ignoring: !shown,
              child: Opacity(
                opacity: clamped,
                child: Transform.translate(
                  offset: Offset(0, (1 - progress) * 14),
                  child: child,
                ),
              ),
            );
          },
        );
      },
      child: CoilButton.icon(
        key: buttonKey,
        size: CoilSize.compact,
        semanticLabel: 'Jump to latest',
        style: const CoilButtonStyle(radius: 999),
        icon: const CatalogIcon(Glyph.arrowDown),
        onPressed: () => unawaited(controller.scrollToBottom()),
      ),
    );
  }
}

/// Brand-tinted trailing caret rendered at the end of a streaming
/// [CoilMarkdown] reply.
class ChatStreamingCaret extends StatelessWidget {
  const ChatStreamingCaret({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = CoilTheme.of(context).colors;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: colors.brand,
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        child: const SizedBox(width: 6, height: 14),
      ),
    );
  }
}
